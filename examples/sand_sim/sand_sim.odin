package sand_sim

import tg"../../../tg_render_sdl3gpu"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:slice"
import "core:c"
import "core:fmt"
import "core:math"
import "core:math/rand"

import hm "../../handle_map_static_virtual"
import an"../../ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"
import "base:intrinsics"

// MAP_SIZE:[2]int:{32,16}
// CHUNCK_SIZE::16
MAP_SIZE:[2]int:{16,8}
CHUNCK_SIZE::32
CELL_SIZE::10
FULL_MAP_SIZE:[2]int:{ MAP_SIZE.x * CHUNCK_SIZE *CELL_SIZE, (MAP_SIZE.y * CHUNCK_SIZE *CELL_SIZE)}
// MAP_SIZE:[2]int:{8,4}
// CHUNCK_SIZE::64 

MAX_CELL_CMDS::1000

Map::struct{
	tick_count:u32,
	rand_tick_seed:u32,
	tick_count_loc:u32,
	l_r:int,
	physics_cells:Physics_Cells,
	chuncks:[MAP_SIZE.x][MAP_SIZE.y]Chunck,
	list_of_add_cell_CMD:[MAX_CELL_CMDS]Add_Cell_CMD,
	cell_CMD_count:int,
	next_chunck_to_sink:[2]int,
	time_to_next_chunck_sink:i32,

	overlay_mesh:tg.Mesh_Handle,
	// info:Map_Info,
}
Chunck::struct{
	tick_count:u32,
	// l_r:int,
	mesh:tg.Mesh_Handle,
	cells:[CHUNCK_SIZE][CHUNCK_SIZE]Cell,
	cell_has_moved:[CHUNCK_SIZE][CHUNCK_SIZE]bool,
	has_changed:bool,
	changes_since_last_sync:u32,
	ticks_to_sleep:i32, // this is the number of ticks untill the chunk will sleep will wakeup if somthing changes in it

	dirty_rect_last:[4]int,
	dirty_rect_cur:[4]int,
}
Sink_Chunck_Data::struct{//this is the data that gets sent over udp to sink chunck data
	pos:[2]int,
	cells:[CHUNCK_SIZE][CHUNCK_SIZE]Cell,
}
   

Map_Info::struct{
	wh:[2]u32,
}

Sand_Sim_Cell_Vertex_Data :: struct #align(16) {
	pos:tg.Vec4,
	// _1:f32,
	col:tg.Vec4,
	// uv: [2]f32,
	// _2:[2]f32,
	// img_index:u32,
	// layer:u32,
	// col_over:[4]f32,
}

DEFALT_MAP_INFO::Map_Info{
	wh = {CHUNCK_SIZE,CHUNCK_SIZE},
}
Cell_Neighbors:[4][2]int:{
	{0,1},
	{0,-1},
	{1,0},
	{-1,0},
}


Cell_Temperature::enum i8{
	
	Deth_Cold = -6,
	Unbelievably_Cold = -5,
	Extremely_Cold = -4,
	Very_Cold = -3,
	Cold = -2,
	Cool = -1,
	Room = 0,
	Warm = 1,
	Hot = 2,
	Very_Hot = 3,
	Extremely_Hot = 4,
	Unbelievably_Hot = 5,
	Deth_Hot = 6,
}

Cell::struct{
	id:Cell_ids,
	temperature:Cell_Temperature,
	flags:bit_set[Cell_Flags],
	hp:u8,
}


Cell_ids::enum u16{
	air,
	sand,
	gravel,
	up_sand,
	water,
	ice,
	lava,
	stone,
	steam,
	out_of_bounds,
}
Cell_Flags::enum{
	has_grav,
	is_solid,
	is_gass,
}
Cell_Data::struct{
	color:[4]f32,
	flags:bit_set[Cell_Flags],
	starting_temperature:Cell_Temperature,
	slippage:int,
	density:f32,
	flow_rate:int,
	starting_hp:u8,
	hp_decay_rate:i32,
	hp_decay_chance:f32,

	// cold_transmute_at_temp:Cell_Temperature,
	// cold_transmute_into_id:Cell_ids,

	// hot_transmute_at_temp:Cell_Temperature,
	// hot_transmute_into_id:Cell_ids,

	on_contact:proc([2]int,),
}

