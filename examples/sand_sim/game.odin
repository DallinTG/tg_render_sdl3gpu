package sand_sim

import "core:time"
import tg"../../../tg_render_sdl3gpu"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import "core:thread"
import hm "../../handle_map_static_virtual"
import an"../../ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"
import st"core:strings"
import steam "../../steamworks"

USE_TRACKING_ALLOCATOR :: #config(USE_TRACKING_ALLOCATOR, true)

Handle :: hm.Handle
s:^tg.State
g:^Game
Game::struct{
	
	cam:tg.Camera,
	cam_ui:tg.Camera,
	ui_clay_inst:tg.Clay_I_Handle,
	w_map:^Map,
	entitys:Entity_Handle_Map,
	entitys_mesh:tg.Mesh_Handle,
	all_player_data:All_Player_data,
	// world_mesh:tg.Mesh_Handle,
	frame_data:tg.Frame_Data,
	pass:tg.R_Pass,
	ui_pass:tg.R_Pass,
	window:tg.Window_Handle, 
	curent_game_mode:Game_Mode,
	next_game_mode:Game_Mode,

	vert_shader:tg.Shader_Handle,
	frag_shader:tg.Shader_Handle,
	ui_vert_shader:tg.Shader_Handle,
	ui_frag_shader:tg.Shader_Handle,


	render_thread:^thread.Thread,
	server:tg.Networking_Instance,
	input_events:event_data,
	game_should_close:bool,

	clay_render_comands:cl.ClayArray(cl.RenderCommand),
	


}

Game_Mode::enum{
	start,
	in_game,
	loby,
}



init::proc(){
	// tg.init_steam()
	init_map(&g.w_map)
	wh:=tg.get_window_size(g.window)
	fmt.print(wh)
	// init_net_thread()
	init_tg_inputs()
	tg.init_networking_instance(&g.server,pros_server_cmd,start_server)
	reg_input_events()
	init_entitys_mesh()
	g.ui_clay_inst=tg.init_clay_instance({cast(f32)wh.x,cast(f32)wh.y},g.ui_vert_shader, g.ui_frag_shader, gbl_font_size = .1)
	init_rendering_thread()
	tg.update_steam_friend_info()
	fmt.print("inport theems\n")
	// tg.load_ui_theme_by_file("themes/tokyo-night.json",&s.ui_style)
	// tg.load_ui_theme_by_file("themes/catppuccin-mauve.json",&s.ui_style,0)
	// tg.load_ui_theme_by_file("themes/dracula.json",&s.ui_style,1)
	// tg.load_ui_theme_by_file("themes/snazzy.json",&s.ui_style,0)
	// tg.load_ui_theme_by_file("themes/nvim-nightfox.json",&s.ui_style,13)
	// tg.load_ui_theme_by_file("themes/zed_material_theme.json",&s.ui_style,0)
	tg.load_ui_theme_by_file("themes/everforest-regular.json",&s.ui_style,2)
	
	// spawn_entity(&g.entitys)
}

