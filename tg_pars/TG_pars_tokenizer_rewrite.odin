package tg_pars

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:strings"
import rf "core:reflect"
import tok "core:odin/tokenizer"
import "base:runtime"

// -----------------------------------------------------------------------------
// Reflection and pointer helpers
// -----------------------------------------------------------------------------

tg_ptr_offset :: proc(ptr: rawptr, offset: int) -> rawptr {
	if ptr == nil {
		return nil
	}
	return rawptr(mem.ptr_offset((^u8)(ptr), offset))
}

tg_type_name :: proc(info: ^rf.Type_Info) -> string {
	if info == nil {
		return ""
	}

	if rf.type_kind(info.id) == .Named {
		return info.variant.(rf.Type_Info_Named).name
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	rf.write_type_builder(&builder, info)
	return strings.clone(strings.to_string(builder))
}

tg_check_declared_type :: proc(field: rf.Struct_Field, declared_type: string, check_types: bool) -> bool {
	if len(declared_type) == 0 || !check_types {
		return true
	}
	return declared_type == tg_type_name(field.type)
}

Block :: struct {
	name: string,
	type_name: string,
	header_start: int,
	body_start: int,
	body_end: int,
	end: int,
	valid: bool,
}

// -----------------------------------------------------------------------------
// Tokenizer-backed parser
// -----------------------------------------------------------------------------

Tg_Token_Parser :: struct {
	tokens: [dynamic]tok.Token,
	tokenizer: tok.Tokenizer,
	current: tok.Token,
	source: string,
	path: string,
	index: int,
	valid: bool,
	check_types: bool,// only for wrighting
}

tg_tok_advance :: proc(p: ^Tg_Token_Parser) {
	for {
		p.current = tok.scan(&p.tokenizer)
		if p.current.kind == .Comment {
			continue
		}
		if p.current.kind == .Invalid || p.tokenizer.error_count != 0 {
			p.valid = false
		}
		return
	}
}

tg_tok_init :: proc(p: ^Tg_Token_Parser, source, path: string) {
	// Tokenizer.init does not overwrite flags, so zero the whole parser first.
	// This leaves .Insert_Semicolon disabled and newlines act as whitespace.
	p^ = {}
	p.source = source
	p.path = path
	p.valid = true
	tok.init(&p.tokenizer, source, path)
	tg_tok_advance(p)
}

tg_tok_init_at :: proc(p: ^Tg_Token_Parser, source, path: string, offset: int) {
	tg_tok_init(p, source, path)
	for p.current.kind != .EOF && p.current.pos.offset < offset {
		tg_tok_advance(p)
	}
}

tg_tok_error :: proc(p: ^Tg_Token_Parser, message: string) -> bool {
	fmt.printf("%s(%d:%d): %s\n", p.path, p.current.pos.line, p.current.pos.column, message)
	p.valid = false
	return false
}

tg_tok_expect :: proc(p: ^Tg_Token_Parser, kind: tok.Token_Kind) -> bool {
	if p.current.kind != kind {
		fmt.printf("%s(%d:%d): expected %s, got %s\n", p.path, p.current.pos.line, p.current.pos.column, tok.to_string(kind), tok.token_to_string(p.current))
		p.valid = false
		return false
	}
	tg_tok_advance(p)
	return p.valid
}

// Reads either `field = value`, `field :type= value`, or
// `block:Type:{...}`. The delimiter is the token that ended the declaration.
tg_tok_read_decl :: proc(p: ^Tg_Token_Parser) -> (name, declared_type: string, delimiter: tok.Token_Kind, ok: bool) {
	if p.current.kind != .Ident {
		return "", "", .Invalid, false
	}

	name = p.current.text
	tg_tok_advance(p)

	if p.current.kind == .Colon {
		tg_tok_advance(p)
		type_start := p.current.pos.offset
		brace_depth, bracket_depth, paren_depth := 0, 0, 0

		for p.current.kind != .EOF {
			if brace_depth == 0 && bracket_depth == 0 && paren_depth == 0 && (p.current.kind == .Eq || p.current.kind == .Colon) {
				break
			}

			#partial switch p.current.kind {
			case .Open_Brace: brace_depth += 1
			case .Close_Brace: brace_depth -= 1
			case .Open_Bracket: bracket_depth += 1
			case .Close_Bracket: bracket_depth -= 1
			case .Open_Paren: paren_depth += 1
			case .Close_Paren: paren_depth -= 1
			}
			if brace_depth < 0 || bracket_depth < 0 || paren_depth < 0 {
				return "", "", .Invalid, false
			}
			tg_tok_advance(p)
		}

		if brace_depth != 0 || bracket_depth != 0 || paren_depth != 0 {
			return "", "", .Invalid, false
		}
		type_end := p.current.pos.offset
		if type_end <= type_start {
			return "", "", .Invalid, false
		}
		declared_type = strings.trim_space(p.source[type_start:type_end])
		if len(declared_type) == 0 {
			return "", "", .Invalid, false
		}
	}

	delimiter = p.current.kind
	if delimiter != .Eq && delimiter != .Colon {
		return "", "", .Invalid, false
	}

	tg_tok_advance(p)
	return name, declared_type, delimiter, p.valid
}

// Skips one value, whatever its type. All settings containers use braces, so
// balanced token braces are enough; strings and comments are already tokens.
tg_tok_skip_braced :: proc(p: ^Tg_Token_Parser) -> (close: tok.Token, ok: bool) {
	if p.current.kind != .Open_Brace {
		return {}, false
	}

	depth := 0
	for {
		if p.current.kind == .EOF {
			return {}, false
		}

		current := p.current
		#partial switch current.kind {
		case .Open_Brace:
			depth += 1
		case .Close_Brace:
			depth -= 1
		}

		tg_tok_advance(p)
		if !p.valid {
			return {}, false
		}
		if depth == 0 {
			return current, true
		}
	}
}