Cell_Info:=[Cell_ids]Cell_Data{
	.air ={
		flags={
			// .is_solid,
		},
		color = {0,1,1,.1},
		density = 0,
	},
	.sand ={
		flags={
			.has_grav,
			.is_solid,

		},
		slippage = 2,
		color = {.9,.8,.2,1},
		density = 3,
		starting_hp = 5,
	},
	.gravel ={
		flags={
			.has_grav,
			.is_solid,

		},
		slippage = 1,
		color = {.23,.22,.27,1},
		density = 4,
		starting_hp = 5,
	},
	.up_sand ={
		flags={
			.has_grav,
			.is_solid,
		},
		slippage = 2,
		color = {.9,.8,.2,1},
		density = -3,
		starting_hp = 5,
	},
	.water ={
		flags={

			.has_grav,
		},
		slippage = 1,
		color = {.27,.49,.9,1},
		density = 1,
		flow_rate = 5,
		starting_hp = 10,
		// temperature = -90,
		// cold_transmute_temp = -100,
		// cold_transmute = .ice,
		// hot_transmute_temp = 101,
		// hot_transmute = .steam,
	},
	.ice ={
		flags={
			.is_solid,

		},
		// has_grav = false,
		// slippage = 4,
		color = {.349,.78,.851,1},
		density = .9,
		starting_hp = 5,
		// flow_rate = 4,
		// temperature = -1,
		// cold_transmute_temp = -100,
		// cold_transmute = .air,
		// hot_transmute_temp = 1,
		// hot_transmute = .water,
	},
	.lava ={
		flags={
			.has_grav,
		},
		slippage = 2,
		color = {.929,.337,.055,1},
		density = 3,
		flow_rate = 2,
		starting_hp = 10,
		// temperature = 1500,
		// cold_transmute_temp = -1,
		// cold_transmute = .stone,
		// hot_transmute_temp = 10000,
		// hot_transmute = .air,
	},
	.stone ={
		flags={
			.is_solid,
		},
		// has_grav = false,
		// slippage = 4,
		color = {.38,.365,.341,1},
		density = 4,
		starting_hp = 50,
		// flow_rate = 4,
		// temperature = 0,
		// cold_transmute_temp = -100,
		// cold_transmute = .air,
		// hot_transmute_temp = 100,
		// hot_transmute = .lava,
	},
	.steam = {
		flags={

			.is_gass,
		},
		// has_grav = false,
		slippage = 2,
		color = {.129,.237,.355,4},
		density = 1,
		flow_rate = 2,
		starting_hp = 5,
		hp_decay_rate = 1,
		hp_decay_chance = .1,
		// temperature = 200,
		// hot_transmute_temp = 10000,
		// cold_transmute_temp = -10,
		// cold_transmute = .water,
	},
	.out_of_bounds ={
		flags={
			.is_solid 
		},
		// has_grav = false,
		color = {0,0,0,1},
		density = 100,
	}
}
out_of_bounds_cell:Cell={
	id = .out_of_bounds,
}

CHUNCK_VERTEX_TYPE::Sand_Sim_Cell_Vertex_Data
init_chunck_mesh::proc(w_map:^Chunck, map_info:=DEFALT_MAP_INFO){
	mesh_cpu:tg.Mesh_CPU={attribute_type = CHUNCK_VERTEX_TYPE}
	mesh_attribute_info:=type_info_of(mesh_cpu.attribute_type)
	// resize(&mesh_cpu.vertex_buf,size_of(CHUNCK_VERTEX_TYPE) * CHUNCK_SIZE * CHUNCK_SIZE * 4) 
	tg.init_buffer(&mesh_cpu.vertex_buf,size_of(CHUNCK_VERTEX_TYPE) * CHUNCK_SIZE * CHUNCK_SIZE * 4,size_of(CHUNCK_VERTEX_TYPE) * CHUNCK_SIZE * CHUNCK_SIZE * 4,.static_buff)
	resize(&mesh_cpu.index_buf,CHUNCK_SIZE * CHUNCK_SIZE * 6) 
	w_map.mesh = tg.create_mesh(mesh_cpu,CHUNCK_SIZE * CHUNCK_SIZE * 4,CHUNCK_SIZE * CHUNCK_SIZE * 6,debug_name = "chunk")
}

get_cell_pos_by_pos::proc(pos:[2]f32)->([2]int){
	cell := tg.screane_space_to_world_2d(&g.cam,{pos.x,-pos.y}) / CELL_SIZE
	return {cast(int)cell.x,cast(int)-cell.y}
}


init_map::proc(new_map:^^Map,){
	delete_w_map(new_map^)
	new_map^ = new(Map)
	for &row in new_map^.chuncks{
		for &chunck in row{
			init_chunck_mesh(&chunck)
		}
	}
	overlay_mesh_cpu:tg.Mesh_CPU={attribute_type = tg.Vertex_Data}
	new_map^.overlay_mesh = tg.create_mesh(overlay_mesh_cpu,debug_name = "overlay_mesh")
	
}
// init_chunck::proc(new_chunck:^^Chunck,){
// 	delete_chunck(new_chunck^)
// 	new_chunck^ = new(Chunck)
// 	init_chunck_mesh(new_chunck^)
// }
delete_w_map::proc(w_map:^Map){
	if w_map == nil{return}
	for &row in w_map^.chuncks{
		for &chunck in row{
			tg.delete_mesh(chunck.mesh)
		}
	}
	tg.delete_mesh(w_map.overlay_mesh)
	free(w_map)
}
delete_chunck::proc(w_map:^Chunck){
	if w_map == nil{return}
	free(w_map)
}

mesh_map::proc(w_map:^Map){
	for &chuncks,x in &w_map.chuncks{
		for &chunck,y in &chuncks{
			if chunck.has_changed{
				mesh_chunck(&chunck,{x,y},w_map)
			}
		}
	}
	for &chuncks,x in &w_map.chuncks{
		for &chunck,y in &chuncks{
			chunck.has_changed = false
			chunck.cell_has_moved = {}
		}
	}
	tg.update_mesh(w_map.overlay_mesh)
	mesh:=tg.get_mesh(w_map.overlay_mesh)
	tg.clear_mesh_cpu(&mesh.cpu)
}

