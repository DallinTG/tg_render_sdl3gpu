package tg_test

import tg"../../../tg_render_sdl3"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
// import str"core:strings"
import "core:fmt"
// import "core:math"
// import lin"core:math/linalg"
// import "base:runtime"
import hm "../../handle_map_static_virtual"
import an"ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"
// import "core:image"
// import "core:image/jpeg"
// import "core:image/bmp"
// import "core:image/png"
// import "core:image/tga"

// raw_shader_frag:=#load("shader_frag.spv")
// raw_shader_vert:=#load("shader_vert.spv")
USE_TRACKING_ALLOCATOR :: #config(USE_TRACKING_ALLOCATOR, true)
rot:f32=0

pass:tg.R_Pass
texture:tg.Texture_GPU_Handle
texture_2:tg.Texture_GPU_Handle
tex_arr:[2]tg.Texture_GPU_Handle
s:^tg.State
camera :tg.Camera//= {
// 	pos = {0,0,3},
// 	target = {0,0,0},
// 	depth_texture_createinfo = tg.DEFALT_DEPTH_TEXTURE_CREATEINFO,
// }
camera2 :tg.Camera//= {
// 	pos = {0,0,3},
// 	target = {0,0,0},
// 	depth_texture_createinfo = tg.DEFALT_DEPTH_TEXTURE_CREATEINFO,
// }

main :: proc(){
	context.logger = log.create_console_logger()
	when USE_TRACKING_ALLOCATOR {
		default_allocator := context.allocator
		tracking_allocator: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking_allocator, default_allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
	}
	s=tg.init()
	
	window_hd := tg.init_window()
	window_hd2 := tg.init_window()
	
	// _ = sdl.SetWindowRelativeMouseMode(tg.get_window(window_hd).data,true)
	
	camera  = tg.create_camera()
	camera2 = tg.create_camera(type = .orthographic)
	 
	vert_shader:=tg.load_shader_file(file_path = "shader.vert")
	frag_shader:=tg.load_shader_file(file_path = "shader.frag")
	
	texture = tg.load_texture_from_file("world_tileset.png")	
	// texture_2 = tg.load_texture_from_file("world_tileset.png")	
	texture_2 = tg.load_texture_from_file("Glass_Block.png")
	tg.reg_texture_from_file("BAD.png")
	tg.reg_texture_from_file("Glass_Block.png")
	tg.reg_texture_from_file("world_tileset.png")
	
	tg.reg_texture_from_file("0.png")
	tg.reg_texture_from_file("1.png")
	tg.reg_texture_from_file("ax_man.png")
	tg.reg_texture_from_file("castle.png")
	tg.reg_texture_from_file("mine.png")
	tg.reg_texture_from_file("Pawn.png")

	// tex_arr={texture,texture_2}	
	pass = tg.create_render_pass(vert_shader, frag_shader)
	mesh_cpu:tg.Mesh_CPU={attribute_type = tg.Vertex_Data_t}
	clay_inst:=tg.init_clay_instance({40,40},vert_shader,frag_shader, gbl_font_size = .1)

	


	// tg.draw_cube(mesh = &mesh_cpu, tex_id = "glass_block", cube = {pos = {0,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)
	// tg.draw_cube(mesh = &mesh_cpu, tex_id = "world_tileset", cube = {pos = {3,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)
	// tg.draw_cube(mesh = &mesh_cpu, tex_id = "0", cube = {pos = {5,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)
	// tg.draw_cube(mesh = &mesh_cpu, tex_id = "1", cube = {pos = {7,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)
	// tg.draw_cube(mesh = &mesh_cpu, tex_id = "ax_man", cube = {pos = {10,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)
	// tg.draw_cube(mesh = &mesh_cpu, tex_id = "castle", cube = {pos = {13,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)
	// tg.draw_cube(mesh = &mesh_cpu, tex_id = "mine", cube = {pos = {14,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)
	// tg.draw_cube(mesh = &mesh_cpu, tex_id = "pawn", cube = {pos = {16,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)
	tg.draw_cube(mesh = &mesh_cpu, tex_id = "awn", cube = {pos = {-2,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)
	tg.draw_text(mesh = &mesh_cpu, text = "FWwaAffFlLe.EsS", scale = 2,pos = {0,0,5},rot = {0,0,3.145},origin = {0,0,0}, vert_t = tg.Vertex_Data_t,fixed_spacing = 12,txt_origin = .top)
	// tg.draw_cube(mesh = &mesh_cpu, tex_id = "awn", cube = {pos = {0,0,5},w_h_l = {1,1,1}},rot = {0,0,0},origin = {0,0,0}, vert_t = tg.Vertex_Data_t)
	tg.draw_rect(mesh = &mesh_cpu, tex_id = "pawn", rect = {pos = {3,0,-6},w_h = {15,10}},rot = {0,0,.5},origin = {0,6,0}, vert_t = tg.Vertex_Data_t)
	tg.draw_rect_rounded(mesh = &mesh_cpu, tex_id = "pawn", rec = {pos = {3,0,-5},w_h = {15,10}},rot = {0,0,.5},origin = {0,6,0}, vert_t = tg.Vertex_Data_t)
	mesh_hd := tg.create_mesh(mesh_cpu)

	tg.update_mesh(mesh_hd)
	new_ticks := sdl.GetTicks()
	s.delta_time = f32(new_ticks - s.ticks) / 1000
	s.ticks = new_ticks

	main_loop:for tg.start_frame(){
		s.mouse_move = {}
		for ev in &tg.s.events {
			#partial switch ev.type{
			case .KEY_DOWN:
				s.key_down[ev.key.scancode] = true
			case .KEY_UP:
				s.key_down[ev.key.scancode] = false
			case .MOUSE_MOTION:
				s.mouse_move += tg.Vec2{ev.motion.xrel, ev.motion.yrel}
			}
		}
		tg.update_camera_3d(&camera, s.delta_time, )
		tg.update_camera_3d(&camera2, s.delta_time, )
		tg.start_render()

		// tg.clear_render({.3,.3,1,1},&pass, &camera, window_hd)
		// tg.clear_render({.3,.3,1,1},&pass, &camera, window_hd2)
		
		render_comands:=create_layout()

		tg.update_clay_instance(clay_inst,&render_comands)


		tg.do_render_pass(&pass, &camera, {mesh_hd}, window_hd,  load_op = .CLEAR, d_load_op = .CLEAR, store_op = .STORE)
		tg.render_clay_instance(clay_inst,&camera,window_hd,     load_op = .LOAD,  d_load_op = .LOAD,  store_op = .RESOLVE)
		tg.do_render_pass(&pass, &camera2, {mesh_hd}, window_hd2,load_op = .CLEAR, d_load_op = .CLEAR, store_op = .STORE)
		tg.render_clay_instance(clay_inst,&camera2,window_hd2,   load_op = .LOAD,  d_load_op = .LOAD,  store_op = .RESOLVE)
	

		tg.submit_render()
		
	}
	tg.delete_r_pass(&pass)
	tg.delete_mesh(mesh_hd)
	tg.delete_clay_instance(clay_inst)
	tg.delete_camera(&camera)
	tg.delete_camera(&camera2)
	tg.cleane_app()
	
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
