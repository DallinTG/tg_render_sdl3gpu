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
import "base:intrinsics"

import sc"shader_cross"

import "core:image"
import "core:image/jpeg"
import "core:image/bmp"
import "core:image/png"
import "core:image/tga"
import byt"core:bytes"
import "core:io"


Generic_Buffer::struct{
	buffer:byt.Buffer,
	type:Buffer_Types,
}

Buffer_Types::enum{
	dynamic_buff,
	static_buff,
}

init_buffer::proc(buff:^Generic_Buffer,len:int,size:int,type:Buffer_Types = .dynamic_buff){
	buff.type = type
	byt.buffer_init_allocator(&buff.buffer,len,size)
}

clear_buffer::proc(buff:^Generic_Buffer){
	byt.buffer_reset(&buff.buffer)
}

delete_buffer::proc(buff:^Generic_Buffer){
	byt.buffer_destroy(&buff.buffer)
}

buffer_write_slice::proc(buff:^Generic_Buffer, slice: $S/[]$T, loc := #caller_location)->(n: int, err: io.Error){
	old_cap := cap(buff.buffer.buf)
	n, err = byt.buffer_write_slice(&buff.buffer, slice ,loc)
	if buff.type == .static_buff{
		cap := cap(buff.buffer.buf)
		assert(cap != old_cap, fmt.tprint("atemt to grow static_buff",loc))
	}
	return n, err
}
