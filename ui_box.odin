package tg_render

import "vendor:stb/truetype"

import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
// import hm "handle_map_static_virtual"
import hm "core:container/handle_map"
import "core:time"
import lin"core:math/linalg"
import cl"clay-odin"
import "core:encoding/json"
import "core:os"
import "core:strconv"
import steam "steamworks"
import sdl3i"vendor:sdl3/image"
import "core:sort"
import "core:slice"


UI_Box_Handle::distinct Handle
UI_Box_Data::struct{
	handle:UI_Box_Handle,
	cl_inst_hd:Clay_I_Handle,
	offset:[2]f32,
	name:string,
	is_visible:bool,
	// sizing_type:cl.SizingType,
	last_interact:f64,
	inspector:Inspector,
	update_proc:proc(ui_box_handle:UI_Box_Handle),
	
}


delete_ui_box::proc(hd:UI_Box_Handle)->(found:bool){
	box,ok:=get_ui_box(hd)
	if ok{
		if inspector.fields != nil{
			delete(inspector.fields)
			delete(inspector.parent_history)
		}
	}
	found, _ = hm.remove(&s.ui.boxes,hd)
	return
}
create_ui_box::proc(ui_box_data:UI_Box_Data,cl_inst_hd:Clay_I_Handle)->(hd:UI_Box_Handle){
	assert(cl_inst_hd != {0,0},"create_ui_box() cl_inst_hd == {0,0}")
	box_data:=ui_box_data
	box_data.cl_inst_hd = cl_inst_hd
	hd=hm.add(&s.ui.boxes,box_data)
	return
}
get_ui_box::proc(hd:UI_Box_Handle)->(ui_box_data:^UI_Box_Data,ok:bool){
	ui_box_data,ok=hm.get(&s.ui.boxes,hd)
	return
}
do_ui_boxes::proc(){
	boxes_iterator:=hm.iterator_make(&s.ui.boxes)
	clear(&s.ui.sorted_boxes)
	for box, box_hd in hm.dynamic_iterate(&boxes_iterator){
		append(&s.ui.sorted_boxes,box)
	}
	slice.sort_by(s.ui.sorted_boxes[:],sort_ui_boxes)
	for box in s.ui.sorted_boxes[:]{
		if box.update_proc != nil{
			box.update_proc(box.handle)
		}
	}
}
sort_ui_boxes::proc(box1,box2:^UI_Box_Data)->bool{
	if box1.last_interact < box2.last_interact{return true}
	return false
}
start_ui_box::proc(ui_box_handle:UI_Box_Handle)->(ui_box:^UI_Box_Data,cl_inst:^Clay_Instance,ok:bool,vis:bool){
	ui_box,ok=get_ui_box(ui_box_handle)
	if !ok{
		ok = false
		vis = false
		return
	}
	vis = ui_box.is_visible
	cl_inst=get_clay_instance(ui_box.cl_inst_hd)
	if cl_inst == nil{
		ok = false
		vis = false
		return 
	}
	if !ui_box.is_visible {
		ok = false 
		vis = false
		return
	}
	return
}
interact_ui_box::proc(ui_box_handle:UI_Box_Handle){
	ui_box,ok:=get_ui_box(ui_box_handle)
	if !ok {return}
	if ui_box == nil{return}
	if cl.Hovered(){
		ui_box.last_interact = s.time.time
	}
}
interact_ui_box_click::proc(ui_box_handle:UI_Box_Handle){
	ui_box,ok:=get_ui_box(ui_box_handle)
	if !ok {return}
	if ui_box == nil{return}
	if cl.Hovered(){
		if is_input_event(.ui_l_c,always_consume_d = true){
			ui_box.last_interact = s.time.time
		}
	}
}
ui_box_dec::proc(
	ui_box_hd:UI_Box_Handle,

	border_col_id:Color_Types = .border,
	background_col_id:Color_Types = .element_background,
	background_huv_col_id:Color_Types = .element_background,
	
	border_size_id:UI_Size = .normal,
	padding_size_id:UI_Size = .normal,
	child_gap_id:UI_Size = .small,
	roundnes_id:UI_Roundnes = .sharp,

	layout_direction :cl.LayoutDirection= .TopToBottom,
	// child_alignment: = cl.ChildAlignment{x=.Center,y=.Center},
	
	clip:cl.ClipElementConfig={
		horizontal=false, // clip overflowing elements on the "X" axis
		vertical=false, // clip overflowing elements on the "Y" axis
		childOffset={}, // offsets the [X,Y] positions of all child elements, primarily for scrolling containers
	},
	do_sizing:bool=false,
	sizing:cl.Sizing={},
)->(dec:cl.ElementDeclaration){
	new_sizing:cl.Sizing={ cl.SizingFit(), cl.SizingFit() }
	if do_sizing == true{
		new_sizing = sizing
	}

	border_col:=get_color(border_col_id)
	background_col:=get_color(background_col_id)
	background_huv_col:=get_color(background_huv_col_id)

	border_size:= get_ui_border(border_size_id)
	padding_size:= get_ui_pading(padding_size_id)
	child_gap_id:= get_ui_child_gap(child_gap_id)
	roundnes_id:= get_ui_roundnes(roundnes_id)

	ui_box,ok:=get_ui_box(ui_box_hd)
	if !ok{
		log.log(.Warning,"invalid drag_box HD")
		return
	}
	// fmt.print("1\n")
	button_hov:=cl.Hovered()
	new_clip:=clip
	if clip.horizontal{ new_clip.childOffset = cl.GetScrollOffset()}
	if clip.vertical{new_clip.childOffset = cl.GetScrollOffset()}
	dec = cl.ElementDeclaration{
		layout = {
				layoutDirection = layout_direction,
				sizing = new_sizing,
				// childAlignment = child_alignment,
				padding = {padding_size,padding_size,padding_size,padding_size},
				childGap = child_gap_id,
			},
		floating ={
			offset = {ui_box.offset.x,ui_box.offset.y},
			attachTo = .Root,
			attachment = {
				element = .CenterCenter,
				parent = .CenterCenter,
			},
			// pointerCaptureMode = .Capture,
	
		},
		clip = new_clip,
		// transition = cl.TransitionElementConfig{

		// 	handler = cl.EaseOut,
		// 	duration = .2,
		// 	properties = cl.TransitionPropertyFlags{.X,.Y},
		// 	interactionHandling = .AllowInteractionsWhileTransitioningPosition,
		// 	enter = {
		// 		setInitialState = state_slide_in_right,
		// 		trigger = cl.TransitionEnterTriggerType.TriggerOnFirstParentFrame,
		// 	},
		// 	exit = {
		// 		setFinalState = state_slide_in_right,
		// 		// trigger=         .TriggerOnFirstParentFrame,
		// 		// siblingOrdering: TriggerOnFirstParentFrame,
		// 	},

		// },
		backgroundColor = background_col if !button_hov else background_huv_col,
		border = cl.BorderElementConfig{
			color = border_col,
			width = cl.BorderWidth{border_size,border_size,border_size,border_size,0}
		},
	}
	return dec
}