tg_tok_skip_value :: proc(p: ^Tg_Token_Parser) -> bool {
	if p.current.kind == .EOF || !p.valid {
		return false
	}

	if p.current.kind == .Open_Brace {
		_, ok := tg_tok_skip_braced(p)
		return ok
	}

	if p.current.kind == .Add || p.current.kind == .Sub {
		tg_tok_advance(p)
		if p.current.kind != .Integer && p.current.kind != .Float {
			return false
		}
	}

	tg_tok_advance(p)
	return p.valid
}

// Extracts a scalar token. A leading +/- is joined with the following numeric
// token using source offsets, so negative values remain a single parse string.
tg_tok_read_atom :: proc(p: ^Tg_Token_Parser) -> (value: string, kind: tok.Token_Kind, ok: bool) {
	if p.current.kind == .Add || p.current.kind == .Sub {
		start := p.current.pos.offset
		tg_tok_advance(p)
		if p.current.kind != .Integer && p.current.kind != .Float {
			return "", .Invalid, false
		}
		end := p.current.pos.offset + len(p.current.text)
		value = p.source[start:end]
		kind = p.current.kind
		tg_tok_advance(p)
		return value, kind, p.valid
	}

	#partial switch p.current.kind {
	case .Ident, .Integer, .Float, .String:
		value = p.current.text
		kind = p.current.kind
		tg_tok_advance(p)
		return value, kind, p.valid
	case:
		return "", .Invalid, false
	}
}

// Shared brace/comma handling for structs, arrays, maps, and enumerated arrays.
tg_tok_container_begin :: proc(p: ^Tg_Token_Parser) -> (empty, ok: bool) {
	if p.current.kind != .Open_Brace {
		return false, false
	}
	tg_tok_advance(p)
	if !p.valid {
		return false, false
	}

	if p.current.kind == .Close_Brace {
		tg_tok_advance(p)
		return true, p.valid
	}
	return false, true
}

tg_tok_container_next :: proc(p: ^Tg_Token_Parser) -> (done, ok: bool) {
	if p.current.kind == .Close_Brace {
		tg_tok_advance(p)
		return true, p.valid
	}

	if p.current.kind != .Comma {
		return false, false
	}
	tg_tok_advance(p)

	if p.current.kind == .Close_Brace {
		tg_tok_advance(p)
		return true, p.valid
	}
	return false, p.valid
}

// -----------------------------------------------------------------------------
// Type support
// -----------------------------------------------------------------------------

tg_is_supported_map_key :: proc(info: ^rf.Type_Info) -> bool {
	if info == nil {
		return false
	}

	base_info := rf.type_info_base(info)
	if rf.is_enum(base_info) {
		return true
	}

	switch rf.typeid_base(base_info.id) {
	case typeid_of(bool), typeid_of(int), typeid_of(uint), typeid_of(i8), typeid_of(i16), typeid_of(i32), typeid_of(i64), typeid_of(u8), typeid_of(u16), typeid_of(u32), typeid_of(u64), typeid_of(f32), typeid_of(f64), typeid_of(string):
		return true
	case:
		return false
	}
}

tg_is_supported_type :: proc(info: ^rf.Type_Info) -> bool {
	if info == nil {
		return false
	}

	base_info := rf.type_info_base(info)
	if rf.is_enum(base_info) || rf.is_struct(base_info) {
		return true
	}

	if rf.is_array(base_info) {
		return tg_is_supported_type(base_info.variant.(rf.Type_Info_Array).elem)
	}
	if rf.is_enumerated_array(base_info) {
		return tg_is_supported_type(base_info.variant.(rf.Type_Info_Enumerated_Array).elem)
	}
	if rf.is_dynamic_array(base_info) {
		return tg_is_supported_type(base_info.variant.(rf.Type_Info_Dynamic_Array).elem)
	}
	if rf.is_fixed_capacity_dynamic_array(base_info) {
		return tg_is_supported_type(base_info.variant.(rf.Type_Info_Fixed_Capacity_Dynamic_Array).elem)
	}
	if rf.is_dynamic_map(base_info) {
		map_info := base_info.variant.(rf.Type_Info_Map)
		return tg_is_supported_map_key(map_info.key) && tg_is_supported_type(map_info.value)
	}

	switch rf.typeid_base(base_info.id) {
	case typeid_of(bool), typeid_of(int), typeid_of(uint), typeid_of(i8), typeid_of(i16), typeid_of(i32), typeid_of(i64), typeid_of(u8), typeid_of(u16), typeid_of(u32), typeid_of(u64), typeid_of(f32), typeid_of(f64), typeid_of(string):
		return true
	case:
		return false
	}
}

// -----------------------------------------------------------------------------
// Shared sequence metadata
// -----------------------------------------------------------------------------

Tg_Sequence_Kind :: enum {
	Fixed,
	Dynamic,
	Fixed_Capacity,
}

Tg_Sequence_Info :: struct {
	kind: Tg_Sequence_Kind,
	data: rawptr,
	count: int,
	capacity: int,
	elem_size: int,
	elem: ^rf.Type_Info,
	dynam: ^runtime.Raw_Dynamic_Array,
	len_ptr: ^int,
}

