package sand_sim

import tg"../../../tg_render_sdl3"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import "core:math"
import "core:math/rand"

import hm "../../handle_map_static_virtual"
import an"ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"
import "base:intrinsics"

// MAP_SIZE:[2]int:{32,16}
// CHUNCK_SIZE::16
MAP_SIZE:[2]int:{16,8}
CHUNCK_SIZE::32 
// MAP_SIZE:[2]int:{8,4}
// CHUNCK_SIZE::64 

MAX_CELL_CMDS::1000

Map::struct{
	tick_count:u32,
	rand_tick_seed:u32,
	tick_count_loc:u32,
	chuncks:[MAP_SIZE.x][MAP_SIZE.y]Chunck,
	l_r:int,

	list_of_add_cell_CMD:[MAX_CELL_CMDS]Add_Cell_CMD,
	cell_CMD_count:int,
	next_chunck_to_sink:[2]int,
	// info:Map_Info,
}
Chunck::struct{
	tick_count:u32,
	// l_r:int,
	mesh:tg.Mesh_Handle,
	cells:[CHUNCK_SIZE][CHUNCK_SIZE]Cell,
	cell_has_moved:[CHUNCK_SIZE][CHUNCK_SIZE]bool,
	has_changed:bool,
	change_count:i32,
}
Sink_Chunck_Data::struct{//this is the data that gets sent over udp to sink chunck data
	pos:[2]int,
	cells:[CHUNCK_SIZE][CHUNCK_SIZE]Cell,
}
waf::2
Map_Info::struct{
	wh:[waf]u32,
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

CELL_SIZE::10
Cell_Temperature::enum i8{
	
	Deth_Cold = 6,
	Unbelievably_Cold = 5,
	Extremely_Cold = 4,
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
	on_contact:proc([2]int,),
	// has_grav:bool,
	// solid:bool,
	// is_gass:bool,
	
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
	},
	.gravel ={
		flags={
			.has_grav,
			.is_solid,

		},
		slippage = 1,
		color = {.23,.22,.27,1},
		density = 4,
	},
	.up_sand ={
		flags={
			.has_grav,
			.is_solid,
		},
		slippage = 2,
		color = {.9,.8,.2,1},
		density = -3,
	},
	.water ={
		flags={

			.has_grav,
		},
		slippage = 4,
		color = {.27,.49,.9,1},
		density = 1,
		flow_rate = 4,
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

init_chunck_mesh::proc(w_map:^Chunck, map_info:=DEFALT_MAP_INFO){
	mesh_cpu:tg.Mesh_CPU={attribute_type = tg.Vertex_Data}
	mesh_attribute_info:=type_info_of(mesh_cpu.attribute_type)
	w_map.mesh = tg.create_mesh(mesh_cpu,cast(int)(map_info.wh.x*map_info.wh.y)*mesh_attribute_info.size)
}



init_map::proc(new_map:^^Map,){
	delete_w_map(new_map^)
	new_map^ = new(Map)
	for &row in new_map^.chuncks{
		for &chunck in row{
			init_chunck_mesh(&chunck)
		}
	}
}
init_chunck::proc(new_chunck:^^Chunck,){
	delete_chunck(new_chunck^)
	new_chunck^ = new(Chunck)
	init_chunck_mesh(new_chunck^)
}
delete_w_map::proc(w_map:^Map){
	if w_map == nil{return}
	for &row in w_map^.chuncks{
		for &chunck in row{
			tg.delete_mesh(chunck.mesh)
		}
	}
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
				mesh_chunck(&chunck,{x,y})
			}
		}
	}
	for &chuncks,x in &w_map.chuncks{
		for &chunck,y in &chuncks{
			chunck.has_changed = false
			chunck.cell_has_moved = {}
		}
	}
}

