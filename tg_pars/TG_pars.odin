package tg_pars

// import "core:thread"
// import "vendor:stb/truetype"

// import sdl "vendor:sdl3"
// import "core:log"
// import "core:mem"
// import "core:hash"
// import "core:c"
// import "core:fmt"
// import "core:strings"
// import rf"core:reflect"

// // import hm "handle_map_static_virtual"
// import hm "core:container/handle_map"
// import "core:time"
// import lin"core:math/linalg"

// import "core:encoding/json"
// import "core:os"
// import "core:strconv"

// import sdl3i"vendor:sdl3/image"
// import "core:sort"
// import "core:slice"
// import "base:runtime"
// import "core:encoding/ini"


// tg_parse_field_decl :: proc(lhs: string) -> (field_name, declared_type: string) {
// 	lhs := strings.trim_space(lhs)
// 	colon := strings.index_byte(lhs, ':')

// 	if colon < 0 {
// 		return lhs, ""
// 	}

// 	field_name = strings.trim_space(lhs[:colon])
// 	declared_type = strings.trim_space(lhs[colon+1:])
// 	return
// }

// tg_check_declared_type :: proc(field: rf.Struct_Field, declared_type: string, check_types: bool) -> bool {
// 	if len(declared_type) == 0 || !check_types {
// 		return true
// 	}

// 	return declared_type == tg_type_name(field.type)
// }

// Block :: struct {
// 	name: string,
// 	type_name: string,
// 	header_start: int,
// 	body_start: int,
// 	body_end: int,
// 	end: int,
// 	valid: bool,
// }




// tg_type_name :: proc(info: ^rf.Type_Info) -> string {

// 	if info == nil {
// 		return ""
// 	}

// 	if rf.type_kind(info.id) == .Named {
// 		return info.variant.(rf.Type_Info_Named).name
// 	}

// 	builder := strings.builder_make()
// 	defer strings.builder_destroy(&builder)

// 	rf.write_type_builder(&builder, info)
// 	return strings.clone(strings.to_string(builder))
// }


// tg_parse_block_header :: proc(line: string) -> (name, type_name: string, ok: bool) {
// 	first := strings.index_byte(line, ':')
// 	if first <= 0 {
// 		return "", "", false
// 	}

// 	second_rel := strings.index_byte(line[first+1:], ':')
// 	if second_rel < 0 {
// 		return "", "", false
// 	}

// 	second := first+1+second_rel
// 	if strings.trim_space(line[second+1:]) != "{" {
// 		return "", "", false
// 	}

// 	name = strings.trim_space(line[:first])
// 	type_name = strings.trim_space(line[first+1:second])
// 	return name, type_name, len(name) > 0 && len(type_name) > 0
// }

// tg_find_block_close :: proc(text: string, open_pos: int) -> (close_pos: int, ok: bool) {
// 	depth := 0
// 	quote: u8 = 0
// 	escaped := false
// 	i := open_pos

// 	for i < len(text) {
// 		c := text[i]

// 		if quote != 0 {
// 			if escaped {
// 				escaped = false
// 			} else if c == '\\' {
// 				escaped = true
// 			} else if c == quote {
// 				quote = 0
// 			}
// 		} else if c == '/' && i+1 < len(text) && text[i+1] == '/' {
// 			for i < len(text) && text[i] != '\n' {
// 				i += 1
// 			}
// 			continue
// 		} else if c == '"' || c == '\'' {
// 			quote = c
// 		} else if c == '{' {
// 			depth += 1
// 		} else if c == '}' {
// 			depth -= 1
// 			if depth == 0 {
// 				return i, true
// 			}
// 		}

// 		i += 1
// 	}

// 	return -1, false
// }

// tg_find_next_block :: proc(text: string, start: int) -> (block: Block, found: bool) {
// 	line_start := max(0, start)

// 	if line_start > 0 {
// 		for line_start < len(text) && text[line_start-1] != '\n' {
// 			line_start += 1
// 		}
// 	}

// 	for line_start <= len(text) {
// 		line_end := line_start
// 		for line_end < len(text) && text[line_end] != '\n' {
// 			line_end += 1
// 		}

// 		raw_line := text[line_start:line_end]
// 		line := strings.trim_space(raw_line)
// 		name, type_name, header_ok := tg_parse_block_header(line)

// 		if header_ok {
// 			open_rel := strings.index_byte(raw_line, '{')
// 			if open_rel < 0 {
// 				return {}, false
// 			}

// 			open_pos := line_start+open_rel
// 			close_pos, valid := tg_find_block_close(text, open_pos)

// 			if !valid {
// 				return Block{
// 					name = name,
// 					type_name = type_name,
// 					header_start = line_start,
// 					body_start = open_pos+1,
// 					body_end = len(text),
// 					end = len(text),
// 					valid = false,
// 				}, true
// 			}

// 			return Block{
// 				name = name,
// 				type_name = type_name,
// 				header_start = line_start,
// 				body_start = open_pos+1,
// 				body_end = close_pos,
// 				end = close_pos+1,
// 				valid = true,
// 			}, true
// 		}

// 		if line_end >= len(text) {
// 			break
// 		}

// 		line_start = line_end+1
// 	}

// 	return {}, false
// }

// tg_write_fields :: proc(builder: ^strings.Builder, settings: rawptr, info: ^rf.Type_Info, depth: int) -> bool {
// 	root_info := rf.type_info_base(info)
// 	if !rf.is_struct(root_info) {
// 		return false
// 	}

// 	for i in 0..<rf.struct_field_count(root_info.id) {
// 		field := rf.struct_field_at(root_info.id, i)

// 		if !tg_is_supported_type(field.type) {
// 			tg_write_unsupported_comment(builder, field.name, field.type, depth)
// 			continue
// 		}

// 		tg_write_indent(builder, depth)
// 		strings.write_string(builder, field.name)
// 		strings.write_string(builder, " = ")

// 		field_ptr := rawptr(uintptr(settings) + field.offset)
// 		if !tg_write_value(builder, field_ptr, field.type, depth) {
// 			return false
// 		}

// 		strings.write_byte(builder, '\n')
// 	}

// 	return true
// }


// tg_write :: proc(path: string, settings: ^$T, name: string = "") -> bool{
// 	if settings == nil {
// 		return false
// 	}

// 	root_info := rf.type_info_base(type_info_of(T))
// 	if !rf.is_struct(root_info) {
// 		return false
// 	}