tg_get_sequence_info :: proc(value_ptr: rawptr, info: ^rf.Type_Info) -> (seq: Tg_Sequence_Info, ok: bool) {
	if rf.is_array(info) {
		array := info.variant.(rf.Type_Info_Array)
		return Tg_Sequence_Info{
			kind = .Fixed,
			data = value_ptr,
			count = array.count,
			capacity = array.count,
			elem_size = array.elem_size,
			elem = array.elem,
		}, true
	}

	if rf.is_dynamic_array(info) {
		array_info := info.variant.(rf.Type_Info_Dynamic_Array)
		array := (^runtime.Raw_Dynamic_Array)(value_ptr)
		return Tg_Sequence_Info{
			kind = .Dynamic,
			data = array.data,
			count = array.len,
			capacity = array.cap,
			elem_size = array_info.elem_size,
			elem = array_info.elem,
			dynam = array,
		}, true
	}

	if rf.is_fixed_capacity_dynamic_array(info) {
		array_info := info.variant.(rf.Type_Info_Fixed_Capacity_Dynamic_Array)
		array_len := (^int)(tg_ptr_offset(value_ptr, cast(int)array_info.len_offset))
		return Tg_Sequence_Info{
			kind = .Fixed_Capacity,
			data = value_ptr,
			count = array_len^,
			capacity = array_info.capacity,
			elem_size = array_info.elem_size,
			elem = array_info.elem,
			len_ptr = array_len,
		}, true
	}

	return {}, false
}

tg_is_compound_type :: proc(info: ^rf.Type_Info) -> bool {
	if info == nil {
		return false
	}
	base_info := rf.type_info_base(info)
	return rf.is_array(base_info) || rf.is_enumerated_array(base_info) || rf.is_dynamic_array(base_info) || rf.is_fixed_capacity_dynamic_array(base_info) || rf.is_dynamic_map(base_info) || rf.is_struct(base_info)
}

// -----------------------------------------------------------------------------
// Writer
// -----------------------------------------------------------------------------

tg_write_indent :: proc(builder: ^strings.Builder, depth: int) {
	for _ in 0..<depth {
		strings.write_byte(builder, '\t')
	}
}

tg_write_unsupported_comment :: proc(builder: ^strings.Builder, field_name: string, info: ^rf.Type_Info, depth: int) {
	tg_write_indent(builder, depth)
	strings.write_string(builder, "// ")
	strings.write_string(builder, field_name)
	strings.write_string(builder, ": unsupported type ")
	rf.write_type_builder(builder, info)
	strings.write_byte(builder, '\n')
}

tg_write_sequence :: proc(builder: ^strings.Builder, seq: Tg_Sequence_Info, depth: int, write_types: bool) -> bool {
	if seq.count < 0 || seq.count > seq.capacity || seq.elem_size <= 0 || (seq.count > 0 && seq.data == nil) {
		return false
	}

	if seq.count == 0 {
		strings.write_string(builder, "{}")
		return true
	}

	if !tg_is_compound_type(seq.elem) {
		strings.write_byte(builder, '{')
		for i in 0..<seq.count {
			if i > 0 {
				strings.write_string(builder, ", ")
			}
			elem_ptr := tg_ptr_offset(seq.data, i*seq.elem_size)
			if !tg_write_value(builder, elem_ptr, seq.elem, depth, write_types) {
				return false
			}
		}
		strings.write_byte(builder, '}')
		return true
	}

	strings.write_string(builder, "{\n")
	for i in 0..<seq.count {
		tg_write_indent(builder, depth+1)
		elem_ptr := tg_ptr_offset(seq.data, i*seq.elem_size)
		if !tg_write_value(builder, elem_ptr, seq.elem, depth+1, write_types) {
			return false
		}
		strings.write_string(builder, ",\n")
	}
	tg_write_indent(builder, depth)
	strings.write_byte(builder, '}')
	return true
}

tg_enum_read_i64 :: proc(value_ptr: rawptr, info: ^rf.Type_Info) -> (value: i64, ok: bool) {
	base_info := rf.type_info_base(info)
	switch rf.typeid_base(base_info.id) {
	case typeid_of(int): return i64((^int)(value_ptr)^), true
	case typeid_of(uint): return i64((^uint)(value_ptr)^), true
	case typeid_of(i8): return i64((^i8)(value_ptr)^), true
	case typeid_of(i16): return i64((^i16)(value_ptr)^), true
	case typeid_of(i32): return i64((^i32)(value_ptr)^), true
	case typeid_of(i64): return (^i64)(value_ptr)^, true
	case typeid_of(u8): return i64((^u8)(value_ptr)^), true
	case typeid_of(u16): return i64((^u16)(value_ptr)^), true
	case typeid_of(u32): return i64((^u32)(value_ptr)^), true
	case typeid_of(u64): return i64((^u64)(value_ptr)^), true
	case:
		return 0, false
	}
}

tg_enum_write_i64 :: proc(value_ptr: rawptr, info: ^rf.Type_Info, value: i64) -> bool {
	base_info := rf.type_info_base(info)
	switch rf.typeid_base(base_info.id) {
	case typeid_of(int):
		if size_of(int) == 4 && (value < -2147483648 || value > 2147483647) { return false }
		(^int)(value_ptr)^ = int(value)
	case typeid_of(uint):
		if value < 0 || (size_of(uint) == 4 && value > 4294967295) { return false }
		(^uint)(value_ptr)^ = uint(value)
	case typeid_of(i8):
		if value < -128 || value > 127 { return false }
		(^i8)(value_ptr)^ = i8(value)
	case typeid_of(i16):
		if value < -32768 || value > 32767 { return false }
		(^i16)(value_ptr)^ = i16(value)
	case typeid_of(i32):
		if value < -2147483648 || value > 2147483647 { return false }
		(^i32)(value_ptr)^ = i32(value)
	case typeid_of(i64):
		(^i64)(value_ptr)^ = value
	case typeid_of(u8):
		if value < 0 || value > 255 { return false }
		(^u8)(value_ptr)^ = u8(value)
	case typeid_of(u16):
		if value < 0 || value > 65535 { return false }
		(^u16)(value_ptr)^ = u16(value)
	case typeid_of(u32):
		if value < 0 || value > 4294967295 { return false }
		(^u32)(value_ptr)^ = u32(value)
	case typeid_of(u64):
		if value < 0 { return false }
		(^u64)(value_ptr)^ = u64(value)
	case:
		return false
	}
	return true
}

