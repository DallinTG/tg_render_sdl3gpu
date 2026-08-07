package tg_render

import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import "core:reflect"
import "core:strconv"
import cl"clay-odin"

import hm "core:container/handle_map"

import lin"core:math/linalg"

Inspector::struct{
	fields:[dynamic]Field,
	parent_history:[dynamic]any,
	parent: any,
	do_depth:bool,
}


Field :: struct {
	name:  string,
	value: any,
	tag:   reflect.Struct_Tag,
	field_type:Field_Type,
	depth: int,
}

Field_Type::enum{
	nil,
	info,
	bool,
	enum_flag,
	int,
	uint,
	float,
}

selected := 0
inspector:Inspector

inspect :: proc() {
	inspector.parent = s
	collect_fields(&inspector)
	for field in inspector.fields{
		fmt.print("new_fild:=",field,"\n\n")
	}

}

// collect_fields :: proc(fields: ^[dynamic]Field, value: any, tag: reflect.Struct_Tag, depth := 0) {
// 	for field in reflect.struct_fields_zipped(value.id) {
// 		field_value := reflect.struct_field_value(value, field)
// 		field_tag := field.tag
// 		if field_tag == "" {field_tag = tag}

// 		if reflect.is_struct(field.type) {
// 			append(fields, Field{field.name, nil, field_tag, depth})
// 			collect_fields(fields, field_value, field_tag, depth + 1)
// 		} else {
// 			append(fields, Field{field.name, field_value, field_tag, depth})
// 		}
// 	}
// }
clear_fields::proc(insp: ^Inspector){
	clear(&insp.fields)
}
collect_fields :: proc(insp: ^Inspector, value: any = nil, depth := 0) {
	// fmt.print("value:=",value,"\n")
	// clear(&insp.fields)
	value:=value
	if value == nil{value = insp.parent}
	fields:=reflect.struct_fields_zipped(reflect.deref(value).id)
	for field in fields {
		field_value := reflect.struct_field_value(reflect.deref(value), field)
		field_tag := field.tag
		// if field_tag == "" {field_tag = tag}

		if reflect.is_struct(field.type) && insp.do_depth {
			append(&insp.fields, Field{name = field.name,value =  nil,tag =  field_tag,field_type = .nil,depth =  depth})
			collect_fields(insp, field_value, depth + 1)
		} else {
			append(&insp.fields, Field{name = field.name,value = field_value,tag = field_tag,field_type = .nil,depth = depth})
		}
	}
}

edit :: proc(field: Field, direction: int) {
	if field.value == nil {return}

	#partial switch reflect.underlying_type_kind(field.value.id) {
	case .Enum:
		values := reflect.enum_field_values(field.value.id)
		if len(values) == 0 {return}

		current, _ := reflect.as_i64(field.value)
		index := 0
		for value, i in values {
			if cast(i64)value == current {index = i}
		}
		index = (index + direction + len(values)) % len(values)
		write_number(field.value, f64(values[index]))

	case .Boolean:
		current, _ := reflect.as_bool(field.value)
		write_number(field.value, current ? 0 : 1)

	case .Integer, .Rune, .Float:
		current, number_ok := reflect.as_f64(field.value)
		if !number_ok {return}

		step, found := tag_number(field.tag, "step")
		if !found {step = 1}
		next := current + step * f64(direction)
		if value, min_found := tag_number(field.tag, "min"); min_found {next = max(next, value)}
		if value, max_found := tag_number(field.tag, "max"); max_found {next = min(next, value)}
		write_number(field.value, next)

	case:
	}
}

tag_number :: proc(tag: reflect.Struct_Tag, key: string) -> (f64, bool) {
	text, found := reflect.struct_tag_lookup(tag, key)
	if !found {return 0, false}
	return strconv.parse_f64(text)
}