// 	// name := ""
// 	// if len(names) > 0 {
// 	// 	name = names[0]
// 	// }

// 	if name == "" {
// 		builder := strings.builder_make()
// 		defer strings.builder_destroy(&builder)

// 		if !tg_write_fields(&builder, rawptr(settings), root_info, 0) {
// 			return false
// 		}

// 		err := os.write_entire_file(path, strings.to_string(builder))
// 		return err == nil
// 	}

// 	if strings.index_byte(name, ':') >= 0 || strings.index_byte(name, '\n') >= 0 || strings.index_byte(name, '\r') >= 0 || strings.index_byte(name, '{') >= 0 || strings.index_byte(name, '}') >= 0 {
// 		return false
// 	}

// 	type_name := tg_type_name(type_info_of(T))
// 	if type_name == "" {
// 		return false
// 	}

// 	block_builder := strings.builder_make()
// 	defer strings.builder_destroy(&block_builder)

// 	strings.write_string(&block_builder, name)
// 	strings.write_byte(&block_builder, ':')
// 	strings.write_string(&block_builder, type_name)
// 	strings.write_string(&block_builder, ":{\n")

// 	if !tg_write_fields(&block_builder, rawptr(settings), root_info, 1,) {
// 		return false
// 	}

// 	strings.write_string(&block_builder, "}\n")
// 	block_text := strings.to_string(block_builder)

// 	old_data, read_err := os.read_entire_file(path,context.allocator)
// 	old_text := ""
// 	if read_err == nil {
// 		old_text = strings.clone(string(old_data))
// 		delete(old_data)
// 	}

// 	target: Block
// 	found_target := false
// 	scan := 0

// 	for {
// 		block, found := tg_find_next_block(old_text, scan)
// 		if !found {
// 			break
// 		}
// 		if !block.valid {
// 			return false
// 		}

// 		if block.name == name {
// 			target = block
// 			found_target = true
// 			break
// 		}

// 		if block.end <= scan {
// 			return false
// 		}
// 		scan = block.end
// 	}

// 	output := strings.builder_make()
// 	defer strings.builder_destroy(&output)

// 	if found_target {
// 		replace_end := target.end

// 		if replace_end < len(old_text) && old_text[replace_end] == '\r' {
// 			replace_end += 1
// 		}
// 		if replace_end < len(old_text) && old_text[replace_end] == '\n' {
// 			replace_end += 1
// 		}

// 		strings.write_string(&output, old_text[:target.header_start])
// 		strings.write_string(&output, block_text)
// 		strings.write_string(&output, old_text[replace_end:])
// 	} else {
// 		strings.write_string(&output, old_text)

// 		if len(old_text) > 0 && old_text[len(old_text)-1] != '\n' {
// 			strings.write_byte(&output, '\n')
// 		}

// 		strings.write_string(&output, block_text)
// 	}

// 	err := os.write_entire_file(path, strings.to_string(output))
// 	return err == nil
// }

// // tg_read_fields :: proc(text: string, settings: rawptr, info: ^rf.Type_Info) -> bool {
// // 	root_info := rf.type_info_base(info)
// // 	if !rf.is_struct(root_info) {
// // 		return false
// // 	}

// // 	pos := 0

// // 	for {
// // 		tg_skip_space(text, &pos)

// // 		if pos >= len(text) {
// // 			return true
// // 		}

// // 		key_start := pos

// // 		for pos < len(text) && text[pos] != '=' && text[pos] != '\n' && text[pos] != '\r' {
// // 			pos += 1
// // 		}

// // 		if pos >= len(text) || text[pos] != '=' {
// // 			return false
// // 		}

// // 		key := strings.trim_space(text[key_start:pos])
// // 		if len(key) == 0 {
// // 			return false
// // 		}

// // 		pos += 1
// // 		tg_skip_space(text, &pos)

// // 		field := rf.struct_field_by_name(root_info.id, key)

// // 		if field.name == "" || !tg_is_supported_type(field.type) {
// // 			if !tg_skip_value(text, &pos) {
// // 				return false
// // 			}
// // 		} else {
// // 			field_ptr := rawptr(uintptr(settings)+field.offset)
// // 			if !tg_read_value(text, &pos, field_ptr, field.type) {
// // 				fmt.printf("Settings: failed to read field '%s'\n", key)
// // 				return false
// // 			}
// // 		}

// // 		tg_skip_space(text, &pos)
// // 		if pos < len(text) && text[pos] == ',' {
// // 			pos += 1
// // 		}
// // 	}
// // }

// tg_is_supported_map_key :: proc(info: ^rf.Type_Info) -> bool {
// 	if info == nil {
// 		return false
// 	}

// 	base_info := rf.type_info_base(info)

// 	if rf.is_enum(base_info) {
// 		return true
// 	}

// 	switch base_info.id {
// 	case typeid_of(bool), typeid_of(int), typeid_of(uint), typeid_of(i8), typeid_of(i16), typeid_of(i32), typeid_of(i64), typeid_of(u8), typeid_of(u16), typeid_of(u32), typeid_of(u64), typeid_of(f32), typeid_of(f64), typeid_of(string):
// 		return true
// 	case:
// 		return false
// 	}
// }

// tg_is_supported_type :: proc(info: ^rf.Type_Info) -> bool {
// 	if info == nil {
// 		return false
// 	}

// 	base_info := rf.type_info_base(info)

// 	if rf.is_enum(base_info) || rf.is_struct(base_info) {
// 		return true
// 	}

// 	if rf.is_array(base_info) {
// 		return tg_is_supported_type(base_info.variant.(rf.Type_Info_Array).elem)
// 	}

// 	if rf.is_enumerated_array(base_info) {
// 		return tg_is_supported_type(base_info.variant.(rf.Type_Info_Enumerated_Array).elem)
// 	}

// 	if rf.is_dynamic_array(base_info) {
// 		return tg_is_supported_type(base_info.variant.(rf.Type_Info_Dynamic_Array).elem)
// 	}

// 	if rf.is_fixed_capacity_dynamic_array(base_info) {
// 		return tg_is_supported_type(base_info.variant.(rf.Type_Info_Fixed_Capacity_Dynamic_Array).elem)
// 	}

