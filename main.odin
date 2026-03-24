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
	defalt_context: runtime.Context,
	allocator: runtime.Allocator,
	frame_arena: runtime.Arena,
	frame_allocator: runtime.Allocator,
	
	
	swap_chain_texture_format:	sdl.GPUTextureFormat,
	depth_texture_format:		sdl.GPUTextureFormat,
	
	texture_arr_map:map[[2]u32]Texture,
	texture_arr_groop:[Texture_Arr_Groop]Texture_Arr_Data,
	
	texture_groop: Texture_Groop,
	shaders:        hm.Handle_Map(Shader, Shader_Handle, 200),
	windows:        hm.Handle_Map(Window, Window_Handle, 50),
	meshes:         hm.Handle_Map(Mesh, Mesh_Handle, 1024*10),
	fonts:          hm.Handle_Map(Font, Font_Handle, 200),
	clay_instances: hm.Handle_Map(Clay_Instance, Clay_I_Handle, 50),
	
	defalt_font:Font_Handle,

	gpu_device: ^sdl.GPUDevice,
	copy_cmd_buf   :^sdl.GPUCommandBuffer,
	render_cmd_buf :^sdl.GPUCommandBuffer,

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
	// swap_chain:^sdl.GPUTexture,//TODO move this to Render_Target:
	// msaa_tex:^sdl.GPUTexture,
	Render_Target:Render_Target,
	// msaa_texture_createinfo : sdl.GPUTextureCreateInfo,
	
}

Init_Dec ::struct{
	win_name:string,
	win_size:[2]i32,
	msaa_txture_createinfo:sdl.GPUTextureCreateInfo
}
ASSETS_PATH:: "assets/"
SHADER_PATH:: ASSETS_PATH+"shaders/"
TEXTUR_PATH:: ASSETS_PATH+"textures/"
INIT_DEC:Init_Dec:{
	win_name="Defalt win name",
	win_size= {1280,780},
	msaa_txture_createinfo=DEFALT_MSAA_TEXTURE_CREATEINFO
}

Input_EV::union{
	sdl.Scancode,
	sdl.MouseButtonFlag,
	sdl.GamepadButton,
	
}


R_Pass ::struct{
	window_hd: Window_Handle,
	info:Render_Pass_Info,
	render_pas: ^sdl.GPURenderPass,
	pipeline: ^sdl.GPUGraphicsPipeline,
	sampler: ^sdl.GPUSampler,
	
	msaa_texture: ^sdl.GPUTexture,
	
	texture_sampler_binding:[dynamic]sdl.GPUTextureSamplerBinding,//this gets rebuilt per frame
	// win_size:[2]i32,
	ubo:UBO,
}

Render_Pass_Info::struct{
	// load_op : sdl.GPULoadOp, 
	clear_color : [4]f32,
	has_depth_stencil_target:bool,
	// depth_texture_createinfo : sdl.GPUTextureCreateInfo,
	// depth_msaa_texture_createinfo : sdl.GPUTextureCreateInfo,
	// msaa_texture_createinfo : sdl.GPUTextureCreateInfo,
	depth_stencil_state : sdl.GPUDepthStencilState,
	rasterizer_state : sdl.GPURasterizerState,
	blend_state : sdl.GPUColorTargetBlendState,
	vertex_input_state : sdl.GPUVertexInputState,
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
	s.defalt_font = load_font_from_data(font_id = "font_1",height = 16)
	s.defalt_context = context
	
	return
}

