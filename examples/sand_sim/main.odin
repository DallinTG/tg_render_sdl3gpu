package sand_sim

import tg"../../../tg_render_sdl3"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import hm "../../handle_map_static_virtual"
import an"ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"
import st"core:strings"

USE_TRACKING_ALLOCATOR :: #config(USE_TRACKING_ALLOCATOR, true)

Handle :: hm.Handle
s:^tg.State
g:Game
Game::struct{
	cam:tg.Camera,
	cam_ui:tg.Camera,
	ui_clay_inst:tg.Clay_I_Handle,
	w_map:^Map,
	entitys:hm.Handle_Map(Entitys, Entity_Handle, 1000),
	// world_mesh:tg.Mesh_Handle,
	pass:tg.R_Pass,
	window:tg.Window_Handle, 
	curent_game_mode:Game_Mode,
	next_game_mode:Game_Mode,
	vert_shader:tg.Shader_Handle,
	frag_shader:tg.Shader_Handle,

	server:Net_Server_Info,
}

Game_Mode::enum{
	start,
	in_game,
	loby,
}



init::proc(){
	init_map(&g.w_map)
	wh:=tg.get_window_size(g.window)
	fmt.print(wh)
	init_net_thread()
	g.ui_clay_inst=tg.init_clay_instance({cast(f32)wh.x,cast(f32)wh.y},g.vert_shader, g.frag_shader, gbl_font_size = .1)
}

main :: proc(){
	context.logger = log.create_console_logger()
	when USE_TRACKING_ALLOCATOR {
		default_allocator := context.allocator
		tracking_allocator: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking_allocator, default_allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
	}
	s=tg.init()
	
	g.window = tg.init_window()

	g.cam = tg.create_camera(type = .orthographic)
	g.cam_ui = tg.create_camera(type = .orthographic)

	g.vert_shader = tg.load_shader_file(file_path = "shader.vert")
	g.frag_shader = tg.load_shader_file(file_path = "shader.frag")
	tg.reg_texture_from_file("BAD.png")
	tg.reg_texture_from_file("white.png")

	g.pass = tg.create_render_pass(g.vert_shader, g.frag_shader)

	// temp_t:f32
	init()
	main_loop:for tg.start_frame(){
		for ev in &tg.s.events {
		}
		
		new_ticks := sdl.GetTicks()
		s.delta_time = f32(new_ticks - s.ticks) / 1000
		s.ticks = new_ticks
		// temp_t+=s.delta_time
		// fmt.print(1/s.delta_time,"\n")
		// if temp_t > 1{
		// 	temp_t = 0
		
		// do_networking()
		manage_gmae_mode_state()
		switch g.curent_game_mode{
			case .start:
			do_mode_start()
			case .loby:
			do_mode_loby()
			case .in_game:
			do_mode_game()
		}

		// tg.update_camera_2d_pan(&g.cam, s.delta_time, )
		// tg.update_camera_2d_wasd(&g.cam, s.delta_time, )
		// tg.update_camera_zoom(&g.cam)

		do_rendering()
	}
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
	tg.delete_r_pass(&g.pass)
	delete_map(g.w_map)
	tg.delete_camera(&g.cam)
	tg.delete_clay_instance(g.ui_clay_inst)
	tg.cleane_app()
}

do_mode_start::proc(){

}
do_mode_loby::proc(){

}
do_mode_game::proc(){
	set_cell_by_id({10,10}, .sand,g.w_map)
	set_cell_by_id({20,20}, .water,g.w_map)
	set_cell_by_id({200,20}, .gravel,g.w_map)
	set_cell_by_id({175,20}, .lava,g.w_map)
	set_cell_by_id({150,20}, .steam,g.w_map)
	set_cell_by_id({350,20}, .steam,g.w_map)
	update_map(g.w_map)

	tg.update_camera_2d_pan(&g.cam, s.delta_time, )
	tg.update_camera_2d_wasd(&g.cam, s.delta_time, )
	tg.update_camera_zoom(&g.cam)
}

manage_gmae_mode_state::proc(){
	g.curent_game_mode = g.next_game_mode
}

do_rendering::proc(){
	tg.start_render()//----------------------------------------------------------->
	
	// tg.clear_mesh_cpu(&mesh.cpu)
	mesh_map(g.w_map)
	render_map(g.w_map)
	
	wh:=tg.get_window_size(g.window)
	mouse_pos:[2]f32 
	flag:=sdl.GetMouseState(&mouse_pos.x,&mouse_pos.y)
	
	render_comands:=create_layout()
	tg.update_clay_instance(g.ui_clay_inst,&render_comands,wh,mouse_pos,.LEFT in flag)
	tg.render_clay_instance(g.ui_clay_inst,&g.cam_ui, g.window,   load_op = .LOAD,  d_load_op = .CLEAR,  store_op = .RESOLVE)

	tg.submit_render()//----------------------------------------------------------->
}