tg_write_enum :: proc(builder: ^strings.Builder, value_ptr: rawptr, info: ^rf.Type_Info) -> bool {
	enum_info := info.variant.(rf.Type_Info_Enum)
	value, ok := tg_enum_read_i64(value_ptr, enum_info.base)
	if !ok {
		return false
	}
	for i in 0..<len(enum_info.values) {
		if i64(enum_info.values[i]) == value {
			strings.write_string(builder, enum_info.names[i])
			return true
		}
	}
	strings.write_i64(builder, value)
	return true
}

tg_write_scalar :: proc(builder: ^strings.Builder, value_ptr: rawptr, info: ^rf.Type_Info) -> bool {
	switch rf.typeid_base(info.id) {
	case typeid_of(bool):
		if (^bool)(value_ptr)^ { strings.write_string(builder, "true") } else { strings.write_string(builder, "false") }
	case typeid_of(int): strings.write_int(builder, (^int)(value_ptr)^)
	case typeid_of(uint): strings.write_uint(builder, (^uint)(value_ptr)^)
	case typeid_of(i8): strings.write_i64(builder, i64((^i8)(value_ptr)^))
	case typeid_of(i16): strings.write_i64(builder, i64((^i16)(value_ptr)^))
	case typeid_of(i32): strings.write_i64(builder, i64((^i32)(value_ptr)^))
	case typeid_of(i64): strings.write_i64(builder, (^i64)(value_ptr)^)
	case typeid_of(u8): strings.write_u64(builder, u64((^u8)(value_ptr)^))
	case typeid_of(u16): strings.write_u64(builder, u64((^u16)(value_ptr)^))
	case typeid_of(u32): strings.write_u64(builder, u64((^u32)(value_ptr)^))
	case typeid_of(u64): strings.write_u64(builder, (^u64)(value_ptr)^)
	case typeid_of(f32): strings.write_f32(builder, (^f32)(value_ptr)^, 'g')
	case typeid_of(f64): strings.write_f64(builder, (^f64)(value_ptr)^, 'g')
	case typeid_of(string): strings.write_quoted_string(builder, (^string)(value_ptr)^)
	case:
		return false
	}
	return true
}

tg_write_map :: proc(builder: ^strings.Builder, value_ptr: rawptr, info: ^rf.Type_Info, depth: int, write_types: bool) -> bool {
	map_type := info.variant.(rf.Type_Info_Map)
	map_value := (^runtime.Raw_Map)(value_ptr)^
	if map_value.len == 0 {
		strings.write_string(builder, "{}")
		return true
	}

	keys, values, hashes, _, _ := runtime.map_kvh_data_dynamic(map_value, map_type.map_info)
	strings.write_string(builder, "{\n")
	for i in 0..<runtime.map_cap(map_value) {
		if !runtime.map_hash_is_valid(hashes[i]) {
			continue
		}

		key_ptr := rawptr(runtime.map_cell_index_dynamic(keys, map_type.map_info.ks, uintptr(i)))
		value_ptr := rawptr(runtime.map_cell_index_dynamic(values, map_type.map_info.vs, uintptr(i)))

		tg_write_indent(builder, depth+1)
		if !tg_write_value(builder, key_ptr, map_type.key, depth+1, write_types) {
			return false
		}
		strings.write_string(builder, " = ")
		if !tg_write_value(builder, value_ptr, map_type.value, depth+1, write_types) {
			return false
		}
		strings.write_string(builder, ",\n")
	}
	tg_write_indent(builder, depth)
	strings.write_byte(builder, '}')
	return true
}

tg_write_enumerated_array :: proc(builder: ^strings.Builder, value_ptr: rawptr, info: ^rf.Type_Info, depth: int, write_types: bool) -> bool {
	array := info.variant.(rf.Type_Info_Enumerated_Array)
	index_info := rf.type_info_base(array.index)
	if !rf.is_enum(index_info) {
		return false
	}
	index_enum := index_info.variant.(rf.Type_Info_Enum)
	if array.count == 0 {
		strings.write_string(builder, "{}")
		return true
	}

	strings.write_string(builder, "{\n")
	for i in 0..<len(index_enum.names) {
		enum_value := i64(index_enum.values[i])
		elem_index := i
		if !array.is_sparse {
			elem_index = int(enum_value - i64(array.min_value))
		}
		if elem_index < 0 || elem_index >= array.count {
			continue
		}

		tg_write_indent(builder, depth+1)
		strings.write_string(builder, index_enum.names[i])
		strings.write_string(builder, " = ")
		elem_ptr := tg_ptr_offset(value_ptr, elem_index*array.elem_size)
		if !tg_write_value(builder, elem_ptr, array.elem, depth+1, write_types) {
			return false
		}
		strings.write_string(builder, ",\n")
	}
	tg_write_indent(builder, depth)
	strings.write_byte(builder, '}')
	return true
}

