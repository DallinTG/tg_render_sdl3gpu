package tg_test

import tg"../../../tg_render_sdl3"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
// import str"core:strings"
import "core:fmt"
// import "core:math"
// import lin"core:math/linalg"
// import "base:runtime"
import hm "../../handle_map_static_virtual"
import an"ansi"
import lin"core:math/linalg"
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
camera :tg.Camera= {
	pos = {0,0,3},
	target = {0,0,0},
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
	
	window_hd := tg.init_window()
	window_hd2 := tg.init_window()
	
	_ = sdl.SetWindowRelativeMouseMode(tg.get_window(window_hd).data,true)

	// atr_offset:[]tg.Vertex_Attrs_Info={
	// 	{cast(u32)offset_of(tg.Vertex_Data_t, pos),0},
	// 	{cast(u32)offset_of(tg.Vertex_Data_t, col),0},
	// 	{cast(u32)offset_of(tg.Vertex_Data_t, uv),0},
	// 	{cast(u32)offset_of(tg.Vertex_Data_t, col_over),0},
	// }
	// vert_shader:=tg.load_shader_file(file_path = "shader.vert",vertex_type = tg.Vertex_Data_t, attrs_info = atr_offset)
	// frag_shader:=tg.load_shader_file(file_path = "shader.frag",vertex_type = tg.Vertex_Data_t)
	 
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
	
	tex_arr={texture,texture_2}	
	pass = tg.create_render_pass(window_hd, vert_shader, frag_shader)
	mesh_cpu:tg.Mesh_CPU={attribute_type = tg.Vertex_Data_t}
	
	// lin.quaternion_from_pitch_yaw_roll_f32(3,3,3)

	
	tg.draw_triangle_vx(
		mesh = &mesh_cpu,
		pos = {0,0,0},
		verts = [3]tg.Vertex_Data_t{
		{
			pos = {0, 0, 0},
			col = {1,1,1,1},
			uv = {0,0},
			img_index = 2,
		},
		{
			pos = {0,  -1, 0},
			col = {1,1,1,1},
			uv = {0,1},
			img_index = 2,
		},
		{
			pos = {1, -1, 0},
			col = {1,0,0,1},
			uv = {1,1},
			img_index = 2,
		}
	})
	// // tg.draw_cube(mesh = &mesh_cpu, pos = {})
	tg.draw_triangle_vx(
		mesh = &mesh_cpu,
		pos = {1,0,-5},
		verts = [3]tg.Vertex_Data_t{
		{
			pos = {0,  0, 1},
			col = {1,1,1,1},
			uv = {0,0},
			img_index = 2,
		},
		{
			pos = {0,  -1, 1},
			col = {1,1,1,1},
			uv = {0,1},
			img_index = 2,
		},
		{
			pos = {1, -1, 1},
			col = {1,0,0,1},
			uv = {1,1},
			img_index = 2,
		},
	})
	tg.draw_cube(mesh = &mesh_cpu, tex_id = "glass_block", cube = {pos = {0,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)

	tg.draw_cube(mesh = &mesh_cpu, tex_id = "world_tileset", cube = {pos = {3,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)
	tg.draw_cube(mesh = &mesh_cpu, tex_id = "0", cube = {pos = {5,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)
	tg.draw_cube(mesh = &mesh_cpu, tex_id = "1", cube = {pos = {7,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)
	tg.draw_cube(mesh = &mesh_cpu, tex_id = "ax_man", cube = {pos = {10,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)
	tg.draw_cube(mesh = &mesh_cpu, tex_id = "castle", cube = {pos = {13,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)
	tg.draw_cube(mesh = &mesh_cpu, tex_id = "mine", cube = {pos = {14,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)
	tg.draw_cube(mesh = &mesh_cpu, tex_id = "pawn", cube = {pos = {16,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)
	tg.draw_cube(mesh = &mesh_cpu, tex_id = "awn", cube = {pos = {-2,0,0},w_h_l = {2,2,2}},rot = {1,1,1},origin = {-1,1,1}, vert_t = tg.Vertex_Data_t)

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
	
		tg.do_render_pass(&pass, &camera, tex_arr[:], {mesh_hd}, window_hd)
		tg.do_render_pass(&pass, &camera, tex_arr[:], {mesh_hd}, window_hd2)
	}
	tg.delete_r_pass(&pass)
	tg.delete_mesh(mesh_hd)
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
