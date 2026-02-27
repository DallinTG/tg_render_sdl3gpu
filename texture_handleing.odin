package tg_render

import "core:bytes"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import str"core:strings"
import "core:fmt"
import lin"core:math/linalg"
import "core:hash"

import "core:image"
import "core:image/jpeg"
import "core:image/bmp"
import "core:image/png"
import "core:image/tga"

import stb"vendor:stb/image"

import hm "handle_map_static_virtual"


Texture_GPU_Handle :: distinct Handle


Texture_Groop :: hm.Handle_Map(Texture_GPU_Data, Texture_GPU_Handle, 1024*10)
Texture_Arr_Groop::enum{
	tex_8x8,
	tex_16x16,
	tex_32x32,
	tex_64x64,
	tex_128x128,
	tex_256x256,
	tex_512x512,
	tex_1024x1024,
	tex_2048x2048,
	tex_4096x4096,
}
TEXTURE_ARR_INFO:[Texture_Arr_Groop]Texture_Setup:{
	.tex_8x8 =       {w_h = {8, 8},       layer_count = 100},
	.tex_16x16 =     {w_h = {16, 16},     layer_count = 100},
	.tex_32x32 =     {w_h = {32, 32},     layer_count = 100},
	.tex_64x64 =     {w_h = {64, 64},     layer_count = 100},
	.tex_128x128 =   {w_h = {128, 128},   layer_count = 100},
	.tex_256x256 =   {w_h = {256, 256},   layer_count = 10},
	.tex_512x512 =   {w_h = {512, 512},   layer_count = 10},
	.tex_1024x1024 = {w_h = {1024, 1024}, layer_count = 10},
	.tex_2048x2048 = {w_h = {2048, 2048}, layer_count = 1},
	.tex_4096x4096 = {w_h = {4096, 4096}, layer_count = 1},
}
Texture_Arr_Data::struct{
	tex_hd:Texture_GPU_Handle,
	layers_used:u32,
}
Texture_Setup::struct{
	w_h:[2]u32,
	layer_count:u32,
}

Texture_ID_Types::union{
	string,
	[2]string,
	u32,
	[2]u32,
}

Texture :: struct {

	hd:     Texture_GPU_Handle,
	layer:  u32,
	groop_index:Texture_Arr_Groop,
	w_h:    [2]i32,
	offset: [2]i32,
	
}

Texture_GPU_Data::struct{
	handle: Texture_GPU_Handle,

	format: sdl.GPUTextureFormat,
	data:^sdl.GPUTexture,
	layer_count:u32,
	w:u32,
	h:u32,
}

Load_Texture_Option :: enum {
	// Will multiply the alpha value of the each pixel into the its RGB values. Useful if you want
	// to use `set_blend_mode(.Premultiplied_Alpha)`
	Premultiply_Alpha,
}
Load_Texture_Options :: bit_set[Load_Texture_Option]
TEXTURE_NONE :: Texture_GPU_Handle {}

init_texture_arr_groop::proc(){
	TEXTURE_ARR_INFO:=TEXTURE_ARR_INFO
	// fmt.print(s.texture_arr_map,"\n\n")
	// s.texture_arr_map = new(map[u32]Texture)
	for &tex, i in &s.texture_arr_groop{
		h:=TEXTURE_ARR_INFO[i].w_h.x
		w:=TEXTURE_ARR_INFO[i].w_h.x
		l_c:=TEXTURE_ARR_INFO[i].layer_count
		s.texture_arr_groop[i].tex_hd = create_gpu_texture(width = w,height = h , layer_count = l_c , type = .D2_ARRAY)
	}
	reg_bad_defalt_texture()
}

reg_texture_from_file::proc(filename: string,mod_name: string = ""){
	ARR_INFO:=TEXTURE_ARR_INFO
	tex_map:=&s.texture_arr_map
	tex_groop:=&s.texture_arr_groop
	img, img_err:=load_cpu_texture_file(filename)
	tex_id:=str.trim_suffix(filename,".png")
	tex_id=str.to_lower(tex_id,s.frame_allocator)
	id:[2]string={tex_id,mod_name}
	reg_texture_from_bits(img,id)
}
reg_texture_from_bits::proc(img: ^image.Image,tex_id:Texture_ID_Types){
	id:=get_texture_id(tex_id)
	ARR_INFO:=TEXTURE_ARR_INFO
	tex_map:=&s.texture_arr_map
	tex_groop:=&s.texture_arr_groop
	for &tex, i in tex_groop{
		if cast(u32)img.width <= ARR_INFO[i].w_h.x && cast(u32)img.height <= ARR_INFO[i].w_h.y{
			uplode_data_to_gpu_texture(tex.tex_hd,img.pixels.buf[:],img.width,img.height,layer = tex.layers_used)
			value:=Texture{
				hd = tex.tex_hd,
				layer = tex.layers_used,
				groop_index = i,
				w_h = {cast(i32)img.width,cast(i32)img.height},
				offset = {},
			}
			tex_map[id] = value
			tex.layers_used += 1
			return
		}
	}
}
reg_bad_defalt_texture::proc(){
	per:[4]u8:{255,0,255,255}
	pixles:[][4]u8={
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
	}
	img,ok:=image.pixels_to_image(pixles[:],8,8)
	reg_texture_from_bits(&img,[2]u32{0,0})
}

