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
// import hm "../../handle_map_static_virtual"
import hm "core:container/handle_map"
import an"../../ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"
import st"core:strings"
import steam "../../steamworks"

USE_TRACKING_ALLOCATOR :: #config(USE_TRACKING_ALLOCATOR, true)
MAX_PLAYERS::20

Handle :: hm.Handle32
s:^tg.State
g:^Game
Game::struct{
	
	cam:tg.Camera,
	cam_ui:tg.Camera,
	ui_clay_inst:tg.Clay_I_Handle,
	w_map:^Map,
	entitys:Entity_Handle_Map,
	entitys_mesh:tg.Mesh_Handle,
	// all_player_data:All_Player_data,
	// world_mesh:tg.Mesh_Handle,
	frame_data:tg.Frame_Data,
	window:tg.Window_Handle, 
	info:Game_Info,

	pass:tg.R_Pass,
	ui_pass:tg.R_Pass,
	sand_sim_pass:tg.R_Pass,

	vert_shader:tg.Shader_Handle,
	frag_shader:tg.Shader_Handle,
	ui_vert_shader:tg.Shader_Handle,
	ui_frag_shader:tg.Shader_Handle,
	sand_sim_vert_shader:tg.Shader_Handle,
	sand_sim_frag_shader:tg.Shader_Handle,


	render_thread:^thread.Thread,
	server:tg.Networking_Instance,
	// input_events:event_data,
	// game_should_close:bool,

	clay_render_comands:cl.ClayArray(cl.RenderCommand),
	ui_boxes:Defalt_UI_Boxes,

	player:Player_Info,

}

Game_Info::struct{
	curent_game_mode:Game_Mode,
	next_game_mode:Game_Mode,
	round_number:int,
	// player_list:[dynamic;MAX_PLAYERS]Entity_Handle,
}

Game_Mode::enum{
	start,
	in_game,
	loby,
}

Player_Info::struct{
	curent_cell:Cell_ids,
}



