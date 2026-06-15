package tg_render

import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import str"core:strings"
import "core:fmt"
import "core:time"
import "core:math"
import "core:path/filepath"
import "core:encoding/json"
import lin"core:math/linalg"
import "base:runtime"
import hm "handle_map_static_virtual"
import steam "steamworks"
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
	app_should_close:bool,
	steam:Steam_Info,

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
	// render_cmd_buf :^sdl.GPUCommandBuffer,


	time:Time_Info,
	events:[dynamic]sdl.Event,
	
	// input:Input_Data,

	ui_style:UI_Style,
	// ui_settings:UI_Settings,
	
	lobby:Lobby,
	// key_down: #sparse[sdl.Scancode]bool,
	// mouse_button_down: #sparse[sdl.MouseButtonFlag]bool,
	// mouse_move: Vec2,
	// mouse_wheel:sdl.MouseWheelEvent,

	notifications:Notification_Buffer, 
	is_ui_l_click:proc()->(bool),
	is_ui_r_click:proc()->(bool),

}
Window_Handle :: distinct Handle
Window::struct{
	handle:Window_Handle,
	data:^sdl.Window,
	swap_chain_format:sdl.GPUTextureFormat,
	// swap_chain:^sdl.GPUTexture,//TODO move this to Render_Target:
	// msaa_tex:^sdl.GPUTexture,
	Render_Target:Render_Target,
	last_frame_updated:u64,
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



R_Pass ::struct{
	window_hd: Window_Handle,
	// render_cmd_buf :^sdl.GPUCommandBuffer,
	frame_data:^Frame_Data,//this points to the spisific data that is globl to the curent frame
	info:Render_Pass_Info,
	render_pas: ^sdl.GPURenderPass,
	pipeline: ^sdl.GPUGraphicsPipeline,
	sampler: ^sdl.GPUSampler,
	
	msaa_texture: ^sdl.GPUTexture,
	
	texture_sampler_binding:[dynamic]sdl.GPUTextureSamplerBinding,//this gets rebuilt per frame
	// win_size:[2]i32,
	ubo:UBO,
	render_target:^Render_Target,
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

Vertex_Data :: struct #align(16) {
	pos:Vec4,
	// _1:f32,
	col:Vec4,
	uv: [2]f32,
	// _2:[2]f32,
	img_index:u32,
	layer:u32,
	col_over:[4]f32,
}
Vertex_Data_t :: struct #align(16){
	pos:Vec4,
	// _1:f32,
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

// rot:f32=0// FIXME this should not be heare




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
	
	init_steam()
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
	reg_defalt_assets()
	set_ui_style()
	
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

	// swapchane_ok:=sdl.SetGPUSwapchainParameters(s.gpu_device,window.data,.SDR,.IMMEDIATE)
	return
}

start_tick::proc()->(app_should_close:bool){//returns true if app_should_close
	free_all(s.frame_allocator)
	clear(&s.events)
	event:sdl.Event
	// s.input.mouse_move = {}//reset mouse_move
	// s.input.mouse_wheel = {}//reset mouse_wheel

	s.app_should_close = false
	for sdl.PollEvent(&event) {
		append(&s.events,event)
		#partial switch event.type{
		case .QUIT:

			s.app_should_close = true
		case .WINDOW_CLOSE_REQUESTED:
			win := sdl.GetWindowFromID(event.window.windowID)
			sdl.DestroyWindow(win)
			remove_closed_windows()
			if hm.len(s.windows) <= 0 {
				s.app_should_close = true
			}
			// case .KEY_DOWN:
			// 	s.input.key_down[event.key.scancode] = true
			// case .KEY_UP:
			// 	s.input.key_down[event.key.scancode] = false
			// case .MOUSE_MOTION:
			// 	s.input.mouse_move += Vec2{event.motion.xrel, event.motion.yrel}
			// case .MOUSE_BUTTON_DOWN:
			// 	s.input.mouse_button_down[cast(sdl.MouseButtonFlag)(event.button.button - 1)] = true
			// case .MOUSE_BUTTON_UP:
			// 	s.input.mouse_button_down[cast(sdl.MouseButtonFlag)(event.button.button - 1)] = false
			// case .MOUSE_WHEEL:
			// 	s.input.mouse_wheel = event.wheel
		}
	}
	return s.app_should_close 
}