get_texture::proc(tex_id:Texture_ID_Types)->(tex:^Texture){
	tex = &s.texture_arr_map[get_texture_id(tex_id)]
	if tex == nil{
		tex = &s.texture_arr_map[{0,0}]
		assert(tex != nil,"get_texture() failed returned nil then fall back texture returned nil")
	}
	return
}
get_texture_id::proc(tex_id:Texture_ID_Types)->(new_tex_id:[2]u32){
	mod_id_u32:u32
	tex_id_u32:u32
	switch id in tex_id {
	case string:
		tex_id_u32 = hash.murmur32(transmute([]u8)id)
	case [2]string:
		tex_id_u32 = hash.murmur32(transmute([]u8)id.x)
		if id.y == ""{
			mod_id_u32 = 0
		}else{
			mod_id_u32 = hash.murmur32(transmute([]u8)id.y)
		}
	case u32:
		tex_id_u32 = id
	case [2]u32:
		tex_id_u32 = id.x
		mod_id_u32 = id.y
	}
	new_tex_id = {tex_id_u32,mod_id_u32}
	return
}


// Texture_ID::enum u32{
//     non     = 0,
//     pig     = #hash("pig","murmur32"),
//     cow     = #hash("cow","murmur32"),
//     player  = #hash("player","murmur32"),
// }
// reg_texture::proc(){

// }

load_texture_from_file :: proc(filename: string, options: Load_Texture_Options = {}) -> Texture_GPU_Handle {
		img, img_err :=load_cpu_texture_file(filename, options)
		if img_err != nil {
			log.errorf("Error loading texture '%v': %v", filename, img_err)
			return {0,0}
		}
		return load_texture_from_bytes_raw(img.pixels.buf[:], img.width, img.height, .R8G8B8A8_UNORM)
}

load_cpu_texture_file :: proc(filename: string, options: Load_Texture_Options = {}) -> (img:^image.Image, img_err:image.Error) {
	when FILESYSTEM_SUPPORTED {
		load_options := image.Options {
			.alpha_add_if_missing,
		}
		if .Premultiply_Alpha in options {
			load_options += { .alpha_premultiply }
		}
		img, img_err = image.load_from_file(filename, options = load_options, allocator = s.frame_allocator)
		if img_err != nil{
			true_file_path:=str.concatenate({TEXTUR_PATH, filename},s.frame_allocator)
			img, img_err = image.load_from_file(true_file_path, options = load_options, allocator = s.frame_allocator)
			if img_err != nil{log.error("cant find ",filename)}
		}
		if img_err != nil {
			log.errorf("Error loading texture '%v': %v", filename, img_err)
			return {}, img_err
		}

		return
	} else {
		log.errorf("load_texture_from_file failed: OS %v has no filesystem support! Tip: Use load_texture_from_bytes(#load(\"the_texture.png\")) instead.", ODIN_OS)
		return {}
	}
}

load_texture_from_bytes :: proc(bytes:union{[][]u8,[]u8}, options: Load_Texture_Options = {}, layer_count:u32 = 1, layer:u32 = 0) -> (texture:Texture_GPU_Handle) {
	load_options := image.Options {
		.alpha_add_if_missing,
	}
	if .Premultiply_Alpha in options {
		load_options += { .alpha_premultiply }
	}
	
	img:^image.Image 
	buf_buf:[dynamic][]u8
	defer delete(buf_buf)
	img_err:image.Error
	switch byte in bytes{
	case []u8:
		img, img_err = image.load_from_bytes(byte, options = load_options, allocator = s.frame_allocator)
	case [][]u8:
		for byt , i in byte{
			img, img_err = image.load_from_bytes(byt, options = load_options, allocator = s.frame_allocator)
			append_elems(&buf_buf,img.pixels.buf[:])
		}
	}
	

	if img_err != nil {
		log.errorf("Error loading texture: %v", img_err)
		return {}
	}
	switch byte in bytes{
	case []u8:
		texture = load_texture_from_bytes_raw(img.pixels.buf[:], img.width, img.height, .R8G8B8A8_UNORM, layer_count = layer_count)
	case [][]u8:
		texture = load_texture_from_bytes_raw(buf_buf[:], img.width, img.height, .R8G8B8A8_UNORM, layer_count = layer_count)
	}
	return
}