mesh_chunck::proc(chunck:^Chunck,pos:[2]int,w_map:^Map){
	mesh:=tg.get_mesh(chunck.mesh)
	// tg.clear_mesh_cpu(&mesh.cpu)//TODO Clears the mesh every frame this should only do that if somthing has changed
	draw_chunck(
		mesh = &mesh.cpu,
		tex_id = 1,
		vert_t = Sand_Sim_Cell_Vertex_Data,
		pos = {cast(f32)(pos.x*CELL_SIZE*CHUNCK_SIZE),cast(f32)(pos.y*CELL_SIZE*CHUNCK_SIZE*-1),0},
		// w_h = {CHUNCK_SIZE,CHUNCK_SIZE},
		chunck = chunck,
		scale = {CELL_SIZE,CELL_SIZE},
	)
	w_map_overlay_mesh:=tg.get_mesh(w_map.overlay_mesh)
	if chunck.dirty_rect_last != {CHUNCK_SIZE,CHUNCK_SIZE,0,0}{
		tg.draw_rect(
			mesh = &w_map_overlay_mesh.cpu, 
			tex_id = 1,
			vert_t = tg.Vertex_Data, 
			rect = {
				// {
				// 	cast(f32)(chunck.dirty_rect_last.x + pos.x*CHUNCK_SIZE) * (CELL_SIZE),
				// 	cast(f32)((chunck.dirty_rect_last.y*-1 + pos.y*-1*CHUNCK_SIZE) * (CELL_SIZE) + (CHUNCK_SIZE*CHUNCK_SIZE*CELL_SIZE*pos.y)),
				// 	0,
				// },
				// {
				// 	cast(f32)((chunck.dirty_rect_last.z + pos.x*CHUNCK_SIZE) * (CELL_SIZE)-(chunck.dirty_rect_last.x + pos.x*CHUNCK_SIZE) * (CELL_SIZE)),
				// 	cast(f32)((chunck.dirty_rect_last.w + pos.y*CHUNCK_SIZE) * (CELL_SIZE)-(chunck.dirty_rect_last.y + pos.y*CHUNCK_SIZE) * (CELL_SIZE)),
				// }
				{
					cast(f32)(chunck.dirty_rect_last.x) * (CELL_SIZE),
					cast(f32)(chunck.dirty_rect_last.y*-1) * (CELL_SIZE),
					0,
				},
				{
					cast(f32)((chunck.dirty_rect_last.z) * (CELL_SIZE)-(chunck.dirty_rect_last.x) * (CELL_SIZE)),
					cast(f32)((chunck.dirty_rect_last.w) * (CELL_SIZE)-(chunck.dirty_rect_last.y) * (CELL_SIZE)),
				},
			},
			origin = {
				cast(f32)(pos.x*CHUNCK_SIZE*CELL_SIZE),
				cast(f32)(pos.y*CHUNCK_SIZE*CELL_SIZE*-1),
				0,
			},
			col = {1,1,1,.25}
		)
	}
	// if chunck.ticks_to_sleep > 0 {
	// 	tg.draw_text(mesh = &mesh.cpu,vert_t = tg.Vertex_Data,pos = {cast(f32)(pos.x*CELL_SIZE*CHUNCK_SIZE),cast(f32)(pos.y*CELL_SIZE*CHUNCK_SIZE*-1),0},text =fmt.tprint(chunck.ticks_to_sleep))
	// }
	// tg.draw_text(mesh = &mesh.cpu,vert_t = tg.Vertex_Data,pos = {cast(f32)(pos.x*CELL_SIZE*CHUNCK_SIZE),cast(f32)(pos.y*CELL_SIZE*CHUNCK_SIZE*-1),0},text =fmt.tprint(chunck.ticks_to_sleep))
	tg.update_mesh(chunck.mesh)
}

render_map::proc(w_map:^Map){
	meshes:[MAP_SIZE.x*MAP_SIZE.y]tg.Mesh_Handle
	index:int
	for &chuncks in w_map.chuncks{
		for &chunck in chuncks{
			meshes[index] = chunck.mesh
			index+=1
		}
	}
	tg.do_render_pass(&g.sand_sim_pass, &g.cam, meshes[:],)
}

render_map_debug_overlay::proc(w_map:^Map){
	tg.do_render_pass(&g.pass, &g.cam, {w_map.overlay_mesh},)
}

