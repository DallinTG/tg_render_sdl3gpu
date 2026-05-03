package sand_sim

import tg"../../../tg_render_sdl3"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import hm "../../handle_map_static_virtual"
import an"ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"

Entity_Handle :: distinct Handle

Entity_Types::enum{
	player,
	mob,
}

Entitys::struct{
	pos:[3]f32,
	types:Entity_Types,
}