ui_drag_box_dec::proc(
	ui_box_hd:UI_Box_Handle,
	cursor_delta:[2]f32,


	border_col_id:Color_Types = .border,
	background_col_id:Color_Types = .element_background,
	background_huv_col_id:Color_Types = .element_background,
	
	border_size_id:UI_Size = .normal,
	padding_size_id:UI_Size = .normal,
	child_gap_id:UI_Size = .small,
	roundnes_id:UI_Roundnes = .sharp,
)->(dec:cl.ElementDeclaration){

	border_col:=get_color(border_col_id)
	background_col:=get_color(background_col_id)
	background_huv_col:=get_color(background_huv_col_id)

	border_size:= get_ui_border(border_size_id)
	padding_size:= get_ui_pading(padding_size_id)
	child_gap_id:= get_ui_child_gap(child_gap_id)
	roundnes_id:= get_ui_roundnes(roundnes_id)

	ui_box,ok:=get_ui_box(ui_box_hd)
	button_hov:=cl.Hovered()
	if !ok{
		log.log(.Warning,"invalid drag_box HD")
		return
	}
	if button_hov{
		if is_input_event(.ui_l_c_d){
			interact_ui_box(ui_box_hd)
			ui_box.offset += cursor_delta
		}
	}

	// fmt.print("1\n")
	dec = cl.ElementDeclaration{
		layout = {
				layoutDirection = .TopToBottom,
				sizing = { cl.SizingGrow(), cl.SizingGrow() },
				childAlignment = cl.ChildAlignment{x=.Center,y=.Center},
				padding = {padding_size,padding_size,padding_size,padding_size},

				childGap = child_gap_id,
			},
		// floating ={
			// attachment = {.Root},
			// expand = {1000,1000},
			// offset = {ui_box.offset.x,ui_box.offset.y},
			// attachTo = .Parent,
			// attachTo = .Root,
			// attachment = {
			// 	element = .CenterCenter,
			// 	parent = .CenterCenter,
			// },
			// pointerCaptureMode = .Capture,
			// attachment= cl.FloatingAttachPoints{
			// 	element = cl.FloatingAttachPointType.RightTop,
			// 	parent =   cl.FloatingAttachPointType.RightTop,
			// }
		// },
		// transition = cl.TransitionElementConfig{

		// 	handler = cl.EaseOut,
		// 	duration = .2,
		// 	properties = cl.TransitionPropertyFlags{.X,.Y},
		// 	interactionHandling = .AllowInteractionsWhileTransitioningPosition,
		// 	enter = {
		// 		setInitialState = state_slide_in_right,
		// 		trigger = cl.TransitionEnterTriggerType.TriggerOnFirstParentFrame,
		// 	},
		// 	exit = {
		// 		setFinalState = state_slide_in_right,
		// 		// trigger=         .TriggerOnFirstParentFrame,
		// 		// siblingOrdering: TriggerOnFirstParentFrame,
		// 	},

		// },
		backgroundColor = background_col if !button_hov else background_huv_col,
		border = cl.BorderElementConfig{
			color = border_col,
			width = cl.BorderWidth{border_size,border_size,border_size,border_size,0}
		},
	}
	return dec
}