tg_write_struct_fields :: proc(builder: ^strings.Builder, value_ptr: rawptr, info: ^rf.Type_Info, depth: int, write_types: bool, braces: bool) -> bool {
	root_info := rf.type_info_base(info)
	if !rf.is_struct(root_info) {
		return false
	}

	field_depth := depth
	value_depth := depth
	if braces {
		strings.write_string(builder, "{\n")
		field_depth += 1
		value_depth += 1
	}

	for i in 0..<rf.struct_field_count(root_info.id) {
		field := rf.struct_field_at(root_info.id, i)
		if !tg_is_supported_type(field.type) {
			tg_write_unsupported_comment(builder, field.name, field.type, field_depth)
			continue
		}

		tg_write_indent(builder, field_depth)
		strings.write_string(builder, field.name)
		if write_types {
			strings.write_string(builder, " :")
			rf.write_type_builder(builder, field.type)
			strings.write_string(builder, "= ")
		} else {
			strings.write_string(builder, " = ")
		}

		field_ptr := tg_ptr_offset(value_ptr, cast(int)field.offset)
		if !tg_write_value(builder, field_ptr, field.type, value_depth, write_types) {
			return false
		}
		if braces {
			strings.write_string(builder, ",\n")
		} else {
			strings.write_byte(builder, '\n')
		}
	}

	if braces {
		tg_write_indent(builder, depth)
		strings.write_byte(builder, '}')
	}
	return true
}

tg_write_value :: proc(builder: ^strings.Builder, value_ptr: rawptr, info: ^rf.Type_Info, depth: int, write_types: bool = false) -> bool {
	if info == nil {
		return false
	}

	base_info := rf.type_info_base(info)

	seq, is_sequence := tg_get_sequence_info(value_ptr, base_info)
	if is_sequence {
		return tg_write_sequence(builder, seq, depth, write_types)
	}
	if rf.is_dynamic_map(base_info) {
		return tg_write_map(builder, value_ptr, base_info, depth, write_types)
	}
	if rf.is_enumerated_array(base_info) {
		return tg_write_enumerated_array(builder, value_ptr, base_info, depth, write_types)
	}
	if rf.is_struct(base_info) {
		return tg_write_struct_fields(builder, value_ptr, base_info, depth, write_types, true)
	}
	if rf.is_enum(base_info) {
		return tg_write_enum(builder, value_ptr, base_info)
	}
	return tg_write_scalar(builder, value_ptr, base_info)
}

tg_write_fields :: proc(builder: ^strings.Builder, settings: rawptr, info: ^rf.Type_Info, depth: int, write_types: bool = false) -> bool {
	return tg_write_struct_fields(builder, settings, info, depth, write_types, false)
}

// -----------------------------------------------------------------------------
// Tokenizer-based block discovery (also used by named-block writing)
// -----------------------------------------------------------------------------

tg_scan_blocks :: proc(text, path, target_name, target_type: string) -> (target: Block, any_block, found, valid: bool, match_count: int) {
	p: Tg_Token_Parser
	tg_tok_init(&p, text, path)
	valid = true

	for p.current.kind != .EOF {
		if !p.valid {
			valid = false
			return
		}
		if p.current.kind != .Ident {
			tg_tok_advance(&p)
			continue
		}

		header_name := p.current.text
		header_offset := p.current.pos.offset
		name, type_name, delimiter, decl_ok := tg_tok_read_decl(&p)
		if !decl_ok {
			valid = false
			return
		}

		if delimiter == .Eq {
			if !tg_tok_skip_value(&p) {
				valid = false
				return
			}
			continue
		}

		if delimiter != .Colon || p.current.kind != .Open_Brace {
			valid = false
			return
		}

		any_block = true
		open_token := p.current
		close_token, close_ok := tg_tok_skip_braced(&p)
		if !close_ok {
			valid = false
			return
		}

		block := Block{
			name = name,
			type_name = type_name,
			header_start = header_offset,
			body_start = open_token.pos.offset + len(open_token.text),
			body_end = close_token.pos.offset,
			end = close_token.pos.offset + len(close_token.text),
			valid = true,
		}

		matches := (target_name != "" && header_name == target_name) || (target_name == "" && target_type != "" && type_name == target_type)
		if matches {
			match_count += 1
			if !found {
				target = block
				found = true
			}
		}
	}

	valid = p.valid
	return
}

tg_write :: proc(path: string, settings: ^$T, name: string = "", write_types: bool = false) -> bool {
	if settings == nil {
		return false
	}

	root_info := rf.type_info_base(type_info_of(T))
	if !rf.is_struct(root_info) {
		return false
	}

	if name == "" {
		builder := strings.builder_make()
		defer strings.builder_destroy(&builder)
		if !tg_write_fields(&builder, rawptr(settings), root_info, 0, write_types) {
			return false
		}
		err := os.write_entire_file(path, strings.to_string(builder))
		return err == nil
	}

	if strings.index_byte(name, ':') >= 0 || strings.index_byte(name, '\n') >= 0 || strings.index_byte(name, '\r') >= 0 || strings.index_byte(name, '{') >= 0 || strings.index_byte(name, '}') >= 0 {
		return false
	}

	type_name := tg_type_name(type_info_of(T))
	if type_name == "" {
		return false
	}

	block_builder := strings.builder_make()
	defer strings.builder_destroy(&block_builder)
	strings.write_string(&block_builder, name)
	strings.write_byte(&block_builder, ':')
	strings.write_string(&block_builder, type_name)
	strings.write_string(&block_builder, ":{\n")
	if !tg_write_fields(&block_builder, rawptr(settings), root_info, 1, write_types) {
		return false
	}
	strings.write_string(&block_builder, "}\n")
	block_text := strings.to_string(block_builder)

	old_data, read_err := os.read_entire_file(path, context.allocator)
	old_text := ""
	if read_err == nil {
		old_text = strings.clone(string(old_data))
		delete(old_data)
	}

	target, _, found_target, scan_ok, match_count := tg_scan_blocks(old_text, path, name, "")
	if !scan_ok || match_count > 1 {
		return false
	}

	output := strings.builder_make()
	defer strings.builder_destroy(&output)
	if found_target {
		replace_end := target.end
		if replace_end < len(old_text) && old_text[replace_end] == '\r' {
			replace_end += 1
		}
		if replace_end < len(old_text) && old_text[replace_end] == '\n' {
			replace_end += 1
		}
		strings.write_string(&output, old_text[:target.header_start])
		strings.write_string(&output, block_text)
		strings.write_string(&output, old_text[replace_end:])
	} else {
		strings.write_string(&output, old_text)
		if len(old_text) > 0 && old_text[len(old_text)-1] != '\n' {
			strings.write_byte(&output, '\n')
		}
		strings.write_string(&output, block_text)
	}

	err := os.write_entire_file(path, strings.to_string(output))
	return err == nil
}