create_render_pass :: proc (frame_data:^Frame_Data,vert_shader_hd: Shader_Handle, frag_shader_hd: Shader_Handle, info:Render_Pass_Info=DEFALT_MASKED_PASS) ->(pass:R_Pass){
	// window:=get_window(window_hd)
	vert_shader:=get_shader(vert_shader_hd)
	frag_shader:=get_shader(frag_shader_hd)
	pass.info = info
	pass.frame_data = frame_data
	
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

do_render_pass::proc(
	pass:^R_Pass,
	cam:^Camera,
	meshes_hd:[]Mesh_Handle,
){

	if pass.render_target == nil{return}

	view_mat :Mat4= 1//lin.matrix4_look_at_f32(cam.pos, cam.target, {0,1,0})
	proj_mat :Mat4= 1//lin.matrix4_perspective_f32(lin.to_radians(cast(f32)90), cast(f32)render_target.wh.x / cast(f32)render_target.wh.y, 0.001, 1000)
	
	switch cam.type {
	case .perspective:
		view_mat = lin.matrix4_look_at_f32(cam.pos, cam.target, {0,1,0})
		proj_mat = lin.matrix4_perspective_f32(lin.to_radians(cast(f32)90 * cam.zoom), cast(f32)pass.render_target.wh.x / cast(f32)pass.render_target.wh.y,-100, 100)
	case .orthographic:
		pos:=cam.pos
		view_mat = lin.matrix4_translate_f32({-pos.x,-pos.y,-pos.z})
		proj_mat = lin.matrix_ortho3d_f32(
			left= 0, 
			right= cast(f32)pass.render_target.wh.x * cam.zoom, 
			bottom= -cast(f32)pass.render_target.wh.y * cam.zoom, 
			top= 0, 
			near= -1.001, 
			far= 1000,
		)
	}
	modl_mat := lin.matrix4_translate_f32({0,0,0})//*lin.matrix4_rotate_f32(rot, {0,0,0})
	pass.ubo = {mvp = proj_mat * view_mat * modl_mat,}

	sdl.BindGPUGraphicsPipeline(pass.render_pas,pass.pipeline)
	sdl.PushGPUVertexUniformData(pass.frame_data.render_cmd_buf, 0, &pass.ubo,size_of(pass.ubo))
	
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
}
check_and_resize_all_frame_buffers::proc(
	cam:^Camera,
	render_target:Render_Targets,
){
	
	render_target := get_render_target(render_target)
	// if render_target == nil{return}
	// if render_target.data == nil{return}

	rtci:=&render_target.msaa_texture_createinfo
	cdtci:=&cam.depth_texture_createinfo

	if render_target.wh != {cam.texture_size.x, cam.texture_size.y}{// update depth_texture if screane is resized
		ok:=sdl.WaitForGPUIdle(s.gpu_device)
		if ok{
			fmt.print("new cam.depth_texture size",render_target.wh,[2]i32{cam.texture_size.x, cam.texture_size.y},"\n")

			cam.texture_size.x  = render_target.wh.x
			cam.texture_size.y = render_target.wh.y
	
			cam.texture_size = render_target.wh
			sdl.ReleaseGPUTexture(s.gpu_device, cam.depth_texture)
			cdtci.format =  s.depth_texture_format
			cdtci.width = cast(u32)cam.texture_size.x
			cdtci.height = cast(u32)cam.texture_size.y
			cam.depth_texture = sdl.CreateGPUTexture(s.gpu_device, createinfo = cdtci^)		
		}
	}
		
	if render_target.wh != {cast(i32)rtci.width,cast(i32)rtci.height}{// update depth_texture if screane is resized
		ok:=sdl.WaitForGPUIdle(s.gpu_device)
		if ok{
			fmt.print("new pass.msaa_texture size",render_target.wh,[2]i32{cast(i32)rtci.width,cast(i32)rtci.height},"\n")

			rtci.width  = cast(u32)render_target.wh.x
			rtci.height = cast(u32)render_target.wh.y
			
			sdl.ReleaseGPUTexture(s.gpu_device, render_target.msaa_tex)
			rtci.format =  s.swap_chain_texture_format
			rtci.width = cast(u32)render_target.wh.x
			rtci.height = cast(u32)render_target.wh.y
			render_target.msaa_tex = sdl.CreateGPUTexture(s.gpu_device, createinfo = rtci^)
		}
	}
	
	if cam.depth_texture == nil{
		ok:=sdl.WaitForGPUIdle(s.gpu_device)
		if ok{
			fmt.print("new cam.depth_texture == nil",render_target.wh,[2]i32{cast(i32)cam.texture_size.x,cast(i32)cam.texture_size.y},"\n")

			cdtci.format =  s.depth_texture_format
			cdtci.width = cast(u32)cam.texture_size.x
			cdtci.height = cast(u32)cam.texture_size.y
			cam.depth_texture = sdl.CreateGPUTexture(s.gpu_device, createinfo = cdtci^)
		}
	}
	
	if render_target.msaa_tex == nil{
		ok:=sdl.WaitForGPUIdle(s.gpu_device)
		if ok{
			fmt.print("new pass.msaa_texture == nil",render_target.wh,[2]i32{cast(i32)render_target.wh.x,cast(i32)render_target.wh.y},"\n")

			rtci.format =  s.swap_chain_texture_format
			rtci.width = cast(u32)render_target.wh.x
			rtci.height = cast(u32)render_target.wh.y
			render_target.msaa_tex = sdl.CreateGPUTexture(s.gpu_device, createinfo = rtci^)
		}
	}
	
}
start_render::proc(
	pass:^R_Pass,
	cam:^Camera,
	// meshes_hd:[]Mesh_Handle,
	render_target:Render_Targets,
	load_op:	sdl.GPULoadOp  = .CLEAR,
	d_load_op:	sdl.GPULoadOp  = .CLEAR,
	store_op:   sdl.GPUStoreOp = .STORE,
	d_store_op: sdl.GPUStoreOp = .STORE,
	clear_color:[4]f32={.3,.3,.3,1},
){
	// pass.render_cmd_buf = sdl.AcquireGPUCommandBuffer(s.gpu_device)
	pass.render_target = get_render_target(render_target)
	switch rt in render_target {
		case Window_Handle:
			win:=get_window(rt)
			if win.last_frame_updated < pass.frame_data.frame_count{
				win.last_frame_updated = pass.frame_data.frame_count
				update_window(win,pass.frame_data.render_cmd_buf)
			}
		case ^Render_Target:
	}
	check_and_resize_all_frame_buffers(cam,render_target)
	if pass.render_target.data != nil{
		texture:=pass.render_target.msaa_tex
		resolve_texture:^sdl.GPUTexture=nil
		if store_op == .RESOLVE ||store_op == .RESOLVE_AND_STORE {
			texture=pass.render_target.msaa_tex
			resolve_texture=pass.render_target.data
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
		pass.render_pas = sdl.BeginGPURenderPass(pass.frame_data.render_cmd_buf, &color_target, 1, &depth_target_info )
	}
}

submit_render::proc(pass:^R_Pass,){
	sdl.EndGPURenderPass(pass.render_pas)
	// ok := sdl.SubmitGPUCommandBuffer(pass.render_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed\n")
}

Frame_Data::struct{
	render_cmd_buf :^sdl.GPUCommandBuffer,
	frame_count:u64,
}

// this starts the frame 
start_frame::proc(frame:^Frame_Data){
	frame.frame_count+=1
	frame.render_cmd_buf = sdl.AcquireGPUCommandBuffer(s.gpu_device)
}
submit_frame::proc(frame:^Frame_Data){
	ok := sdl.SubmitGPUCommandBuffer(frame.render_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed\n")
}


update_windows::proc(render_cmd_buf :^sdl.GPUCommandBuffer,){
	my_iter := hm.make_iter(&s.windows)
	for win, i in hm.iter(&my_iter) {
		update_window(win,render_cmd_buf)
	}
}
update_window::proc(win:^Window,render_cmd_buf :^sdl.GPUCommandBuffer,){			swap_chan_w:u32
	swap_chan_h:u32
	ok:=sdl.WaitAndAcquireGPUSwapchainTexture(render_cmd_buf, win.data, &win.Render_Target.data,&swap_chan_w,&swap_chan_h)
	if !ok {
		log.log(.Debug,"WaitAndAcquireGPUSwapchainTexture failed")
	}
	if win.Render_Target.wh != {cast(i32)swap_chan_w,cast(i32)swap_chan_h}{
		ok:=sdl.WaitForGPUIdle(s.gpu_device)
		if !ok{
			log.log(.Debug,"sdl.WaitForGPUIdle() failed")
		}
	}
	win.Render_Target.wh = {cast(i32)swap_chan_w,cast(i32)swap_chan_h}
	if !ok{log.log(.Debug,"WaitAndAcquireGPUSwapchainTexture failed")}
}
remove_closed_windows::proc(){
	windows_iter := hm.make_iter(&s.windows)
	for window in hm.iter(&windows_iter) {
		if sdl.GetWindowID(window.data) == 0 {
			hm.remove(&s.windows,window.handle)
		}
	}
}

get_window::proc(window_hd:Window_Handle) -> (window:^Window){
	window = hm.get(s.windows,window_hd)
	return window
}
get_window_size::proc(window_hd:Window_Handle)-> (win_size:[2]i32) {
	win:=get_window(window_hd)
	// ok:=sdl.GetWindowSize(win.data,&win_size.x,&win_size.y)
	ok:=sdl.GetWindowSizeInPixels(win.data,&win_size.x,&win_size.y)
	return win_size
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
	zoom:f32,
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
		zoom = 1,
		depth_texture_createinfo = depth_texture_createinfo,
	}
	return
}
delete_camera::proc(cam:^Camera){
	if cam.depth_texture != nil{
		sdl.ReleaseGPUTexture(s.gpu_device,cam.depth_texture)
	}
}
screane_space_to_world_2d::proc(cam:^Camera,pos:[2]f32)->(world:[2]f32){
	pos_world :[2]f32= {pos.x,pos.y} * cam.zoom
	world = cam.pos.xy + pos_world
	return 
}
// this is a very rudimenty controler and should only be used for testing
update_camera_3d::proc(cam:^Camera, dt:f32, sensitivity:f32=3, speed:f32=1.5,){
	// move_input:Vec2
	// if s.input.key_down[.W] do move_input.y = 1
	// else if s.input.key_down[.S] do move_input.y = -1
	// if s.input.key_down[.A] do move_input.x = -1
	// else if s.input.key_down[.D] do move_input.x = 1
	
	// look_input := s.input.mouse_move * sensitivity * dt
	
	// cam.look.yaw = math.wrap(cam.look.yaw - look_input.x, 360)
	// cam.look.pitch = math.clamp(cam.look.pitch - look_input.y, -89, 89)

	// look_mat := lin.matrix3_from_yaw_pitch_roll_f32(lin.to_radians(cam.look.yaw), lin.to_radians(cam.look.pitch), 0)

	// forward := look_mat * Vec3 {0,0,-1}
	// right := look_mat * Vec3 {1,0,0}
	// move_dir := forward * move_input.y + right * move_input.x
	// // move_dir.y = 0

	// motion := lin.normalize0(move_dir) * speed * dt

	// cam.pos += motion
	// cam.target = cam.pos + forward
}


// this is a very rudimenty controler and should only be used for testing
update_camera_2d_wasd::proc(cam:^Camera, dt:f32, speed:f32=1.5,){
	// move_input:Vec3
	// if s.input.key_down[.W] do move_input.y = -1
	// else if s.input.key_down[.S] do move_input.y = 1
	// if s.input.key_down[.A] do move_input.x = 1
	// else if s.input.key_down[.D] do move_input.x = -1
	// look_mat := lin.matrix3_from_yaw_pitch_roll_f32(lin.to_radians(cam.look.yaw), lin.to_radians(cam.look.pitch), 0)
	// motion := move_input * speed * dt
	// cam.pos += motion
}

update_camera_zoom::proc(cam:^Camera, speed:f32=1, min_zoom:f32= .1,max_zoom:f32=5){
	// cam.zoom += cast(f32)(s.input.mouse_wheel.integer_y)*.100 * speed
	// if cam.zoom < min_zoom {
	// 	cam.zoom = min_zoom
	// }
	// if cam.zoom > max_zoom{
	// 	cam.zoom = max_zoom
	// }
}

update_camera_2d_pan::proc(cam:^Camera, dt:f32=1, speed:f32=1,){
	// move_input:Vec3
	// if s.input.mouse_button_down[.RIGHT]{
	// 	move_input.x = s.input.mouse_move.x
	// 	move_input.y = s.input.mouse_move.y * -1
	// 	look_mat := lin.matrix3_from_yaw_pitch_roll_f32(lin.to_radians(cam.look.yaw), lin.to_radians(cam.look.pitch), 0)
	// 	motion := move_input * (speed*cam.zoom) * dt
	// 	cam.pos += motion
	// }
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
			// fmt.print(texture.wh.x," ",texture.wh.y,"    ")
			// texture.data = win.swap_chain
			// sdl.GetWindowSize(win.data,&texture.wh.x,&texture.wh.y)
			// sdl.GetWindowSizeInPixels(win.data,&texture.wh.x,&texture.wh.y)
			// fmt.print(texture.wh.x," ",texture.wh.y,"\n")
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
	delete_player_groop(&s.steam.friends)
	free(s)
}
delete_r_pass::proc(pass:^R_Pass){
	delete(pass.texture_sampler_binding)
}



Time_Info::struct{
	start_time:time.Time, // time when game was started
	
	prev_frame_time:time.Time,
	frame_time:f64,//time in seconds sence last frame

	prev_tick_time:time.Time,
	tick_time:f64, //seconds sence last tick

	time:f64, //seconds from game start

	fps:   f64,
	tps:   f64,
	smooth_fps:f64,
	smooth_tps:f64,

	is_120_hz:bool,
	ti_120_hz:f64,
	dt_120_hz:f64,

	is_90_hz:bool,
	ti_90_hz:f64,
	dt_90_hz:f64,

	is_80_hz:bool,
	ti_80_hz:f64,
	dt_80_hz:f64,

	is_60_hz:bool,
	ti_60_hz:f64,
	dt_60_hz:f64,

	is_30_hz:bool,
	ti_30_hz:f64,
	dt_30_hz:f64,

	is_20_hz:bool,
	ti_20_hz:f64,
	dt_20_hz:f64,

	is_15_hz:bool,
	ti_15_hz:f64,
	dt_15_hz:f64,

	is_10_hz:bool,
	ti_10_hz:f64,
	dt_10_hz:f64,

	temp:int,
}

update_time_fps_info::proc(){	
	now := time.now()
	s.time.temp+=1
	if s.time.prev_frame_time != {} {
		since := time.diff(s.time.prev_frame_time, now)
		s.time.frame_time = time.duration_seconds(since)
	}else{
		s.time.frame_time = 100
	}
	s.time.prev_frame_time = now
	if s.time.start_time == {} {
		s.time.start_time = time.now()
	}
	s.time.time = time.duration_seconds(time.since(s.time.start_time))
	s.time.fps = 1/s.time.frame_time
	s.time.smooth_fps=math.lerp(s.time.smooth_fps,s.time.fps, 0.05)
}
update_time_info::proc(){



	now := time.now()
	if s.time.prev_tick_time != {} {
		since := time.diff(s.time.prev_tick_time, now)
		s.time.tick_time = time.duration_seconds(since)
	}else{
		s.time.tick_time = 100
	}
	s.time.prev_tick_time = now
	if s.time.start_time == {} {
		s.time.start_time = time.now()
	}
	s.time.tps = 1/s.time.tick_time
	s.time.time = time.duration_seconds(time.since(s.time.start_time))

	s.time.smooth_tps=math.lerp(s.time.smooth_tps,s.time.tps, 0.01)
	s.time.is_120_hz = false
	s.time.ti_120_hz += s.time.tick_time
	if 1/s.time.ti_120_hz <=120{
		s.time.is_120_hz = true
		s.time.ti_120_hz = 0
	}

	s.time.is_90_hz = false
	s.time.ti_90_hz += s.time.tick_time
	if 1/s.time.ti_90_hz <=90{
		s.time.is_90_hz = true
		s.time.ti_90_hz = 0
	}

	s.time.is_80_hz = false
	s.time.ti_80_hz += s.time.tick_time
	if 1/s.time.ti_80_hz <=80{
		s.time.is_80_hz = true
		s.time.ti_80_hz = 0
	}

	s.time.is_60_hz = false
	s.time.ti_60_hz += s.time.tick_time
	if 1/s.time.ti_60_hz <=60{
		s.time.is_60_hz = true
		s.time.dt_60_hz = s.time.ti_60_hz
		s.time.ti_60_hz = 0
	}

	s.time.is_30_hz = false
	s.time.ti_30_hz += s.time.tick_time
	if 1/s.time.ti_30_hz <=30{
		s.time.is_30_hz = true
		s.time.ti_30_hz = 0
	}

	s.time.is_20_hz = false
	s.time.ti_20_hz += s.time.tick_time
	if 1/s.time.ti_20_hz <=20{
		s.time.is_20_hz = true
		s.time.ti_20_hz = 0
	}

	s.time.is_15_hz = false
	s.time.ti_15_hz += s.time.tick_time
	if 1/s.time.ti_15_hz <=15{
		s.time.is_15_hz = true
		s.time.ti_15_hz = 0
	}

	s.time.is_10_hz = false
	s.time.ti_10_hz += s.time.tick_time
	if 1/s.time.ti_10_hz <=10{
		s.time.is_10_hz = true
		s.time.ti_10_hz = 0
	}
}