// 	if rf.is_dynamic_map(base_info) {
// 		map_info := base_info.variant.(rf.Type_Info_Map)
// 		return tg_is_supported_map_key(map_info.key) && tg_is_supported_type(map_info.value)
// 	}

// 	switch base_info.id {
// 	case typeid_of(bool), typeid_of(int), typeid_of(uint), typeid_of(i8), typeid_of(i16), typeid_of(i32), typeid_of(i64), typeid_of(u8), typeid_of(u16), typeid_of(u32), typeid_of(u64), typeid_of(f32), typeid_of(f64), typeid_of(string):
// 		return true
// 	case:
// 		return false
// 	}
// }

// tg_skip_space :: proc(text: string, pos: ^int) {
// 	for {
// 		for pos^ < len(text) {
// 			c := text[pos^]
// 			if c != ' ' && c != '\t' && c != '\r' && c != '\n' {
// 				break
// 			}
// 			pos^ += 1
// 		}

// 		if pos^ + 1 < len(text) && text[pos^] == '/' && text[pos^+1] == '/' {
// 			for pos^ < len(text) && text[pos^] != '\n' {
// 				pos^ += 1
// 			}
// 			continue
// 		}

// 		break
// 	}
// }

// tg_read_quoted :: proc(text: string, pos: ^int) -> (token: string, ok: bool) {
// 	if pos^ >= len(text) || (text[pos^] != '"' && text[pos^] != '\'') {
// 		return "", false
// 	}

// 	start := pos^
// 	quote := text[pos^]
// 	pos^ += 1
// 	escaped := false

// 	for pos^ < len(text) {
// 		c := text[pos^]
// 		pos^ += 1

// 		if escaped {
// 			escaped = false
// 			continue
// 		}

// 		if c == '\\' {
// 			escaped = true
// 			continue
// 		}

// 		if c == quote {
// 			return text[start:pos^], true
// 		}
// 	}

// 	return "", false
// }

// tg_read_atom :: proc(text: string, pos: ^int) -> (token: string, ok: bool) {
// 	tg_skip_space(text, pos)
// 	start := pos^

// 	for pos^ < len(text) {
// 		c := text[pos^]
// 		if c == ',' || c == '}' || c == ' ' || c == '\t' || c == '\r' || c == '\n' {
// 			break
// 		}
// 		pos^ += 1
// 	}

// 	if start == pos^ {
// 		return "", false
// 	}

// 	return text[start:pos^], true
// }

// tg_skip_value :: proc(text: string, pos: ^int) -> bool {
// 	tg_skip_space(text, pos)

// 	if pos^ >= len(text) {
// 		return false
// 	}

// 	c := text[pos^]

// 	if c == '"' || c == '\'' {
// 		_, ok := tg_read_quoted(text, pos)
// 		return ok
// 	}

// 	if c == '{' {
// 		pos^ += 1
// 		tg_skip_space(text, pos)

// 		if pos^ < len(text) && text[pos^] == '}' {
// 			pos^ += 1
// 			return true
// 		}

// 		probe := pos^
// 		depth := 0
// 		quote: u8 = 0
// 		escaped := false
// 		is_struct := false

// 		for probe < len(text) {
// 			c := text[probe]

// 			if quote != 0 {
// 				if escaped {
// 					escaped = false
// 				} else if c == '\\' {
// 					escaped = true
// 				} else if c == quote {
// 					quote = 0
// 				}
// 			} else if c == '"' || c == '\'' {
// 				quote = c
// 			} else if c == '{' {
// 				depth += 1
// 			} else if c == '}' {
// 				if depth == 0 {
// 					break
// 				}
// 				depth -= 1
// 			} else if depth == 0 {
// 				if c == '=' {
// 					is_struct = true
// 					break
// 				}
// 				if c == ',' {
// 					break
// 				}
// 			}

// 			probe += 1
// 		}

// 		if is_struct {
// 			for {
// 				tg_skip_space(text, pos)

// 				if pos^ >= len(text) {
// 					return false
// 				}

// 				if text[pos^] == '}' {
// 					pos^ += 1
// 					return true
// 				}

// 				for pos^ < len(text) && text[pos^] != '=' && text[pos^] != ',' && text[pos^] != '}' {
// 					pos^ += 1
// 				}

// 				if pos^ >= len(text) || text[pos^] != '=' {
// 					return false
// 				}

// 				pos^ += 1

// 				if !tg_skip_value(text, pos) {
// 					return false
// 				}

// 				tg_skip_space(text, pos)

// 				if pos^ >= len(text) {
// 					return false
// 				}

// 				if text[pos^] == ',' {
// 					pos^ += 1
// 				} else if text[pos^] != '}' {
// 					return false
// 				}
// 			}
// 		} else {
// 			for {
// 				tg_skip_space(text, pos)

// 				if pos^ >= len(text) {
// 					return false
// 				}

// 				if text[pos^] == '}' {
// 					pos^ += 1
// 					return true
// 				}

// 				if !tg_skip_value(text, pos) {
// 					return false
// 				}

// 				tg_skip_space(text, pos)

// 				if pos^ >= len(text) {
// 					return false
// 				}

// 				if text[pos^] == ',' {
// 					pos^ += 1
// 				} else if text[pos^] != '}' {
// 					return false
// 				}
// 			}
// 		}
// 	}

// 	_, ok := tg_read_atom(text, pos)
// 	return ok
// }


// tg_is_compound_type :: proc(info: ^rf.Type_Info) -> bool {
// 	if info == nil {
// 		return false
// 	}

// 	base_info := rf.type_info_base(info)
// 	return rf.is_array(base_info) || rf.is_enumerated_array(base_info) || rf.is_dynamic_array(base_info) || rf.is_fixed_capacity_dynamic_array(base_info) || rf.is_dynamic_map(base_info) || rf.is_struct(base_info)
// }

// tg_write_sequence :: proc(builder: ^strings.Builder, data_ptr: rawptr, count, elem_size, depth: int, elem_info: ^rf.Type_Info) -> bool {
// 	if count < 0 || elem_size <= 0 || (count > 0 && data_ptr == nil) {
// 		return false
// 	}

// 	if count == 0 {
// 		strings.write_string(builder, "{}")
// 		return true
// 	}

// 	if !tg_is_compound_type(elem_info) {
// 		strings.write_byte(builder, '{')

// 		for i in 0..<count {
// 			if i > 0 {
// 				strings.write_string(builder, ", ")
// 			}