// -----------------------------------------------------------------------------
// Reader scalar and enum values
// -----------------------------------------------------------------------------

tg_read_enum :: proc(p: ^Tg_Token_Parser, value_ptr: rawptr, info: ^rf.Type_Info) -> bool {
	token, _, ok := tg_tok_read_atom(p)
	if !ok {
		return false
	}

	enum_info := info.variant.(rf.Type_Info_Enum)
	for i in 0..<len(enum_info.names) {
		if enum_info.names[i] == token {
			return tg_enum_write_i64(value_ptr, enum_info.base, i64(enum_info.values[i]))
		}
	}

	value, value_ok := strconv.parse_i64(token)
	if !value_ok {
		return false
	}
	return tg_enum_write_i64(value_ptr, enum_info.base, value)
}

tg_read_scalar :: proc(p: ^Tg_Token_Parser, value_ptr: rawptr, info: ^rf.Type_Info) -> bool {
	token, token_kind, ok := tg_tok_read_atom(p)
	if !ok {
		return false
	}

	switch rf.typeid_base(info.id) {
	case typeid_of(bool):
		value, parse_ok := strconv.parse_bool(token)
		if !parse_ok { return false }
		(^bool)(value_ptr)^ = value

	case typeid_of(int):
		value, parse_ok := strconv.parse_int(token)
		if !parse_ok { return false }
		(^int)(value_ptr)^ = value

	case typeid_of(uint):
		value, parse_ok := strconv.parse_uint(token)
		if !parse_ok { return false }
		(^uint)(value_ptr)^ = value

	case typeid_of(i8):
		value, parse_ok := strconv.parse_i64(token)
		if !parse_ok || value < i64(min(i8)) || value > i64(max(i8)) { return false }
		(^i8)(value_ptr)^ = i8(value)

	case typeid_of(i16):
		value, parse_ok := strconv.parse_i64(token)
		if !parse_ok || value < i64(min(i16)) || value > i64(max(i16)) { return false }
		(^i16)(value_ptr)^ = i16(value)

	case typeid_of(i32):
		value, parse_ok := strconv.parse_i64(token)
		if !parse_ok || value < i64(min(i32)) || value > i64(max(i32)) { return false }
		(^i32)(value_ptr)^ = i32(value)

	case typeid_of(i64):
		value, parse_ok := strconv.parse_i64(token)
		if !parse_ok { return false }
		(^i64)(value_ptr)^ = value

	case typeid_of(u8):
		value, parse_ok := strconv.parse_u64(token)
		if !parse_ok || value > u64(max(u8)) { return false }
		(^u8)(value_ptr)^ = u8(value)

	case typeid_of(u16):
		value, parse_ok := strconv.parse_u64(token)
		if !parse_ok || value > u64(max(u16)) { return false }
		(^u16)(value_ptr)^ = u16(value)

	case typeid_of(u32):
		value, parse_ok := strconv.parse_u64(token)
		if !parse_ok || value > u64(max(u32)) { return false }
		(^u32)(value_ptr)^ = u32(value)

	case typeid_of(u64):
		value, parse_ok := strconv.parse_u64(token)
		if !parse_ok { return false }
		(^u64)(value_ptr)^ = value

	case typeid_of(f32):
		if token_kind != .Float && token_kind != .Integer { return false }
		value, parse_ok := strconv.parse_f32(token)
		if !parse_ok { return false }
		(^f32)(value_ptr)^ = value

	case typeid_of(f64):
		if token_kind != .Float && token_kind != .Integer { return false }
		value, parse_ok := strconv.parse_f64(token)
		if !parse_ok { return false }
		(^f64)(value_ptr)^ = value

	case typeid_of(string):
		if token_kind == .String {
			value, allocated, unquote_ok := strconv.unquote_string(token)
			if !unquote_ok { return false }
			if allocated {
				(^string)(value_ptr)^ = value
			} else {
				(^string)(value_ptr)^ = strings.clone(value)
			}
		} else {
			(^string)(value_ptr)^ = strings.clone(token)
		}

	case:
		return false
	}
	return true
}

// -----------------------------------------------------------------------------
// Reader containers
// -----------------------------------------------------------------------------

tg_zero_raw :: proc(data: rawptr, size: int) {
	bytes := ([^]u8)(data)
	for i in 0..<size {
		bytes[i] = 0
	}
}