load_texture_array_from_file :: proc(filename:string, options: Load_Texture_Options = {}) -> (texture:Texture_GPU_Handle) {
	
	when FILESYSTEM_SUPPORTED {
		load_options := image.Options {
			.alpha_add_if_missing,
		}

		if .Premultiply_Alpha in options {
			load_options += { .alpha_premultiply }
		}
		
		img, img_err := image.load_from_file(filename, options = load_options, allocator = s.frame_allocator)
		if img_err != nil{
			true_file_path:=str.concatenate({TEXTUR_PATH, filename},s.frame_allocator)
			img, img_err = image.load_from_file(true_file_path, options = load_options, allocator = s.frame_allocator)
			if img_err != nil{log.error("cant find ",filename)}
		}
		if img_err != nil {
			log.errorf("Error loading texture '%v': %v", filename, img_err)
			return {}
		}

		texture = load_texture_from_bytes_raw(img.pixels.buf[:], img.width, img.height, .R8G8B8A8_UNORM)
	} else {
		log.errorf("load_texture_from_file failed: OS %v has no filesystem support! Tip: Use load_texture_from_bytes(#load(\"the_texture.png\")) instead.", ODIN_OS)
		texture = {}
	}

	return
}

load_texture_from_bytes_raw :: proc(
	bytes: union{[][]u8,[]u8}, 
	width: int, 
	height: int, 
	format: sdl.GPUTextureFormat  = .R8G8B8A8_UNORM, 
	type:sdl.GPUTextureType = .D2,
	layer_count: u32 = 1,
) -> (texture:Texture_GPU_Handle) {

	texture = create_gpu_texture(
		width = cast(u32)width,
		height = cast(u32)height,
		format = format,
		type = type,
		layer_count = layer_count,
	)
	if texture == TEXTURE_NONE {
		return {}
	}
	// texture_ptr := hm.get(s.textures, texture.handle)
	switch byte in bytes{
	case []u8:
		uplode_data_to_gpu_texture(texture,byte,width,height)
	case [][]u8:
		for byt in byte{
			uplode_data_to_gpu_texture(texture,byt,width,height)
		}
	}
	return
}
create_gpu_texture::proc(
	width: u32, 
	height: u32, 
	format: sdl.GPUTextureFormat  = .R8G8B8A8_UNORM, 
	type:sdl.GPUTextureType = .D2,
	layer_count: u32 = 1,
	texture_groop:^Texture_Groop = nil,
) -> (Texture_GPU_Handle){
	texture_groop:=texture_groop
	if texture_groop == nil{
		texture_groop = &s.texture_groop
	}

	tex := sdl.CreateGPUTexture(s.gpu_device,createinfo={
		type = type,
		format=format,
		usage = {.SAMPLER},
		width = width,
		height = height,
		layer_count_or_depth = layer_count,
		num_levels = 1,
	})
	texture_data:Texture_GPU_Data={
		w=width,
		h=height,
		layer_count = layer_count,
		format=format,
		data=tex,
	}
	backend_tex := hm.add(texture_groop, texture_data)
	
	return backend_tex
}
uplode_data_to_gpu_texture::proc(texture:Texture_GPU_Handle,	bytes: []u8, width: int, height: int, layer:u32 = 0){
	tex_ptr := get_gpu_texture(texture)
	assert(cast(u32)width<=tex_ptr.w && cast(u32)height<=tex_ptr.h,"texture data must be = or < texture ")
	
	pixels_byte_size := width * height * 4
	tex_transfer_buf := sdl.CreateGPUTransferBuffer(s.gpu_device,{
		usage = .UPLOAD,
		size = cast(u32)(pixels_byte_size),
	})

	tex_transfer_mem := sdl.MapGPUTransferBuffer(s.gpu_device, tex_transfer_buf, false)
	mem.copy(tex_transfer_mem, raw_data(bytes), pixels_byte_size)
	sdl.UnmapGPUTransferBuffer(s.gpu_device, tex_transfer_buf)
	
	copy_cmd_buf := sdl.AcquireGPUCommandBuffer(s.gpu_device)
	copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)

	sdl.UploadToGPUTexture(copy_pass, 
		{transfer_buffer = tex_transfer_buf},
		{texture = tex_ptr.data,layer = layer, w = cast(u32)width,h = cast(u32)height, d = 1},
		false,
	)
	sdl.EndGPUCopyPass(copy_pass)
	ok := sdl.SubmitGPUCommandBuffer(copy_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")
	sdl.ReleaseGPUTransferBuffer(s.gpu_device, tex_transfer_buf)
}

destroy_texture :: proc(th: Texture_GPU_Handle, texture_groop:^Texture_Groop = nil) {
	texture_groop:=texture_groop
	if texture_groop == nil{
		texture_groop = &s.texture_groop
	}
	tex := hm.get(texture_groop^, th)

	if tex == nil {
		return
	}
	// Free the GPU resource
    sdl.ReleaseGPUTexture(s.gpu_device, tex.data)
    
	hm.remove(texture_groop, th)
}

get_gpu_texture::proc(tex_h:Texture_GPU_Handle,texture_groop:^Texture_Groop = nil,)->(data:^Texture_GPU_Data){
	texture_groop:=texture_groop
	if texture_groop == nil{
		texture_groop = &s.texture_groop
	}
	return hm.get(s.texture_groop,tex_h)
}






FILESYSTEM_SUPPORTED :: ODIN_OS != .JS && ODIN_OS != .Freestanding