// 			elem_ptr := rawptr(uintptr(data_ptr) + uintptr(i*elem_size))
// 			if !tg_write_value(builder, elem_ptr, elem_info, depth) {
// 				return false
// 			}
// 		}

// 		strings.write_byte(builder, '}')
// 		return true
// 	}

// 	strings.write_string(builder, "{\n")

// 	for i in 0..<count {
// 		tg_write_indent(builder, depth+1)
// 		elem_ptr := rawptr(uintptr(data_ptr) + uintptr(i*elem_size))

// 		if !tg_write_value(builder, elem_ptr, elem_info, depth+1) {
// 			return false
// 		}

// 		strings.write_string(builder, ",\n")
// 	}

// 	tg_write_indent(builder, depth)
// 	strings.write_byte(builder, '}')
// 	return true
// }

// tg_write_value :: proc(builder: ^strings.Builder, value_ptr: rawptr, info: ^rf.Type_Info, depth: int) -> bool {
// 	if info == nil {
// 		return false
// 	}

// 	base_info := rf.type_info_base(info)
	
// 	if rf.is_dynamic_array(base_info) {
// 		array_info := base_info.variant.(rf.Type_Info_Dynamic_Array)
// 		array := (^runtime.Raw_Dynamic_Array)(value_ptr)^
	
// 		if array.len < 0 || array.len > array.cap || (array.len > 0 && array.data == nil) {
// 			return false
// 		}
	
// 		return tg_write_sequence(builder, array.data, array.len, array_info.elem_size, depth, array_info.elem)
// 	}
	
// 	if rf.is_fixed_capacity_dynamic_array(base_info) {
// 		array_info := base_info.variant.(rf.Type_Info_Fixed_Capacity_Dynamic_Array)
// 		array_len := (^int)(rawptr(uintptr(value_ptr) + array_info.len_offset))^
	
// 		if array_len < 0 || array_len > array_info.capacity {
// 			return false
// 		}
	
// 		return tg_write_sequence(builder, value_ptr, array_len, array_info.elem_size, depth, array_info.elem)
// 	}
	
// 	if rf.is_dynamic_map(base_info) {
// 		map_type := base_info.variant.(rf.Type_Info_Map)
// 		map_value := (^runtime.Raw_Map)(value_ptr)^
	
// 		if map_value.len == 0 {
// 			strings.write_string(builder, "{}")
// 			return true
// 		}
	
// 		keys, values, hashes, _, _ := runtime.map_kvh_data_dynamic(map_value, map_type.map_info)
// 		strings.write_string(builder, "{\n")
	
// 		for i in 0..<runtime.map_cap(map_value) {
// 			if !runtime.map_hash_is_valid(hashes[i]) {
// 				continue
// 			}
	
// 			key_ptr := rawptr(runtime.map_cell_index_dynamic(keys, map_type.map_info.ks, uintptr(i)))
// 			value_ptr := rawptr(runtime.map_cell_index_dynamic(values, map_type.map_info.vs, uintptr(i)))
	
// 			tg_write_indent(builder, depth+1)
// 			if !tg_write_value(builder, key_ptr, map_type.key, depth+1) {
// 				return false
// 			}
	
// 			strings.write_string(builder, " = ")
	
// 			if !tg_write_value(builder, value_ptr, map_type.value, depth+1) {
// 				return false
// 			}
	
// 			strings.write_string(builder, ",\n")
// 		}
	
// 		tg_write_indent(builder, depth)
// 		strings.write_byte(builder, '}')
// 		return true
// 	}

// 	if rf.is_enumerated_array(base_info) {
// 		array := base_info.variant.(rf.Type_Info_Enumerated_Array)
// 		index_info := rf.type_info_base(array.index)
// 		if !rf.is_enum(index_info) {
// 			return false
// 		}
// 		index_enum := index_info.variant.(rf.Type_Info_Enum)
	
// 		if array.count == 0 {
// 			strings.write_string(builder, "{}")
// 			return true
// 		}
	
// 		strings.write_string(builder, "{\n")
	
// 		for i in 0..<len(index_enum.names) {
// 			enum_value := i64(index_enum.values[i])
// 			elem_index := i
	
// 			if !array.is_sparse {
// 				elem_index = int(enum_value - i64(array.min_value))
// 			}
	
// 			if elem_index < 0 || elem_index >= array.count {
// 				continue
// 			}
	
// 			tg_write_indent(builder, depth+1)
// 			strings.write_string(builder, index_enum.names[i])
// 			strings.write_string(builder, " = ")
	
// 			elem_ptr := rawptr(uintptr(value_ptr) + uintptr(elem_index*array.elem_size))
// 			if !tg_write_value(builder, elem_ptr, array.elem, depth+1) {
// 				return false
// 			}
	
// 			strings.write_string(builder, ",\n")
// 		}
	
// 		tg_write_indent(builder, depth)
// 		strings.write_byte(builder, '}')
// 		return true
// 	}

// 	if rf.is_array(base_info) {
// 		array := base_info.variant.(rf.Type_Info_Array)
// 		return tg_write_sequence(builder, value_ptr, array.count, array.elem_size, depth, array.elem)
// 	}

// 	if rf.is_struct(base_info) {
// 		if rf.struct_field_count(base_info.id) == 0 {
// 			strings.write_string(builder, "{}")
// 			return true
// 		}

// 		strings.write_string(builder, "{\n")

// 		for i in 0..<rf.struct_field_count(base_info.id) {
// 			field := rf.struct_field_at(base_info.id, i)

// 			if !tg_is_supported_type(field.type) {
// 				tg_write_unsupported_comment(builder, field.name, field.type, depth+1)
// 				continue
// 			}

// 			tg_write_indent(builder, depth+1)
// 			strings.write_string(builder, field.name)
			

// 			strings.write_string(builder, " = ")
		

// 			field_ptr := rawptr(uintptr(value_ptr) + field.offset)
// 			if !tg_write_value(builder, field_ptr, field.type, depth+1) {
// 				return false
// 			}

// 			strings.write_string(builder, ",\n")
// 		}

// 		tg_write_indent(builder, depth)
// 		strings.write_byte(builder, '}')
// 		return true
// 	}

// 	if rf.is_enum(base_info) {
// 		enum_info := base_info.variant.(rf.Type_Info_Enum)
// 		value, ok := tg_enum_read_i64(value_ptr, enum_info.base)
// 		if !ok {
// 			return false
// 		}
	
