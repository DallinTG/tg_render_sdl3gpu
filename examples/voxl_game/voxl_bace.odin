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









CHUNK_VERTEX_TYPE::tg.Vert_Face






render_map_debug_overlay::proc(w_map:^Map){
	// tg.do_render_pass(&g.pass, &g.cam, {w_map.overlay_mesh},)
}

draw_cube_by_face_item::proc(
	mesh: ^tg.Mesh_CPU,
	pos:[3]u16,
	item_hd:Item_HD,
){
	faces:[6]tg.Vert_Face
	item:=reg.get(&g.item_reg,item_hd)

	packed_pos := pack_block_pos(pos)

	for &face in &faces{
		face.block_pos = packed_pos
		face.texture_face_index = cast(u32)item.texture_face_index
	}
	for &face,i in &faces{
		face.geometry_face_index = cast(u16)item.model_data.cube_indices[cast(Model_Sides)i]
	}
	
	tg.draw_feces(mesh,faces[:])
}