tg_dynamic_array_reserve :: proc(array: ^runtime.Raw_Dynamic_Array, elem_info: ^rf.Type_Info, elem_size, wanted: int) -> bool {
	if wanted < 0 || elem_size <= 0 || array.cap < 0 {
		return false
	}
	if wanted <= array.cap && (wanted == 0 || array.data != nil) {
		return true
	}
	if array.allocator.procedure == nil {
		array.allocator = context.allocator
	}

	new_cap := max(4, array.cap)
	for new_cap < wanted {
		if new_cap > max(int)/2 {
			return false
		}
		new_cap *= 2
	}
	if new_cap > max(int)/elem_size {
		return false
	}

	old_size := 0
	if array.data != nil {
		old_size = array.cap*elem_size
	}
	new_size := new_cap*elem_size
	new_data, err := mem.resize(array.data, old_size, new_size, elem_info.align, array.allocator)
	if err != nil || new_data == nil {
		return false
	}
	array.data = new_data
	array.cap = new_cap
	return true
}

tg_read_sequence :: proc(p: ^Tg_Token_Parser, seq: Tg_Sequence_Info, check_types: bool) -> bool {
	if seq.elem_size <= 0 || seq.capacity < 0 {
		return false
	}

	switch seq.kind {
	case .Dynamic:
		seq.dynam.len = 0
	case .Fixed_Capacity:
		seq.len_ptr^ = 0
	case .Fixed:
	}

	empty, ok := tg_tok_container_begin(p)
	if !ok {
		return false
	}
	if empty {
		return true
	}

	index := 0
	for {
		elem_ptr: rawptr = nil
		switch seq.kind {
		case .Fixed:
			if index < seq.capacity {
				elem_ptr = tg_ptr_offset(seq.data, index*seq.elem_size)
			} else if !tg_tok_skip_value(p) {
				return false
			}

		case .Dynamic:
			if !tg_dynamic_array_reserve(seq.dynam, seq.elem, seq.elem_size, index+1) {
				return false
			}
			elem_ptr = tg_ptr_offset(seq.dynam.data, index*seq.elem_size)
			tg_zero_raw(elem_ptr, seq.elem.size)

		case .Fixed_Capacity:
			if index >= seq.capacity {
				return false
			}
			elem_ptr = tg_ptr_offset(seq.data, index*seq.elem_size)
			tg_zero_raw(elem_ptr, seq.elem.size)
		}

		if elem_ptr != nil && !tg_read_value(p, elem_ptr, seq.elem, check_types) {
			return false
		}

		index += 1
		switch seq.kind {
		case .Dynamic:
			seq.dynam.len = index
		case .Fixed_Capacity:
			seq.len_ptr^ = index
		case .Fixed:
		}

		done, valid := tg_tok_container_next(p)
		if !valid {
			return false
		}
		if done {
			return true
		}
	}
}

tg_read_map :: proc(p: ^Tg_Token_Parser, value_ptr: rawptr, info: ^rf.Type_Info, check_types: bool) -> bool {
	map_type := info.variant.(rf.Type_Info_Map)
	map_ptr := (^runtime.Raw_Map)(value_ptr)
	if map_ptr.allocator.procedure == nil {
		map_ptr.allocator = context.allocator
	}
	runtime.map_clear_dynamic(map_ptr, map_type.map_info)

	empty, ok := tg_tok_container_begin(p)
	if !ok {
		return false
	}
	if empty {
		return true
	}

	key_size := max(1, map_type.key.size)
	value_size := max(1, map_type.value.size)
	key_align := max(1, map_type.key.align)
	value_align := max(1, map_type.value.align)
	padding := (value_align - key_size%value_align) % value_align
	value_offset := key_size + padding
	if value_offset > max(int)-value_size {
		return false
	}

	allocator := context.allocator
	scratch, err := mem.alloc_bytes(value_offset+value_size, max(key_align, value_align), allocator)
	if err != nil || len(scratch) == 0 {
		return false
	}
	defer mem.free_bytes(scratch, allocator)

	key_ptr := rawptr(&scratch[0])
	value_ptr_scratch := rawptr(&scratch[value_offset])

	for {
		if !tg_read_value(p, key_ptr, map_type.key, check_types) {
			return false
		}
		if !tg_tok_expect(p, .Eq) {
			return false
		}

		_, entry_value_ptr, _, entry_err := runtime.__dynamic_map_entry(map_ptr, map_type.map_info, key_ptr, value_ptr_scratch)
		if entry_err != nil || entry_value_ptr == nil {
			return false
		}
		if !tg_read_value(p, entry_value_ptr, map_type.value, check_types) {
			return false
		}

		done, valid := tg_tok_container_next(p)
		if !valid {
			return false
		}
		if done {
			return true
		}
	}
}

tg_read_enumerated_array :: proc(p: ^Tg_Token_Parser, value_ptr: rawptr, info: ^rf.Type_Info, check_types: bool) -> bool {
	array := info.variant.(rf.Type_Info_Enumerated_Array)
	index_info := rf.type_info_base(array.index)
	if !rf.is_enum(index_info) {
		return false
	}
	index_enum := index_info.variant.(rf.Type_Info_Enum)

	empty, ok := tg_tok_container_begin(p)
	if !ok {
		return false
	}
	if empty {
		return true
	}

	for {
		if p.current.kind != .Ident {
			return false
		}
		key := p.current.text
		tg_tok_advance(p)
		if !tg_tok_expect(p, .Eq) {
			return false
		}

		enum_index := -1
		for i in 0..<len(index_enum.names) {
			if index_enum.names[i] == key {
				enum_index = i
				break
			}
		}

		elem_index := -1
		if enum_index >= 0 {
			elem_index = enum_index
			if !array.is_sparse {
				elem_index = int(i64(index_enum.values[enum_index]) - i64(array.min_value))
			}
		}

		if elem_index < 0 || elem_index >= array.count {
			if !tg_tok_skip_value(p) {
				return false
			}
		} else {
			elem_ptr := tg_ptr_offset(value_ptr, elem_index*array.elem_size)
			if !tg_read_value(p, elem_ptr, array.elem, check_types) {
				return false
			}
		}

		done, valid := tg_tok_container_next(p)
		if !valid {
			return false
		}
		if done {
			return true
		}
	}
}

