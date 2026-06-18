package sand_sim

import tg"../../../tg_render_sdl3gpu"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import hm "../../handle_map_static_virtual"
import an"../../ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"



create_layout :: proc(dt:=cast(f32)s.time.dt_60_hz) -> cl.ClayArray(cl.RenderCommand) {
	cl.BeginLayout()
	if g.curent_game_mode == .start {start_menu()}
	if g.curent_game_mode == .loby &&  g.server.status == .joining	{loby_joining()}
	if g.curent_game_mode == .loby && (g.server.status == .joined || g.server.status == .hosting)	{loby_menu()}
	if g.curent_game_mode == .loby &&  g.server.status == .regected	{loby_joining_regected()}
	tg.draw_notification_buffer(&s.notifications)
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

				if cl.Hovered() && is_input_event(.ui_l_c){
					g.next_game_mode = .loby
					fmt.print("Button--Host\n")
					string_ep:=tg.endpoint_from_string_endpoint()
					tg.start_server(server_endpoint = s.steam.networking_identity, net_inst=&g.server)
				}
			}
			if cl.UI(cl.ID("Button--Join"))(tg.button_dec()) {
				tg.button_txt("Join")
				
				if cl.Hovered() && is_input_event(.ui_l_c){
					g.next_game_mode = .loby
					fmt.print("Button--Join\n")
					string_ep:=tg.endpoint_from_string_endpoint()
					tg.join_server(server_endpoint = s.steam.steam_lobby.loby_owner_net_id, net_inst=&g.server)
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

				if cl.Hovered() && is_input_event(.ui_l_c){
					g.next_game_mode = .in_game
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
				g.next_game_mode = .start
			}
		}
	}
	if cl.UI(cl.ID("Outer_Container_Right"))({
		layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
		backgroundColor = {0,0,0,0},
	}) {}
}
