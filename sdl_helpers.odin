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
// import hm "handle_map_static_virtual"
import hm "core:container/handle_map"
import "core:os"

import sc"shader_cross"

import "core:image"
import "core:image/jpeg"
import "core:image/bmp"
import "core:image/png"
import "core:image/tga"


Mouse_Mode::enum{
	non,
	relitive,
}
set_mouse_mode::proc(win_hd:Window_Handle,mode:Mouse_Mode){
	win:=get_window(win_hd)
	MouseMode:=sdl.SetWindowRelativeMouseMode(win.data, true)
}
toggle_mouse_mode::proc(win_hd:Window_Handle){
	win:=get_window(win_hd)
	MouseMode:=sdl.SetWindowRelativeMouseMode(win.data, !sdl.GetWindowRelativeMouseMode(win.data))
}
toggle_mouse_mode_on_input_event::proc(win_hd:Window_Handle,input_e_id:input_e_id){
	if is_input_event(input_e_id,){
		toggle_mouse_mode(win_hd)
	}
}
