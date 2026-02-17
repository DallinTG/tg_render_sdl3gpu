package tg_render

import "core:bytes"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import str"core:strings"
import "core:fmt"
import lin"core:math/linalg"

import "core:image"
import "core:image/jpeg"
import "core:image/bmp"
import "core:image/png"
import "core:image/tga"

import stb"vendor:stb/image"

import hm "handle_map_static_virtual"


Texture_GPU_Handle :: distinct Handle


Texture_Groop::struct{
	textures:[10]Texture_GPU_Data,
	layer_count:[10]u32,
	textures_cpu:[dynamic]^image.Image,
}


Texture :: struct {

	hd:     Texture_GPU_Handle,
	layer:  u32,
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

// update_texture_groop::proc(groop:^Texture_Groop){
// 	for tex in groop.textures_cpu{
	 
// 	}

// }
// load_image_into_texture_groop::proc(groop:^Texture_Groop,filename: string, options: Load_Texture_Options = {})->(ok:bool){

// 	when FILESYSTEM_SUPPORTED {
// 		load_options := image.Options {
// 			.alpha_add_if_missing,
// 		}

// 		if .Premultiply_Alpha in options {
// 			load_options += { .alpha_premultiply }
// 		}
// 		// im:[2]i32
// 		// img:=stb.load(frame_cstring(filename),&im.x,&im.y,nil,4,)
// 		img, img_err := image.load_from_file(filename, options = load_options, allocator = s.frame_allocator)
// 		if img_err != nil{
// 			true_file_path:=str.concatenate({TEXTUR_PATH, filename},s.frame_allocator)
// 			img, img_err = image.load_from_file(true_file_path, options = load_options, allocator = s.frame_allocator)
// 			if img_err != nil{log.error("cant find ",filename)}
// 		}
// 		if img_err != nil {
// 			log.errorf("Error loading texture '%v': %v", filename, img_err)
// 			return false
// 		}
// 		append(&groop.textures_cpu,img)
// 		return true
// 	} else {
// 		log.errorf("load_texture_from_file failed: OS %v has no filesystem support! Tip: Use load_texture_from_bytes(#load(\"the_texture.png\")) instead.", ODIN_OS)
// 		return false
// 	}

// }
load_texture_from_file :: proc(filename: string, options: Load_Texture_Options = {}) -> Texture_GPU_Handle {
	when FILESYSTEM_SUPPORTED {
		load_options := image.Options {
			.alpha_add_if_missing,
		}

		if .Premultiply_Alpha in options {
			load_options += { .alpha_premultiply }
		}
		// im:[2]i32
		// img:=stb.load(frame_cstring(filename),&im.x,&im.y,nil,4,)
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

		return load_texture_from_bytes_raw(img.pixels.buf[:], img.width, img.height, .R8G8B8A8_UNORM)
	} else {
		log.errorf("load_texture_from_file failed: OS %v has no filesystem support! Tip: Use load_texture_from_bytes(#load(\"the_texture.png\")) instead.", ODIN_OS)
		return {}
	}
}


// Load a texture from a byte slice and upload it to the GPU so you can draw it to the screen.
// Supports PNG, BMP, TGA and baseline PNG. Note that progressive PNG files are not supported!
//
// The `options` parameter can be used to specify things things such as premultiplication of alpha.
load_texture_from_bytes :: proc(bytes:union{[][]u8,[]u8}, options: Load_Texture_Options = {}, layer_count:u32 = 1, layer:u32 = 0) -> (texture:Texture_GPU_Handle) {
	load_options := image.Options {
		.alpha_add_if_missing,
	}

	if .Premultiply_Alpha in options {
		load_options += { .alpha_premultiply }
	}
	
	// img, img_err := image.load_from_bytes(bytes, options = load_options, allocator = s.frame_allocator)
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
		width = width,
		height = height,
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
	width: int, 
	height: int, 
	format: sdl.GPUTextureFormat  = .R8G8B8A8_UNORM, 
	type:sdl.GPUTextureType = .D2,
	layer_count: u32 = 1,
) -> (Texture_GPU_Handle){

	tex := sdl.CreateGPUTexture(s.gpu_device,createinfo={
		type = type,
		format=format,
		usage = {.SAMPLER},
		width = cast(u32)width,
		height = cast(u32)height,
		layer_count_or_depth = layer_count,
		num_levels = 1,
	})
	texture_data:Texture_GPU_Data={
		w=cast(u32)width,
		h=cast(u32)height,
		layer_count = layer_count,
		format=format,
		data=tex,
	}
	backend_tex := hm.add(&s.textures_gpu, texture_data)
	
	return backend_tex
}
uplode_data_to_gpu_texture::proc(texture:Texture_GPU_Handle,	bytes: []u8, width: int, height: int, layer:u32 = 0){
	tex_ptr := get_gpu_texture(texture)
	assert(cast(u32)width<=tex_ptr.w && cast(u32)height<=tex_ptr.h,fmt.aprintf("texture data must be = or < texture [width = %i, height = %i]",width, height))
	
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

destroy_texture :: proc(th: Texture_GPU_Handle) {
	tex := hm.get(s.textures_gpu, th)

	if tex == nil {
		return
	}
	// Free the GPU resource
    sdl.ReleaseGPUTexture(s.gpu_device, tex.data)
    
	hm.remove(&s.textures_gpu, th)
}


get_gpu_texture::proc(tex_h:Texture_GPU_Handle)->(data:^Texture_GPU_Data){
	return hm.get(s.textures_gpu,tex_h)
}






FILESYSTEM_SUPPORTED :: ODIN_OS != .JS && ODIN_OS != .Freestanding
