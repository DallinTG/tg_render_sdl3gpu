package sand_sim

import tg"../../../tg_render_sdl3gpu"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
// import hm "../../handle_map_static_virtual"
import hm "core:container/handle_map"
import an"../../ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"



create_layout :: proc(dt:=cast(f32)s.time.dt_60_hz) -> cl.ClayArray(cl.RenderCommand) {
	cl.BeginLayout()
	tg.do_ui_boxes()
	if g.info.curent_game_mode == .start {start_menu()}
	if g.info.curent_game_mode == .loby &&  g.server.status == .joining	{loby_joining()}
	if g.info.curent_game_mode == .loby && (g.server.status == .joined || g.server.status == .hosting)	{loby_menu()}
	if g.info.curent_game_mode == .loby &&  g.server.status == .regected	{loby_joining_regected()}
	// sand_sim_cell_id_picker_ui_box(g.ui_boxes.test)
	// tg.theme_picker_ui_box(g.ui_boxes.test)
	tg.draw_notification_buffer(&s.ui.notifications)
	tg.draw_steam_friends()
	tg.draw_steam_lobby_ui()
	tg.draw_debug_info()
	return cl.EndLayout(dt)
}

start_menu::proc(){
	if cl.UI(cl.ID("Outer_Container_left"))({
		layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
		backgroundColor = {0,0,0,0},
	}) {}
	if cl.UI(cl.ID("Outer_Container_Mid"))({
		layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
		backgroundColor = {0,0,0,0},
		}) {
		if cl.UI(cl.ID("Iner_Container_Mid"))(
			cl.ElementDeclaration{
				layout = cl.LayoutConfig{
					layoutDirection = .TopToBottom,
					sizing = cl.Sizing{ cl.SizingGrow(), cl.SizingGrow() },
					childGap = 32,
					childAlignment = cl.ChildAlignment{x=.Center,y=.Center},
				},
			backgroundColor = {0,0,0,0},
		}) {
			if cl.UI(cl.ID("Button--Host"))(tg.button_dec()) {
				tg.button_txt("Host")

				if cl.Hovered() && tg.is_input_event(.ui_l_c){
					g.info.next_game_mode = .loby
					fmt.print("Button--Host\n")
					string_ep:=tg.endpoint_from_string_endpoint()
					tg.start_server(server_endpoint = s.steam.networking_identity, net_inst=&g.server)
					// tg.start_server(server_endpoint = string_ep, net_inst=&g.server)
			
				}
			}
			if cl.UI(cl.ID("Button--Join"))(tg.button_dec()) {
				tg.button_txt("Join")
				
				if cl.Hovered() && tg.is_input_event(.ui_l_c){
					g.info.next_game_mode = .loby
					fmt.print("Button--Join\n")
					string_ep:=tg.endpoint_from_string_endpoint()
					temp_endpoint:tg.Endpoint = s.steam.steam_lobby.loby_owner_net_id
					tg.join_server(server_endpoint = &temp_endpoint, net_inst=&g.server)
					// tg.join_server(server_endpoint = string_ep, net_inst=&g.server)
				}
			}
		}
	}
	if cl.UI(cl.ID("Outer_Container_Right"))({
		layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
		backgroundColor = {0,0,0,0},
	}) {}
}

loby_menu::proc(){
	if cl.UI(cl.ID("Outer_Container_left"))({
		layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
		backgroundColor = {0,0,0,0},
	}) {}
	if cl.UI(cl.ID("Outer_Container_Mid"))({
		layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
		backgroundColor = {0,0,0,0},
		}) {
		if cl.UI(cl.ID("Iner_Container_Mid"))(
			cl.ElementDeclaration{
				layout = cl.LayoutConfig{
					layoutDirection = .TopToBottom,
					sizing = cl.Sizing{ cl.SizingGrow(), cl.SizingGrow() },
					childGap = 32,
					childAlignment = cl.ChildAlignment{x=.Center,y=.Center},
				},
			backgroundColor = {0,0,0,0},
		}) {
			if cl.UI(cl.ID("Button--Start"))(tg.button_dec()) {
				tg.button_txt("Start")

				if cl.Hovered() && tg.is_input_event(.ui_l_c){
					g.info.next_game_mode = .in_game
					fmt.print("Button--in_game\n")
				}
			}
		}
	}
	if cl.UI(cl.ID("Outer_Container_Right"))({
		layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
		backgroundColor = {0,0,0,0},
	}) {}
}

loby_joining::proc(){
		if cl.UI(cl.ID("Outer_Container_left"))({
		layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
		backgroundColor = {0,0,0,0},
	}) {}
	if cl.UI(cl.ID("Outer_Container_Mid"))({
		layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
		backgroundColor = {0,0,0,0},
		}) {
		if cl.UI(cl.ID("Iner_Container_Mid"))(
			cl.ElementDeclaration{
				layout = cl.LayoutConfig{
					layoutDirection = .TopToBottom,
					sizing = cl.Sizing{ cl.SizingGrow(), cl.SizingGrow() },
					childGap = 32,
					childAlignment = cl.ChildAlignment{x=.Center,y=.Center},
				},
			backgroundColor = {0,0,0,0},
		}) {
			if cl.UI(cl.ID("joining"))(tg.button_dec()) {
				tg.button_txt("Joining")
			}
		}
	}
	if cl.UI(cl.ID("Outer_Container_Right"))({
		layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
		backgroundColor = {0,0,0,0},
	}) {}
}

