package tg_pars

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:strings"
import rf "core:reflect"
import tok "core:odin/tokenizer"
import "base:runtime"

// Tg_Token_Parser :: struct {
// 	source: string,
// 	path: string,
// 	tokens: [dynamic]tok.Token,
// 	index: int,
// 	check_types: bool,
// }

Tg_Token_Sequence_Kind :: enum {
	Fixed,
	Dynamic,
	Fixed_Capacity,
}

tg_tok_current :: proc(p: ^Tg_Token_Parser) -> tok.Token {
	if len(p.tokens) == 0 {
		return tok.Token{kind = .EOF}
	}
	return p.tokens[min(p.index, len(p.tokens)-1)]
}

// tg_tok_advance :: proc(p: ^Tg_Token_Parser) {
// 	if p.index < len(p.tokens)-1 {
// 		p.index += 1
// 	}
// }

// tg_tok_error :: proc(p: ^Tg_Token_Parser, message: string) {
// 	token := tg_tok_current(p)
// 	fmt.eprintf("%s(%d:%d): %s\n", p.path, token.pos.line, token.pos.column, message)
// }

// tg_tok_expect :: proc(p: ^Tg_Token_Parser, kind: tok.Token_Kind) -> bool {
// 	if tg_tok_current(p).kind != kind {
// 		return false
// 	}
// 	tg_tok_advance(p)
// 	return true
// }

tg_tok_skip_separators :: proc(p: ^Tg_Token_Parser) {
	for tg_tok_current(p).kind == .Semicolon {
		tg_tok_advance(p)
	}
}

// tg_tok_init :: proc(p: ^Tg_Token_Parser, source, path: string, check_types: bool = false) -> bool {
// 	lexer: tok.Tokenizer = {}
// 	tok.init(&lexer, source, path)

// 	tokens: [dynamic]tok.Token
// 	for {
// 		token := tok.scan(&lexer)
// 		if token.kind != .Comment {
// 			append(&tokens, token)
// 		}
// 		if token.kind == .EOF {
// 			break
// 		}
// 	}

// 	if lexer.error_count != 0 {
// 		delete(tokens)
// 		return false
// 	}

// 	p^ = Tg_Token_Parser{
// 		source = source,
// 		path = path,
// 		tokens = tokens,
// 		index = 0,
// 		check_types = check_types,
// 	}
// 	return true
// }

tg_tok_read_field_header :: proc(p: ^Tg_Token_Parser) -> (name, declared_type: string, ok: bool) {
	token := tg_tok_current(p)
	if token.kind != .Ident {
		return "", "", false
	}

	name = token.text
	tg_tok_advance(p)

	if tg_tok_current(p).kind == .Colon {
		tg_tok_advance(p)
		if tg_tok_current(p).kind == .Eq || tg_tok_current(p).kind == .EOF {
			return "", "", false
		}
		type_start := tg_tok_current(p).pos.offset

		for tg_tok_current(p).kind != .Eq && tg_tok_current(p).kind != .EOF {
			tg_tok_advance(p)
		}

		if tg_tok_current(p).kind != .Eq {
			return "", "", false
		}

		type_end := tg_tok_current(p).pos.offset
		if type_end < type_start || type_end > len(p.source) {
			return "", "", false
		}
		declared_type = strings.trim_space(p.source[type_start:type_end])
	}

	if !tg_tok_expect(p, .Eq) {
		return "", "", false
	}

	return name, declared_type, true
}

// tg_tok_container_begin :: proc(p: ^Tg_Token_Parser) -> (empty, ok: bool) {
// 	if !tg_tok_expect(p, .Open_Brace) {
// 		return false, false
// 	}

// 	if tg_tok_current(p).kind == .Close_Brace {
// 		tg_tok_advance(p)
// 		return true, true
// 	}

// 	return false, true
// }

// tg_tok_container_next :: proc(p: ^Tg_Token_Parser) -> (done, ok: bool) {
// 	kind := tg_tok_current(p).kind
// 	if kind == .Close_Brace {
// 		tg_tok_advance(p)
// 		return true, true
// 	}

// 	if kind != .Comma {
// 		return false, false
// 	}
// 	tg_tok_advance(p)

