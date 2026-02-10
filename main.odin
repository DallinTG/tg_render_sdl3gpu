package tg_render

import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import str"core:strings"
import "core:fmt"
import "core:math"
import "core:path/filepath"
import "core:encoding/json"
import lin"core:math/linalg"
import "base:runtime"
import hm "handle_map_static_virtual"
import "core:os"

import sc"shader_cross"

import "core:image"
import "core:image/jpeg"
import "core:image/bmp"
import "core:image/png"
import "core:image/tga"

Handle :: hm.Handle
s:^State
State :: struct{
	allocator: runtime.Allocator,
	frame_arena: runtime.Arena,
	frame_allocator: runtime.Allocator,
	
	depth_texture_format:sdl.GPUTextureFormat,
	
	textures:  hm.Handle_Map(Texture_Data, Texture_Handle, 1024*10),
	shaders:   hm.Handle_Map(Shader, Shader_Handle, 1024*10),
	windows:   hm.Handle_Map(Window, Window_Handle, 1024*10),
	meshes:   hm.Handle_Map(Mesh, Mesh_Handle, 1024*10),

	gpu_device: ^sdl.GPUDevice,
	copy_cmd_buf :^sdl.GPUCommandBuffer,

	delta_time: f32,
	ticks:u64,

	key_down: #sparse[sdl.Scancode]bool,
	mouse_move: Vec2,
}
Window_Handle :: distinct Handle
Window::struct{
	handle:Window_Handle,
	data:^sdl.Window,
}

Init_Dec ::struct{
	win_name:string,
	win_size:[2]i32,
}
ASSETS_PATH:: "assets/"
SHADER_PATH:: ASSETS_PATH+"shaders/"
TEXTUR_PATH:: ASSETS_PATH+"textures/"
INIT_DEC:Init_Dec:{
	win_name="Defalt win name",
	win_size= {1280,780},
}

Input_EV::union{
	sdl.Scancode,
	sdl.MouseButtonFlag,
	sdl.GamepadButton,
	
}


R_Pass ::struct{
	window_hd: Window_Handle,
	camera:Camera,
	pipeline: ^sdl.GPUGraphicsPipeline,
	render_pas: ^sdl.GPURenderPass,
	cmd_buf: ^sdl.GPUCommandBuffer,
	sampler: ^sdl.GPUSampler,
	texture: Texture,
	mesh:Mesh_Handle,
	
	copy_pass :^sdl.GPUCopyPass,
	
	// vertex_buf:^sdl.GPUBuffer,
	// index_buf:^sdl.GPUBuffer,
	transfer_buf:^sdl.GPUTransferBuffer,
	
	// Problobly a swapchain_tex or render texture
	render_target: ^sdl.GPUTexture,
	depth_texture: ^sdl.GPUTexture,
	
	win_size:[2]i32,
	
	
	ubo:UBO,
}

Camera ::struct {
	pos:[3]f32,
	target:[3]f32,
	look: struct {
		yaw: f32,
		pitch: f32,
	},
}

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32

Vertex_Data :: struct{
	pos:Vec3,
	col:Vec4,
	uv: [2]f32,
}
Vertex_Data_t :: struct #align(16){
	pos:Vec3,
	_1:f32,
	col:Vec4,
	uv: [2]f32,
	_2:[2]f32,
	col_over:[4]f32,
}

UBO ::struct{
	mvp: matrix[4,4]f32
}

rot:f32=0// FIXME this should not be heare



init :: proc(state:^State=nil, allocator:= context.allocator, location:=#caller_location)->(new_state:^State){
	ok:bool
	sdl.SetLogPriorities(.VERBOSE)
	// sdl.SetLogOutputFunction()
	if state != nil{
		s = state
	}else{
		s = new(State)
		log.log(.Debug,"no Init_Dec provited now using defalt")
	}
	new_state = s
	
	s.frame_allocator = runtime.arena_allocator(&s.frame_arena)
	s.allocator = allocator

	ok = sdl.Init({.VIDEO})
	assert(ok , "SDL init failed")

	s.gpu_device = sdl.CreateGPUDevice({.SPIRV ,.DXIL ,.MSL} ,true, nil)
	assert(s.gpu_device != nil,"SDL CreateGPUDevice failed")
	
	
	try_depth_format::proc(format: sdl.GPUTextureFormat){
		if sdl.GPUTextureSupportsFormat(s.gpu_device, format, .D2, {.DEPTH_STENCIL_TARGET}){
			s.depth_texture_format = format
		}
	}
	s.depth_texture_format = .D16_UNORM
	try_depth_format(.D32_FLOAT)
	try_depth_format(.D24_UNORM)
	
	s.copy_cmd_buf = sdl.AcquireGPUCommandBuffer(s.gpu_device)
	
	return
}