rand_1_1:[2]int:{1,-1}
update_map::proc(w_map:^Map){
	// fmt.print(hash.ginger_hash16(cast(u16)w_map.tick_count),"\n")
	w_map.rand_tick_seed = cast(u32)hash.ginger_hash16(cast(u16)w_map.tick_count)
	if w_map.rand_tick_seed % 2 == 0{
		w_map.l_r = -1
	}else{
		w_map.l_r = 1
	}
	// rand.reset(cast(u64)w_map.rand_tick_seed)
	temp:=rand.int32_range(0,2)
	if temp == 0{
		w_map.l_r = -1
	}else{
		w_map.l_r = 1
	}
	// rand.reset(cast(u64)w_map.rand_tick_seed)
	// w_map.l_r=rand.choice(rand_1[:])



	proses_set_cell_cmd(&g.server, w_map)
	sink_next_chunck(&g.server, w_map)
	sink_w_map_info(&g.server, g.w_map)


	// for &chuncks,x in &w_map.chuncks{
	// 	for &chunck,y in &chuncks{
	// 		update_chunck(&chunck,x,y,w_map)
	// 	}
	// }
	
	
	for &chuncks,x in &w_map.chuncks{
		for &chunck,y in &chuncks{
			update_chunck(&chunck,x,y,w_map)
			chunck.dirty_rect_last = chunck.dirty_rect_cur
			chunck.dirty_rect_cur = {CHUNCK_SIZE,CHUNCK_SIZE,0,0}
		}
	}


	w_map.tick_count+=1
	w_map.tick_count_loc+=1


}
update_chunck::proc(chunck:^Chunck,c_x:int,c_y:int,w_map:^Map){
	// chunck.cell_has_moved = {}
	// rand_1:[2]int=rand_1_1
	// chunck.l_r=rand.choice(rand_1[:])

	if chunck.ticks_to_sleep <=0 {return}
	chunck.ticks_to_sleep -= 1

	dirt_rect:=chunck.dirty_rect_last + {-1,-1,1,1}
	dirt_rect.x = clamp(dirt_rect.x,0,CHUNCK_SIZE-1)
	dirt_rect.y = clamp(dirt_rect.y,0,CHUNCK_SIZE-1)
	dirt_rect.z = clamp(dirt_rect.z,0,CHUNCK_SIZE-1)
	dirt_rect.w = clamp(dirt_rect.w,0,CHUNCK_SIZE-1)
	
	temp:=rand.int32_range(0,2)
	if temp == 0{
		for x := dirt_rect.x; x <= dirt_rect.z; x += 1 {
			if w_map.tick_count % 2 == 0{
				for y := dirt_rect.y; y <= dirt_rect.w; y += 1 {
					cell:=get_cell({x+(c_x*CHUNCK_SIZE),y+(c_y*CHUNCK_SIZE)},w_map)
					update_cell(x+(c_x*CHUNCK_SIZE),y+(c_y*CHUNCK_SIZE),cell,w_map)
				}
			}else{
				for y := dirt_rect.w; y >= dirt_rect.y; y -= 1 {
					cell:=get_cell({x+(c_x*CHUNCK_SIZE),y+(c_y*CHUNCK_SIZE)},w_map)
					update_cell(x+(c_x*CHUNCK_SIZE),y+(c_y*CHUNCK_SIZE),cell,w_map)
				}
			}
		}
	}else{
		for x := dirt_rect.z; x >= dirt_rect.x; x -= 1 {
			if w_map.tick_count % 2 == 0{
				for y := dirt_rect.y; y <= dirt_rect.w; y += 1 {
					cell:=get_cell({x+(c_x*CHUNCK_SIZE),y+(c_y*CHUNCK_SIZE)},w_map)
					update_cell(x+(c_x*CHUNCK_SIZE),y+(c_y*CHUNCK_SIZE),cell,w_map)
				}
			}else{
				for y := dirt_rect.w; y >= dirt_rect.y; y -= 1 {
					cell:=get_cell({x+(c_x*CHUNCK_SIZE),y+(c_y*CHUNCK_SIZE)},w_map)
					update_cell(x+(c_x*CHUNCK_SIZE),y+(c_y*CHUNCK_SIZE),cell,w_map)
				}
			}
		}
	}

	
}
update_cell::proc(x,y:int,cell:^Cell,w_map:^Map){
	c:=&Cell_Info[cell.id]
	if cell.id == .air {return}
	if !is_cell_valid({x,y}, w_map){return}
	if !get_cell_moved({x,y}, w_map){
		do_cell_decay(cell, c, {x,y}, w_map)
		if cell.id == .air {return}
		// do_cell_temperature(c, {x,y}, w_map)
		do_cell_gass(cell, c, {x,y}, w_map)
		do_cell_grav(cell, c, {x,y}, w_map)

	do_cell_flow(cell, c, {x,y}, w_map)
	}
}

do_cell_grav::proc(cell:^Cell, c:^Cell_Data,pos:[2]int,w_map:^Map){
	if .has_grav not_in cell.flags {return}
	new_y:int
	if c.density> 0 {new_y = pos.y+1  }
	if c.density< 0 {new_y = pos.y-1 }
	if can_cell_fall_through(pos ,{pos.x,new_y},w_map){ // fall down
		swap_cell(pos, {pos.x,new_y},w_map)
	}else {
		for i in 1..=c.slippage{
			if can_cell_fall_through(pos, {pos.x+w_map.l_r*i,new_y},w_map){ //fall right
				swap_cell(pos, {pos.x+w_map.l_r*i,new_y},w_map)
				return
			}else if can_cell_fall_through(pos, {pos.x+w_map.l_r*-1*i,new_y},w_map){ //fall left
				swap_cell(pos, {pos.x+w_map.l_r*-1*i,new_y},w_map)
				return
			}
		}
	}
}

do_cell_decay::proc(cell:^Cell, c:^Cell_Data,pos:[2]int,w_map:^Map){
	cell_data:=get_cell_data(pos,w_map)
	rand_val:=rand.float32_range(0,1)
	if cell_data.hp_decay_chance > rand_val {
		cell.hp -= cast(u8)cell_data.hp_decay_rate
	}
	if cell.hp <=0 {
		destroy_cell(pos,w_map)
	}
}


do_cell_flow::proc(cell:^Cell, c:^Cell_Data,pos:[2]int,w_map:^Map){
	// if get_cell_moved(pos, w_map){return}
	// if can_cell_fall_through(pos,{pos.x, pos.y-1},w_map)||can_cell_fall_through(pos,{pos.x, pos.y-2},w_map){return}
	if c.flow_rate > 0{ // flowing
		// for i in 1..=c.flow_rate{
		// 	if can_cell_fall_through(pos,{pos.x+w_map.l_r*i, pos.y},w_map){ //flow right
		// 		swap_cell(pos,{pos.x+w_map.l_r*i,pos.y},w_map)
		// 		return
		// 	}else if can_cell_fall_through(pos,{pos.x+w_map.l_r*-1*i, pos.y},w_map){ //flow left
		// 		swap_cell(pos,{pos.x+w_map.l_r*-1*i, pos.y},w_map)
		// 		return
		// 	}

		// }
		
		

		if can_cell_fall_through(pos,{pos.x+w_map.l_r, pos.y},w_map){ //flow right
			// swap_cell(pos,{pos.x+w_map.l_r,pos.y},w_map)
			shift_cells_in_row(cell,pos,w_map,c.flow_rate,1*w_map.l_r)
			return
		// }
		}else if can_cell_fall_through(pos,{pos.x+w_map.l_r*-1, pos.y},w_map){ //flow left
			// swap_cell(pos,{pos.x+w_map.l_r*-1, pos.y},w_map)
			shift_cells_in_row(cell,pos,w_map,c.flow_rate,-1*w_map.l_r)
			return
		}
		
		
	}
}
shift_cells_in_row::proc(cell:^Cell,pos:[2]int,w_map:^Map,shift_count:int,shift_dir:int){
	for i in 1..=shift_count{
	// i:=1
		cell_id:=cell.id
		if cell_id == get_cell({pos.x+(i-1)*shift_dir,pos.y},w_map).id{
		// if can_cell_fall_through(pos,{pos.x+i*shift_dir, pos.y},w_map){
			swap_cell({pos.x+(i-1)*shift_dir,pos.y},{pos.x+i*shift_dir,pos.y},w_map)
		}else{
			return
		}
	}
}

