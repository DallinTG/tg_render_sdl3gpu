package tg_render

import "base:runtime"
import "core:bytes"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:os"
import str"core:strings"
import "core:fmt"
import lin"core:math/linalg"
import "core:hash"
import an"ansi"
import "core:image"
import "core:image/jpeg"
import "core:image/bmp"
import "core:image/png"
import "core:image/tga"

import stb"vendor:stb/image"

// import hm "handle_map_static_virtual"
import hm "core:container/handle_map"
import "core:encoding/cbor"


reg_defalt_assets::proc(){
	reg_defalt_textures()
	gen_mipmaps()
}
reg_defalt_textures::proc(){
	reg_bad_defalt_texture()
	reg_white_defalt_texture()
	reg_all_texture_from_loaded_directory_enum(Icons_Dir,&Icons_Data)
	reg_all_texture_from_loaded_directory_enum(Textures_Dir,&Textures_Data)
}
gen_mipmaps::proc(){
	copy_cmd_buf := sdl.AcquireGPUCommandBuffer(s.gpu_device)
	for &tex_arr, i in &s.texture_arr_groop {
		if tex_arr != {} {
			tex := get_gpu_texture(tex_arr.tex_hd)
			sdl.GenerateMipmapsForGPUTexture(
				copy_cmd_buf,
				tex.data,
			)
		}
	}
	ok := sdl.SubmitGPUCommandBuffer(copy_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")
}

gen_mipmap::proc(groop:Texture_Arr_Groop){
	cmd_buf := sdl.AcquireGPUCommandBuffer(s.gpu_device)

	tex_arr:= &s.texture_arr_groop[groop] 
	if tex_arr != {} {
		tex := get_gpu_texture(tex_arr.tex_hd)
		sdl.GenerateMipmapsForGPUTexture(
			cmd_buf,
			tex.data,
		)
	}
	
	ok := sdl.SubmitGPUCommandBuffer(cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")
}