write_number :: proc(value: any, number: f64) -> bool {
	switch &dst in reflect.any_core(value) {
	case bool:
		dst = number != 0
	case int:
		dst = int(number)
	case i8:
		dst = i8(number)
	case i16:
		dst = i16(number)
	case i32:
		dst = i32(number)
	case i64:
		dst = i64(number)
	case uint:
		dst = uint(number)
	case u8:
		dst = u8(number)
	case u16:
		dst = u16(number)
	case u32:
		dst = u32(number)
	case u64:
		dst = u64(number)
	case f16:
		dst = f16(number)
	case f32:
		dst = f32(number)
	case f64:
		dst = number
	case:
		return false
	}
	return true
}




//_____________________ UI for the inspector_________________________


inspector_ui_box::proc(ui_box_handle:UI_Box_Handle){
	ui_box,cl_inst,ok,vis:=start_ui_box(ui_box_handle)
	index:=cast(u32)ui_box_handle.idx
	if !ok {return}

	if !vis {return}
	if cl.UI(cl.ID("inspector_ui_box_container",index))(ui_box_dec(ui_box_handle,sizing ={cl.SizingFit({0,cast(f32)cl_inst.wh.x*.8}),cl.SizingFit({0,cast(f32)cl_inst.wh.y*.8})} , do_sizing = true)) {

		
		if cl.UI(cl.ID("drag_box_inspector_ui_box",index))(
			ui_drag_box_dec(ui_box_handle,s.input_events.mouse_move)
		){
			cl.Text("Inspector",text_dec())
		}
		inspector_go_back_button(&ui_box.inspector,cast(u32)ui_box_handle.idx)

	
		pading:=get_ui_pading(.small)
		clear_fields(&ui_box.inspector)
		collect_fields(&ui_box.inspector)
		if cl.UI(cl.ID("inspector_constrante",index))(defalt_box_dec(clip = {vertical=true,childOffset=cl.GetScrollOffset()},child_alignment = {.Left,.Top} )){
			id:u32
			for &fild ,fild_index in &ui_box.inspector.fields{
				if cl.UI(cl.ID("inspector_constrante_row",cast(u32)fild_index))({
					layout = {
						sizing = {cl.SizingGrow(),cl.SizingFit()},
						layoutDirection = .LeftToRight,
					},
				}
				){
					if cl.UI(cl.ID("inspector_constrante_row_spacer_1",cast(u32)fild_index))({layout = {sizing = {cl.SizingFit(),cl.SizingFit()},layoutDirection = .LeftToRight,},}){
						cl.TextDynamic(fild.name,text_dec(text_size_id = .small))
					}
					if cl.UI(cl.ID("inspector_constrante_row_spacer_2",cast(u32)fild_index))({layout = {sizing = {cl.SizingGrow(),cl.SizingFit()},layoutDirection = .LeftToRight,},}){
						cl.Text("     ",text_dec())
					}
					if cl.UI(cl.ID("inspector_constrante_row_spacer_3",cast(u32)fild_index))({layout = {sizing = {cl.SizingFit(),cl.SizingFit()},layoutDirection = .LeftToRight,},}){
						type_info:=type_info_of(fild.value.id)
						switch &dst in reflect.any_core(fild.value) {
						case bool:
							true_false_button(&dst,cast(u32)fild_index)
						case :
							if reflect.is_enum(type_info){

								enum_drop_down_menu(fild.value,cast(u32)fild_index)
							}else if reflect.is_struct(type_info){
								change_inspector_parent_button(&ui_box.inspector,fild.value,cast(u32)fild_index)
							}else{

								cl.TextDynamic(value_text(fild.value),text_dec(text_size_id = .small))
							}
						}
					}
				}
			}
		}
		interact_ui_box_click(ui_box_handle)
	}
}

value_text :: proc(value: any) -> string {
	type_info:=type_info_of(value.id)
	if reflect.is_float(type_info) {
		number, _ := reflect.as_f64(value)
		return fmt.tprintf("%.2f", number)
	}
	if reflect.is_struct(type_info) {
		return "Struct:{}"
	}
	if reflect.is_array(type_info) {
		return "Array:{}"
	}
	if reflect.is_dynamic_array(type_info) {
		return "Dnamic Array:{}"
	}
	if reflect.is_enumerated_array(type_info) {
		return "Enumerated Array:{}"
	}
	if reflect.is_fixed_capacity_dynamic_array(type_info) {
		return "Fixed Cap Array:{}"
	}
	return fmt.tprint(value)
}