mesh_chunck::proc(chunck:^Chunck,pos:[2]int){
	mesh:=tg.get_mesh(chunck.mesh)
	tg.clear_mesh_cpu(&mesh.cpu)//TODO Clears the mesh every frame this should only do that if somthing has changed
	draw_chunck(
		mesh = &mesh.cpu,
		tex_id = "white",
		vert_t = tg.Vertex_Data,
		pos = {cast(f32)(pos.x*CELL_SIZE*CHUNCK_SIZE),cast(f32)(pos.y*CELL_SIZE*CHUNCK_SIZE*-1),0},
		// w_h = {CHUNCK_SIZE,CHUNCK_SIZE},
		chunck = chunck,
		scale = {CELL_SIZE,CELL_SIZE},
	)
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
	tg.do_render_pass(&g.pass, &g.cam, meshes[:], g.window,  load_op = .CLEAR, d_load_op = .CLEAR, store_op = .RESOLVE)
}

rand_1_1:[2]int:{1,-1}
update_map::proc(w_map:^Map){
	fmt.print(hash.ginger_hash16(cast(u16)w_map.tick_count),"\n")
	w_map.rand_tick_seed = cast(u32)hash.ginger_hash16(cast(u16)w_map.tick_count)
	if w_map.rand_tick_seed % 2 == 0{
		w_map.l_r = -1
	}else{
		w_map.l_r = 1
	}

	// w_map.l_r=rand.choice(rand_1[:])



	proses_set_cell_cmd(w_map)
	sink_next_chunck(w_map)
	sink_w_map_info(g.w_map)


	for &chuncks,x in &w_map.chuncks{
		for &chunck,y in &chuncks{
			update_chunck(&chunck,x,y,w_map)
		}
	}

	w_map.tick_count+=1
	w_map.tick_count_loc+=1


}
update_chunck::proc(chunck:^Chunck,c_x:int,c_y:int,w_map:^Map){
	// chunck.cell_has_moved = {}
	// rand_1:[2]int=rand_1_1
	// chunck.l_r=rand.choice(rand_1[:])


	for &cells,x in &chunck.cells{
		if w_map.tick_count % 2 == 0{
			for &cell,y in &cells{
				update_cell(x+(c_x*CHUNCK_SIZE),y+(c_y*CHUNCK_SIZE),&cell,w_map)
			}
		}else{
			#reverse for &cell,y in &cells{
				update_cell(x+(c_x*CHUNCK_SIZE),y+(c_y*CHUNCK_SIZE),&cell,w_map)
			}
		}
	}
}
update_cell::proc(x,y:int,cell:^Cell,w_map:^Map){
	c:=&Cell_Info[cell.id]
	if cell.id == .air {return}
	if !is_cell_valid({x,y}, w_map){return}
	if !get_cell_moved({x,y}, w_map){
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

do_cell_flow::proc(cell:^Cell, c:^Cell_Data,pos:[2]int,w_map:^Map){
	if get_cell_moved(pos, w_map){return}
	if c.flow_rate > 0{ // flowing
		for i in 1..=c.flow_rate{
			if can_cell_fall_through(pos,{pos.x+w_map.l_r*i, pos.y},w_map){ //flow right
				swap_cell(pos,{pos.x+w_map.l_r*i,pos.y},w_map)
				return
			}else if can_cell_fall_through(pos,{pos.x+w_map.l_r*-1*i, pos.y},w_map){ //flow left
				swap_cell(pos,{pos.x+w_map.l_r*-1*i, pos.y},w_map)
				return
			}
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
		chunck.change_count += 1
	}
	chunck.cell_has_moved[cell.x%CHUNCK_SIZE][cell.y%CHUNCK_SIZE] = state
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

	// set that the cell has moved this frame to stop it frome moving multipul times
	set_cell_moved(cell_a, w_map, true)
	set_cell_moved(cell_b, w_map, true)
}
set_cell::proc(cell:[2]int, new_cell_data:Cell, w_map:^Map){
	if !is_cell_valid(cell,w_map) {return}
	// w_map.cells[cell.x][cell.y] = new_cell_data
	get_cell(cell,w_map)^ = new_cell_data
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



proses_set_cell_cmd::proc(w_map:^Map){
	if g.server.status == .hosting{
		cell_cmd := w_map.list_of_add_cell_CMD[:w_map.cell_CMD_count]
		buf:=mem.slice_data_cast([]u8,cell_cmd)
		send_net_command_to_all_clients({type = .sink_cell_cmds},buf)
	}
	for i := 0; i < w_map.cell_CMD_count; i += 1 {
		cell:=w_map.list_of_add_cell_CMD[i]
		set_cell(cell.pos, cell.cell_data,w_map)
	}
	w_map.cell_CMD_count = 0
	w_map.list_of_add_cell_CMD = {}
}

resv_set_cell_cmds::proc(server_cmd:^Server_CMD,w_map:^Map){
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

	for y in 0..<CHUNCK_SIZE{
		for x in 0..<CHUNCK_SIZE{
			if chunck.cells[x][y].id != .air{
				when intrinsics.type_has_field(vert_t, "pos"){
					//front
					// fmt.print( (x+w_h.x*y)*4 ,x,y," {x*y =",x*y,"}","\n")
					verts[0].pos =  { 0+cast(f32)x,   0 +(cast(f32)y*-1),  0}
					verts[1].pos =  { 0+cast(f32)x,  -1 +(cast(f32)y*-1),  0}
					verts[2].pos =  { 1+cast(f32)x,  -1 +(cast(f32)y*-1),  0}
					verts[3].pos =  { 1+cast(f32)x,   0 +(cast(f32)y*-1),  0}
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
				tg.draw_verts_by_quad_mat(mesh, cast(u32)(1), verts[:], mat)
			}
		}
	}
}

sink_all_chuncks::proc(w_map:^Map){
	if g.server.status == .hosting{
		for &row,x in &w_map.chuncks{
			for &chunck,y in &row{
				send_sink_chunck({x,y},w_map)
			}
		}
	}
}
send_sink_chunck::proc(pos:[2]int,w_map:^Map){
	chunck:=get_chunck_by_pos(pos, w_map)
	if chunck == nil{
		fmt.print("faild to send chunk spesifid cunck is out of bounds\n")
		return
	}
	chunck.change_count = 0
	sink_chunck:Sink_Chunck_Data={
		pos = pos,
		cells = chunck.cells,
	}
	temp_buf:=transmute([size_of(Sink_Chunck_Data)]u8)sink_chunck
	send_net_command_to_all_clients(cmd = {type=.sink_chunck},buf = temp_buf[:])
}

sink_next_chunck::proc(w_map:^Map){
	if g.server.status != .hosting{return}
	w_map.next_chunck_to_sink.x+=1
	if w_map.next_chunck_to_sink.x > MAP_SIZE.x-1{
		w_map.next_chunck_to_sink.x = 0
		w_map.next_chunck_to_sink.y+=1
	}
	if w_map.next_chunck_to_sink.y > MAP_SIZE.y-1{
		w_map.next_chunck_to_sink.y = 0
		w_map.next_chunck_to_sink.x = 0
	}
	send_sink_chunck(w_map.next_chunck_to_sink,w_map,)
	
}

resv_sink_chunck::proc(server_cmd:^Server_CMD){
	sink_chunck_s:=mem.slice_data_cast([]Sink_Chunck_Data,server_cmd.buf)[0:1]
	chunck:=get_chunck_by_pos(sink_chunck_s[0].pos, g.w_map)
	chunck.has_changed = true
	chunck.cell_has_moved = {}
	chunck.cells = sink_chunck_s[0].cells

}

Sink_W_Map_Info::struct{
	tick_count:u32,
}
sink_w_map_info::proc(w_map:^Map){
	sink_w_map_info:Sink_W_Map_Info={
		tick_count = w_map.tick_count,
	}
	temp_buf:=transmute([size_of(Sink_W_Map_Info)]u8)sink_w_map_info
	send_net_command_to_all_clients(cmd = {type=.sink_w_map_info},buf = temp_buf[:])
}

resv_w_map_info::proc(server_cmd:^Server_CMD,w_map:^Map){
	w_map_info:=mem.slice_data_cast([]Sink_W_Map_Info,server_cmd.buf)[0:1]
	w_map.tick_count = w_map_info[0].tick_count
}
