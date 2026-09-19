package voxl_game


import "core:time"
import tg"../../../tg_render_sdl3gpu"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import "core:thread"
// import hm "../../handle_map_static_virtual"
import hm "core:container/handle_map"
import an"../../ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"
import st"core:strings"
import steam "../../steamworks"
import reg "../../registry"


CHUNCK_SIZE::32

Voxel::struct{
	item_hd:Item_HD,
}
Map::struct{
	chunks:map[[3]int]Chunck,
}
Chunck_Data::[CHUNCK_SIZE][CHUNCK_SIZE][CHUNCK_SIZE]Voxel
Chunck::struct{
	data:Chunck_Data,
	mesh_hd:tg.Mesh_Handle,

	draw_cmd:[Model_Indices]sdl.GPUIndirectDrawCommand
}


Model_Indices::enum{
	pos_x,
	neg_x,
	pos_y,
	neg_y,
	pos_z,
	neg_z,
	extra,
}

Model_Data :: struct {
	cube_indices:[Model_Indices]int,
	extra_count:int,
}