do_cell_gass::proc(cell:^Cell, c:^Cell_Data,pos:[2]int,w_map:^Map){
	if get_cell_moved(pos, w_map){return}
	if .is_gass not_in cell.flags{return}
	// rand_1:[2]int=rand_1_1
	l_r:int
	l_r_2:int
	if hash.ginger_hash16(cast(u16)(w_map.rand_tick_seed*(cast(u32)pos.x+w_map.rand_tick_seed))) % 2 == 0{
		l_r = 1
	}else{
		l_r = -1
	}

	if hash.ginger_hash16(cast(u16)(w_map.rand_tick_seed*(cast(u32)pos.y+w_map.rand_tick_seed))) % 2 == 0{
		l_r_2 = 1
	}else{
		l_r_2 = -1
	}
	if l_r >0{
		l_r=l_r_2
		if can_cell_fall_through(pos,{pos.x+l_r, pos.y},w_map){
			swap_cell(pos,{pos.x+l_r,pos.y},w_map)
			return
		}else if can_cell_fall_through(pos,{pos.x+l_r*-1, pos.y},w_map){ 
			swap_cell(pos,{pos.x+l_r*-1, pos.y},w_map)
			return
		}
	}else{
		l_r=l_r_2
		if can_cell_fall_through(pos,{pos.x, pos.y+l_r},w_map){
			swap_cell(pos,{pos.x, pos.y+l_r},w_map)
			return
		}else if can_cell_fall_through(pos,{pos.x, pos.y+l_r*-1},w_map){
			swap_cell(pos,{pos.x, pos.y+l_r*-1},w_map)
			return
		}
	}
}

// do_cell_temperature::proc(c:^Cell_Data,pos:[2]int,w_map:^Chunck){
// 	// if c.temperature == 0 {return}
// 	cell_can_hot_trans:bool
// 	for nab in Cell_Neighbors{
// 		cell_a_can,cell_b_can:=can_cell_hot_transmute(pos,pos+nab,w_map)
// 		if cell_a_can{ cell_can_hot_trans = true}
// 		if cell_b_can{ hot_transmute_cell(pos+nab, w_map)}
// 	}
// 	if cell_can_hot_trans{hot_transmute_cell(pos, w_map)}

// 	cell_can_cold_trans:bool
// 	for nab in Cell_Neighbors{
// 		cell_a_can,cell_b_can:=can_cell_cold_transmute(pos,pos+nab,w_map)
// 		if cell_a_can{ cell_can_cold_trans = true}
// 		if cell_b_can{ cold_transmute_cell(pos+nab, w_map)}
// 	}
// 	if cell_can_cold_trans{cold_transmute_cell(pos, w_map)}
// }

is_cell_valid::proc(cell:[2]int,w_map:^Map)->(is_valid:bool){
	if cell.x < 0{return false}
	if cell.y < 0{return false}
	if cell.x >= cast(int)CHUNCK_SIZE * MAP_SIZE.x {return false}
	if cell.y >= cast(int)CHUNCK_SIZE * MAP_SIZE.y {return false}
	return true
}
get_cell::proc(cell:[2]int,w_map:^Map)->(cell_data:^Cell){
	if !is_cell_valid(cell,w_map) {return &out_of_bounds_cell}
	cell_data=&get_chunck(cell, w_map).cells[cell.x%CHUNCK_SIZE][cell.y%CHUNCK_SIZE]
	return cell_data
}
set_cell_moved::proc(cell:[2]int,w_map:^Map, state:bool = true){
	if !is_cell_valid(cell,w_map) {return}
	chunck:=get_chunck(cell, w_map)
	chunck.has_changed =  state
	if state == true{
		chunck.changes_since_last_sync += 1
		chunck.ticks_to_sleep = 10
		// update_chuncks_dirty_rect(cell,w_map)
	}
	chunck.cell_has_moved[cell.x%CHUNCK_SIZE][cell.y%CHUNCK_SIZE] = state
}
destroy_cell::proc(cell:[2]int,w_map:^Map){
	cell_data:=get_cell(cell,w_map)
	cell_data^ = {}
	chunck:=get_chunck(cell, w_map)
	chunck.has_changed = true
	chunck.ticks_to_sleep = 10
	update_chuncks_dirty_rect(cell,w_map)
}
get_cell_moved::proc(cell:[2]int,w_map:^Map,)->(bool){
	if !is_cell_valid(cell,w_map) {return true}
	chunck:=get_chunck(cell, w_map)
	return chunck.cell_has_moved[cell.x%CHUNCK_SIZE][cell.y%CHUNCK_SIZE]
}
get_chunck::proc(cell:[2]int,w_map:^Map)->(chunck_data:^Chunck){
	chunck_data = &w_map.chuncks[cell.x/CHUNCK_SIZE][cell.y/CHUNCK_SIZE]
	return chunck_data
}
get_chunck_by_pos::proc(pos:[2]int,w_map:^Map)->(chunck_data:^Chunck){
	if pos.x < 0 || pos.x > MAP_SIZE.x-1{return nil}
	if pos.y < 0 || pos.y > MAP_SIZE.y-1{return nil}
	chunck_data = &w_map.chuncks[pos.x][pos.y]
	return chunck_data
}
get_chunck_change_count_by_cell::proc(cell:[2]int,w_map:^Map)->(change_count:u32){
	chunck:=get_chunck(cell,w_map)
	change_count=chunck.changes_since_last_sync
	return change_count
}
get_chunck_change_count::proc(pos:[2]int,w_map:^Map)->(change_count:u32){
	chunck:=get_chunck_by_pos(pos,w_map)
	change_count=chunck.changes_since_last_sync
	return change_count
}
update_chuncks_dirty_rect::proc(pos:[2]int,w_map:^Map){
	chunck:=get_chunck(pos,w_map)
	if pos.x%CHUNCK_SIZE < chunck.dirty_rect_cur.x+1{
		chunck.dirty_rect_cur.x = pos.x%CHUNCK_SIZE-1
	}
	if pos.y%CHUNCK_SIZE < chunck.dirty_rect_cur.y+1{
		chunck.dirty_rect_cur.y = pos.y%CHUNCK_SIZE-1
	}
	if pos.x%CHUNCK_SIZE > chunck.dirty_rect_cur.z-2{
		chunck.dirty_rect_cur.z = pos.x%CHUNCK_SIZE+2
	}
	if pos.y%CHUNCK_SIZE > chunck.dirty_rect_cur.w-2{
		chunck.dirty_rect_cur.w = pos.y%CHUNCK_SIZE+2
	}

}

