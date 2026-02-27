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
	
	texture_arr_map:map[[2]u32]Texture,
	texture_arr_groop:[Texture_Arr_Groop]Texture_Arr_Data,
	
	texture_groop: Texture_Groop,
	shaders:   hm.Handle_Map(Shader, Shader_Handle, 1024*10),
	windows:   hm.Handle_Map(Window, Window_Handle, 1024*10),
	meshes:   hm.Handle_Map(Mesh, Mesh_Handle, 1024*10),

	gpu_device: ^sdl.GPUDevice,
	copy_cmd_buf :^sdl.GPUCommandBuffer,

	delta_time: f32,
	ticks:u64,
	events:[dynamic]sdl.Event,

	key_down: #sparse[sdl.Scancode]bool,
	mouse_move: Vec2,
}
Window_Handle :: distinct Handle
Window::struct{
	handle:Window_Handle,
	data:^sdl.Window,
	swap_chain_format:sdl.GPUTextureFormat,
	swap_chain:sdl.GPUTexture,
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
	// camera:Camera,
	info:Render_Pass_Info,
	pipeline: ^sdl.GPUGraphicsPipeline,
	render_pas: ^sdl.GPURenderPass,
	cmd_buf: ^sdl.GPUCommandBuffer,
	sampler: ^sdl.GPUSampler,
	
	texture_sampler_binding:[dynamic]sdl.GPUTextureSamplerBinding,//this gets rebuilt per frame
	// sampler2: ^sdl.GPUSampler,
	
	// texture: []Texture_GPU_Handle,
	// mesh: []Mesh_Handle,
	
	copy_pass: ^sdl.GPUCopyPass,
	
	// vertex_buf:^sdl.GPUBuffer,
	// index_buf:^sdl.GPUBuffer,
	transfer_buf:^sdl.GPUTransferBuffer,
	
	// Problobly a swapchain_tex or render texture
	render_target: ^sdl.GPUTexture,
	// depth_texture: ^sdl.GPUTexture,
	
	win_size:[2]i32,
	
	
	ubo:UBO,
}

Render_Pass_Info::struct{
	load_op : sdl.GPULoadOp, 
	clear_color : [4]f32,
	has_depth_stencil_target:bool,
	depth_texture_createinfo : sdl.GPUTextureCreateInfo,
	depth_stencil_state : sdl.GPUDepthStencilState,
	rasterizer_state : sdl.GPURasterizerState,
	blend_state : sdl.GPUColorTargetBlendState,
	vertex_input_state : sdl.GPUVertexInputState,
}


Camera ::struct {
	pos:[3]f32,
	target:[3]f32,
	look: struct {
		yaw: f32,
		pitch: f32,
	},
	
	depth_texture: ^sdl.GPUTexture,
}

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32
Mat3 :: lin.Matrix3f32;
Mat4 :: lin.Matrix4f32;

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
	// _2:[2]f32,
	img_index:u32,
	layer:u32,
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
	init_texture_arr_groop()
	
	
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
		swap_chain_format = sdl.GetGPUSwapchainTextureFormat(s.gpu_device, window_data),
	}
	window_hd = hm.add(&s.windows,window)
	return
}

start_frame::proc()->(ok:bool){
	free_all(s.frame_allocator)
	clear(&s.events)
	event:sdl.Event
	ok = true
	for sdl.PollEvent(&event) {
		append(&s.events,event)
		#partial switch event.type{
		case .QUIT:
			ok = false
		case .WINDOW_CLOSE_REQUESTED:
			win := sdl.GetWindowFromID(event.window.windowID)
			sdl.DestroyWindow(win)
			remove_closed_windows()
			if hm.len(s.windows) <= 0 {
				ok = false
			}
		// case .KEY_DOWN:
		// 	s.key_down[ev.key.scancode] = true
		// case .KEY_UP:
		// 	s.key_down[ev.key.scancode] = false
		// case .MOUSE_MOTION:
		// 	s.mouse_move += tg.Vec2{ev.motion.xrel, ev.motion.yrel}
		}
	}
	return ok
}

create_render_pass :: proc (window_hd:Window_Handle, vert_shader_hd: Shader_Handle, frag_shader_hd: Shader_Handle, info:Render_Pass_Info=DEFALT_MASKED_PASS) ->(pass:R_Pass){
	window:=get_window(window_hd)
	// pass.window_hd = window_hd
	vert_shader:=get_shader(vert_shader_hd)
	frag_shader:=get_shader(frag_shader_hd)
	pass.info = info

	// assert(vert_shader.shader_info.vertex_type == frag_shader.shader_info.vertex_type,"vert_shader and frag_shader do not have the same atttribute type")
	// assert(len(vert_shader.shader_info.vertex_info) == len(vert_shader.shader_info.inputs), "vert_shader mismatch vertex_info and inputs")
	pass.sampler = sdl.CreateGPUSampler(s.gpu_device,{})
	aspect:=sdl.GetWindowSize(window.data,&pass.win_size.x,&pass.win_size.y)

	// pass.info.depth_texture_createinfo.format =  s.depth_texture_format
	// pass.info.depth_texture_createinfo.width = cast(u32)pass.win_size.x
	// pass.info.depth_texture_createinfo.height = cast(u32)pass.win_size.y
	// pass.depth_texture = sdl.CreateGPUTexture(s.gpu_device, createinfo = pass.info.depth_texture_createinfo)
	
	target_info := sdl.GPUGraphicsPipelineTargetInfo{
		num_color_targets = 1,
		color_target_descriptions=&(sdl.GPUColorTargetDescription{
			format = window.swap_chain_format,
			blend_state = pass.info.blend_state,
		}),
		has_depth_stencil_target = pass.info.has_depth_stencil_target,
		depth_stencil_format = s.depth_texture_format,
	}
	pass.pipeline = sdl.CreateGPUGraphicsPipeline(s.gpu_device,sdl.GPUGraphicsPipelineCreateInfo{
		vertex_shader = vert_shader.shader,
		fragment_shader = frag_shader.shader,
		primitive_type = .TRIANGLELIST,
		vertex_input_state = pass.info.vertex_input_state,
		depth_stencil_state = pass.info.depth_stencil_state,
		rasterizer_state = pass.info.rasterizer_state,
		target_info = target_info,
	})
	return
}


