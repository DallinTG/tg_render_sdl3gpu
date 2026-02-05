package tg_test

import tg"../../../tg_render_sdl3"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
// import str"core:strings"
import "core:fmt"
// import "core:math"
// import lin"core:math/linalg"
// import "base:runtime"
// import hm "handle_map_static_virtual"

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
texture:tg.Texture
s:^tg.State

main :: proc(){
	context.logger = log.create_console_logger()
	when USE_TRACKING_ALLOCATOR {
		default_allocator := context.allocator
		tracking_allocator: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking_allocator, default_allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)
	}
	s=tg.init()
	
	window := tg.init_window()
	_ = sdl.SetWindowRelativeMouseMode(window,true)

	atr_offset:[]tg.Vertex_Attrs_Info={
		{cast(u32)offset_of(tg.Vertex_Data, pos),0},
		{cast(u32)offset_of(tg.Vertex_Data, color),0},
		{cast(u32)offset_of(tg.Vertex_Data, uv),0}
	}
	vert_shader:=tg.load_shader_file(file_path = "shader.vert",vertex_type = tg.Vertex_Data, attrs_info = atr_offset)
	frag_shader:=tg.load_shader_file(file_path = "shader.frag",vertex_type = tg.Vertex_Data)
	
	texture = tg.load_texture_from_file("world_tileset.png")	
	pass = tg.create_render_pass(window, vert_shader, frag_shader)
	vertices := []tg.Vertex_Data{
		{pos={ -.5,  .5, 0},color= {1,1,1,1}, uv= {0,0}},
		{pos={  .5,  .5, 0},color= {1,1,1,1}, uv= {1,0}},
		{pos={ -.5, -.5, 0},color= {1,1,1,1}, uv= {0,1}},
		{pos={  .5, -.5, 0},color= {1,1,1,1}, uv= {1,1}},
		
		{pos={ -.5,  .5, -1},color= {1,1,0,1}, uv= {0,0}},
		{pos={  .5,  .5, -1},color= {1,1,0,1}, uv= {1,0}},
		{pos={ -.5, -.5, -1},color= {1,1,0,1}, uv= {0,1}},
		{pos={  .5, -.5, -1},color= {1,1,0,1}, uv= {1,1}},
	}

	vertices_byte_size:= len(vertices) * size_of(vertices[0])
	indices := []u32 {
		
		0+4,1+4,2+4,
		2+4,1+4,3+4,
		
		0,1,2,
		2,1,3,
		
	}
	indices_byte_size:= len(indices) * size_of(indices[0])
	mesh_cpu:tg.Mesh_CPU={}
	resize_dynamic_array(&mesh_cpu.vertex_buf, vertices_byte_size)
	resize_dynamic_array(&mesh_cpu.index_buf,  indices_byte_size)

	mem.copy(raw_data(mesh_cpu.vertex_buf), raw_data(vertices), vertices_byte_size)
	mem.copy(raw_data(mesh_cpu.index_buf), raw_data(indices), indices_byte_size)

	mesh_cpu.attribute_type = tg.Vertex_Data
	mesh := tg.create_mesh(mesh_cpu)
	tg.update_mesh(&mesh)
	
	new_ticks := sdl.GetTicks()
	s.delta_time = f32(new_ticks - s.ticks) / 1000
	s.ticks = new_ticks
	
	main_loop:for{
		ok:bool
		ev:sdl.Event
		s.mouse_move = {}
		for sdl.PollEvent(&ev) {
			#partial switch ev.type{
			case .QUIT:
				break main_loop
				
			case .KEY_DOWN:
				s.key_down[ev.key.scancode] = true
			case .KEY_UP:
				s.key_down[ev.key.scancode] = false
			case .MOUSE_MOTION:
				s.mouse_move += {ev.motion.xrel, ev.motion.yrel}
			}
		}
		tg.start_frame()
		tg.update_camera_3d(&pass.camera, s.delta_time, )
		tg.start_render_pass(&pass, texture, &mesh)
		
		tg.rot+=.01
		tg.finish_render_pass(&pass)
	}
	
	tg.cleane_app()
	
	when USE_TRACKING_ALLOCATOR {
		for _, value in tracking_allocator.allocation_map {
			log.errorf("%v: Leaked %v bytes\n", value.location, value.size)
		}
		mem.tracking_allocator_destroy(&tracking_allocator)
	}
}