get_cell_data::proc(cell:[2]int,w_map:^Map)->(cell_data:^Cell_Data){
	if !is_cell_valid(cell,w_map) {return &Cell_Info[.air]}
	cell_d:=get_cell(cell,w_map)
	cell_data=&Cell_Info[cell_d.id]
	return cell_data
}

can_cell_fall_through::proc(cell_a:[2]int, cell_b:[2]int, w_map:^Map) ->(can_cell_fall_through:bool){
	cell_a_data:=get_cell_data(cell_a,w_map)
	cell_b_data:=get_cell_data(cell_b,w_map)
	cell_b:=get_cell(cell_b,w_map)
	// fmt.print(cell_b.flags,"waffles 90 \n")
	if .is_solid in cell_b.flags {return false}
	if math.abs(cell_a_data.density) > cell_b_data.density {return true}
	return false
}
can_cell_hot_transmute::proc(cell_a:[2]int, cell_b:[2]int, w_map:^Map) ->(can_cell_a_hot_transmute:bool,can_cell_b_hot_transmute:bool,){
	cell_b_data:=get_cell_data(cell_b,w_map)
	// if cell_b_data.temperature == 0 {return false, false}
	cell_a_data:=get_cell_data(cell_a,w_map)
	// if cell_b_data.hot_transmute_temp < cell_a_data.temperature/2 {can_cell_b_hot_transmute = true}
	// if cell_a_data.hot_transmute_temp < cell_b_data.temperature/2 {can_cell_a_hot_transmute = true}
	return 
}
can_cell_cold_transmute::proc(cell_a:[2]int, cell_b:[2]int, w_map:^Map) ->(can_cell_a_cold_transmute:bool,can_cell_b_cold_transmute:bool,){
	cell_b_data:=get_cell_data(cell_b,w_map)
	// if cell_b_data.temperature == 0 {return false, false}
	cell_a_data:=get_cell_data(cell_a,w_map)
	// if cell_b_data.cold_transmute_temp > cell_a_data.temperature/2 {can_cell_b_cold_transmute = true}
	// if cell_a_data.cold_transmute_temp > cell_b_data.temperature/2 {can_cell_a_cold_transmute = true}
	return 
}
// hot_transmute_cell::proc(cell:[2]int, w_map:^Chunck){
// 	cell_d:=get_cell_data(cell, w_map)
// 	set_cell(cell,{cell_d.hot_transmute}, w_map)
// }
// cold_transmute_cell::proc(cell:[2]int, w_map:^Chunck){
// 	cell_d:=get_cell_data(cell, w_map)
// 	set_cell(cell,{cell_d.cold_transmute}, w_map)
// }

swap_cell::proc(cell_a:[2]int, cell_b:[2]int, w_map:^Map){
	if !is_cell_valid(cell_a,w_map) {return}
	if !is_cell_valid(cell_b,w_map) {return}

	cell_a_p:=get_cell(cell_a, w_map)
	cell_b_p:=get_cell(cell_b, w_map)

	cell_a_val:=get_cell(cell_a, w_map)^
	cell_b_val:=get_cell(cell_b, w_map)^

	// swaps the values
	cell_a_p^ = cell_b_val
	cell_b_p^ = cell_a_val

	update_chuncks_dirty_rect(cell_a,w_map)
	update_chuncks_dirty_rect(cell_b,w_map)
	// set that the cell has moved this frame to stop it frome moving multipul times
	set_cell_moved(cell_a, w_map, true)
	set_cell_moved(cell_b, w_map, true)
}
set_cell::proc(cell:[2]int, new_cell_data:Cell, w_map:^Map){
	if !is_cell_valid(cell,w_map) {return}
	// w_map.cells[cell.x][cell.y] = new_cell_data
	chunck:=get_chunck(cell, w_map)
	get_cell(cell,w_map)^ = new_cell_data
	chunck.ticks_to_sleep = 10
	update_chuncks_dirty_rect(cell,w_map)
}
set_cell_by_id::proc(cell:[2]int, id:Cell_ids, w_map:^Map){
	set_cell(cell, {id =id, temperature = Cell_Info[id].starting_temperature ,hp = Cell_Info[id].starting_hp, flags = Cell_Info[id].flags}, w_map)
}