loby_joining_regected::proc(){
		if cl.UI(cl.ID("Outer_Container_left"))({
		layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
		backgroundColor = {0,0,0,0},
	}) {}
	if cl.UI(cl.ID("Outer_Container_Mid"))({
		layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
		backgroundColor = {0,0,0,0},
		}) {
		if cl.UI(cl.ID("Iner_Container_Mid"))(
			cl.ElementDeclaration{
				layout = cl.LayoutConfig{
					layoutDirection = .TopToBottom,
					sizing = cl.Sizing{ cl.SizingGrow(), cl.SizingGrow() },
					childGap = 32,
					childAlignment = cl.ChildAlignment{x=.Center,y=.Center},
				},
			backgroundColor = {0,0,0,0},
		}) {
			if cl.UI(cl.ID("Info_text"))(tg.button_dec()) {
				tg.button_txt("your request to join was rejected")
			}
			if cl.UI(cl.ID("Button--Back-to-Start"))(tg.button_dec()) {
				tg.button_txt("Back to Start")
				g.info.next_game_mode = .start
			}
		}
	}
	if cl.UI(cl.ID("Outer_Container_Right"))({
		layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
		backgroundColor = {0,0,0,0},
	}) {}
}
// tg.ui_drag_box_dec(g.ui_boxes.test,{0,0},true)
sand_sim_cell_id_picker_ui_box::proc(ui_box_handle:tg.UI_Box_Handle){

	ui_box,cl_inst,ok,vis:=tg.start_ui_box(ui_box_handle)
	if !ok {return}

	if !vis {return}
	if cl.UI(cl.ID("sand_sim_cell_id_picker_ui_box_container"))(tg.ui_box_dec(ui_box_handle)) {
		if cl.UI(cl.ID("drag_box_sand_sim_cell_id_picker_ui_box"))(
			tg.ui_drag_box_dec(ui_box_handle,s.input_events.mouse_move)
		){
			tg.button_txt("temp")
		}
		MAX_IN_ROW::10
		courent_pos_in_row:int
		pading:=tg.get_ui_pading(.small)
		row_count:u32
		for cell, cell_id in Cell_Info{
			if courent_pos_in_row == 0{
				cl._OpenElementWithId(cl.ID("sand_sim_cell_id_picker_ui_box_row",row_count))
				cl.ConfigureOpenElement({layout = {layoutDirection = .LeftToRight,childGap = pading},})
			}
			sand_sim_cell_id_picker(cell_id,ui_box_handle)
			courent_pos_in_row +=1
			if courent_pos_in_row == MAX_IN_ROW{
				courent_pos_in_row = 0
				row_count+=1
				cl._CloseElement()
			}
		}
		if courent_pos_in_row != MAX_IN_ROW{
			cl._CloseElement()
		}
		tg.interact_ui_box_click(ui_box_handle)
	}
}
sand_sim_cell_id_icon_dec::proc(
	cell_color:[4]f32,
	border_col_id:tg.Color_Types = .border,
	border_huv_col_id:tg.Color_Types = .border_focused,
	background_huv_col_id:tg.Color_Types = .element_background,
	border_size_id:tg.UI_Size = .normal,
)->(dec:cl.ElementDeclaration){
	border_col:=tg.get_color(border_col_id)
	border_huv_col:=tg.get_color(border_huv_col_id)
	background_huv_col:=tg.get_color(background_huv_col_id)
	border_size:= tg.get_ui_border(border_size_id)
	button_hov:=cl.Hovered()
	dec = cl.ElementDeclaration{
		layout = {
				layoutDirection = .TopToBottom,
				sizing = { cl.SizingFixed(50*s.ui.style.siz.pading_multiplyer), cl.SizingFixed(50*s.ui.style.siz.pading_multiplyer) },
				childAlignment = cl.ChildAlignment{x=.Center,y=.Center},
			},
		backgroundColor = cell_color if !button_hov else cell_color+{.1,.1,.1,.1},
		overlayColor = [4]f32{0,0,0,0} if !button_hov else background_huv_col,
		border = cl.BorderElementConfig{
			color = border_col if !button_hov else border_huv_col,
			width = cl.BorderWidth{border_size,border_size,border_size,border_size,0}
		},
	}
	return dec
}

sand_sim_cell_id_picker::proc(id:Cell_ids,ui_box_handle:tg.UI_Box_Handle){
	cell:=Cell_Info[id]
	if cl.UI(cl.ID("sand_sim_cell_id_picker",cast(u32)id))(sand_sim_cell_id_icon_dec(cell.color)) {
		if cl.Hovered() {
			if tg.is_input_event(.ui_l_c,always_consume_d = true){
				tg.interact_ui_box(ui_box_handle)
				g.player.curent_cell = id
			}
		}
	}

}

Defalt_UI_Boxes::struct{
	test:tg.UI_Box_Handle,
}

init_defalt_ui_boxes::proc(){
	g.ui_boxes.test = tg.create_ui_box({name="theme_picker_ui_box",update_proc=tg.theme_picker_ui_box,is_visible = false},g.ui_clay_inst)
	tg.create_ui_box({name="sand_sim_cell_id_picker_ui_box",update_proc=sand_sim_cell_id_picker_ui_box,is_visible = false},g.ui_clay_inst)
	tg.create_ui_box(tg.UI_Box_Data{name="inspector_ui_box",update_proc=tg.inspector_ui_box,is_visible = false,inspector={parent = s,do_depth = false}},g.ui_clay_inst)
	
}