main :: proc(){
	g = new(Game)
	context.logger = log.create_console_logger()
	when USE_TRACKING_ALLOCATOR {
		tracking_allocator: mem.Tracking_Allocator
		default_allocator := context.allocator
		mem.tracking_allocator_init(&tracking_allocator, default_allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
	}
	// tg.init_steam()
	s=tg.init()
	fmt.print("size_of(tg.Vertex_Data) ",size_of(tg.Vertex_Data),"\n")
	fmt.print("size_of(tg.UI_Vertex_Data) ",size_of(tg.UI_Vertex_Data),"\n")
	g.window = tg.init_window()

	g.cam = tg.create_camera(type = .orthographic)
	g.cam_ui = tg.create_camera(type = .orthographic)

	g.vert_shader = tg.load_shader_file(file_path = "shader.vert")
	g.frag_shader = tg.load_shader_file(file_path = "shader.frag")

	g.ui_vert_shader = tg.load_shader_file(file_path = "ui_shader.vert")
	g.ui_frag_shader = tg.load_shader_file(file_path = "ui_shader.frag")

	// tg.reg_texture_from_file("BAD.png")
	// tg.reg_texture_from_file("white.png")
	// tg.reg_all_texture_from_dir_path("assets/textures/icons","icon")
	// tg.reg_all_texture_from_loaded_directory(#load_directory("assets/textures/icons"),"icon")

	// tg.reg_all_texture_from_dir_path("assets/textures/icons","icon")

	g.pass = tg.create_render_pass(&g.frame_data, g.vert_shader, g.frag_shader)
	g.ui_pass = tg.create_render_pass(&g.frame_data,g.ui_vert_shader, g.ui_frag_shader)

	init()
	tg.get_number_of_current_players()
	main_loop:for !tg.start_tick(){
		tg.update_time_info()
		gather_input_info()
		tg.run_steam_callbacks()
		tg.update_notification_buffer(&s.notifications,s.time.tick_time)
		for ev in &tg.s.events {
		}


		if s.time.is_60_hz{

			g.clay_render_comands=create_layout()
			wh:=tg.get_window_size(g.window)
			mouse_pos:[2]f32 
			flag:=sdl.GetMouseState(&mouse_pos.x,&mouse_pos.y)
			tg.update_clay_instance(
				clay_instance=g.ui_clay_inst, 
				renderCommands=&g.clay_render_comands, 
				wh=wh, 
				mouse_pos=mouse_pos, 
				mouse_down=.LEFT in flag,
				scroll_dt={cast(f32)g.input_events.mouse_wheel.x,cast(f32)g.input_events.mouse_wheel.y,},
				dt_time=cast(f32)s.time.dt_60_hz,
				// enable_drag_scrolling=.
			)
			if is_input_event(.ui_shift){
				// tg.update_lobby_data(temp.ulSteamIDLobby)
				fmt.print("updating_stuff\n")
				tg.update_steam_friend_info()
			}
			
			tg.pros_server_cmd_q(&g.server)
			manage_gmae_mode_state()
			switch g.curent_game_mode{
				case .start:
				do_mode_start()
				case .loby:
				do_mode_loby()
				case .in_game:
				do_mode_game()
			}
			maintain_input_info()
		}

		

		// do_rendering()
	}
	tg.leave_shutdown_server(&g.server)
	cleane_up_game()

	when USE_TRACKING_ALLOCATOR {
		for _, value in tracking_allocator.allocation_map {
			log.errorf("%v: Leaked %v bytes\n", value.location, value.size)
			if value.size<256 {
				str_b:=cast([^]u8)value.memory
				str_d:=str_b[:value.size]
				str:=cast(string)str_d
				fmt.print(str)
			}
		}
		mem.tracking_allocator_destroy(&tracking_allocator)
	}
}
cleane_up_game::proc(){
	thread.terminate(g.render_thread,0)
	thread.terminate(g.server.net_thread,0)
	thread.destroy(g.render_thread)
	thread.destroy(g.server.net_thread)
	tg.delete_r_pass(&g.pass)
	tg.delete_r_pass(&g.ui_pass)
	delete_w_map(g.w_map)
	tg.delete_camera(&g.cam)
	hm.delete(&g.entitys)
	delete(g.server.clients)
	delete(g.all_player_data.players)
	tg.delete_clay_instance(g.ui_clay_inst)
	tg.cleane_app()
}

do_mode_start::proc(){

}
do_mode_loby::proc(){
	update_map(g.w_map)
	draw_update_entitys_mesh(&g.entitys)
}
do_mode_game::proc(){
	do_player_inputs()
	if g.server.status == .hosting{
		server_set_cell_by_id({10,10}, .sand,g.w_map)
		server_set_cell_by_id({20,20}, .water,g.w_map)
		server_set_cell_by_id({200,20}, .gravel,g.w_map)
		server_set_cell_by_id({175,20}, .lava,g.w_map)
		server_set_cell_by_id({150,20}, .steam,g.w_map)
		server_set_cell_by_id({350,20}, .steam,g.w_map)
	}
	if is_input_event(.ui_shift){
		// enabled := steam.Utils_IsOverlayEnabled(steam.Utils())
		// fmt.println("overlay enabled:", enabled)
		// friends := steam.Friends()
		// fmt.print(friends,friends != nil)
		// steam.Friends_ActivateGameOverlay(friends,"Friends")
		tg.send_simp_notification(&s.notifications,"waffles shift")
		tg.update_steam_friend_info()
	}
	do_entitys(&g.entitys)
	draw_update_entitys_mesh(&g.entitys)
	update_map(g.w_map)
	mesh_map(g.w_map)

	if is_input_event(.ui_esc){
		tg.leave_shutdown_server(&g.server)
	}

	update_camera_2d_pan(&g.cam,  )
	// tg.update_camera_2d_wasd(&g.cam, cast(f32)s.time.tick_time, )
	update_camera_zoom(&g.cam)
}



reset_game_state::proc(){
	g.all_player_data.players = {}
	hm.clear(&g.entitys)
	g.next_game_mode = .start
	for &x in &g.w_map.chuncks{
		for &chunck in &x{
			mesh:=tg.get_mesh(chunck.mesh)
			chunck.cell_has_moved = {}
			chunck.cells = {}
		}
	}
	g.cam.pos={}
	g.cam.target={}
	g.cam.zoom = 1
	g.server.server = {}
	g.server.net_state.is_up = false
}


manage_gmae_mode_state::proc(){
	g.curent_game_mode = g.next_game_mode
}

init_rendering_thread::proc(){
	g.render_thread = thread.create_and_start(do_rendering)
}

do_rendering::proc(){
	rendering_loop:for !g.game_should_close {
		
		tg.start_frame(&g.frame_data)

		// do gameplay pass
		tg.start_render(&g.pass ,&g.cam_ui, g.window,   load_op = .CLEAR,  d_load_op = .CLEAR,  store_op = .RESOLVE_AND_STORE)
		render_map(g.w_map)
		// draw_update_entitys_mesh(&g.entitys)
		render_entitys(&g.entitys)
		// tg.render_clay_instance(g.ui_clay_inst,&g.pass,&g.cam_ui)
		tg.submit_render(&g.pass)


		//do render pass
		tg.start_render(&g.ui_pass ,&g.cam_ui, g.window,   load_op = .LOAD,  d_load_op = .LOAD,  store_op = .RESOLVE)
		tg.render_clay_instance(g.ui_clay_inst,&g.ui_pass,&g.cam_ui)
		tg.submit_render(&g.ui_pass)


		tg.update_time_fps_info()
		
		tg.submit_frame(&g.frame_data)

	}
}

init_tg_inputs::proc(){
	s.is_ui_l_click = is_ui_l_click
	s.is_ui_r_click = is_ui_r_click
}
is_ui_l_click::proc()->(bool){
	return is_input_event(.ui_l_c)
}
is_ui_r_click::proc()->(bool){
	return is_input_event(.ui_r_c)
}
update_camera_2d_pan::proc(cam:^tg.Camera, dt:f32=1, speed:f32=1,){
	move_input:tg.Vec3
	if is_input_event(.ui_r_c){
		move_input.x = g.input_events.mouse_move.x * -1
		move_input.y = g.input_events.mouse_move.y
		look_mat := lin.matrix3_from_yaw_pitch_roll_f32(lin.to_radians(cam.look.yaw), lin.to_radians(cam.look.pitch), 0)
		motion := move_input * (speed*cam.zoom) * dt
		cam.pos += motion
		// fmt.print(motion,"pan",move_input,"mouse move" ,g.input_events.mouse_move,"\n")
	}
}

update_camera_zoom::proc(cam:^tg.Camera, speed:f32=1, min_zoom:f32= .1,max_zoom:f32=5){
	cam.zoom += cast(f32)(g.input_events.mouse_wheel.y)*.100 * speed
	
	if cam.zoom < min_zoom {
		cam.zoom = min_zoom
	}
	if cam.zoom > max_zoom{
		cam.zoom = max_zoom
	}
}

@(export)
game_memory :: proc() -> rawptr {
	return 	cast(rawptr)g
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game)
}


@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g = cast(^Game)(mem)
	// mem = cast(rawptr)g

	// Here you can also set your own global variables. A good idea is to make
	// your global variables into pointers that point to something inside `g`.
}

@(export)
game_force_reload :: proc() -> bool {
	// return rl.IsKeyPressed(.F5)
	return false
}

@(export)
game_force_restart :: proc() -> bool {
	// return rl.IsKeyPressed(.F6)
	return false
}
