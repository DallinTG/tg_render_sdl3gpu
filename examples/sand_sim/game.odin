package sand_sim

import "core:time"
import tg"../../../tg_render_sdl3"
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
g:Game
Game::struct{
	cam:tg.Camera,
	cam_ui:tg.Camera,
	ui_clay_inst:tg.Clay_I_Handle,
	w_map:^Map,
	entitys:Entity_Handle_Map,
	entitys_mesh:tg.Mesh_Handle,
	all_player_data:All_Player_data,
	// world_mesh:tg.Mesh_Handle,
	pass:tg.R_Pass,
	window:tg.Window_Handle, 
	curent_game_mode:Game_Mode,
	next_game_mode:Game_Mode,
	vert_shader:tg.Shader_Handle,
	frag_shader:tg.Shader_Handle,
	render_thread:^thread.Thread,
	server:Net_Server_Info,
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
	init_net_thread()
	reg_input_events()
	init_entitys_mesh()
	g.ui_clay_inst=tg.init_clay_instance({cast(f32)wh.x,cast(f32)wh.y},g.vert_shader, g.frag_shader, gbl_font_size = .1)
	init_rendering_thread()
	tg.update_steam_friend_info()
	// spawn_entity(&g.entitys)
}

main :: proc(){
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
	tg.reg_texture_from_file("BAD.png")
	tg.reg_texture_from_file("white.png")

	g.pass = tg.create_render_pass(g.vert_shader, g.frag_shader)

	init()
	tg.get_number_of_current_players()
	main_loop:for !tg.start_frame(){
		tg.run_steam_callbacks()
		for ev in &tg.s.events {
		}
		gather_input_info()
		tg.update_time_info()
		if s.time.is_60_hz{
			pros_server_cmd_q()
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
		g.clay_render_comands=create_layout()
		
		wh:=tg.get_window_size(g.window)
		mouse_pos:[2]f32 
		flag:=sdl.GetMouseState(&mouse_pos.x,&mouse_pos.y)
		tg.update_clay_instance(g.ui_clay_inst,&g.clay_render_comands,wh,mouse_pos,.LEFT in flag)

		// do_rendering()
	}
	leave_shutdown_server()
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
		tg.update_steam_friend_info()
	}
	update_map(g.w_map)
	mesh_map(g.w_map)
	do_entitys(&g.entitys)

	if is_input_event(.ui_esc){
		leave_shutdown_server()
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
		tg.start_render()//----------------------------------------------------------->
	
		// mesh_map(g.w_map)
		render_map(g.w_map)
		render_entitys(&g.entitys)
		// wh:=tg.get_window_size(g.window)
		// mouse_pos:[2]f32 
		// flag:=sdl.GetMouseState(&mouse_pos.x,&mouse_pos.y)
		
		// render_comands:=create_layout()
		// render_comands:=g.clay_render_comands
		// tg.update_clay_instance(g.ui_clay_inst,&render_comands,wh,mouse_pos,.LEFT in flag)
		tg.render_clay_instance(g.ui_clay_inst,&g.cam_ui, g.window,   load_op = .LOAD,  d_load_op = .CLEAR,  store_op = .RESOLVE)
	
		tg.submit_render()//----------------------------------------------------------->
		tg.update_time_fps_info()
	}
}


update_camera_2d_pan::proc(cam:^tg.Camera, dt:f32=1, speed:f32=1,){
	move_input:tg.Vec3
	if s.input.mouse_button_down[.RIGHT]{
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