// 	if tg_tok_current(p).kind == .Close_Brace {
// 		tg_tok_advance(p)
// 		return true, true
// 	}

// 	return false, true
// }

// tg_tok_skip_value :: proc(p: ^Tg_Token_Parser) -> bool {
// 	kind := tg_tok_current(p).kind

// 	if kind == .EOF || kind == .Close_Brace || kind == .Comma {
// 		return false
// 	}

// 	if kind == .Open_Brace {
// 		depth := 0
// 		for {
// 			kind = tg_tok_current(p).kind
// 			if kind == .EOF {
// 				return false
// 			}
// 			if kind == .Open_Brace {
// 				depth += 1
// 			} else if kind == .Close_Brace {
// 				depth -= 1
// 			}
// 			tg_tok_advance(p)
// 			if depth == 0 {
// 				return true
// 			}
// 		}
// 	}

// 	if kind == .Add || kind == .Sub {
// 		tg_tok_advance(p)
// 		kind = tg_tok_current(p).kind
// 		if kind != .Integer && kind != .Float {
// 			return false
// 		}
// 	}

// 	tg_tok_advance(p)
// 	return true
// }

tg_tok_read_number_text :: proc(p: ^Tg_Token_Parser, allow_float: bool) -> (text: string, kind: tok.Token_Kind, ok: bool) {
	first := tg_tok_current(p)
	start := first.pos.offset

	if first.kind == .Add || first.kind == .Sub {
		tg_tok_advance(p)
		first = tg_tok_current(p)
	}

	if first.kind != .Integer && !(allow_float && first.kind == .Float) {
		return "", .Invalid, false
	}

	end := first.pos.offset + len(first.text)
	if start < 0 || end > len(p.source) || end < start {
		return "", .Invalid, false
	}

	text = p.source[start:end]
	kind = first.kind
	tg_tok_advance(p)
	return text, kind, true
}