init::proc(){
	// tg.init_steam()
	
	init_map(&g.w_map)
	wh:=tg.get_window_size(g.window)
	g.ui_clay_inst=tg.init_clay_instance({cast(f32)wh.x,cast(f32)wh.y},g.ui_vert_shader, g.ui_frag_shader, gbl_font_size = .1)
	// fmt.print(g.ui_clay_inst,"\n\n\n")
	// init_net_thread()
	init_tg_inputs()
	tg.init_networking_instance(&g.server,pros_server_cmd,start_server)
	tg.set_defalt_networking_instance(&g.server)
	tg.reg_input_events()
	init_entitys_mesh()
	init_defalt_ui_boxes()
	init_rendering_thread()
	tg.update_steam_friend_info()


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
	g.window = tg.init_window()

	g.cam = tg.create_camera(type = .orthographic)
	g.cam_ui = tg.create_camera(type = .orthographic)

	g.vert_shader = tg.load_shader_file(file_path = "shader.vert")
	g.frag_shader = tg.load_shader_file(file_path = "shader.frag")

	g.ui_vert_shader = tg.load_shader_file(file_path = "ui_shader.vert")
	g.ui_frag_shader = tg.load_shader_file(file_path = "ui_shader.frag")

	g.sand_sim_vert_shader = tg.load_shader_file(file_path = "sand_sim_shader.vert")
	g.sand_sim_frag_shader = tg.load_shader_file(file_path = "sand_sim_shader.frag")



	g.pass = tg.create_render_pass(&g.frame_data, g.vert_shader, g.frag_shader)
	g.ui_pass = tg.create_render_pass(&g.frame_data, g.ui_vert_shader, g.ui_frag_shader)
	g.sand_sim_pass = tg.create_render_pass(&g.frame_data, g.sand_sim_vert_shader, g.sand_sim_frag_shader)

	init()
	tg.get_number_of_current_players()
	main_loop:for !tg.start_tick(){
		tg.update_time_info()
		tg.gather_input_info()
		tg.run_steam_callbacks()
		tg.update_notification_buffer(& s.ui.notifications,s.time.tick_time)
		
		for ev in &tg.s.events {
		}

		if s.time.is_60_hz{
			fmt.print(g.server.type,"\n")
			sink_game_info(&g.server,&g.info)
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
				scroll_dt={cast(f32)s.input_events.mouse_wheel.x,cast(f32)s.input_events.mouse_wheel.y,},
				dt_time=cast(f32)s.time.dt_60_hz,
				// enable_drag_scrolling=.
			)
			// if is_input_event(.ui_shift){
			// 	// tg.update_lobby_data(temp.ulSteamIDLobby)
			// 	fmt.print("updating_stuff\n")
			// 	tg.update_steam_friend_info()
			// 	tg.join_server(server_endpoint = s.steam.steam_lobby.loby_owner_net_id, net_inst=&g.server)
			// }
			tg.pros_server_cmd_q(&g.server)
			manage_gmae_mode_state()
			switch g.info.curent_game_mode{
				case .start:
				do_mode_start()
				case .loby:
				do_mode_loby()
				case .in_game:
				do_mode_game()
			} 
			tg.maintain_input_info()
		}

		

		// do_rendering()
	}
	tg.leave_shutdown_server(&g.server)

	cleane_up_game()

	when USE_TRACKING_ALLOCATOR {
		for _, val in tracking_allocator.allocation_map {
			log.errorf("\n%v: Leaked %v bytes,err: %v , mode:%v\n", val.location, val.size,val.err,val.mode)
			if val.size<256 {
				str_b:=cast([^]u8)val.memory
				str_d:=str_b[:val.size]
				str:=cast(string)str_d
				fmt.print(str)
			}
		}
		mem.tracking_allocator_destroy(&tracking_allocator)
	}
}
cleane_up_game::proc(){
	fmt.print("g.game_should_close",s.app_should_close,"\n")

	thread.join(g.render_thread)
	thread.destroy(g.render_thread)
	thread.join(g.server.net_thread)
	thread.destroy(g.server.net_thread)
	tg.cleane_up_input_handling(&s.input_events)
	tg.delete_r_pass(&g.pass)
	tg.delete_r_pass(&g.ui_pass)
	tg.delete_mesh(g.entitys_mesh)
	delete_w_map(g.w_map)
	tg.delete_camera(&g.cam)
	// hm.delete(&g.entitys)
	// hm.dynamic_destroy(&g.entitys)
	delete(g.server.clients)
	// delete(g.all_player_data.players)
	tg.delete_clay_instance(g.ui_clay_inst)
	tg.cleane_up_app()
}

do_mode_start::proc(){

}
do_mode_loby::proc(){
	update_map(g.w_map)
	draw_update_entitys_mesh(&g.entitys)
}
do_mode_game::proc(){
	do_player_inputs()
	// spawn_p_cell_by_id(.gravel,{600,-100},{0,0},g.w_map)
	spawn_berst_of_p_cell_by_id(.gravel,{600,-100},g.w_map)
	if g.server.status == .hosting{
		server_set_cell_by_id({10,10}, .sand,g.w_map)
		server_set_cell_by_id({20,20}, .water,g.w_map)
		server_set_cell_by_id({200,20}, .lava,g.w_map)
		server_set_cell_by_id({175,20}, .water,g.w_map)
		server_set_cell_by_id({150,20}, .gravel,g.w_map)
		server_set_cell_by_id({350,20}, .water,g.w_map)
	}
	if tg.is_input_event(.ui_shift){
		if g.server.status == .hosting{
			server_set_cell_by_id({10,10}, .sand,g.w_map)
			server_set_cell_by_id({20,20}, .water,g.w_map)
			server_set_cell_by_id({200,20}, .water,g.w_map)
			server_set_cell_by_id({175,20}, .water,g.w_map)
			server_set_cell_by_id({150,20}, .water,g.w_map)
			server_set_cell_by_id({350,20}, .water,g.w_map)
		}
		// enabled := steam.Utils_IsOverlayEnabled(steam.Utils())

		// friends := steam.Friends()

		// steam.Friends_ActivateGameOverlay(friends,"Friends")
		// tg.send_simp_notification(&s.notifications,"waffles shift")
		// tg.update_steam_friend_info()
	}
	do_entitys(&g.entitys)
	update_p_cells(g.w_map,&g.entitys)
	draw_update_entitys_mesh(&g.entitys)
	draw_p_cells(g.w_map)
	update_map(g.w_map)
	mesh_map(g.w_map)

	if tg.is_input_event(.ui_esc){
		tg.leave_shutdown_server(&g.server)
	}
	update_camera_2d_pan(&g.cam,  )
	// tg.update_camera_2d_wasd(&g.cam, cast(f32)s.time.tick_time, )
	update_camera_zoom(&g.cam)
}



