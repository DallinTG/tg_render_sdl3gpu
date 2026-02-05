package tg_render

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


Texture_Handle :: distinct Handle
Texture :: struct {
	// The render-backend specific texture identifier.
	handle: Texture_Handle,

	// The horizontal size of the texture, measured in pixels.
	w: int,

	// The vertical size of the texture, measure in pixels.
	h: int,
}
Texture_Data::struct{
	handle: Texture_Handle,

	format: sdl.GPUTextureFormat,
	data:^sdl.GPUTexture,
	w:u32,
	h:u32,
}

Load_Texture_Option :: enum {
	// Will multiply the alpha value of the each pixel into the its RGB values. Useful if you want
	// to use `set_blend_mode(.Premultiplied_Alpha)`
	Premultiply_Alpha,
}
Load_Texture_Options :: bit_set[Load_Texture_Option]

TEXTURE_NONE :: Texture_Handle {}

// Load a texture from disk and upload it to the GPU so you can draw it to the screen.
// Supports PNG, BMP, TGA and baseline PNG. Note that progressive PNG files are not supported!
//
// The `options` parameter can be used to specify things things such as premultiplication of alpha.
load_texture_from_file :: proc(filename: string, options: Load_Texture_Options = {}) -> Texture {
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
load_texture_from_bytes :: proc(bytes: []u8, options: Load_Texture_Options = {}) -> Texture {
	load_options := image.Options {
		.alpha_add_if_missing,
	}

	if .Premultiply_Alpha in options {
		load_options += { .alpha_premultiply }
	}
	
	img, img_err := image.load_from_bytes(bytes, options = load_options, allocator = s.frame_allocator)

	if img_err != nil {
		log.errorf("Error loading texture: %v", img_err)
		return {}
	}

	return load_texture_from_bytes_raw(img.pixels.buf[:], img.width, img.height, .R8G8B8A8_UNORM)
}

// Load raw texture data. You need to specify the data, size and format of the texture yourself.
// This assumes that there is no header in the data. If your data has a header (you read the data
// from a file on disk), then please use `load_texture_from_bytes` instead.
load_texture_from_bytes_raw :: proc(bytes: []u8, width: int, height: int, format: sdl.GPUTextureFormat  = .R8G8B8A8_UNORM) -> (Texture) {
	tex := sdl.CreateGPUTexture(s.gpu_device,createinfo={
		format=format,
		usage = {.SAMPLER},
		width = cast(u32)width,
		height = cast(u32)height,
		layer_count_or_depth = 1,
		num_levels = 1,
	})

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
		{texture = tex, w = cast(u32)width,h = cast(u32)height, d = 1},
		false,
	)
	
	sdl.EndGPUCopyPass(copy_pass)
	ok := sdl.SubmitGPUCommandBuffer(copy_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")
	
	texture_data:Texture_Data={
		w=cast(u32)width,
		h=cast(u32)height,
		format=format,
		data=tex,
	}
	
	backend_tex := hm.add(&s.textures, texture_data)
	sdl.ReleaseGPUTransferBuffer(s.gpu_device, tex_transfer_buf)

	if backend_tex == TEXTURE_NONE {
		return {}
	}

	return {
		handle = backend_tex,
		w = width,
		h = height,
	}

}

destroy_texture :: proc(th: Texture_Handle) {
	tex := hm.get(s.textures, th)

	if tex == nil {
		return
	}
	// Free the GPU resource
    sdl.ReleaseGPUTexture(s.gpu_device, tex.data)
    
	hm.remove(&s.textures, th)
}

get_texture_data::proc(tex_h:Texture_Handle)->(data:^sdl.GPUTexture){
	return hm.get(s.textures,tex_h).data
}






FILESYSTEM_SUPPORTED :: ODIN_OS != .JS && ODIN_OS != .Freestanding