init_window::proc(dec:Init_Dec=INIT_DEC)->(window_hd:Window_Handle){
	win_name:=frame_cstring(dec.win_name)
	window_data := sdl.CreateWindow(win_name,dec.win_size.x,dec.win_size.y,{})
	assert(window_data != nil,"SDL CreateWindow failed")
	
	ok:=sdl.ClaimWindowForGPUDevice(s.gpu_device,window_data)
	assert(ok,"SLD ClaimWindowForGPUDevice failed")
	
	// ok = sdl.SetGPUSwapchainParameters(s.gpu_device,window_data,sdl.GPUSwapchainComposition{},sdl.GPUPresentMode{})
	
	window:Window={
		data = window_data,
		swap_chain_format = sdl.GetGPUSwapchainTextureFormat(s.gpu_device, window_data),
		Render_Target = Render_Target{
			msaa_texture_createinfo = dec.msaa_txture_createinfo
		}
	}
	s.swap_chain_texture_format = window.swap_chain_format
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

create_render_pass :: proc (vert_shader_hd: Shader_Handle, frag_shader_hd: Shader_Handle, info:Render_Pass_Info=DEFALT_MASKED_PASS) ->(pass:R_Pass){
	// window:=get_window(window_hd)
	vert_shader:=get_shader(vert_shader_hd)
	frag_shader:=get_shader(frag_shader_hd)
	pass.info = info

	
	pass.sampler = sdl.CreateGPUSampler(s.gpu_device,{})

	target_info := sdl.GPUGraphicsPipelineTargetInfo{
		num_color_targets = 1,
		color_target_descriptions=&(sdl.GPUColorTargetDescription{
			// format = window.swap_chain_format,
			format = s.swap_chain_texture_format,
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
		multisample_state = sdl.GPUMultisampleState{
			sample_count= ._4,
			// enable_alpha_to_coverage = true,
		},
	})
	return
}
// stil undesided whether or not to use this
// clear_render::proc(col:[4]f32,pass:^R_Pass,cam:^Camera,window_hd:Window_Handle){
// 	window:=get_window(window_hd)
// 	if window == nil{return}
// 	render_target := window.swap_chain
	
// 	if render_target != nil{
// 		color_target := sdl.GPUColorTargetInfo{
// 			texture = render_target,
// 			load_op = .CLEAR,
// 			clear_color = cast(sdl.FColor)col,
// 			store_op = .STORE,
// 		}
// 		depth_target_info:^sdl.GPUDepthStencilTargetInfo
// 		if cam.depth_texture != nil{
// 			depth_target_info = &sdl.GPUDepthStencilTargetInfo{
// 				texture = cam.depth_texture,
// 				load_op = .CLEAR,
// 				clear_depth = 1,
// 				store_op = .STORE,
// 			}
// 		}
// 		pass.render_pas = sdl.BeginGPURenderPass(s.render_cmd_buf, &color_target, 1, depth_target_info )
// 		sdl.EndGPURenderPass(pass.render_pas);
// 	}else{
// 		log.log(.Debug,"Clear_render() failed render_target == nil\n")
// 	}
// }
do_render_pass::proc(
	pass:^R_Pass,
	cam:^Camera,
	meshes_hd:[]Mesh_Handle,
	render_target:Render_Targets,
	load_op:	sdl.GPULoadOp=.LOAD,
	d_load_op:	sdl.GPULoadOp=.LOAD,
	store_op:   sdl.GPUStoreOp = .STORE,
	d_store_op: sdl.GPUStoreOp = .STORE,
	clear_color:[4]f32={.3,.3,.3,1})
{
	// window:=get_window(window_hd)
	// window_valid:bool=hm.valid(s.windows, window_hd)
	render_target := get_render_target(render_target)
	if render_target == nil{return}
	// if render_target.data == nil{return}

	rtci:=&render_target.msaa_texture_createinfo
	cdtci:=&cam.depth_texture_createinfo

	if render_target.wh != {cam.texture_size.x, cam.texture_size.y}{// update depth_texture if screane is resized
		cam.texture_size.x  = render_target.wh.x
		cam.texture_size.y = render_target.wh.y

		cam.texture_size = render_target.wh
		sdl.ReleaseGPUTexture(s.gpu_device, cam.depth_texture)
		cdtci.format =  s.depth_texture_format
		cdtci.width = cast(u32)cam.texture_size.x
		cdtci.height = cast(u32)cam.texture_size.y
		cam.depth_texture = sdl.CreateGPUTexture(s.gpu_device, createinfo = cdtci^)		
		fmt.print("new cam.depth_texture size\n")
	}
		
	if render_target.wh != {cast(i32)rtci.width,cast(i32)rtci.height}{// update depth_texture if screane is resized
		rtci.width  = cast(u32)render_target.wh.x
		rtci.height = cast(u32)render_target.wh.y
		
		sdl.ReleaseGPUTexture(s.gpu_device, render_target.msaa_tex)
		rtci.format =  s.swap_chain_texture_format
		rtci.width = cast(u32)render_target.wh.x
		rtci.height = cast(u32)render_target.wh.y
		render_target.msaa_tex = sdl.CreateGPUTexture(s.gpu_device, createinfo = rtci^)
		fmt.print("new pass.msaa_texture size\n")
	}
	
	if cam.depth_texture == nil{
		cdtci.format =  s.depth_texture_format
		cdtci.width = cast(u32)cam.texture_size.x
		cdtci.height = cast(u32)cam.texture_size.y
		cam.depth_texture = sdl.CreateGPUTexture(s.gpu_device, createinfo = cdtci^)
		fmt.print("new cam.depth_texture == nil\n")
	}
	
	if render_target.msaa_tex == nil{
		rtci.format =  s.swap_chain_texture_format
		rtci.width = cast(u32)render_target.wh.x
		rtci.height = cast(u32)render_target.wh.y
		render_target.msaa_tex = sdl.CreateGPUTexture(s.gpu_device, createinfo = rtci^)
		fmt.print("new pass.msaa_texture == nil\n")
	}
	
	// sdl.BlitGPUTexture()
	view_mat :Mat4= 1//lin.matrix4_look_at_f32(cam.pos, cam.target, {0,1,0})
	proj_mat :Mat4= 1//lin.matrix4_perspective_f32(lin.to_radians(cast(f32)90), cast(f32)render_target.wh.x / cast(f32)render_target.wh.y, 0.001, 1000)
	
	switch cam.type {
	case .perspective:
	view_mat = lin.matrix4_look_at_f32(cam.pos, cam.target, {0,1,0})
	proj_mat = lin.matrix4_perspective_f32(lin.to_radians(cast(f32)90), cast(f32)render_target.wh.x / cast(f32)render_target.wh.y,-100, 100)
	case .orthographic:
	pos:=cam.pos
	view_mat = lin.matrix4_translate_f32(pos*-1)
	proj_mat = lin.matrix_ortho3d_f32(
		left= 0, 
		right= cast(f32)render_target.wh.x, 
		bottom= -cast(f32)render_target.wh.y, 
		top= 0, 
		near= 0.001, 
		far= 1000,
		)
	}
	modl_mat := lin.matrix4_translate_f32({0,0,0})//*lin.matrix4_rotate_f32(rot, {0,0,0})
	pass.ubo = {mvp = proj_mat * view_mat * modl_mat,}
	
	
	if render_target.data != nil{
		texture:=render_target.msaa_tex
		resolve_texture:^sdl.GPUTexture=nil
		if store_op == .RESOLVE ||store_op == .RESOLVE_AND_STORE {
			texture=render_target.msaa_tex
			resolve_texture=render_target.data
		}

		color_target := sdl.GPUColorTargetInfo{
			texture = texture,
			resolve_texture = resolve_texture,
			load_op = load_op,
			clear_color = cast(sdl.FColor)clear_color,
			store_op = store_op,
		}
		depth_target_info:= sdl.GPUDepthStencilTargetInfo{
			texture = cam.depth_texture,
			load_op = d_load_op,
			clear_depth = 1,
			store_op = .STORE,
		}
		pass.render_pas = sdl.BeginGPURenderPass(s.render_cmd_buf, &color_target, 1, &depth_target_info )
		sdl.BindGPUGraphicsPipeline(pass.render_pas,pass.pipeline)
		sdl.PushGPUVertexUniformData(s.render_cmd_buf, 0, &pass.ubo,size_of(pass.ubo))
		
		clear_dynamic_array(&pass.texture_sampler_binding)
		for &texture in  s.texture_arr_groop{
			if texture != {}{
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
		sdl.EndGPURenderPass(pass.render_pas)
	}
}
start_render::proc(){
	s.render_cmd_buf = sdl.AcquireGPUCommandBuffer(s.gpu_device)
	update_windows()
}
submit_render::proc(){
	ok := sdl.SubmitGPUCommandBuffer(s.render_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed\n")
}
update_windows::proc(){
	my_iter := hm.make_iter(&s.windows)
    for win, i in hm.iter(&my_iter) {
    	swap_chan_w:u32
     	swap_chan_h:u32
    	ok:=sdl.WaitAndAcquireGPUSwapchainTexture(s.render_cmd_buf, win.data, &win.Render_Target.data,&swap_chan_w,&swap_chan_h)
     	win.Render_Target.wh = {cast(i32)swap_chan_w,cast(i32)swap_chan_h}
     	if !ok{log.log(.Debug,"WaitAndAcquireGPUSwapchainTexture failed")}
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

get_window::proc(window_hd:Window_Handle) -> (window:^Window){
	window = hm.get(s.windows,window_hd)
	return window
}
// blit_to_window::proc(pass:R_Pass, win_hd:Window_Handle){
// 	blit_info:sdl.GPUBlitInfo={
	
// 	}
// 	win:=get_render_target(win_hd)
// 	sdl.BlitGPUTexture(s.render_cmd_buf,blit_info)
// }

//cam___________________________________________________________________________
Camera_Types::enum{
	perspective, 
	orthographic,
}

Camera ::struct {
	pos:[3]f32,
	target:[3]f32,
	look: struct {
		yaw: f32,
		pitch: f32,
	},
	texture_size:[2]i32,
	type:Camera_Types,
	depth_texture_createinfo : sdl.GPUTextureCreateInfo,
	depth_texture: ^sdl.GPUTexture,
	// msaa_depth_texture: ^sdl.GPUTexture,
} 

create_camera::proc(
	type:Camera_Types = .perspective,
	depth_texture_createinfo:sdl.GPUTextureCreateInfo = DEFALT_DEPTH_TEXTURE_CREATEINFO,
	
)->(cam:Camera){
	cam = {
		type = type,
		depth_texture_createinfo = depth_texture_createinfo,
	}
	return
}
delete_camera::proc(cam:^Camera){
	if cam.depth_texture != nil{
		sdl.ReleaseGPUTexture(s.gpu_device,cam.depth_texture)
	}
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

//------------------------------------------------------------------------------
Render_Target::struct{
	data:^sdl.GPUTexture,
	msaa_tex:^sdl.GPUTexture,
	msaa_texture_createinfo : sdl.GPUTextureCreateInfo,
	wh:[2]i32,
}
Render_Targets::union{
	Window_Handle,
	^Render_Target,
}
get_render_target::proc(render_target:Render_Targets)->(texture:^Render_Target){
	
	switch rt in render_target {
	case Window_Handle:
		win:=get_window(rt)
		if win != nil{
			texture = &win.Render_Target
			// texture.data = win.swap_chain
			sdl.GetWindowSize(win.data,&texture.wh.x,&texture.wh.y)
		}
	case ^Render_Target:
		texture = rt
	}
	return texture
}

//------------------------------------------------------------------------------
//call befor closing app dus not close app
cleane_app::proc(){
	delete(s.events)
	delete(s.texture_arr_map)
	hm.delete(&s.meshes)
	hm.delete(&s.texture_groop)
	hm.delete(&s.windows)
	hm.delete(&s.shaders)
	hm.delete(&s.clay_instances)
	free(s)
}
delete_r_pass::proc(pass:^R_Pass){
	delete(pass.texture_sampler_binding)
}