tg_tok_read_scalar :: proc(p: ^Tg_Token_Parser, value_ptr: rawptr, info: ^rf.Type_Info) -> bool {
	switch rf.typeid_base(info.id) {
	case typeid_of(bool):
		token := tg_tok_current(p)
		if token.kind != .Ident {
			return false
		}
		value, ok := strconv.parse_bool(token.text)
		if !ok {
			return false
		}
		(^bool)(value_ptr)^ = value
		tg_tok_advance(p)

	case typeid_of(int):
		token, kind, ok := tg_tok_read_number_text(p, false)
		if !ok || kind != .Integer {
			return false
		}
		value, value_ok := strconv.parse_int(token)
		if !value_ok {
			return false
		}
		(^int)(value_ptr)^ = value

	case typeid_of(uint):
		token, kind, ok := tg_tok_read_number_text(p, false)
		if !ok || kind != .Integer || strings.has_prefix(token, "-") {
			return false
		}
		value, value_ok := strconv.parse_uint(token)
		if !value_ok {
			return false
		}
		(^uint)(value_ptr)^ = value

	case typeid_of(i8):
		token, kind, ok := tg_tok_read_number_text(p, false)
		if !ok || kind != .Integer {
			return false
		}
		value, value_ok := strconv.parse_i64(token)
		if !value_ok || value < i64(min(i8)) || value > i64(max(i8)) {
			return false
		}
		(^i8)(value_ptr)^ = i8(value)

	case typeid_of(i16):
		token, kind, ok := tg_tok_read_number_text(p, false)
		if !ok || kind != .Integer {
			return false
		}
		value, value_ok := strconv.parse_i64(token)
		if !value_ok || value < i64(min(i16)) || value > i64(max(i16)) {
			return false
		}
		(^i16)(value_ptr)^ = i16(value)

	case typeid_of(i32):
		token, kind, ok := tg_tok_read_number_text(p, false)
		if !ok || kind != .Integer {
			return false
		}
		value, value_ok := strconv.parse_i64(token)
		if !value_ok || value < i64(min(i32)) || value > i64(max(i32)) {
			return false
		}
		(^i32)(value_ptr)^ = i32(value)

	case typeid_of(i64):
		token, kind, ok := tg_tok_read_number_text(p, false)
		if !ok || kind != .Integer {
			return false
		}
		value, value_ok := strconv.parse_i64(token)
		if !value_ok {
			return false
		}
		(^i64)(value_ptr)^ = value

	case typeid_of(u8):
		token, kind, ok := tg_tok_read_number_text(p, false)
		if !ok || kind != .Integer || strings.has_prefix(token, "-") {
			return false
		}
		value, value_ok := strconv.parse_u64(token)
		if !value_ok || value > u64(max(u8)) {
			return false
		}
		(^u8)(value_ptr)^ = u8(value)

	case typeid_of(u16):
		token, kind, ok := tg_tok_read_number_text(p, false)
		if !ok || kind != .Integer || strings.has_prefix(token, "-") {
			return false
		}
		value, value_ok := strconv.parse_u64(token)
		if !value_ok || value > u64(max(u16)) {
			return false
		}
		(^u16)(value_ptr)^ = u16(value)

	case typeid_of(u32):
		token, kind, ok := tg_tok_read_number_text(p, false)
		if !ok || kind != .Integer || strings.has_prefix(token, "-") {
			return false
		}
		value, value_ok := strconv.parse_u64(token)
		if !value_ok || value > u64(max(u32)) {
			return false
		}
		(^u32)(value_ptr)^ = u32(value)

	case typeid_of(u64):
		token, kind, ok := tg_tok_read_number_text(p, false)
		if !ok || kind != .Integer || strings.has_prefix(token, "-") {
			return false
		}
		value, value_ok := strconv.parse_u64(token)
		if !value_ok {
			return false
		}
		(^u64)(value_ptr)^ = value

	case typeid_of(f32):
		token, _, ok := tg_tok_read_number_text(p, true)
		if !ok {
			return false
		}
		value, value_ok := strconv.parse_f32(token)
		if !value_ok {
			return false
		}
		(^f32)(value_ptr)^ = value

	case typeid_of(f64):
		token, _, ok := tg_tok_read_number_text(p, true)
		if !ok {
			return false
		}
		value, value_ok := strconv.parse_f64(token)
		if !value_ok {
			return false
		}
		(^f64)(value_ptr)^ = value

	case typeid_of(string):
		token := tg_tok_current(p)
		if token.kind == .String || token.kind == .Rune {
			value, allocated, ok := strconv.unquote_string(token.text)
			if !ok {
				return false
			}
			if allocated {
				(^string)(value_ptr)^ = value
			} else {
				(^string)(value_ptr)^ = strings.clone(value)
			}
		} else if token.kind == .Ident || token.kind == .Integer || token.kind == .Float {
			// Keep compatibility with older files that used unquoted scalar strings.
			(^string)(value_ptr)^ = strings.clone(token.text)
		} else {
			return false
		}
		tg_tok_advance(p)

	case:
		return false
	}

	return true
}

tg_tok_read_enum :: proc(p: ^Tg_Token_Parser, value_ptr: rawptr, info: ^rf.Type_Info) -> bool {
	enum_info := info.variant.(rf.Type_Info_Enum)
	token := tg_tok_current(p)

	if token.kind == .Ident {
		for i in 0..<len(enum_info.names) {
			if enum_info.names[i] == token.text {
				if !tg_enum_write_i64(value_ptr, enum_info.base, i64(enum_info.values[i])) {
					return false
				}
				tg_tok_advance(p)
				return true
			}
		}
	}

	number, kind, ok := tg_tok_read_number_text(p, false)
	if !ok || kind != .Integer {
		return false
	}
	value, value_ok := strconv.parse_i64(number)
	if !value_ok {
		return false
	}
	return tg_enum_write_i64(value_ptr, enum_info.base, value)
}

