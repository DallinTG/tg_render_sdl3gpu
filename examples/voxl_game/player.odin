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