tg_read_field :: proc(p: ^Tg_Token_Parser, value_ptr: rawptr, info: ^rf.Type_Info, check_types: bool) -> bool {
	key, declared_type, delimiter, ok := tg_tok_read_decl(p)
	if !ok || delimiter != .Eq || len(key) == 0 {
		return false
	}

	field := rf.struct_field_by_name(info.id, key)
	if field.name == "" || !tg_is_supported_type(field.type) {
		return tg_tok_skip_value(p)
	}

	if !tg_check_declared_type(field, declared_type, check_types) {
		fmt.printf("%s(%d:%d): field '%s' declares type '%s', expected '%s'\n", p.path, p.current.pos.line, p.current.pos.column, key, declared_type, tg_type_name(field.type))
		return false
	}

	field_ptr := tg_ptr_offset(value_ptr, cast(int)field.offset)
	if !tg_read_value(p, field_ptr, field.type, check_types) {
		fmt.printf("%s(%d:%d): failed to read field '%s'\n", p.path, p.current.pos.line, p.current.pos.column, key)
		return false
	}
	return true
}

Tg_Field_List_Mode :: enum {
	Flat,
	Block,
	Braced,
}

tg_read_struct_fields :: proc(p: ^Tg_Token_Parser, value_ptr: rawptr, info: ^rf.Type_Info, check_types: bool, mode: Tg_Field_List_Mode) -> bool {
	root_info := rf.type_info_base(info)
	if !rf.is_struct(root_info) {
		return false
	}

	if mode == .Flat {
		for p.current.kind != .EOF {
			if !tg_read_field(p, value_ptr, root_info, check_types) {
				return false
			}
			if p.current.kind == .Comma {
				tg_tok_advance(p)
			}
		}
		return p.valid
	}

	if mode == .Block {
		for p.current.kind != .Close_Brace {
			if p.current.kind == .EOF || !p.valid {
				return false
			}
			if !tg_read_field(p, value_ptr, root_info, check_types) {
				return false
			}
			if p.current.kind == .Comma {
				tg_tok_advance(p)
			}
		}
		tg_tok_advance(p)
		return p.valid
	}

	empty, ok := tg_tok_container_begin(p)
	if !ok {
		return false
	}
	if empty {
		return true
	}

	for {
		if !tg_read_field(p, value_ptr, root_info, check_types) {
			return false
		}
		done, valid := tg_tok_container_next(p)
		if !valid {
			return false
		}
		if done {
			return true
		}
	}
}

tg_read_value :: proc(p: ^Tg_Token_Parser, value_ptr: rawptr, info: ^rf.Type_Info, check_types: bool = true) -> bool {
	if info == nil || !p.valid {
		return false
	}

	base_info := rf.type_info_base(info)
	if rf.is_dynamic_map(base_info) {
		return tg_read_map(p, value_ptr, base_info, check_types)
	}
	if rf.is_enumerated_array(base_info) {
		return tg_read_enumerated_array(p, value_ptr, base_info, check_types)
	}

	seq, is_sequence := tg_get_sequence_info(value_ptr, base_info)
	if is_sequence {
		return tg_read_sequence(p, seq, check_types)
	}
	if rf.is_struct(base_info) {
		return tg_read_struct_fields(p, value_ptr, base_info, check_types, .Braced)
	}
	if rf.is_enum(base_info) {
		return tg_read_enum(p, value_ptr, base_info)
	}
	return tg_read_scalar(p, value_ptr, base_info)
}

// -----------------------------------------------------------------------------
// Public reader
// -----------------------------------------------------------------------------

tg_read :: proc(path: string, settings: ^$T, name: string = "", check_types: bool = true) -> bool {
	if settings == nil {
		return false
	}

	root_info := rf.type_info_base(type_info_of(T))
	if !rf.is_struct(root_info) {
		return false
	}

	data, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		return false
	}
	defer delete(data)

	text := string(data)
	type_name := tg_type_name(type_info_of(T))
	target, any_blocks, found, scan_ok, match_count := tg_scan_blocks(text, path, name, type_name)
	if !scan_ok {
		return false
	}

	if any_blocks {
		if !found {
			if name != "" {
				fmt.printf("Settings: block '%s' was not found in '%s'\n", name, path)
			} else {
				fmt.printf("Settings: no block for type '%s' was found in '%s'\n", type_name, path)
			}
			return false
		}
		if name != "" && match_count > 1 {
			fmt.printf("Settings: block name '%s' appears more than once in '%s'\n", name, path)
			return false
		}
		if check_types && target.type_name != type_name {
			fmt.printf("Settings: block '%s' declares type '%s', expected '%s'\n", target.name, target.type_name, type_name)
			return false
		}

		p: Tg_Token_Parser
		tg_tok_init_at(&p, text, path, target.body_start)
		return tg_read_struct_fields(&p, rawptr(settings), root_info, check_types, .Block)
	}

	p: Tg_Token_Parser
	tg_tok_init(&p, text, path)
	return tg_read_struct_fields(&p, rawptr(settings), root_info, check_types, .Flat)
}