// 		for i in 0..<len(enum_info.values) {
// 			if i64(enum_info.values[i]) == value {
// 				strings.write_string(builder, enum_info.names[i])
// 				return true
// 			}
// 		}
	
// 		// Preserve enum values that don't have a declared name.
// 		strings.write_i64(builder, value)
// 		return true
// 	}

// 	switch rf.typeid_base(base_info.id) {
// 	case typeid_of(bool):
// 		if (^bool)(value_ptr)^ {
// 			strings.write_string(builder, "true")
// 		} else {
// 			strings.write_string(builder, "false")
// 		}

// 	case typeid_of(int):
// 		strings.write_int(builder, (^int)(value_ptr)^)

// 	case typeid_of(uint):
// 		strings.write_uint(builder, (^uint)(value_ptr)^)

// 	case typeid_of(i8):
// 		strings.write_i64(builder, i64((^i8)(value_ptr)^))

// 	case typeid_of(i16):
// 		strings.write_i64(builder, i64((^i16)(value_ptr)^))

// 	case typeid_of(i32):
// 		strings.write_i64(builder, i64((^i32)(value_ptr)^))

// 	case typeid_of(i64):
// 		strings.write_i64(builder, (^i64)(value_ptr)^)

// 	case typeid_of(u8):
// 		strings.write_u64(builder, u64((^u8)(value_ptr)^))

// 	case typeid_of(u16):
// 		strings.write_u64(builder, u64((^u16)(value_ptr)^))

// 	case typeid_of(u32):
// 		strings.write_u64(builder, u64((^u32)(value_ptr)^))

// 	case typeid_of(u64):
// 		strings.write_u64(builder, (^u64)(value_ptr)^)

// 	case typeid_of(f32):
// 		strings.write_f32(builder, (^f32)(value_ptr)^, 'g')

// 	case typeid_of(f64):
// 		strings.write_f64(builder, (^f64)(value_ptr)^, 'g')

// 	case typeid_of(string):
// 		strings.write_quoted_string(builder, (^string)(value_ptr)^)

// 	case:
// 		return false
// 	}

// 	return true
// }



// tg_zero_raw :: proc(data: rawptr, size: int) {
// 	bytes := ([^]u8)(data)
// 	for i in 0..<size {
// 		bytes[i] = 0
// 	}
// }

// tg_dynamic_array_reserve :: proc(array: ^runtime.Raw_Dynamic_Array, elem_info: ^rf.Type_Info, elem_size, wanted: int) -> bool {
// 	if wanted < 0 || elem_size <= 0 || array.cap < 0 {
// 		return false
// 	}

// 	if wanted <= array.cap && (wanted == 0 || array.data != nil) {
// 		return true
// 	}

// 	if array.allocator.procedure == nil {
// 		array.allocator = context.allocator
// 	}

// 	new_cap := max(4, array.cap)
// 	for new_cap < wanted {
// 		if new_cap > max(int)/2 {
// 			return false
// 		}
// 		new_cap *= 2
// 	}

// 	if new_cap > max(int)/elem_size {
// 		return false
// 	}

// 	old_size := 0
// 	if array.data != nil {
// 		old_size = array.cap*elem_size
// 	}

// 	new_size := new_cap*elem_size
// 	new_data, err := mem.resize(array.data, old_size, new_size, elem_info.align, array.allocator)
// 	if err != nil || new_data == nil {
// 		return false
// 	}

// 	array.data = new_data
// 	array.cap = new_cap
// 	return true
// }

// tg_read_value :: proc(text: string, pos: ^int, value_ptr: rawptr, info: ^rf.Type_Info) -> bool {
// 	if info == nil {
// 		return false
// 	}

// 	tg_skip_space(text, pos)
// 	if pos^ >= len(text) {
// 		return false
// 	}

// 	base_info := rf.type_info_base(info)

// 	if rf.is_dynamic_map(base_info) {
// 		map_type := base_info.variant.(rf.Type_Info_Map)
	
// 		if text[pos^] != '{' {
// 			return false
// 		}
// 		pos^ += 1
	
// 		map_ptr := (^runtime.Raw_Map)(value_ptr)
// 		if map_ptr.allocator.procedure == nil {
// 			map_ptr.allocator = context.allocator
// 		}
// 		runtime.map_clear_dynamic(map_ptr, map_type.map_info)
	
// 		tg_skip_space(text, pos)
// 		if pos^ < len(text) && text[pos^] == '}' {
// 			pos^ += 1
// 			return true
// 		}
	
// 		key_storage, key_err := mem.alloc(max(1, map_type.key.size), max(1, map_type.key.align))
// 		if key_err != nil {
// 			return false
// 		}
// 		defer mem.free(key_storage)
	
// 		value_storage, value_err := mem.alloc(max(1, map_type.value.size), max(1, map_type.value.align))
// 		if value_err != nil {
// 			return false
// 		}
// 		defer mem.free(value_storage)
	
// 		for {
// 			tg_skip_space(text, pos)
	
// 			if pos^ >= len(text) {
// 				return false
// 			}
	
// 			if text[pos^] == '}' {
// 				pos^ += 1
// 				return true
// 			}
	
// 			tg_zero_raw(key_storage, max(1, map_type.key.size))
	
// 			if !tg_read_value(text, pos, key_storage, map_type.key) {
// 				return false
// 			}
	
// 			tg_skip_space(text, pos)
// 			if pos^ >= len(text) || text[pos^] != '=' {
// 				return false
// 			}
// 			pos^ += 1
	
// 			entry_key_ptr, entry_value_ptr, _, entry_err := runtime.__dynamic_map_entry(map_ptr, map_type.map_info, key_storage, value_storage)
// 			if entry_err != nil || entry_key_ptr == nil || entry_value_ptr == nil {
// 				return false
// 			}
	
// 			if !tg_read_value(text, pos, entry_value_ptr, map_type.value) {
// 				return false
// 			}
	
// 			tg_skip_space(text, pos)
// 			if pos^ >= len(text) {
// 				return false
// 			}
	
// 			if text[pos^] == ',' {
// 				pos^ += 1
// 			} else if text[pos^] != '}' {
// 				return false
// 			}
// 		}
// 	}

