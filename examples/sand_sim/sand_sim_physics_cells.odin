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


Physics_Cell::struct{
	pos:[2]f32,
	velocity:[2]f32,
	cell:Cell,
}
MAX_NUMBER_OF_PHYSICS_CELLS::5000
Physics_Cells::struct{
	cells:[dynamic;MAX_NUMBER_OF_PHYSICS_CELLS]Physics_Cell
}

spawn_berst_of_p_cell_by_id::proc(id:Cell_ids,pos:[2]f32,w_map:^Map,p_count:int=1,min_speed:f32=3,max_speed:f32=8,){
	for i in 0..=p_count{
		angle := rand.float32() * (2.0 * math.PI)
		speed := rand.float32_range(min_speed, max_speed)
		
		dir := [2]f32{
		    math.cos(angle),
		    math.sin(angle),
		}
		spawn_p_cell_by_id(id,pos,dir * speed,w_map)
	}
}

spawn_p_cell_by_id::proc(id:Cell_ids,pos:[2]f32,velocity:[2]f32,w_map:^Map){
	cell:Cell={
		id =id,
		temperature = Cell_Info[id].starting_temperature,
		hp = Cell_Info[id].starting_hp,
		flags = Cell_Info[id].flags
	}
	spawn_p_cell(cell,pos,velocity,w_map)
}
spawn_p_cell::proc(cell:Cell,pos:[2]f32,velocity:[2]f32,w_map:^Map){
	p_cells:=&w_map.physics_cells.cells
	append(p_cells,Physics_Cell{pos = pos, velocity = velocity, cell = cell})
}
remove_p_cell_by_index::proc(index:int,w_map:^Map){
	p_cells:=&w_map.physics_cells.cells
	fmt.print("removed:",index," len:",len(p_cells),"\n")
	// if index >=len(p_cells){
		unordered_remove(p_cells,index)

	// }
}
update_p_cells::proc(w_map:^Map){
	p_cells:=&w_map.physics_cells.cells
	#reverse p_cell_loop: for &cell , index in p_cells{
		cell.velocity +=GRAV
		cell.velocity *= AIR_RESIST
		// cell.pos += cell.velocity
		fmt.print(index,"index\n")
		steps_x := max(1,cast(int)math.ceil(math.abs(cell.velocity.x) / CELL_SIZE),)
		step_x := cell.velocity.x / cast(f32)steps_x
		step_up_hight_incriment:f32=CELL_SIZE * 3
		x_step_loop:for i := 0; i < steps_x; i += 1 { 
	
			cell.pos.x += step_x
			left,right,pos_x:=is_p_cell_coliding_on_x(&cell,w_map,)
			if left{
				grid_cell:=get_cell(pos_x+{1,0},w_map)
				// if grid_cell.id == .air{
					set_cell(pos_x+{-1,0},cell.cell,w_map,)
				// }
				fmt.print(pos_x,"lesft\n")
				remove_p_cell_by_index(index,w_map)
				continue p_cell_loop
			}
			if right{
				grid_cell:=get_cell(pos_x+{-1,0},w_map)
				// if grid_cell.id == .air{
					set_cell(pos_x+{1,0},cell.cell,w_map,)
				// }
				fmt.print(pos_x,"right\n")
				remove_p_cell_by_index(index,w_map)
				continue p_cell_loop
			}
		}

		steps_y := max(1,cast(int)math.ceil(math.abs(cell.velocity.y) / CELL_SIZE),)
		step_y := cell.velocity.y / cast(f32)steps_y
		y_step_loop:for i := 0; i < steps_y; i += 1 {
	
			cell.pos.y += step_y
			up,down,pos_y:=is_p_cell_coliding_on_y(&cell,w_map,)
	
			if up{
				// if grid_cell.id == .air{
					set_cell(pos_y+{0,1},cell.cell,w_map,)
				// }
				fmt.print(pos_y,"up\n")
				remove_p_cell_by_index(index,w_map)
				continue p_cell_loop
			}
			if down{
				// if grid_cell.id == .air{
					set_cell(pos_y+{0,-1},cell.cell,w_map,)
				// }
				fmt.print(pos_y,"down\n")
				remove_p_cell_by_index(index,w_map)
				continue p_cell_loop
			}
		}
	
		if cell.pos.x + cell.velocity.x <= 0{ // MAP_SIZE.x * CHUNCK_SIZE *CELL_SIZE
			cell.pos.x = 0
			cell.velocity.x = 0
		}
		if cell.pos.y + cell.velocity.y >= 0{
			cell.pos.y = 0
			cell.velocity.x = 0
		}
		if cell.pos.x + cell.velocity.x >= cast(f32)FULL_MAP_SIZE.x{
			cell.pos.x = cast(f32)FULL_MAP_SIZE.x
			cell.velocity.y = 0
		}
		if cell.pos.y + cell.velocity.y <= cast(f32)-FULL_MAP_SIZE.y{
			cell.pos.y = cast(f32)-FULL_MAP_SIZE.y
			cell.velocity.y = 0
		}
	}
	fmt.print("new loop\n")
}
draw_p_cells::proc(w_map:^Map){
	p_cells:=&w_map.physics_cells.cells
	for &cell , i in p_cells{
		mesh:=tg.get_mesh(w_map.overlay_mesh)
		tg.draw_rect(&mesh.cpu,1,tg.Vertex_Data,Cell_Info[cell.cell.id].color,{{cell.pos.x,cell.pos.y,0},{CELL_SIZE,CELL_SIZE}},{-CELL_SIZE/2,-CELL_SIZE,0})
	}
}