init_window::proc(dec:Init_Dec=INIT_DEC)->(window_hd:Window_Handle){
	win_name:=frame_cstring(dec.win_name)
	window_data := sdl.CreateWindow(win_name,dec.win_size.x,dec.win_size.y,{})
	assert(window_data != nil,"SDL CreateWindow failed")
	
	ok:=sdl.ClaimWindowForGPUDevice(s.gpu_device,window_data)
	assert(ok,"SLD ClaimWindowForGPUDevice failed")
	
	window:Window={
		data = window_data,
	}
	window_hd = hm.add(&s.windows,window)
	return
}

create_render_pass :: proc (window_hd:Window_Handle, vert_shader_hd: Shader_Handle, frag_shader_hd: Shader_Handle) ->(pass:R_Pass){
	window:=get_window(window_hd)
	pass.window_hd = window_hd
	vert_shader:=get_shader(vert_shader_hd)
	frag_shader:=get_shader(frag_shader_hd)
	// attribute_info:=type_info_of(vert_shader.shader_info.vertex_type)

	// assert(vert_shader.shader_info.vertex_type == frag_shader.shader_info.vertex_type,"vert_shader and frag_shader do not have the same atttribute type")
	// assert(len(vert_shader.shader_info.vertex_info) == len(vert_shader.shader_info.inputs), "vert_shader mismatch vertex_info and inputs")

	pass.camera = {
		pos = {0,0,3},
		target = {0,0,0},
	}
	
	pass.sampler = sdl.CreateGPUSampler(s.gpu_device,{})
	
	vertex_attrs :[dynamic]sdl.GPUVertexAttribute//{
	defer delete(vertex_attrs)
	// for vs_info , i in vert_shader.shader_info.inputs{
	// 	append_elem(&vertex_attrs,sdl.GPUVertexAttribute{})
	// 	vertex_attrs[i].location = vs_info.location
	// 	vertex_attrs[i].format = cast(sdl.GPUVertexElementFormat)vs_info.type
	// }
	// for vs_info , i in vert_shader.shader_info.vertex_info{
	// 	vertex_attrs[i].buffer_slot = vs_info.buff_slot
	// 	vertex_attrs[i].offset = vs_info.offset
	// }

	aspect:=sdl.GetWindowSize(window.data,&pass.win_size.x,&pass.win_size.y)
	
	pass.depth_texture = sdl.CreateGPUTexture(s.gpu_device, {
		format= s.depth_texture_format,
		usage = {.DEPTH_STENCIL_TARGET},
		width = cast(u32)pass.win_size.x,
		height = cast(u32)pass.win_size.y,
		layer_count_or_depth = 1,
		num_levels = 1,
	})
	
	pass.pipeline = sdl.CreateGPUGraphicsPipeline(s.gpu_device,{
		vertex_shader = vert_shader.shader,
		fragment_shader = frag_shader.shader,
		primitive_type = .TRIANGLELIST,
		vertex_input_state = sdl.GPUVertexInputState{
			// num_vertex_buffers = 1,
			// vertex_buffer_descriptions = &(sdl.GPUVertexBufferDescription{
			// 	slot = 0,
			// 	pitch = cast(u32)attribute_info.size,
			// }),
			// num_vertex_attributes = cast(u32)len(vertex_attrs),
			// vertex_attributes = raw_data(vertex_attrs)
		},
		depth_stencil_state ={
			enable_depth_test = true,
			enable_depth_write = true,
			compare_op = .LESS,
		},
		rasterizer_state = {
			cull_mode = .BACK,
		},
		target_info = {
			num_color_targets = 1,
			color_target_descriptions=&(sdl.GPUColorTargetDescription{
				format = sdl.GetGPUSwapchainTextureFormat(s.gpu_device, window.data)
			}),
			has_depth_stencil_target = true,
			depth_stencil_format = s.depth_texture_format,
		}
	})
	return
}

start_frame::proc(){

}

start_render_pass::proc(pass:^R_Pass, texture:Texture, mesh_hd:Mesh_Handle, window_hd:Window_Handle){
	mesh:=get_mesh(mesh_hd)
	pass.mesh = mesh_hd
	window:=get_window(window_hd)
	pass.window_hd = window_hd
	window_valid:bool=hm.valid(s.windows, window_hd)
	if !window_valid{return}
	temp_win_size:[2]i32
	aspect:=sdl.GetWindowSize(window.data,&temp_win_size.x,&temp_win_size.y)
	
	if temp_win_size != pass.win_size && window_valid{// update depth_texture if screane is resized
		pass.win_size = temp_win_size
		sdl.ReleaseGPUTexture(s.gpu_device, pass.depth_texture)
		pass.depth_texture = sdl.CreateGPUTexture(s.gpu_device, {
			format= s.depth_texture_format,
			usage = {.DEPTH_STENCIL_TARGET},
			width = cast(u32)pass.win_size.x,
			height = cast(u32)pass.win_size.y,
			layer_count_or_depth = 1,
			num_levels = 1,
		})
	}
	pass.texture = texture
	
	view_mat := lin.matrix4_look_at_f32(pass.camera.pos, pass.camera.target, {0,1,0})
	proj_mat := lin.matrix4_perspective_f32(lin.to_radians(cast(f32)90), cast(f32)pass.win_size.x / cast(f32)pass.win_size.y, 0.001, 1000)
	modl_mat := lin.matrix4_translate_f32({0,0,-5})*lin.matrix4_rotate_f32(rot, {0,1,0})
	pass.ubo = {mvp = proj_mat * view_mat * modl_mat,}	
		
	pass.cmd_buf = sdl.AcquireGPUCommandBuffer(s.gpu_device)

	ok:bool
	if window_valid {ok=sdl.WaitAndAcquireGPUSwapchainTexture(pass.cmd_buf, window.data, &pass.render_target,nil,nil)}
	if !ok{
		pass.render_target = nil
	}
	// assert(ok, "SDL WaitAndAcquireGPUSwapchainTexture Failed")
}