reset_game_state::proc(){
	// g.all_player_data.players = {}
	// clear(&g.info.player_list)
	hm.clear(&g.entitys)
	g.info.next_game_mode = .start
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
	g.server.type = .nil
}


manage_gmae_mode_state::proc(){
	g.info.curent_game_mode = g.info.next_game_mode
}

init_rendering_thread::proc(){
	g.render_thread = thread.create_and_start(do_rendering,self_cleanup = false)
}

do_rendering::proc(){
	rendering_loop:for !s.app_should_close {

		// mesh_map(g.w_map)

		tg.start_frame(&g.frame_data)

		// do gameplay pass
		tg.start_render(&g.sand_sim_pass ,&g.cam_ui, g.window,   load_op = .CLEAR,  d_load_op = .CLEAR,  store_op = .RESOLVE_AND_STORE)
		render_map(g.w_map)
		tg.submit_render(&g.sand_sim_pass)

		tg.start_render(&g.pass ,&g.cam_ui, g.window,   load_op = .LOAD,  d_load_op = .LOAD,  store_op = .RESOLVE_AND_STORE)
		render_entitys(&g.entitys)
		render_map_debug_overlay(g.w_map)
		tg.submit_render(&g.pass)
		//do render pass
		tg.start_render(&g.ui_pass ,&g.cam_ui, g.window,   load_op = .LOAD,  d_load_op = .LOAD,  store_op = .RESOLVE)
		tg.render_clay_instance(g.ui_clay_inst,&g.ui_pass,&g.cam_ui)
		tg.submit_render(&g.ui_pass)

		tg.update_time_fps_info()
		tg.submit_frame(&g.frame_data)

	}
	log.logf(.Info,"closeing Render Thread",)

}

init_tg_inputs::proc(){
	s.is_ui_l_click = is_ui_l_click
	s.is_ui_r_click = is_ui_r_click
}
is_ui_l_click::proc()->(bool){
	return tg.is_input_event(.ui_l_c,always_consume_p = false, always_consume_d = false)
}
is_ui_r_click::proc()->(bool){
	return tg.is_input_event(.ui_r_c,always_consume_p = false, always_consume_d = false)
}
update_camera_2d_pan::proc(cam:^tg.Camera, dt:f32=1, speed:f32=1,){
	move_input:tg.Vec3
	if tg.is_input_event(.ui_r_c,always_consume_p = false, always_consume_d = false){
		move_input.x = s.input_events.mouse_move.x * -1
		move_input.y = s.input_events.mouse_move.y
		look_mat := lin.matrix3_from_yaw_pitch_roll_f32(lin.to_radians(cam.look.yaw), lin.to_radians(cam.look.pitch), 0)
		motion := move_input * (speed*cam.zoom) * dt
		cam.pos += motion
	}
}

update_camera_zoom::proc(cam:^tg.Camera, speed:f32=1, min_zoom:f32= .1,max_zoom:f32=5){
	cam.zoom += cast(f32)(s.input_events.mouse_wheel.y)*.100 * speed
	
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
