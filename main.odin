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

	gpu_device: ^sdl.GPUDevice,
	copy_cmd_buf :^sdl.GPUCommandBuffer,

	delta_time: f32,
	ticks:u64,

	key_down: #sparse[sdl.Scancode]bool,
	mouse_move: Vec2,
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

Mesh_CPU::struct{
	vertex_buf:[dynamic]u8,
	index_buf:[dynamic]u8,
	attribute_type:typeid,
}
Mesh_GPU::struct{
	is_good:bool,
	vertex_buf:^sdl.GPUBuffer,
	index_buf:^sdl.GPUBuffer,
	transfer_buf:^sdl.GPUTransferBuffer,
	attribute_type:typeid,
}
Mesh::struct{
	cpu:Mesh_CPU,
	gpu:Mesh_GPU,
}

R_Pass ::struct{
	window: ^sdl.Window,
	camera:Camera,
	pipeline: ^sdl.GPUGraphicsPipeline,
	render_pas: ^sdl.GPURenderPass,
	cmd_buf: ^sdl.GPUCommandBuffer,
	sampler: ^sdl.GPUSampler,
	texture: Texture,
	mesh:^Mesh,
	
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
	color:Vec4,
	uv: [2]f32,
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

init_window::proc(dec:Init_Dec=INIT_DEC)->(window:^sdl.Window){

	win_name:=frame_cstring(dec.win_name)
	window = sdl.CreateWindow(win_name,dec.win_size.x,dec.win_size.y,{})
	assert(window != nil,"SDL CreateWindow failed")
	
	ok:=sdl.ClaimWindowForGPUDevice(s.gpu_device,window)
	assert(ok,"SLD ClaimWindowForGPUDevice failed")
	return
}
create_mesh::proc(cpu_mesh:Mesh_CPU) ->(mesh:Mesh){
	vertices_byte_size:=len(cpu_mesh.vertex_buf)
	indices_byte_size:=len(cpu_mesh.index_buf)
	mesh.cpu = cpu_mesh
	mesh.gpu.vertex_buf = sdl.CreateGPUBuffer(s.gpu_device,{
		usage={.VERTEX},
		size = cast(u32)vertices_byte_size,
	})
	mesh.gpu.index_buf = sdl.CreateGPUBuffer(s.gpu_device,{
		usage={.INDEX},
		size = cast(u32)indices_byte_size,
	})
	mesh.gpu.transfer_buf = sdl.CreateGPUTransferBuffer(s.gpu_device,{
		usage = .UPLOAD,
		size = cast(u32)(vertices_byte_size + indices_byte_size),
	})
	return
}
update_mesh::proc(mesh:^Mesh){

	vertices_byte_size:=len(mesh.cpu.vertex_buf)
	indices_byte_size:=len(mesh.cpu.index_buf)
	transfer_mem := transmute([^]byte)sdl.MapGPUTransferBuffer(s.gpu_device, mesh.gpu.transfer_buf, false)
	mem.copy(transfer_mem, raw_data(mesh.cpu.vertex_buf), vertices_byte_size)
	mem.copy(transfer_mem[vertices_byte_size:], raw_data(mesh.cpu.index_buf), indices_byte_size)	
	copy_pass: = sdl.BeginGPUCopyPass(s.copy_cmd_buf)
	sdl.UploadToGPUBuffer(copy_pass,
		{transfer_buffer = mesh.gpu.transfer_buf,},
		{buffer = mesh.gpu.vertex_buf, size = cast(u32)vertices_byte_size},
		false,
	)
	sdl.UploadToGPUBuffer(copy_pass,
		{transfer_buffer = mesh.gpu.transfer_buf,offset = cast(u32)vertices_byte_size},
		{buffer = mesh.gpu.index_buf, size = cast(u32)indices_byte_size},
		false,
		
	)
	sdl.EndGPUCopyPass(copy_pass)
	ok := sdl.SubmitGPUCommandBuffer(s.copy_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")
	sdl.ReleaseGPUTransferBuffer(s.gpu_device, mesh.gpu.transfer_buf)
}

create_render_pass :: proc (window:^sdl.Window, vert_shader_hd: Shader_Handle, frag_shader_hd: Shader_Handle) ->(pass:R_Pass){

	vert_shader:=get_shader(vert_shader_hd)
	frag_shader:=get_shader(frag_shader_hd)
	attribute_info:=type_info_of(vert_shader.shader_info.vertex_type)

	assert(vert_shader.shader_info.vertex_type == frag_shader.shader_info.vertex_type,"vert_shader and frag_shader do not have the same atttribute type")
	assert(len(vert_shader.shader_info.vertex_info) == len(vert_shader.shader_info.inputs), "vert_shader mismatch vertex_info and inputs")

	pass.window = window
	
	pass.camera = {
		pos = {0,0,3},
		target = {0,0,0},
	}
	
	// vertices := []Vertex_Data{
	// 	{pos={ -.5,  .5, 0},color= {1,1,1,1}, uv= {0,0}},
	// 	{pos={  .5,  .5, 0},color= {1,1,1,1}, uv= {1,0}},
	// 	{pos={ -.5, -.5, 0},color= {1,1,1,1}, uv= {0,1}},
	// 	{pos={  .5, -.5, 0},color= {1,1,1,1}, uv= {1,1}},
		
	// 	{pos={ -.5,  .5, -1},color= {1,1,0,1}, uv= {0,0}},
	// 	{pos={  .5,  .5, -1},color= {1,1,0,1}, uv= {1,0}},
	// 	{pos={ -.5, -.5, -1},color= {1,1,0,1}, uv= {0,1}},
	// 	{pos={  .5, -.5, -1},color= {1,1,0,1}, uv= {1,1}},
	// }
	// vertices_byte_size:= len(vertices) * size_of(vertices[0])
	// indices := []u32 {
		
	// 	0+4,1+4,2+4,
	// 	2+4,1+4,3+4,
		
	// 	0,1,2,
	// 	2,1,3,
		
	// }
	// indices_byte_size:= len(indices) * size_of(indices[0])
	
	// pass.vertex_buf = sdl.CreateGPUBuffer(gpu_device,{
	// 	usage={.VERTEX},
	// 	size = cast(u32)vertices_byte_size,
	// })
	
	// pass.index_buf = sdl.CreateGPUBuffer(pass.gpu_device,{
	// 	usage={.INDEX},
	// 	size = cast(u32)indices_byte_size,
	// })
	
	// pass.transfer_buf = sdl.CreateGPUTransferBuffer(pass.gpu_device,{
	// 	usage = .UPLOAD,
	// 	size = cast(u32)(vertices_byte_size + indices_byte_size),
	// })
	
	// transfer_mem := transmute([^]byte)sdl.MapGPUTransferBuffer(pass.gpu_device, pass.transfer_buf, false)
	// mem.copy(transfer_mem, raw_data(vertices), vertices_byte_size)
	// mem.copy(transfer_mem[vertices_byte_size:], raw_data(indices), indices_byte_size)
	// sdl.UnmapGPUTransferBuffer(pass.gpu_device, pass.transfer_buf)
		
	// pass.copy_cmd_buf = sdl.AcquireGPUCommandBuffer(pass.gpu_device)
	// pass.copy_pass = sdl.BeginGPUCopyPass(pass.copy_cmd_buf)
	
	// sdl.UploadToGPUBuffer(pass.copy_pass,
	// 	{transfer_buffer = pass.transfer_buf,},
	// 	{buffer = pass.vertex_buf, size = cast(u32)vertices_byte_size},
	// 	false,
		
	// )
	// sdl.UploadToGPUBuffer(pass.copy_pass,
	// 	{transfer_buffer = pass.transfer_buf,offset = cast(u32)vertices_byte_size},
	// 	{buffer = pass.index_buf, size = cast(u32)indices_byte_size},
	// 	false,
		
	// )
	// sdl.EndGPUCopyPass(pass.copy_pass)
	// ok := sdl.SubmitGPUCommandBuffer(pass.copy_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")
	// sdl.ReleaseGPUTransferBuffer(pass.gpu_device,pass.transfer_buf)
	
	pass.sampler = sdl.CreateGPUSampler(s.gpu_device,{})
	
	vertex_attrs :[dynamic]sdl.GPUVertexAttribute//{
	defer delete(vertex_attrs)
	for vs_info , i in vert_shader.shader_info.inputs{
		append_elem(&vertex_attrs,sdl.GPUVertexAttribute{})
		vertex_attrs[i].location = vs_info.location
		vertex_attrs[i].format = cast(sdl.GPUVertexElementFormat)vs_info.type
	}
	for vs_info , i in vert_shader.shader_info.vertex_info{
		vertex_attrs[i].buffer_slot = vs_info.buff_slot
		vertex_attrs[i].offset = vs_info.offset
	}
	// win_size:[2]i32
	aspect:=sdl.GetWindowSize(pass.window,&pass.win_size.x,&pass.win_size.y)
	
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
		vertex_input_state = {
			num_vertex_buffers = 1,
			vertex_buffer_descriptions = &(sdl.GPUVertexBufferDescription{
				slot = 0,
				pitch = cast(u32)attribute_info.size,
			}),
			num_vertex_attributes = cast(u32)len(vertex_attrs),
			vertex_attributes = raw_data(vertex_attrs)
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
				format = sdl.GetGPUSwapchainTextureFormat(s.gpu_device, pass.window)
			}),
			has_depth_stencil_target = true,
			depth_stencil_format = s.depth_texture_format,
		}
	})
	return
}