is_p_cell_coliding_on_x::proc(ent:^Physics_Cell, w_map:^Map, offset:[2]f32 = {})->(left:bool,right:bool,cell_pos:[2]int,){


	
	min_y := cast(int)math.floor(((-ent.pos.y + offset.y) - CELL_SIZE) / CELL_SIZE)
	max_y := cast(int)math.floor((-ent.pos.y + offset.y) / CELL_SIZE)

	if ent.velocity.x > 0{
		cell_x :=  math.floor(((ent.pos.x + offset.x + CELL_SIZE * 0.5) / CELL_SIZE))
		for y := min_y; y <= max_y; y += 1 {
			cell := get_cell({cast(int)cell_x, y}, w_map)
			// if .is_solid in cell.flags  {
			if cell.id != .air  {
				fmt.print(cell.id,"\n")
				right = true
				cell_pos = {cast(int)cell_x, y}
		        // ent.pos.x = (cell_x * CELL_SIZE) - ent.collider.x * 0.5 - EPS
		        // ent.velocity.x = 0
		        return
		    }
		}
	}
	if ent.velocity.x < 0{
		cell_x := math.floor(((ent.pos.x + offset.x - CELL_SIZE * 0.5) / CELL_SIZE))
		for y := min_y; y <= max_y; y += 1 {
			cell := get_cell({cast(int)cell_x, y}, w_map)
			// if .is_solid in cell.flags  {
			if cell.id != .air  {
				fmt.print(cell.id,"\n")
				left = true
				cell_pos = {cast(int)cell_x, y}
		        // ent.pos.x = ((cell_x + 1) * CELL_SIZE) + ent.collider.x * 0.5 + EPS
		        // ent.velocity.x = 0
		        return
		    }
		}
	}
	return
}


is_p_cell_coliding_on_y::proc(ent:^Physics_Cell, w_map:^Map, offset:[2]f32 = {})->(up:bool,down:bool,cell_pos:[2]int,){

	min_x :=  cast(int)math.floor(((ent.pos.x + offset.x - CELL_SIZE/2) / CELL_SIZE))
	max_x := cast(int)math.floor(((ent.pos.x + offset.x + CELL_SIZE/2) / CELL_SIZE))

	if ent.velocity.y > 0{

		cell_y := math.floor((((-ent.pos.y + offset.y) - CELL_SIZE) / CELL_SIZE))
		for x := min_x; x <= max_x; x += 1 {
			cell := get_cell({x, cast(int)cell_y}, w_map)
			// if .is_solid in cell.flags  {
			if cell.id != .air  {
				fmt.print(cell.id,"\n")
				up = true
				cell_pos = {x, cast(int)cell_y}
		        // ent.pos.y = -((cell_y + 1) * CELL_SIZE) + ent.collider.y + EPS
		        // ent.velocity.y = 0
		        return
		    }
		}
	}
	if ent.velocity.y < 0{
		cell_y := math.floor(((-ent.pos.y + offset.y) / CELL_SIZE))

		for x := min_x; x <= max_x; x += 1 {
			cell := get_cell({x, cast(int)cell_y}, w_map)
			// if .is_solid in cell.flags  {
			if cell.id != .air  {
				fmt.print(cell.id,"\n")
				down = true
				cell_pos = {x, cast(int)cell_y}
		        // ent.pos.y = -(cell_y * CELL_SIZE) - EPS
		        // ent.velocity.y = 0
		        return
		    }
		}
	}
	return
}