ui_box_close_button_dec::proc(
	ui_box_hd:UI_Box_Handle,
	cursor_delta:[2]f32,
	is_draging:bool,
)->(dec:cl.ElementDeclaration){
	
	return
}


theme_picker_ui_box::proc(ui_box_handle:UI_Box_Handle){
	ui_box,cl_inst,ok,vis:=start_ui_box(ui_box_handle)
	if !ok {return}

	if !vis {return}
	if cl.UI(cl.ID("theme_picker_ui_box_container"))(ui_box_dec(ui_box_handle,sizing ={cl.SizingFit({0,cast(f32)cl_inst.wh.x*.8}),cl.SizingFit({0,cast(f32)cl_inst.wh.y*.8})} , do_sizing = true)) {

		
		if cl.UI(cl.ID("drag_box_theme_picker_ui_box_ui_box"))(
			ui_drag_box_dec(ui_box_handle,s.input_events.mouse_move)
		){
		
			cl.Text("Theme Picker",text_dec())
		}

		size:=cl.SizingPercent(.5)
		pading:=get_ui_pading(.small)
		if cl.UI(cl.ID("theme_picker_constrante"))({
				layout = {
					// sizing = { width={constraints={sizePercent=13},type=.Percent}, height={constraints={sizePercent=13},type=.Percent},},
					sizing = {cl.SizingFit(),cl.SizingFit()},
					layoutDirection = .TopToBottom,
				},
				clip = {
					// horizontal
					vertical = true,
					childOffset = cl.GetScrollOffset()
				},
			}
		){
			id:u32
			for &theme_groop ,groop_index in &s.ui.themes{
				groop_name:=text_dec()
				if cl.UI(cl.ID("theme_picker_Groop",id))(
					defalt_box_dec(child_alignment = {.Left,.Top})
				// {}
				){
					if cl.UI(cl.ID("Groop_Name_row_theme_picker",id))({layout = {layoutDirection = .LeftToRight,},}){
						// cl.Text("Name:",name)
						cl.TextDynamic(transmute(string)theme_groop[0].groop_name[:],groop_name)
					}
					for &theme ,row in &theme_groop{
						name:=text_dec(.text,.small,style_overide = &theme)
						author:=text_dec(.text_muted,.small,style_overide = &theme)
						appearance:=text_dec(.text_accent,.small,style_overide = &theme)
						id+=1
						if cl.UI(cl.ID("theme_picker_row",id))(
							defalt_box_dec(child_alignment = {.Left,.Top},style_overide = &theme)
							// {}
						){
							if cl.UI(cl.ID("Name_row_theme_picker",id))({layout = {layoutDirection = .LeftToRight,},}){
								// cl.Text("Sub Name:",sub_name)
								cl.TextDynamic(transmute(string)theme.name[:],name)
							}
							if cl.UI(cl.ID("Author_row_theme_picker",id))({layout = {layoutDirection = .LeftToRight,},}){
								// cl.Text("Author:",author)
								cl.TextDynamic(transmute(string)theme.author[:],author)
							}
							if cl.UI(cl.ID("Appearance_row_theme_picker",id))({layout = {layoutDirection = .LeftToRight,},}){
								// cl.Text("Appearance:",appearance)
								cl.TextDynamic(transmute(string)theme.appearance[:],appearance)
							}
							if cl.Hovered(){
								if is_input_event(.ui_l_c,always_consume_d = true){
									interact_ui_box(ui_box_handle)
									set_ui_style(theme)
								}
							}
						}
					}
				}
			}
		}
	interact_ui_box_click(ui_box_handle)
	}
}