// 	if rf.is_fixed_capacity_dynamic_array(base_info) {
// 		array_info := base_info.variant.(rf.Type_Info_Fixed_Capacity_Dynamic_Array)
// 		array_len := (^int)(rawptr(uintptr(value_ptr) + array_info.len_offset))
	
// 		if text[pos^] != '{' {
// 			return false
// 		}
// 		pos^ += 1
// 		array_len^ = 0
	
// 		index := 0
	
// 		for {
// 			tg_skip_space(text, pos)
	
// 			if pos^ >= len(text) {
// 				return false
// 			}
	
// 			if text[pos^] == '}' {
// 				pos^ += 1
// 				return true
// 			}
	
// 			if index >= array_info.capacity {
// 				return false
// 			}
	
// 			elem_ptr := rawptr(uintptr(value_ptr) + uintptr(index*array_info.elem_size))
// 			tg_zero_raw(elem_ptr, array_info.elem.size)
	
// 			if !tg_read_value(text, pos, elem_ptr, array_info.elem) {
// 				return false
// 			}
	
// 			index += 1
// 			array_len^ = index
	
// 			tg_skip_space(text, pos)
	
// 			if pos^ >= len(text) {
// 				return false
// 			}
	
// 			if text[pos^] == ',' {
// 				pos^ += 1
// 			} else if text[pos^] != '}' {
// 				return false
// 			}
// 		}
// 	}

// 	if rf.is_dynamic_array(base_info) {
// 		array_info := base_info.variant.(rf.Type_Info_Dynamic_Array)
	
// 		if text[pos^] != '{' {
// 			return false
// 		}
// 		pos^ += 1
	
// 		array := (^runtime.Raw_Dynamic_Array)(value_ptr)
// 		if array.allocator.procedure == nil {
// 			array.allocator = context.allocator
// 		}
// 		array.len = 0
	
// 		for {
// 			tg_skip_space(text, pos)
	
// 			if pos^ >= len(text) {
// 				return false
// 			}
	
// 			if text[pos^] == '}' {
// 				pos^ += 1
// 				return true
// 			}
	
// 			if !tg_dynamic_array_reserve(array, array_info.elem, array_info.elem_size, array.len+1) {
// 				return false
// 			}
	
// 			elem_ptr := rawptr(uintptr(array.data) + uintptr(array.len*array_info.elem_size))
// 			tg_zero_raw(elem_ptr, array_info.elem.size)
	
// 			if !tg_read_value(text, pos, elem_ptr, array_info.elem) {
// 				return false
// 			}
// 			array.len += 1
	
// 			tg_skip_space(text, pos)
	
// 			if pos^ >= len(text) {
// 				return false
// 			}
	
// 			if text[pos^] == ',' {
// 				pos^ += 1
// 			} else if text[pos^] != '}' {
// 				return false
// 			}
// 		}
// 	}

// 	if rf.is_enumerated_array(base_info) {
// 		array := base_info.variant.(rf.Type_Info_Enumerated_Array)
// 		index_info := rf.type_info_base(array.index)
// 		if !rf.is_enum(index_info) {
// 			return false
// 		}
// 		index_enum := index_info.variant.(rf.Type_Info_Enum)
	
// 		if text[pos^] != '{' {
// 			return false
// 		}
// 		pos^ += 1
	
// 		for {
// 			tg_skip_space(text, pos)
	
// 			if pos^ >= len(text) {
// 				return false
// 			}
	
// 			if text[pos^] == '}' {
// 				pos^ += 1
// 				return true
// 			}
	
// 			key_start := pos^
// 			for pos^ < len(text) && text[pos^] != '=' && text[pos^] != ',' && text[pos^] != '}' {
// 				pos^ += 1
// 			}
	
// 			if pos^ >= len(text) || text[pos^] != '=' {
// 				return false
// 			}
	
// 			key := strings.trim_space(text[key_start:pos^])
// 			pos^ += 1
	
// 			enum_index := -1
// 			for i in 0..<len(index_enum.names) {
// 				if index_enum.names[i] == key {
// 					enum_index = i
// 					break
// 				}
// 			}
	
// 			elem_index := -1
// 			if enum_index >= 0 {
// 				enum_value := i64(index_enum.values[enum_index])
// 				elem_index = enum_index
	
// 				if !array.is_sparse {
// 					elem_index = int(enum_value - i64(array.min_value))
// 				}
// 			}
	
// 			if elem_index < 0 || elem_index >= array.count {
// 				if !tg_skip_value(text, pos) {
// 					return false
// 				}
// 			} else {
// 				elem_ptr := rawptr(uintptr(value_ptr) + uintptr(elem_index*array.elem_size))
// 				if !tg_read_value(text, pos, elem_ptr, array.elem) {
// 					return false
// 				}
// 			}
	
// 			tg_skip_space(text, pos)
	
// 			if pos^ >= len(text) {
// 				return false
// 			}
	
// 			if text[pos^] == ',' {
// 				pos^ += 1
// 			} else if text[pos^] != '}' {
// 				return false
// 			}
// 		}
// 	}

// 	if rf.is_array(base_info) {
// 		array := base_info.variant.(rf.Type_Info_Array)

// 		if text[pos^] != '{' {
// 			return false
// 		}
// 		pos^ += 1

// 		array_index := 0

// 		for {
// 			tg_skip_space(text, pos)

// 			if pos^ >= len(text) {
// 				return false
// 			}

// 			if text[pos^] == '}' {
// 				pos^ += 1
// 				return true
// 			}

// 			if array_index < array.count {
// 				elem_ptr := rawptr(uintptr(value_ptr) + uintptr(array_index * array.elem_size))
// 				if !tg_read_value(text, pos, elem_ptr, array.elem) {
// 					return false
// 				}
// 			} else {
// 				if !tg_skip_value(text, pos) {
// 					return false
// 				}
// 			}
// 			array_index += 1

// 			tg_skip_space(text, pos)

// 			if pos^ >= len(text) {
// 				return false
// 			}

// 			if text[pos^] == ',' {
// 				pos^ += 1
// 			} else if text[pos^] != '}' {
// 				return false
// 			}
// 		}
// 	}

// 	if rf.is_struct(base_info) {
// 		if text[pos^] != '{' {
// 			return false
// 		}
// 		pos^ += 1

// 		for {
// 			tg_skip_space(text, pos)

// 			if pos^ >= len(text) {
// 				return false
// 			}

// 			if text[pos^] == '}' {
// 				pos^ += 1
// 				return true
// 			}