tg_tok_read_container_sequence :: proc(
	p: ^Tg_Token_Parser,
	data_ptr: rawptr,
	fixed_count, elem_size: int,
	elem_info: ^rf.Type_Info,
	kind: Tg_Token_Sequence_Kind,
	dynamic_array: ^runtime.Raw_Dynamic_Array,
	len_ptr: ^int,
) -> bool {
	if elem_size <= 0 || fixed_count < 0 {
		return false
	}

	switch kind {
	case .Dynamic:
		if dynamic_array == nil {
			return false
		}
		dynamic_array.len = 0
	case .Fixed_Capacity:
		if len_ptr == nil {
			return false
		}
		len_ptr^ = 0
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

		switch kind {
		case .Fixed:
			if index < fixed_count {
				elem_ptr = rawptr(uintptr(data_ptr) + uintptr(index*elem_size))
			}
		case .Dynamic:
			if !tg_dynamic_array_reserve(dynamic_array, elem_info, elem_size, index+1) {
				return false
			}
			elem_ptr = rawptr(uintptr(dynamic_array.data) + uintptr(index*elem_size))
			tg_zero_raw(elem_ptr, elem_info.size)
		case .Fixed_Capacity:
			if index >= fixed_count {
				return false
			}
			elem_ptr = rawptr(uintptr(data_ptr) + uintptr(index*elem_size))
			tg_zero_raw(elem_ptr, elem_info.size)
		}

		if elem_ptr != nil {
			if !tg_tok_read_value(p, elem_ptr, elem_info) {
				return false
			}
		} else if !tg_tok_skip_value(p) {
			return false
		}

		index += 1
		switch kind {
		case .Dynamic:
			dynamic_array.len = index
		case .Fixed_Capacity:
			len_ptr^ = index
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

tg_tok_read_map :: proc(p: ^Tg_Token_Parser, value_ptr: rawptr, info: ^rf.Type_Info) -> bool {
	map_type := info.variant.(rf.Type_Info_Map)
	map_ptr := (^runtime.Raw_Map)(value_ptr)

	empty, ok := tg_tok_container_begin(p)
	if !ok {
		return false
	}

	if map_ptr.allocator.procedure == nil {
		map_ptr.allocator = context.allocator
	}
	runtime.map_clear_dynamic(map_ptr, map_type.map_info)

	if empty {
		return true
	}

	key_size := max(1, map_type.key.size)
	value_size := max(1, map_type.value.size)
	key_align := max(1, map_type.key.align)
	value_align := max(1, map_type.value.align)
	
	value_offset := key_size
	padding := value_offset % value_align
	if padding != 0 {
		value_offset += value_align-padding
	}
	
	if value_offset > max(int)-value_size {
		return false
	}
	
	scratch, err := mem.alloc_bytes(value_offset+value_size, max(key_align, value_align))
	if err != nil {
		return false
	}
	defer mem.free_bytes(scratch)
	
	key_ptr := rawptr(&scratch[0])
	value_ptr := rawptr(&scratch[value_offset])

	for {
		if !tg_tok_read_value(p, key_ptr, map_type.key) {
			return false
		}

		if !tg_tok_expect(p, .Eq) {
			return false
		}

		_, entry_value_ptr, _, entry_err := runtime.__dynamic_map_entry(map_ptr, map_type.map_info, key_ptr, value_ptr)
		if entry_err != nil || entry_value_ptr == nil {
			return false
		}

		if !tg_tok_read_value(p, entry_value_ptr, map_type.value) {
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

tg_tok_read_enumerated_array :: proc(p: ^Tg_Token_Parser, value_ptr: rawptr, info: ^rf.Type_Info) -> bool {
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
		key := tg_tok_current(p)
		if key.kind != .Ident {
			return false
		}
		tg_tok_advance(p)
		if !tg_tok_expect(p, .Eq) {
			return false
		}

		enum_index := -1
		for i in 0..<len(index_enum.names) {
			if index_enum.names[i] == key.text {
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
			elem_ptr := rawptr(uintptr(value_ptr) + uintptr(elem_index*array.elem_size))
			if !tg_tok_read_value(p, elem_ptr, array.elem) {
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

tg_tok_read_struct :: proc(p: ^Tg_Token_Parser, value_ptr: rawptr, info: ^rf.Type_Info) -> bool {
	empty, ok := tg_tok_container_begin(p)
	if !ok {
		return false
	}
	if empty {
		return true
	}

	for {
		name, declared_type, header_ok := tg_tok_read_field_header(p)
		if !header_ok {
			tg_tok_error(p, "expected a struct field assignment")
			return false
		}

		field := rf.struct_field_by_name(info.id, name)
		if field.name == "" || !tg_is_supported_type(field.type) {
			if !tg_tok_skip_value(p) {
				return false
			}
		} else {
			if !tg_check_declared_type(field, declared_type, p.check_types) {
				fmt.printf("Settings: field '%s' declares type '%s', expected '%s'\n", name, declared_type, tg_type_name(field.type))
				return false
			}

			field_ptr := rawptr(uintptr(value_ptr) + field.offset)
			if !tg_tok_read_value(p, field_ptr, field.type) {
				fmt.printf("Settings: failed to read field '%s'\n", name)
				return false
			}
		}

		// Struct members may be comma-separated (nested structs) or
		// newline/whitespace-separated (named top-level settings blocks).
		if tg_tok_current(p).kind == .Comma || tg_tok_current(p).kind == .Semicolon {
			tg_tok_advance(p)
		}

		if tg_tok_current(p).kind == .Close_Brace {
			tg_tok_advance(p)
			return true
		}
	}
}

tg_tok_read_value :: proc(p: ^Tg_Token_Parser, value_ptr: rawptr, info: ^rf.Type_Info) -> bool {
	if info == nil {
		return false
	}

	base_info := rf.type_info_base(info)

	if rf.is_dynamic_map(base_info) {
		return tg_tok_read_map(p, value_ptr, base_info)
	}

	if rf.is_fixed_capacity_dynamic_array(base_info) {
		array := base_info.variant.(rf.Type_Info_Fixed_Capacity_Dynamic_Array)
		array_len := (^int)(rawptr(uintptr(value_ptr) + array.len_offset))
		return tg_tok_read_container_sequence(p, value_ptr, array.capacity, array.elem_size, array.elem, .Fixed_Capacity, nil, array_len)
	}

	if rf.is_dynamic_array(base_info) {
		array := base_info.variant.(rf.Type_Info_Dynamic_Array)
		dynamic_array := (^runtime.Raw_Dynamic_Array)(value_ptr)
		return tg_tok_read_container_sequence(p, nil, 0, array.elem_size, array.elem, .Dynamic, dynamic_array, nil)
	}

	if rf.is_enumerated_array(base_info) {
		return tg_tok_read_enumerated_array(p, value_ptr, base_info)
	}

	if rf.is_array(base_info) {
		array := base_info.variant.(rf.Type_Info_Array)
		return tg_tok_read_container_sequence(p, value_ptr, array.count, array.elem_size, array.elem, .Fixed, nil, nil)
	}

	if rf.is_struct(base_info) {
		return tg_tok_read_struct(p, value_ptr, base_info)
	}

	if rf.is_enum(base_info) {
		return tg_tok_read_enum(p, value_ptr, base_info)
	}

	return tg_tok_read_scalar(p, value_ptr, base_info)
}

tg_tok_read_fields :: proc(p: ^Tg_Token_Parser, settings: rawptr, info: ^rf.Type_Info, end_index: int) -> bool {
	root_info := rf.type_info_base(info)
	if !rf.is_struct(root_info) {
		return false
	}

	for p.index < end_index {
		tg_tok_skip_separators(p)
		if p.index >= end_index {
			return true
		}

		name, declared_type, header_ok := tg_tok_read_field_header(p)
		if !header_ok {
			tg_tok_error(p, "expected a settings field assignment")
			return false
		}

		field := rf.struct_field_by_name(root_info.id, name)
		if field.name == "" || !tg_is_supported_type(field.type) {
			if !tg_tok_skip_value(p) {
				return false
			}
		} else {
			if !tg_check_declared_type(field, declared_type, p.check_types) {
				fmt.printf("Settings: field '%s' declares type '%s', expected '%s'\n", name, declared_type, tg_type_name(field.type))
				return false
			}

			field_ptr := rawptr(uintptr(settings) + field.offset)
			if !tg_tok_read_value(p, field_ptr, field.type) {
				fmt.printf("Settings: failed to read field '%s'\n", name)
				return false
			}
		}

		if tg_tok_current(p).kind == .Comma || tg_tok_current(p).kind == .Semicolon {
			tg_tok_advance(p)
		}
	}

	return p.index == end_index
}

tg_tok_parse_block_header :: proc(p: ^Tg_Token_Parser, start: int) -> (name, type_name: string, open_index: int, ok: bool) {
	if start < 0 || start+2 >= len(p.tokens) {
		return "", "", -1, false
	}

	if p.tokens[start].kind != .Ident || p.tokens[start+1].kind != .Colon {
		return "", "", -1, false
	}

	type_start := p.tokens[start+2].pos.offset
	for i := start+2; i+1 < len(p.tokens); i += 1 {
		kind := p.tokens[i].kind
		if kind == .Eq || kind == .EOF {
			break
		}

		if kind == .Colon && p.tokens[i+1].kind == .Open_Brace {
			type_end := p.tokens[i].pos.offset
			if type_end < type_start || type_end > len(p.source) {
				return "", "", -1, false
			}
			return p.tokens[start].text, strings.trim_space(p.source[type_start:type_end]), i+1, true
		}
	}

	return "", "", -1, false
}

tg_tok_find_block_end :: proc(p: ^Tg_Token_Parser, open_index: int) -> (close_index: int, ok: bool) {
	if open_index < 0 || open_index >= len(p.tokens) || p.tokens[open_index].kind != .Open_Brace {
		return -1, false
	}

	depth := 0
	for i in open_index..<len(p.tokens) {
		#partial switch p.tokens[i].kind {
		case .Open_Brace:
			depth += 1
		case .Close_Brace:
			depth -= 1
			if depth == 0 {
				return i, true
		}
		case .EOF:
			return -1, false
		}
	}

	return -1, false
}

// tg_read :: proc(path: string, settings: ^$T, name: string = "", check_types: bool = true) -> bool {
// 	if settings == nil {
// 		return false
// 	}

// 	root_info := rf.type_info_base(type_info_of(T))
// 	if !rf.is_struct(root_info) {
// 		return false
// 	}

// 	data, err := os.read_entire_file(path, context.allocator)
// 	if err != nil {
// 		return false
// 	}
// 	defer delete(data)

// 	source := string(data)
// 	parser: Tg_Token_Parser
// 	if !tg_tok_init(&parser, source, path, check_types) {
// 		return false
// 	}
// 	defer delete(parser.tokens)

// 	tg_tok_skip_separators(&parser)
// 	_, _, _, has_blocks := tg_tok_parse_block_header(&parser, parser.index)
// 	if !has_blocks {
// 		parser.index = 0
// 		return tg_tok_read_fields(&parser, rawptr(settings), root_info, len(parser.tokens)-1)
// 	}

// 	expected_type := tg_type_name(type_info_of(T))
// 	for {
// 		block_name, block_type, open_index, header_ok := tg_tok_parse_block_header(&parser, parser.index)
// 		if !header_ok {
// 			tg_tok_error(&parser, "expected a named settings block")
// 			return false
// 		}

// 		close_index, block_ok := tg_tok_find_block_end(&parser, open_index)
// 		if !block_ok {
// 			tg_tok_error(&parser, "settings block is missing its closing brace")
// 			return false
// 		}

// 		selected := false
// 		if name != "" {
// 			selected = block_name == name
// 		} else {
// 			selected = block_type == expected_type
// 		}

// 		if selected {
// 			if check_types && block_type != expected_type {
// 				fmt.printf("Settings: block '%s' declares type '%s', expected '%s'\n", block_name, block_type, expected_type)
// 				return false
// 			}

// 			parser.index = open_index+1
// 			if !tg_tok_read_fields(&parser, rawptr(settings), root_info, close_index) {
// 				return false
// 			}
// 			return parser.index == close_index
// 		}

// 		parser.index = close_index+1
// 		tg_tok_skip_separators(&parser)
// 		if tg_tok_current(&parser).kind == .EOF {
// 			break
// 		}
// 	}

// 	if name != "" {
// 		fmt.printf("Settings: block '%s' was not found\n", name)
// 	} else {
// 		fmt.printf("Settings: no block found for type '%s'\n", expected_type)
// 	}
// 	return false
// }