Add_Cell_CMD::struct{
	pos:[2]int,
	cell_data:Cell,
}
server_set_cell::proc(cell:[2]int, new_cell_data:Cell, w_map:^Map){
	if g.server.status != .hosting {return}
	// set_cell(cell, new_cell_data, w_map)
	if w_map.cell_CMD_count< 1000{
		w_map.list_of_add_cell_CMD[w_map.cell_CMD_count] = {cell,new_cell_data}
		w_map.cell_CMD_count+=1
	}
	
}

server_set_cell_by_id::proc(cell:[2]int, id:Cell_ids, w_map:^Map){
	server_set_cell(cell, {id =id, temperature = Cell_Info[id].starting_temperature ,hp = Cell_Info[id].starting_hp, flags = Cell_Info[id].flags}, w_map)
}



proses_set_cell_cmd::proc(net_inst:^tg.Networking_Instance, w_map:^Map){
	if g.server.status == .hosting{
		cell_cmd := w_map.list_of_add_cell_CMD[:w_map.cell_CMD_count]
		buf:=mem.slice_data_cast([]u8,cell_cmd)
		tg.send_net_command_to_all_clients(net_inst,{type = cast(u32)Game_Net_Commands_Type.sink_cell_cmds},buf)
	}
	for i := 0; i < w_map.cell_CMD_count; i += 1 {
		cell:=w_map.list_of_add_cell_CMD[i]
		set_cell(cell.pos, cell.cell_data,w_map)
	}
	w_map.cell_CMD_count = 0
	w_map.list_of_add_cell_CMD = {}
}

resv_set_cell_cmds::proc(server_cmd:^tg.Server_CMD,w_map:^Map){
	cell_cmd:=mem.slice_data_cast([]Add_Cell_CMD,server_cmd.buf)
	for &cell in &cell_cmd{
		if w_map.cell_CMD_count < MAX_CELL_CMDS-1{
			w_map.cell_CMD_count+=1
			w_map.list_of_add_cell_CMD[w_map.cell_CMD_count] = cell
		}
	}
}






draw_chunck::proc(
	mesh: ^tg.Mesh_CPU,
	tex_id:tg.Texture_ID_Types, 
	$vert_t:typeid, 
	pos:[3]f32,
	// $w_h:[2]int,
	// plane:[$w][$h]tg.Plane_Cell,
	chunck:^Chunck,
	scale:[2]f32 = {1,1},
	origin: tg.Vec3 = {}, 
	rot:[3]f32 = {},
	uv:[4]f32 = tg.DEFALT_QUAD_UV, 
	mat:matrix[4, 4]f32 = tg.Mat4(1),
){
	tex:=tg.get_texture(tex_id)
	verts:[4]vert_t
	// mat:Mat4=mat
	translate_m4: tg.Mat4 = lin.matrix4_translate_f32(pos)
	origin_m4:    tg.Mat4 = lin.matrix4_translate_f32(origin)
	scale_m4:     tg.Mat4 = lin.matrix4_scale_f32({scale.x,scale.y,1,})
	rotate_q:          = lin.quaternion_from_pitch_yaw_roll_f32(rot.x,rot.y,rot.z)
	rotate_m4:    tg.Mat4 = lin.matrix4_from_quaternion_f32(rotate_q)
	mat :=translate_m4 * rotate_m4 * origin_m4 * scale_m4 * mat

	// resize(&mesh.vertex_buf,size_of(vert_t) * CHUNCK_SIZE * CHUNCK_SIZE * 4) 
	// resize(&mesh.index_buf,CHUNCK_SIZE * CHUNCK_SIZE * 6) 

	mesh.index_buf_used = CHUNCK_SIZE * CHUNCK_SIZE * 6
	// mesh.vertex_buf_used = size_of(vert_t) * CHUNCK_SIZE * CHUNCK_SIZE * 4
	// mesh.vertex_count = CHUNCK_SIZE * CHUNCK_SIZE * 4

	// fmt.print(mesh.index_buf_used,mesh.vertex_buf_used,mesh.vertex_count,"\n\n")

	dirt_rect:=chunck.dirty_rect_last + {-1,-1,1,1}
	dirt_rect.x = clamp(dirt_rect.x,0,CHUNCK_SIZE-1)
	dirt_rect.y = clamp(dirt_rect.y,0,CHUNCK_SIZE-1)
	dirt_rect.z = clamp(dirt_rect.z,0,CHUNCK_SIZE-1)
	dirt_rect.w = clamp(dirt_rect.w,0,CHUNCK_SIZE-1)
	
	for x in dirt_rect.x..=dirt_rect.z{
		for y in dirt_rect.y..=dirt_rect.w{
	// for y in 0..<CHUNCK_SIZE{
	// 	for x in 0..<CHUNCK_SIZE{
			vert_offset:= (y*CHUNCK_SIZE+x) * 4
			index_offset:= (y*CHUNCK_SIZE+x) * 6
			if chunck.cells[x][y].id != .air{
				// fmt.print("vert_offset:",vert_offset , "   index_offset:",index_offset,"\n")
				when intrinsics.type_has_field(vert_t, "pos"){
					//front
					// fmt.print( (x+w_h.x*y)*4 ,x,y," {x*y =",x*y,"}","\n")
					verts[0].pos =  { 0+cast(f32)x,   0 +(cast(f32)y*-1),  0, 1}
					verts[1].pos =  { 0+cast(f32)x,  -1 +(cast(f32)y*-1),  0, 1}
					verts[2].pos =  { 1+cast(f32)x,  -1 +(cast(f32)y*-1),  0, 1}
					verts[3].pos =  { 1+cast(f32)x,   0 +(cast(f32)y*-1),  0, 1}
				}
				when intrinsics.type_has_field(vert_t, "col"){
					verts[0].col = Cell_Info[chunck.cells[x][y].id].color
					verts[1].col = Cell_Info[chunck.cells[x][y].id].color
					verts[2].col = Cell_Info[chunck.cells[x][y].id].color
					verts[3].col = Cell_Info[chunck.cells[x][y].id].color
				}
				
				when intrinsics.type_has_field(vert_t, "uv"){
					uvs:=[4][2]f32{
						{uv.x,uv.y},
						{uv.x,uv.w},
						{uv.z,uv.w},
						{uv.z,uv.y},
					}
					verts[0].uv =  uvs.x
					verts[1].uv =  uvs.y
					verts[2].uv =  uvs.z
					verts[3].uv =  uvs.w
				}
				when intrinsics.type_has_field(vert_t, "img_index"){
					for &vert in &verts{
						vert.img_index = cast(u32)tex.groop_index
					}
				}
				
				when intrinsics.type_has_field(vert_t, "layer"){
					for &vert in &verts{
						vert.layer = tex.layer
					}
				}
				// tg.draw_verts_by_quad_mat(mesh, cast(u32)(1), verts[:], mat)
				tg.draw_over_verts_by_quad_mat(mesh, cast(u32)(1), verts[:],vert_offset,index_offset, mat)
			}else{
				verts = {}
				tg.draw_over_verts_by_quad_mat(mesh, cast(u32)(1), verts[:],vert_offset,index_offset, mat)
			}
		}
	}
}