// 			key_start := pos^

// 			for pos^ < len(text) && text[pos^] != '=' && text[pos^] != ',' && text[pos^] != '}' {
// 				pos^ += 1
// 			}

// 			if pos^ >= len(text) || text[pos^] != '=' {
// 				return false
// 			}

// 			key := strings.trim_space(text[key_start:pos^])
// 			pos^ += 1

// 			if len(key) == 0 {
// 				return false
// 			}

// 			tg_skip_space(text, pos)
// 			field := rf.struct_field_by_name(base_info.id, key)

// 			if field.name == "" || !tg_is_supported_type(field.type) {
// 				if !tg_skip_value(text, pos) {
// 					return false
// 				}
// 			} else {
// 				field_ptr := rawptr(uintptr(value_ptr) + field.offset)
// 				if !tg_read_value(text, pos, field_ptr, field.type) {
// 					return false
// 				}
// 			}

// 			tg_skip_space(text, pos)

// 			if pos^ >= len(text) {
// 				return false
// 			}

// 			if text[pos^] == ',' {
// 				pos^ += 1
// 			} else if text[pos^] != '}' {
// 				return false
// 			}
// 		}
// 	}

// 	if rf.is_enum(base_info) {
// 		token, ok := tg_read_atom(text, pos)
// 		if !ok {
// 			return false
// 		}
	
// 		enum_info := base_info.variant.(rf.Type_Info_Enum)
	
// 		for i in 0..<len(enum_info.names) {
// 			if enum_info.names[i] == token {
// 				return tg_enum_write_i64(value_ptr, enum_info.base, i64(enum_info.values[i]))
// 			}
// 		}
	
// 		// Also accept numeric values for compatibility and unnamed enum values.
// 		value, v_ok := strconv.parse_i64(token)
// 		if !v_ok {
// 			return false
// 		}
	
// 		return tg_enum_write_i64(value_ptr, enum_info.base, value)
// 	}

// 	switch base_info.id {
// 	case typeid_of(bool):
// 		token, ok := tg_read_atom(text, pos)
// 		if !ok {
// 			return false
// 		}
// 		v, v_ok := strconv.parse_bool(token)
// 		if !v_ok {
// 			return false
// 		}
// 		(^bool)(value_ptr)^ = v

// 	case typeid_of(int):
// 		token, ok := tg_read_atom(text, pos)
// 		if !ok {
// 			return false
// 		}
// 		v, v_ok := strconv.parse_int(token)
// 		if !v_ok {
// 			return false
// 		}
// 		(^int)(value_ptr)^ = v

// 	case typeid_of(uint):
// 		token, ok := tg_read_atom(text, pos)
// 		if !ok {
// 			return false
// 		}
// 		v, v_ok := strconv.parse_uint(token)
// 		if !v_ok {
// 			return false
// 		}
// 		(^uint)(value_ptr)^ = v

// 	case typeid_of(i8):
// 		token, ok := tg_read_atom(text, pos)
// 		if !ok {
// 			return false
// 		}
// 		v, v_ok := strconv.parse_i64(token)
// 		if !v_ok || v < -128 || v > 127 {
// 			return false
// 		}
// 		(^i8)(value_ptr)^ = i8(v)

// 	case typeid_of(i16):
// 		token, ok := tg_read_atom(text, pos)
// 		if !ok {
// 			return false
// 		}
// 		v, v_ok := strconv.parse_i64(token)
// 		if !v_ok || v < -32768 || v > 32767 {
// 			return false
// 		}
// 		(^i16)(value_ptr)^ = i16(v)

// 	case typeid_of(i32):
// 		token, ok := tg_read_atom(text, pos)
// 		if !ok {
// 			return false
// 		}
// 		v, v_ok := strconv.parse_i64(token)
// 		if !v_ok || v < -2147483648 || v > 2147483647 {
// 			return false
// 		}
// 		(^i32)(value_ptr)^ = i32(v)

// 	case typeid_of(i64):
// 		token, ok := tg_read_atom(text, pos)
// 		if !ok {
// 			return false
// 		}
// 		v, v_ok := strconv.parse_i64(token)
// 		if !v_ok {
// 			return false
// 		}
// 		(^i64)(value_ptr)^ = v

// 	case typeid_of(u8):
// 		token, ok := tg_read_atom(text, pos)
// 		if !ok {
// 			return false
// 		}
// 		v, v_ok := strconv.parse_u64(token)
// 		if !v_ok || v > 255 {
// 			return false
// 		}
// 		(^u8)(value_ptr)^ = u8(v)

// 	case typeid_of(u16):
// 		token, ok := tg_read_atom(text, pos)
// 		if !ok {
// 			return false
// 		}
// 		v, v_ok := strconv.parse_u64(token)
// 		if !v_ok || v > 65535 {
// 			return false
// 		}
// 		(^u16)(value_ptr)^ = u16(v)

// 	case typeid_of(u32):
// 		token, ok := tg_read_atom(text, pos)
// 		if !ok {
// 			return false
// 		}
// 		v, v_ok := strconv.parse_u64(token)
// 		if !v_ok || v > 0xFFFF_FFFF {
// 			return false
// 		}
// 		(^u32)(value_ptr)^ = u32(v)

// 	case typeid_of(u64):
// 		token, ok := tg_read_atom(text, pos)
// 		if !ok {
// 			return false
// 		}
// 		v, v_ok := strconv.parse_u64(token)
// 		if !v_ok {
// 			return false
// 		}
// 		(^u64)(value_ptr)^ = v

// 	case typeid_of(f32):
// 		token, ok := tg_read_atom(text, pos)
// 		if !ok {
// 			return false
// 		}
// 		v, v_ok := strconv.parse_f32(token)
// 		if !v_ok {
// 			return false
// 		}
// 		(^f32)(value_ptr)^ = v

// 	case typeid_of(f64):
// 		token, ok := tg_read_atom(text, pos)
// 		if !ok {
// 			return false
// 		}
// 		v, v_ok := strconv.parse_f64(token)
// 		if !v_ok {
// 			return false
// 		}
// 		(^f64)(value_ptr)^ = v

// 	case typeid_of(string):
// 		token: string
// 		ok: bool

// 		if text[pos^] == '"' || text[pos^] == '\'' {
// 			token, ok = tg_read_quoted(text, pos)
// 		} else {
// 			token, ok = tg_read_atom(text, pos)
// 		}