start_frame::proc(){

}

start_render_pass::proc(pass:^R_Pass, texture:Texture, mesh:^Mesh){
	temp_win_size:[2]i32
	aspect:=sdl.GetWindowSize(pass.window,&temp_win_size.x,&temp_win_size.y)
	pass.mesh = mesh
	
	if temp_win_size != pass.win_size{// update depth_texture if screane is resized
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

	// swapchain_tex: ^sdl.GPUTexture
	ok:=sdl.WaitAndAcquireGPUSwapchainTexture(pass.cmd_buf, pass.window, &pass.render_target,nil,nil)
	assert(ok, "SDL WaitAndAcquireGPUSwapchainTexture Failed")
}

finish_render_pass::proc(pass:^R_Pass){

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
		sdl.BindGPUVertexBuffers(pass.render_pas, 0, &(sdl.GPUBufferBinding{buffer=pass.mesh.gpu.vertex_buf}),1)
		sdl.BindGPUIndexBuffer(pass.render_pas, {buffer = pass.mesh.gpu.index_buf}, ._32BIT)

		sdl.PushGPUVertexUniformData(pass.cmd_buf, 0, &pass.ubo,size_of(pass.ubo))

		sdl.BindGPUFragmentSamplers(pass.render_pas, 0, &(sdl.GPUTextureSamplerBinding{texture = get_texture_data(pass.texture.handle), sampler = pass.sampler}),1)

		sdl.DrawGPUIndexedPrimitives(pass.render_pas, 12, 1, 0, 0, 0)

		sdl.EndGPURenderPass(pass.render_pas);

		ok := sdl.SubmitGPUCommandBuffer(pass.cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")

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

//call befor closing app dus not close app
cleane_app::proc(){
	free(s)
}
