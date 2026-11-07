package voxl_game

import "core:testing"
import "base:runtime"

import "core:os"
import "core:time"
import tg"../../../tg_render_sdl3gpu"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:math"
import "core:math/rand"
import "core:hash"
import "core:c"
import "core:fmt"
// import hm "../../handle_map_static_virtual"
import hm "core:container/handle_map"
import "core:container/xar"
import an"../../ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"
import st"core:strings"
import steam "../../steamworks"
import reg "../../registry"
import "core:thread"
import "core:container/pool"
import atom "core:sync"
import "core:sync/chan"
import nos "core:math/noise"
import "core:prof/spall"
import "core:math/bits"

World_State::struct{
	entity_hm:Entity_HM,
	player_HM:Player_HM,

}


Entity_HM::hm.Dynamic_Handle_Map(Entity,Entity_HD)
Entity_HD::hm.Handle16
Entity::struct{
	handle:Entity_HD,

	typ:Entity_Typ_HDs,
	pos:[3]f32,
}

Entity_Typ_HDs::union{
	Player_HD,
}


Stats::struct{
	mode:Player_Mode,
	hp:f32,
	mp:f32,
}

Player_Mode::enum{
	survival,
	creative,
	ghost,
}

Player_HM::hm.Dynamic_Handle_Map(Player,Player_HD)
Player_HD::hm.Handle16
Player::struct{
	handle:Player_HD,
	ent_hd:Entity_HD,

	stats:Stats,
}


do_player_client_stuff::proc(){
	tg.toggle_mouse_mode_on_input_event(g.window,.ESC)

	dynamic_vox_mesh:=tg.get_mesh(g.w_map.dynamic_map_mesh_hd)
	drawing_mesh:=tg.get_mesh(g.w_map.drawing_map_mesh_hd)


	ray_info,ok:=get_block_by_ray(&g.w_map,g.cam.pos,g.cam.look)
	if !ok {return}
	hylight_block_by_ray_cast(&g.w_map,ray_info)
	draw_ghost_block_by_ray_cast(&g.w_map,ray_info)
	
	if tg.is_input_event(.ui_l_c,never_consume_p = true){
		brake_block_by_ray(&g.w_map,ray_info)
	}
	if tg.is_input_event(.ui_r_c){
		set_block_by_ray(&g.w_map,ray_info)
	}


	tg.update_mesh(g.w_map.dynamic_map_mesh_hd)
	tg.clear_mesh_cpu(&dynamic_vox_mesh.cpu)

	tg.update_mesh(g.w_map.drawing_map_mesh_hd)
	tg.clear_mesh_cpu(&drawing_mesh.cpu)
}