sink_all_chuncks::proc(net_inst:^tg.Networking_Instance,w_map:^Map){
	if g.server.status == .hosting{
		for &row,x in &w_map.chuncks{
			for &chunck,y in &row{
				send_sink_chunck(net_inst,{x,y},w_map)
			}
		}
	}
}
send_sink_chunck::proc(net_inst:^tg.Networking_Instance,pos:[2]int,w_map:^Map){
	chunck:=get_chunck_by_pos(pos, w_map)
	if chunck == nil{
		fmt.print("faild to send chunk spesifid cunck is out of bounds\n")
		return
	}
	chunck.changes_since_last_sync = 0
	sink_chunck:Sink_Chunck_Data={
		pos = pos,
		cells = chunck.cells,
	}
	temp_buf:=transmute([size_of(Sink_Chunck_Data)]u8)sink_chunck
	tg.send_net_command_to_all_clients(net_inst,cmd = {type=cast(u32)Game_Net_Commands_Type.sink_chunck},buf = temp_buf[:])
}

sink_next_chunck::proc(net_inst:^tg.Networking_Instance,w_map:^Map){
	if g.server.status != .hosting{return}
	w_map.time_to_next_chunck_sink -= 1
	if w_map.time_to_next_chunck_sink > 0{return}
	w_map.time_to_next_chunck_sink = 10
	sink_most_changed_chunck(net_inst,w_map)
	w_map.next_chunck_to_sink.x+=1
	if w_map.next_chunck_to_sink.x > MAP_SIZE.x-1{
		w_map.next_chunck_to_sink.x = 0
		w_map.next_chunck_to_sink.y+=1
	}
	if w_map.next_chunck_to_sink.y > MAP_SIZE.y-1{
		w_map.next_chunck_to_sink.y = 0
		w_map.next_chunck_to_sink.x = 0
	}
	// send_sink_chunck(net_inst,w_map.next_chunck_to_sink,w_map,)

	
}
sink_most_changed_chunck::proc(net_inst:^tg.Networking_Instance,w_map:^Map){
	chunck_count::MAP_SIZE.x * MAP_SIZE.y
	chunck_list:[chunck_count][2]int
	list_index:int=0
	for &chuncks,x in &w_map.chuncks{
		for &chunck,y in &chuncks{
			chunck_list[list_index] = {x,y}
			list_index+=1
		}
	}
	slice.sort_by_cmp_with_data(chunck_list[:],cmp_chunks_by_changes,cast(rawptr)w_map )
	send_sink_chunck(net_inst,chunck_list[0],w_map,)
}
cmp_chunks_by_changes::proc(chucnk_a, chucnk_b: [2]int, data:rawptr) -> (order:slice.Ordering){
	w_map:= cast(^Map)data
	a:=get_chunck_change_count(chucnk_a,w_map)
	b:=get_chunck_change_count(chucnk_b,w_map)
	if a < b{
		order = .Greater
	}else if a > b{
		order = .Less
	}else{
		order = .Equal
	}
	return order
}

resv_sink_chunck::proc(server_cmd:^tg.Server_CMD){
	sink_chunck_s:=mem.slice_data_cast([]Sink_Chunck_Data,server_cmd.buf)[0:1]
	chunck:=get_chunck_by_pos(sink_chunck_s[0].pos, g.w_map)
	chunck.has_changed = true
	chunck.cell_has_moved = {}
	chunck.cells = sink_chunck_s[0].cells

}

Sink_W_Map_Info::struct{
	tick_count:u32,
}
sink_w_map_info::proc(net_inst:^tg.Networking_Instance,w_map:^Map){
	sink_w_map_info:Sink_W_Map_Info={
		tick_count = w_map.tick_count,
	}
	temp_buf:=transmute([size_of(Sink_W_Map_Info)]u8)sink_w_map_info
	tg.send_net_command_to_all_clients(net_inst,cmd = {type=cast(u32)Game_Net_Commands_Type.sink_w_map_info},buf = temp_buf[:])
}

resv_w_map_info::proc(server_cmd:^tg.Server_CMD,w_map:^Map){
	w_map_info:=mem.slice_data_cast([]Sink_W_Map_Info,server_cmd.buf)[0:1]
	w_map.tick_count = w_map_info[0].tick_count
}
