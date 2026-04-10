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


CHUNCK_SIZE::250


// Map::struct{
// 	info:Map_Info,
// 	l_r:int,
// 	cells:[CHUNCK_SIZE][CHUNCK_SIZE]Cell,
// 	cell_has_moved:[CHUNCK_SIZE][CHUNCK_SIZE]bool,
// }
Chunck::struct{
	info:Map_Info,
	l_r:int,
	mesh:tg.Mesh_Handle,
	cells:[CHUNCK_SIZE][CHUNCK_SIZE]Cell,
	cell_has_moved:[CHUNCK_SIZE][CHUNCK_SIZE]bool,
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
init_world_mesh::proc(w_map:^Chunck, map_info:=DEFALT_MAP_INFO){
	mesh_cpu:tg.Mesh_CPU={attribute_type = tg.Vertex_Data}
	mesh_attribute_info:=type_info_of(mesh_cpu.attribute_type)
	w_map.mesh = tg.create_mesh(mesh_cpu,cast(int)(map_info.wh.x*map_info.wh.y)*mesh_attribute_info.size)
}


init_map::proc(new_map:^^Chunck, map_info:=DEFALT_MAP_INFO){
	delete_map(new_map^)
	new_map^ = new(Chunck)
	new_map^.info = map_info
	init_world_mesh(new_map^)
}
delete_map::proc(w_map:^Chunck){
	if w_map == nil{return}
	free(w_map)
}
plane:[CHUNCK_SIZE][CHUNCK_SIZE]tg.Plane_Cell
render_map::proc(w_map:^Chunck){
	for &cells,x in &w_map.cells{
		for &cell,y in &cells{
			// render_cell(x,y,cell)
			plane[x][y].col = Cell_Info[cell.id].color
		}
	}
	// plane:[CHUNCK_SIZE][CHUNCK_SIZE]tg.Plane_Cell
	mesh:=tg.get_mesh(w_map.mesh)
	draw_chunck(
		mesh = &mesh.cpu,
		tex_id = "white",
		vert_t = tg.Vertex_Data,
		pos = {0,0,0},
		// w_h = {CHUNCK_SIZE,CHUNCK_SIZE},
		w_map = w_map,
		scale = {CELL_SIZE,CELL_SIZE},
	)
}
// render_cell::proc(x,y:int,cell:Cell){
// 	c:=Cell_Info[cell.id]
// 	mesh:=tg.get_mesh(g.world_mesh)
// 	tg.draw_rect(&mesh.cpu,"white",tg.Vertex_Data,c.color,{{cast(f32)x*CELL_SIZE,cast(f32)y*-1*CELL_SIZE,0},{CELL_SIZE,CELL_SIZE}})
// }

rand_1_1:[2]int:{1,-1}
update_map::proc(w_map:^Chunck){
	w_map.cell_has_moved = {}
	rand_1:[2]int=rand_1_1
	w_map.l_r=rand.choice(rand_1[:])
	for &cells,x in &w_map.cells{
		for &cell,y in &cells{
			update_cell(x,y,&cell,w_map)
		}
	}
}
update_cell::proc(x,y:int,cell:^Cell,w_map:^Chunck){
	c:=&Cell_Info[cell.id]
	if cell.id == .air {return}
	if !w_map.cell_has_moved[x][y]{
		// do_cell_temperature(c, {x,y}, w_map)
		do_cell_gass(cell, c, {x,y}, w_map)
		do_cell_grav(cell, c, {x,y}, w_map)
		do_cell_flow(cell, c, {x,y}, w_map)
	}
}
do_cell_grav::proc(cell:^Cell, c:^Cell_Data,pos:[2]int,w_map:^Chunck){
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

do_cell_flow::proc(cell:^Cell, c:^Cell_Data,pos:[2]int,w_map:^Chunck){
	if w_map.cell_has_moved[pos.x][pos.y]{return}
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
do_cell_gass::proc(cell:^Cell, c:^Cell_Data,pos:[2]int,w_map:^Chunck){
	if w_map.cell_has_moved[pos.x][pos.y]{return}
	if .is_gass not_in cell.flags{return}
	rand_1:[2]int=rand_1_1
	l_r:=rand.choice(rand_1[:])
	if l_r >0{
		l_r=rand.choice(rand_1[:])
		if can_cell_fall_through(pos,{pos.x+l_r, pos.y},w_map){ //flow right
			swap_cell(pos,{pos.x+l_r,pos.y},w_map)
			return
		}else if can_cell_fall_through(pos,{pos.x+l_r*-1, pos.y},w_map){ //flow left
			swap_cell(pos,{pos.x+l_r*-1, pos.y},w_map)
			return
		}
	}else{
		l_r=rand.choice(rand_1[:])
		if can_cell_fall_through(pos,{pos.x, pos.y+l_r},w_map){ //flow left
			swap_cell(pos,{pos.x, pos.y+l_r},w_map)
			return
		}else if can_cell_fall_through(pos,{pos.x, pos.y+l_r*-1},w_map){ //flow left
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

is_cell_valid::proc(cell:[2]int,w_map:^Chunck)->(is_valid:bool){
	if cell.x < 0{return false}
	if cell.y < 0{return false}
	if cell.x >= cast(int)w_map.info.wh.x{return false}
	if cell.y >= cast(int)w_map.info.wh.y{return false}
	return true
}
get_cell::proc(cell:[2]int,w_map:^Chunck)->(cell_data:^Cell){
	if !is_cell_valid(cell,w_map) {return &out_of_bounds_cell}
	cell_data=&w_map.cells[cell.x][cell.y]
	return cell_data
}

get_cell_data::proc(cell:[2]int,w_map:^Chunck)->(cell_data:^Cell_Data){
	if !is_cell_valid(cell,w_map) {return &Cell_Info[.air]}
	cell_d:=get_cell(cell,w_map)
	cell_data=&Cell_Info[cell_d.id]
	return cell_data
}

can_cell_fall_through::proc(cell_a:[2]int, cell_b:[2]int, w_map:^Chunck) ->(can_cell_fall_through:bool){
	cell_a_data:=get_cell_data(cell_a,w_map)
	cell_b_data:=get_cell_data(cell_b,w_map)
	cell_b:=get_cell(cell_b,w_map)
	// fmt.print(cell_b.flags,"waffles 90 \n")
	if .is_solid in cell_b.flags {return false}
	if math.abs(cell_a_data.density) > cell_b_data.density {return true}
	return false
}
can_cell_hot_transmute::proc(cell_a:[2]int, cell_b:[2]int, w_map:^Chunck) ->(can_cell_a_hot_transmute:bool,can_cell_b_hot_transmute:bool,){
	cell_b_data:=get_cell_data(cell_b,w_map)
	// if cell_b_data.temperature == 0 {return false, false}
	cell_a_data:=get_cell_data(cell_a,w_map)
	// if cell_b_data.hot_transmute_temp < cell_a_data.temperature/2 {can_cell_b_hot_transmute = true}
	// if cell_a_data.hot_transmute_temp < cell_b_data.temperature/2 {can_cell_a_hot_transmute = true}
	return 
}
can_cell_cold_transmute::proc(cell_a:[2]int, cell_b:[2]int, w_map:^Chunck) ->(can_cell_a_cold_transmute:bool,can_cell_b_cold_transmute:bool,){
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

swap_cell::proc(cell_a:[2]int, cell_b:[2]int, w_map:^Chunck){
	if !is_cell_valid(cell_a,w_map) {return}
	if !is_cell_valid(cell_b,w_map) {return}
	cell_a_val:=w_map.cells[cell_a.x][cell_a.y]
	cell_b_val:=w_map.cells[cell_b.x][cell_b.y]

	// swaps the values
	w_map.cells[cell_a.x][cell_a.y] = cell_b_val
	w_map.cells[cell_b.x][cell_b.y] = cell_a_val

	// set that the cell has moved this frame to stop it frome moving multipul times
	w_map.cell_has_moved[cell_a.x][cell_a.y] = true
	w_map.cell_has_moved[cell_b.x][cell_b.y] = true
}
set_cell::proc(cell:[2]int, new_cell_data:Cell, w_map:^Chunck){
	if !is_cell_valid(cell,w_map) {return}
	w_map.cells[cell.x][cell.y] = new_cell_data
}
set_cell_by_id::proc(cell:[2]int, id:Cell_ids, w_map:^Chunck){
	set_cell(cell, {id =id, temperature = Cell_Info[id].starting_temperature ,hp = Cell_Info[id].starting_hp, flags = Cell_Info[id].flags}, w_map)
}







draw_chunck::proc(
	mesh: ^tg.Mesh_CPU,
	tex_id:tg.Texture_ID_Types, 
	$vert_t:typeid, 
	pos:[3]f32,
	// $w_h:[2]int,
	// plane:[$w][$h]tg.Plane_Cell,
	w_map:^Chunck,
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
			if w_map.cells[x][y].id != .air{
				when intrinsics.type_has_field(vert_t, "pos"){
					//front
					// fmt.print( (x+w_h.x*y)*4 ,x,y," {x*y =",x*y,"}","\n")
					verts[0].pos =  { 0+cast(f32)x,   0 +(cast(f32)y*-1),  0}
					verts[1].pos =  { 0+cast(f32)x,  -1 +(cast(f32)y*-1),  0}
					verts[2].pos =  { 1+cast(f32)x,  -1 +(cast(f32)y*-1),  0}
					verts[3].pos =  { 1+cast(f32)x,   0 +(cast(f32)y*-1),  0}
				}
				when intrinsics.type_has_field(vert_t, "col"){
					verts[0].col = Cell_Info[w_map.cells[x][y].id].color
					verts[1].col = Cell_Info[w_map.cells[x][y].id].color
					verts[2].col = Cell_Info[w_map.cells[x][y].id].color
					verts[3].col = Cell_Info[w_map.cells[x][y].id].color
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
