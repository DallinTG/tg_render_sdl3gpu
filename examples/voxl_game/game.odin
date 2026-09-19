package voxl_game

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

// USE_TRACKING_ALLOCATOR :: #config(USE_TRACKING_ALLOCATOR, true)
MAX_PLAYERS::20

Handle :: hm.Handle32
s:^tg.State
g:^Game
Game::struct{
	
	item_reg:		Item_Reg,
	material_reg:	Material_Reg,
	texture_facees:	tg.Indexed_GPU_Data,
	geometry_facees:tg.Indexed_GPU_Data,
	
	w_map:Map,
	
	//TODO temp
	cube_face_geometry:Model_Indices,
	// t_chuck:Chunck,

	cam:tg.Camera,
	cam_ui:tg.Camera,
	ui_clay_inst:tg.Clay_I_Handle,
	// w_map:^Map,
	// entitys:Entity_Handle_Map,
	entitys_mesh:tg.Mesh_Handle,
	// all_player_data:All_Player_data,
	// world_mesh:tg.Mesh_Handle,
	frame_data:tg.Frame_Data,
	window:tg.Window_Handle, 
	info:Game_Info,

	pass:tg.R_Pass,
	ui_pass:tg.R_Pass,
	vox_pass:tg.R_Pass,
	// sand_sim_pass:tg.R_Pass,

	vert_shader:tg.Shader_Handle,
	frag_shader:tg.Shader_Handle,
	ui_vert_shader:tg.Shader_Handle,
	ui_frag_shader:tg.Shader_Handle,
	// sand_sim_vert_shader:tg.Shader_Handle,
	// sand_sim_frag_shader:tg.Shader_Handle,
	vox_vert_shader:tg.Shader_Handle,
	vox_frag_shader:tg.Shader_Handle,


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
	// curent_cell:Cell_ids,
}



init::proc(){

	wh:=tg.get_window_size(g.window)
	g.ui_clay_inst=tg.init_clay_instance({cast(f32)wh.x,cast(f32)wh.y},g.ui_vert_shader, g.ui_frag_shader, gbl_font_size = .1)

	init_tg_inputs()
	tg.init_networking_instance(&g.server,pros_server_cmd,start_server)
	tg.set_defalt_networking_instance(&g.server)
	tg.reg_input_events()

	init_defalt_ui_boxes()

	tg.update_steam_friend_info()
	init_all_item_data()
	init_map(&g.w_map)

	init_rendering_thread()

	


}

main :: proc(){
	tracking_allocator:mem.Tracking_Allocator
	context.logger = tg.create_tg_console_logger(opt = {.Thread_Id,.Level,.Short_File_Path,.Line,.Procedure,.Terminal_Color})
	context.allocator = tg.init_tracking_allocator(&tracking_allocator)
	defer tg.end_tracking_allocator(&tracking_allocator)
	tg.name_thread("Main")
	g = new(Game)
	s=tg.init()
	
	g.window = tg.init_window()

	g.cam = tg.create_camera(type = .perspective)
	g.cam_ui = tg.create_camera(type = .orthographic)
	// g.cam_ui.pos.z = 10

	g.vert_shader = tg.load_shader_file(file_path = "shader.vert")
	g.frag_shader = tg.load_shader_file(file_path = "shader.frag")

	g.ui_vert_shader = tg.load_shader_file(file_path = "ui_shader.vert")
	g.ui_frag_shader = tg.load_shader_file(file_path = "ui_shader.frag")

	// g.sand_sim_vert_shader = tg.load_shader_file(file_path = "sand_sim_shader.vert")
	// g.sand_sim_frag_shader = tg.load_shader_file(file_path = "sand_sim_shader.frag")

	g.vox_vert_shader = tg.load_shader_file(file_path = "vox.vert")
	g.vox_frag_shader = tg.load_shader_file(file_path = "vox.frag")



	g.pass = tg.create_render_pass(&g.frame_data, g.vert_shader, g.frag_shader, name = "Defalt_Pass")
	g.ui_pass = tg.create_render_pass(&g.frame_data, g.ui_vert_shader, g.ui_frag_shader, name = "UI_Pass")
	g.vox_pass = tg.create_render_pass(&g.frame_data, g.vox_vert_shader,  g.vox_frag_shader,info = tg.DEFALT_OPAQUE_PASS, name = "VOX_Pass")
	// g.sand_sim_pass = tg.create_render_pass(&g.frame_data, g.vert_shader,  g.frag_shader,info = tg.DEFALT_OPAQUE_PASS, name = "Sand_Sim_Pass")

	init()
	mesh_map(&g.w_map)
	// mesh_chunck(&g.t_chuck)
	tg.get_number_of_current_players()
	main_loop:for !tg.start_tick(){
	
		tg.update_time_info()
		tg.gather_input_info()
		tg.run_steam_callbacks()
		tg.update_notification_buffer(& s.ui.notifications,s.time.tick_time)
		for ev in &tg.s.events {
		}

		if s.time.is_60_hz{
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
	
			tg.pros_server_cmd_q(&g.server)
			manage_gmae_mode_state()
			switch g.info.curent_game_mode{
				case .start:
				do_mode_start()
				case .loby:
				// do_mode_loby()
				case .in_game:
				do_mode_game()
			} 
			tg.maintain_input_info()
		}
	}
	tg.leave_shutdown_server(&g.server)
	cleane_up_game()
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
	tg.delete_r_pass(&g.vox_pass)
	tg.delete_mesh(g.entitys_mesh)
	tg.delete_camera(&g.cam)
	delete(g.server.clients)
	tg.delete_clay_instance(g.ui_clay_inst)
	free(g)
	tg.cleane_up_app()
}

do_mode_start::proc(){

}
// do_mode_loby::proc(){
// 	update_map(g.w_map)
// 	draw_update_entitys_mesh(&g.entitys)
// }
do_mode_game::proc(){


	if tg.is_input_event(.ui_esc){
		tg.leave_shutdown_server(&g.server)
	}
	// update_camera_2d_pan(&g.cam,  )
	tg.update_camera_3d(&g.cam)
	// update_camera_zoom(&g.cam)
}



reset_game_state::proc(){
	g.info.next_game_mode = .start
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
	tg.name_thread("Rendering")
	tracking_allocator:mem.Tracking_Allocator
	context.logger = tg.create_tg_console_logger(opt = {.Thread_Id,.Level,.Short_File_Path,.Line,.Procedure,.Terminal_Color})
	context.allocator = tg.init_tracking_allocator(&tracking_allocator)
	defer tg.end_tracking_allocator(&tracking_allocator)

	// mesh_map(&g.w_map)
	rendering_loop:for !s.app_should_close {
		tg.start_frame(&g.frame_data)

		tg.start_render(&g.vox_pass ,&g.cam, g.window,   load_op = .CLEAR,  d_load_op = .CLEAR,  store_op = .RESOLVE_AND_STORE)
		// render_chunck(&g.t_chuck,)
		render_map(&g.w_map)
		tg.submit_render(&g.vox_pass)

		tg.start_render(&g.pass ,&g.cam_ui, g.window,   load_op = .LOAD,  d_load_op = .LOAD,  store_op = .RESOLVE_AND_STORE)
		tg.submit_render(&g.pass)
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