// 		if !ok {
// 			return false
// 		}

// 		if len(token) > 0 && (token[0] == '"' || token[0] == '\'') {
// 			v, allocated, unquote_ok := strconv.unquote_string(token)
// 			if !unquote_ok {
// 				return false
// 			}

// 			if allocated {
// 				(^string)(value_ptr)^ = v
// 			} else {
// 				(^string)(value_ptr)^ = strings.clone(v)
// 			}
// 		} else {
// 			(^string)(value_ptr)^ = strings.clone(token)
// 		}

// 	case:
// 		return false
// 	}

// 	return true
// }


// // tg_read :: proc(path: string, settings: ^$T, name: string = "", check_types: bool = true) -> bool{
// // 	if settings == nil {
// // 		return false
// // 	}

// // 	root_info := rf.type_info_base(type_info_of(T))
// // 	if !rf.is_struct(root_info) {
// // 		return false
// // 	}

// // 	data, err := os.read_entire_file(path,context.allocator)
// // 	if err != nil {
// // 		return false
// // 	}
// // 	defer delete(data)

// // 	text := string(data)
// // 	// name := ""
// // 	// if len(names) > 0 {
// // 	// 	name = names[0]
// // 	// }

// // 	type_name := tg_type_name(type_info_of(T))
// // 	block, found := tg_find_next_block(text, 0)

// // 	// No typed blocks: use the original flat settings format.
// // 	if !found {
// // 		return tg_read_fields(text, rawptr(settings), root_info)
// // 	}

// // 	for {
// // 		if !block.valid {
// // 			return false
// // 		}

// // 		if name != "" {
// // 			if block.name == name {
// // 				if block.type_name != type_name {
// // 					fmt.printf("Settings: block '%s' contains type '%s', expected '%s'\n", name, block.type_name, type_name)
// // 					return false
// // 				}

// // 				return tg_read_fields(text[block.body_start:block.body_end], rawptr(settings), root_info)
// // 			}
// // 		} else if block.type_name == type_name {
// // 			return tg_read_fields(text[block.body_start:block.body_end], rawptr(settings), root_info)
// // 		}

// // 		if block.end >= len(text) {
// // 			break
// // 		}

// // 		next, next_found := tg_find_next_block(text, block.end)
// // 		if !next_found {
// // 			break
// // 		}
// // 		block = next
// // 	}

// // 	if name != "" {
// // 		fmt.printf("Settings: block '%s' was not found\n", name)
// // 	} else {
// // 		fmt.printf("Settings: no block found for type '%s'\n", type_name)
// // 	}

// // 	return false
// // }
// tg_enum_read_i64 :: proc(value_ptr: rawptr, info: ^rf.Type_Info) -> (value: i64, ok: bool) {
// 	base_info := rf.type_info_base(info)

// 	switch rf.typeid_base(base_info.id) {
// 	case typeid_of(int):
// 		return i64((^int)(value_ptr)^), true
// 	case typeid_of(uint):
// 		return i64((^uint)(value_ptr)^), true
// 	case typeid_of(i8):
// 		return i64((^i8)(value_ptr)^), true
// 	case typeid_of(i16):
// 		return i64((^i16)(value_ptr)^), true
// 	case typeid_of(i32):
// 		return i64((^i32)(value_ptr)^), true
// 	case typeid_of(i64):
// 		return (^i64)(value_ptr)^, true
// 	case typeid_of(u8):
// 		return i64((^u8)(value_ptr)^), true
// 	case typeid_of(u16):
// 		return i64((^u16)(value_ptr)^), true
// 	case typeid_of(u32):
// 		return i64((^u32)(value_ptr)^), true
// 	case typeid_of(u64):
// 		return i64((^u64)(value_ptr)^), true
// 	case:
// 		return 0, false
// 	}
// }

// tg_enum_write_i64 :: proc(value_ptr: rawptr, info: ^rf.Type_Info, value: i64) -> bool {
// 	base_info := rf.type_info_base(info)

// 	switch rf.typeid_base(base_info.id) {
// 	case typeid_of(int):
// 		if size_of(int) == 4 && (value < -2147483648 || value > 2147483647) {
// 			return false
// 		}
// 		(^int)(value_ptr)^ = int(value)

// 	case typeid_of(uint):
// 		if value < 0 || (size_of(uint) == 4 && value > 4294967295) {
// 			return false
// 		}
// 		(^uint)(value_ptr)^ = uint(value)

// 	case typeid_of(i8):
// 		if value < -128 || value > 127 {
// 			return false
// 		}
// 		(^i8)(value_ptr)^ = i8(value)

// 	case typeid_of(i16):
// 		if value < -32768 || value > 32767 {
// 			return false
// 		}
// 		(^i16)(value_ptr)^ = i16(value)

// 	case typeid_of(i32):
// 		if value < -2147483648 || value > 2147483647 {
// 			return false
// 		}
// 		(^i32)(value_ptr)^ = i32(value)

// 	case typeid_of(i64):
// 		(^i64)(value_ptr)^ = value

// 	case typeid_of(u8):
// 		if value < 0 || value > 255 {
// 			return false
// 		}
// 		(^u8)(value_ptr)^ = u8(value)

// 	case typeid_of(u16):
// 		if value < 0 || value > 65535 {
// 			return false
// 		}
// 		(^u16)(value_ptr)^ = u16(value)

// 	case typeid_of(u32):
// 		if value < 0 || value > 4294967295 {
// 			return false
// 		}
// 		(^u32)(value_ptr)^ = u32(value)

// 	case typeid_of(u64):
// 		if value < 0 {
// 			return false
// 		}
// 		(^u64)(value_ptr)^ = u64(value)

// 	case:
// 		return false
// 	}

// 	return true
// }

// tg_write_unsupported_comment :: proc(builder: ^strings.Builder, field_name: string, info: ^rf.Type_Info, depth: int) {
// 	tg_write_indent(builder, depth)
// 	strings.write_string(builder, "// ")
// 	strings.write_string(builder, field_name)
// 	strings.write_string(builder, ": unsupported type ")
// 	rf.write_type_builder(builder, info)
// 	strings.write_byte(builder, '\n')
// }
// tg_write_indent :: proc(builder: ^strings.Builder, depth: int) {
// 	for _ in 0..<depth {
// 		strings.write_byte(builder, '\t')
// 	}
// }