do_render_pass::proc(pass:^R_Pass, cam:^Camera, textures:[]Texture_GPU_Handle, meshes_hd:[]Mesh_Handle, window_hd:Window_Handle){

	// mesh:=get_mesh(mesh_hd[0])
	// pass.mesh = meshes_hd
	window:=get_window(window_hd)
	// pass.window_hd = window_hd
	window_valid:bool=hm.valid(s.windows, window_hd)
	
	if !window_valid{return}
	
	temp_win_size:[2]i32
	aspect:=sdl.GetWindowSize(window.data,&temp_win_size.x,&temp_win_size.y)
	
	if cam.depth_texture == nil && window_valid{
		pass.info.depth_texture_createinfo.format =  s.depth_texture_format
		pass.info.depth_texture_createinfo.width = cast(u32)pass.win_size.x
		pass.info.depth_texture_createinfo.height = cast(u32)pass.win_size.y
		cam.depth_texture = sdl.CreateGPUTexture(s.gpu_device, createinfo = pass.info.depth_texture_createinfo)
	}
	
	if temp_win_size != pass.win_size && window_valid{// update depth_texture if screane is resized
		pass.win_size = temp_win_size
		sdl.ReleaseGPUTexture(s.gpu_device, cam.depth_texture)
		pass.info.depth_texture_createinfo.format =  s.depth_texture_format
		pass.info.depth_texture_createinfo.width = cast(u32)pass.win_size.x
		pass.info.depth_texture_createinfo.height = cast(u32)pass.win_size.y
		cam.depth_texture = sdl.CreateGPUTexture(s.gpu_device, createinfo = pass.info.depth_texture_createinfo)
		
	}
	// pass.texture = texture
	// assign_at(&pass.texture, 0, texture[0])
	// assign_at(&pass.texture, 1, texture[1])
	view_mat := lin.matrix4_look_at_f32(cam.pos, cam.target, {0,1,0})
	proj_mat := lin.matrix4_perspective_f32(lin.to_radians(cast(f32)90), cast(f32)pass.win_size.x / cast(f32)pass.win_size.y, 0.001, 1000)
	modl_mat := lin.matrix4_translate_f32({0,0,-5})*lin.matrix4_rotate_f32(rot, {0,1,0})
	pass.ubo = {mvp = proj_mat * view_mat * modl_mat,}	
		
	pass.cmd_buf = sdl.AcquireGPUCommandBuffer(s.gpu_device)

	ok:bool
	if window_valid {ok=sdl.WaitAndAcquireGPUSwapchainTexture(pass.cmd_buf, window.data, &pass.render_target,nil,nil)}
	if !ok{
		pass.render_target = nil
	}
	
	if pass.render_target != nil{
		color_target := sdl.GPUColorTargetInfo{
			texture = pass.render_target,
			load_op = pass.info.load_op,
			clear_color = cast(sdl.FColor)pass.info.clear_color,
			store_op = .STORE,
		}
		depth_target_info:= sdl.GPUDepthStencilTargetInfo{
			texture = cam.depth_texture,
			load_op = pass.info.load_op,
			clear_depth = 1,
			store_op = .STORE,
		}
		pass.render_pas = sdl.BeginGPURenderPass(pass.cmd_buf, &color_target, 1, &depth_target_info )
		sdl.BindGPUGraphicsPipeline(pass.render_pas,pass.pipeline)
		sdl.PushGPUVertexUniformData(pass.cmd_buf, 0, &pass.ubo,size_of(pass.ubo))
		
		clear_dynamic_array(&pass.texture_sampler_binding)
		for &texture in  s.texture_arr_groop{
		// for &texture in textures{
		// for &texture in &s.texture_groop.items{
			if texture != {}{
				// texture:=get_gpu_texture(texture)
				texture:=get_gpu_texture(texture.tex_hd)
				append_elem(&pass.texture_sampler_binding ,sdl.GPUTextureSamplerBinding{ texture = texture.data, sampler = pass.sampler})
			}
		}

		sdl.BindGPUFragmentSamplers(pass.render_pas, 0, raw_data(pass.texture_sampler_binding), cast(u32)len(pass.texture_sampler_binding))
		
		for mesh_hd in meshes_hd{
			mesh:=get_mesh(mesh_hd)
			sdl.BindGPUVertexStorageBuffers(pass.render_pas, 0, &mesh.gpu.vertex_buf,1)
			sdl.BindGPUVertexStorageBuffers(pass.render_pas, 1, &mesh.gpu.index_buf,1)		
			sdl.DrawGPUPrimitives(pass.render_pas,mesh.gpu.index_count, 1, 0, 0)
		
		}
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
update_camera_3d::proc(cam:^Camera, dt:f32, sensitivity:f32=3, speed:f32=1.5,){
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
	delete(s.events)
	delete(s.texture_arr_map)
	hm.delete(&s.meshes)
	hm.delete(&s.texture_groop)
	hm.delete(&s.windows)
	hm.delete(&s.shaders)
	free(s)
}
delete_r_pass::proc(pass:^R_Pass){
	delete(pass.texture_sampler_binding)
}