finish_render_pass::proc(pass:^R_Pass){
	mesh:=get_mesh(pass.mesh)
	window_valid:bool=hm.valid(s.windows, pass.window_hd)
	if !window_valid{return}
	if pass.render_target != nil{
		color_target := sdl.GPUColorTargetInfo{
			texture = pass.render_target,
			load_op = .CLEAR,
			clear_color = {0,0,1,1},
			store_op = .STORE,
		}
		depth_target_info:= sdl.GPUDepthStencilTargetInfo{
			texture = pass.depth_texture,
			load_op = .CLEAR,
			clear_depth = 1,
			store_op = .DONT_CARE,
		}

		pass.render_pas = sdl.BeginGPURenderPass(pass.cmd_buf, &color_target, 1, &depth_target_info )

		sdl.BindGPUGraphicsPipeline(pass.render_pas,pass.pipeline)
		// sdl.BindGPUVertexBuffers(pass.render_pas, 0, &(sdl.GPUBufferBinding{buffer=mesh.gpu.vertex_buf}),1)
		// sdl.BindGPUIndexBuffer(pass.render_pas, {buffer = mesh.gpu.index_buf}, ._32BIT)

		sdl.PushGPUVertexUniformData(pass.cmd_buf, 0, &pass.ubo,size_of(pass.ubo))
		
		sdl.BindGPUVertexStorageBuffers(pass.render_pas, 0, &mesh.gpu.vertex_buf,1)
		sdl.BindGPUVertexStorageBuffers(pass.render_pas, 1, &mesh.gpu.index_buf,1)
		
		sdl.BindGPUFragmentSamplers(pass.render_pas, 0, &(sdl.GPUTextureSamplerBinding{texture = get_texture_data(pass.texture.handle), sampler = pass.sampler}),1)

		// sdl.DrawGPUIndexedPrimitives(pass.render_pas, mesh.gpu.index_count, 1, 0, 0, 0)
		sdl.DrawGPUPrimitives(pass.render_pas,mesh.gpu.index_count, 1, 0, 0)

		sdl.EndGPURenderPass(pass.render_pas);

		ok := sdl.SubmitGPUCommandBuffer(pass.cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")

	}
}
remove_closed_windows::proc(){
	windows_iter := hm.make_iter(&s.windows)
	for window in hm.iter(&windows_iter) {
		if sdl.GetWindowID(window.data) == 0 {
			hm.remove(&s.windows,window.handle)
		}
	}
}

frame_cstring :: proc(string: string, loc := #caller_location) -> cstring {
	return str.clone_to_cstring(string, s.frame_allocator, loc)
}

// this is a very rudimenty controler and should only be used for testing
update_camera_3d::proc(cam:^Camera, dt:f32, sensitivity:f32=3, speed:f32=4,){
	move_input:Vec2
	if s.key_down[.W] do move_input.y = 1
	else if s.key_down[.S] do move_input.y = -1
	if s.key_down[.A] do move_input.x = -1
	else if s.key_down[.D] do move_input.x = 1
	
	look_input := s.mouse_move * sensitivity * dt
	
	cam.look.yaw = math.wrap(cam.look.yaw - look_input.x, 360)
	cam.look.pitch = math.clamp(cam.look.pitch - look_input.y, -89, 89)

	look_mat := lin.matrix3_from_yaw_pitch_roll_f32(lin.to_radians(cam.look.yaw), lin.to_radians(cam.look.pitch), 0)

	forward := look_mat * Vec3 {0,0,-1}
	right := look_mat * Vec3 {1,0,0}
	move_dir := forward * move_input.y + right * move_input.x
	// move_dir.y = 0

	motion := lin.normalize0(move_dir) * speed * dt

	cam.pos += motion
	cam.target = cam.pos + forward
}

get_window::proc(window_hd:Window_Handle) -> (window:^Window){
	window = hm.get(s.windows,window_hd)
	return window
}

//call befor closing app dus not close app
cleane_app::proc(){
	free(s)
}