change_inspector_parent::proc(insp:^Inspector,new_parent:any){
	type_info:=type_info_of(new_parent.id)
	if reflect.is_struct(type_info) {
		append(&insp.parent_history,insp.parent)
		insp.parent = new_parent
	}
}
inspector_go_back::proc(insp:^Inspector){
	if len(insp.parent_history) > 0{
		insp.parent = insp.parent_history[len(insp.parent_history)-1]
		pop(&insp.parent_history)
	}
}
inspector_go_back_button::proc(
	insp:^Inspector,
	id:u32,

	border_col_id:Color_Types = .border,
	background_col_id:Color_Types = .element_background,
	background_huv_col_id:Color_Types = .element_hover,
	
	border_size_id:UI_Size = .normal,
	padding_size_id:UI_Size = .normal,
	child_gap_id:UI_Size = .small,
	roundnes_id:UI_Roundnes = .sharp,

	text_size_id:UI_Size = .small,
	text_col_id:Color_Types = .text,

	style_overide:^UI_Style = nil,
){
	// fmt.print( len(insp.parent_history),"\n")
	if len(insp.parent_history) <= 0{return}
	new_p:=insp.parent_history[len(insp.parent_history)-1]
	type_info:=type_info_of(new_p.id)

	if cl.UI(cl.ID("inspector_go_back_button",id))(
		button_dec(
			border_col_id=border_col_id,
			background_col_id  = background_col_id,
			border_size_id = border_size_id,
			padding_size_id = .small,
			child_gap_id = child_gap_id,
			roundnes_id = roundnes_id,

			layout_direction = .LeftToRight,
			
			do_sizing = true,
			sizing={ cl.SizingFit(), cl.SizingFit() },
			
			style_overide = style_overide,
		)
	){
		cl.Text("Back",text_dec(text_size_id=text_size_id,text_col_id=text_col_id,style_overide=style_overide))
		texture:=get_texture_by_id(.Arrows_Go_Back_Return_Previous)
		if cl.UI(cl.ID("inspector_go_back_button_img",id))(defalt_img_box_dec(texture,border_size_id = .non,img_color = .element_selected,padding_size_id = .non,size = .normal)){}
		if cl.Hovered(){
			if is_input_event(.ui_l_c,always_consume_d = true){
				inspector_go_back(insp)
			}
		}
	}
	
}

change_inspector_parent_button::proc(
	insp:^Inspector,
	new_parent:any,

	id:u32,

	border_col_id:Color_Types = .border,
	background_col_id:Color_Types = .element_background,
	background_huv_col_id:Color_Types = .element_hover,
	
	border_size_id:UI_Size = .normal,
	padding_size_id:UI_Size = .normal,
	child_gap_id:UI_Size = .small,
	roundnes_id:UI_Roundnes = .sharp,

	text_size_id:UI_Size = .small,
	text_col_id:Color_Types = .text,

	style_overide:^UI_Style = nil,
){
	type_info:=type_info_of(new_parent.id)
	if reflect.is_struct(type_info) {
		if cl.UI(cl.ID("change_inspector_parent_button",id))(
			button_dec(
				border_col_id=border_col_id,
				background_col_id  = background_col_id,
				border_size_id = border_size_id,
				padding_size_id = .small,
				child_gap_id = child_gap_id,
				roundnes_id = roundnes_id,
	
				layout_direction = .LeftToRight,
				style_overide = style_overide,
			)
		){
			cl.Text("Jump TO",text_dec(text_size_id=text_size_id,text_col_id=text_col_id,style_overide=style_overide))
			if cl.Hovered(){
				if is_input_event(.ui_l_c,always_consume_d = true){
					change_inspector_parent(insp,new_parent)
				}
			}
		}
	}
}
