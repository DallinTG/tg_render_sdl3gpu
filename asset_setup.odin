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

import hm "handle_map_static_virtual"
import "core:encoding/cbor"


reg_defalt_assets::proc(){
	reg_defalt_textures()
}
reg_defalt_textures::proc(){
	reg_bad_defalt_texture()
	reg_white_defalt_texture()
	reg_all_texture_from_loaded_directory(Icons_Dir,"icons")
	reg_all_texture_from_loaded_directory(Textures_Dir,"textures")
}
