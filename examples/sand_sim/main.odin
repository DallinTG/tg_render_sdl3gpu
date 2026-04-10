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
USE_TRACKING_ALLOCATOR :: #config(USE_TRACKING_ALLOCATOR, true)


s:^tg.State
g:Game
Game::struct{
	cam:tg.Camera,
	w_map:^Chunck,
	// world_mesh:tg.Mesh_Handle,
	pass:tg.R_Pass,
	window:tg.Window_Handle, 
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

	vert_shader:=tg.load_shader_file(file_path = "shader.vert")
	frag_shader:=tg.load_shader_file(file_path = "shader.frag")
	tg.reg_texture_from_file("BAD.png")
	tg.reg_texture_from_file("white.png")

	g.pass = tg.create_render_pass(vert_shader, frag_shader)



	
	init()
	main_loop:for tg.start_frame(){
		for ev in &tg.s.events {
		}

	new_ticks := sdl.GetTicks()
	s.delta_time = f32(new_ticks - s.ticks) / 1000
	s.ticks = new_ticks
	fmt.print(1/s.delta_time,"\n")
		
		set_cell_by_id({10,10}, .sand,g.w_map)
		// set_cell({12,200},{.up_sand},g.w_map)
		set_cell_by_id({20,20}, .water,g.w_map)
		set_cell_by_id({200,20}, .gravel,g.w_map)
		set_cell_by_id({175,20}, .lava,g.w_map)
		set_cell_by_id({150,20}, .steam,g.w_map)
		update_map(g.w_map)

		tg.update_camera_2d_pan(&g.cam, s.delta_time, )
		tg.update_camera_2d_wasd(&g.cam, s.delta_time, )
		tg.update_camera_zoom(&g.cam)
		tg.start_render()
		
		mesh:=tg.get_mesh(g.w_map.mesh)
		tg.clear_mesh_cpu(&mesh.cpu)
		render_map(g.w_map)
		tg.update_mesh(g.w_map.mesh)
		tg.do_render_pass(&g.pass, &g.cam, {g.w_map.mesh}, g.window,  load_op = .CLEAR, d_load_op = .CLEAR, store_op = .RESOLVE)
		tg.submit_render()
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

init::proc(){
	init_map(&g.w_map)
	// init_world_mesh()
}
cleane_up_game::proc(){
	tg.delete_r_pass(&g.pass)
	tg.delete_mesh(g.w_map.mesh)
	delete_map(g.w_map)
	// tg.delete_clay_instance(clay_inst)
	tg.delete_camera(&g.cam)
	// tg.delete_camera(&camera2)
	tg.cleane_app()

}


create_layout :: proc() -> cl.ClayArray(cl.RenderCommand) {
    cl.BeginLayout()
   if cl.UI(cl.ID("OuterContainer"))({
        layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
        backgroundColor = {1,.5,1,.3},
    }) {
	    if cl.UI(cl.ID("OuterContainer_5"))({
	        layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
	        backgroundColor = {0,1,.5,.3},
	    }) {
           cl.Text(
                "Clay - UI Library waffles ",
                cl.TextConfig({ textColor = {0,0,0,1}, fontSize = 1}),
            )		
		}
	    if cl.UI(cl.ID("OuterContainer_3"))({
	        layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
	        backgroundColor = {0,.5,0,.3},
	    }) {}
	    if cl.UI(cl.ID("OuterContainer_8"))({
	        layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
	        backgroundColor = {1,0,0,.3},
	    }) {}
    }
    if cl.UI(cl.ID("OuterContainer_2"))({
        layout = { layoutDirection = .TopToBottom, sizing = { cl.SizingGrow(), cl.SizingGrow() } },
        backgroundColor = {1,1,.5,.3},
    }) {}
    return cl.EndLayout()
}
