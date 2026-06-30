package sand_sim

import tg"../../../tg_render_sdl3gpu"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import "core:math"
import hm "../../handle_map_static_virtual"
import an"../../ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"

Entity_Handle :: distinct Handle
Entity_Handle_Map :: hm.Handle_Map(Entity, Entity_Handle, 1000)

Entity_Types::enum{
	player,
	mob,
}


Entity::struct{
	handle:Entity_Handle,
	pos:[3]f32,
	velocity:[2]f32,
	collider:[2]f32,
	type:Entity_Types,
	type_data:Entitys_Union,
}

Entitys_Union::union{
	Player_Entitys,
	Mob_Entitys,
}

Player_Entitys::struct{

}

Mob_Entitys::struct{

}

init_entitys_mesh::proc(){
	mesh_cpu:tg.Mesh_CPU={attribute_type = tg.Vertex_Data}
	mesh_attribute_info:=type_info_of(mesh_cpu.attribute_type)
	g.entitys_mesh = tg.create_mesh(mesh_cpu,10000 ,debug_name = "entitys")
}

spawn_entity::proc(entitys:^Entity_Handle_Map,ent:Entity={})->(hd:Entity_Handle){
	hd = hm.add(entitys,Entity{type_data = Player_Entitys{},collider = {20,30}})
	return
}

do_entitys::proc(entitys:^Entity_Handle_Map,){
	ent_iter := hm.make_iter(entitys)
	for ent in hm.iter(&ent_iter) {
		do_entity_physics(ent)
		switch &e in &ent.type_data{
			case Player_Entitys:
			
			do_players(ent,&e)
			case Mob_Entitys:
			
		}
	}
	sink_all_entity_data(&g.server)
}
sink_all_entity_data::proc(net_inst:^tg.Networking_Instance){
	items:=mem.slice_data_cast([]u8,g.entitys.items[:])
	tg.send_net_command_to_all_clients(net_inst, cmd={type = cast(u32)Game_Net_Commands_Type.sink_all_entity_data},buf = items)
}
draw_update_entitys_mesh::proc(entitys:^Entity_Handle_Map,){
	ent_iter := hm.make_iter(entitys)
	mesh:=tg.get_mesh(g.entitys_mesh)
	tg.clear_mesh_cpu(&mesh.cpu)
	for ent in hm.iter(&ent_iter) {
		tg.draw_rect(&mesh.cpu,"",tg.Vertex_Data,{1,1,1,1},{ent.pos,{ent.collider.x,ent.collider.y},},origin = {-ent.collider.x/2, ent.collider.y,0},)
		// tg.draw_rect_rounded(&mesh.cpu,"",tg.Vertex_Data,col={1,1,1,1},rec={ent.pos+{20,20,0},{100,100}},roundness = .2)

		// tg.draw_ring(&mesh.cpu,.Hats_Balloon_Party,tg.Vertex_Data,ent.pos,10,10,20,col={1,1,1,1})
		// switch &e in &ent.type_data{
		// 	case Player_Entitys:
		// 	do_players(ent,&e)
		// 	case Mob_Entitys:
			
		// }
	}
	// pos:[3]f32
	// for fri in s.steam.friends.player{
	// // fmt.print([2]u32{fri.l_player_icon_gpu_id.idx,fri.l_player_icon_gpu_id.gen})
	// 	pos+={100,0,0}
	// 	tg.draw_rect(&mesh.cpu,fri.l_player_icon_gpu_id,tg.Vertex_Data,{1,1,1,1},{pos,{50,50}})
	// }
	tg.draw_fps(&mesh.cpu,tg.Vertex_Data,{0,0,0})
	tg.draw_tps(&mesh.cpu,tg.Vertex_Data,{0,-20,0})
	tg.update_mesh(g.entitys_mesh)
}
render_entitys::proc(entitys:^Entity_Handle_Map,){
	tg.do_render_pass(&g.pass, &g.cam, {g.entitys_mesh})
}
get_entity::proc(hd:Entity_Handle)->(ent:^Entity){
	ent = hm.get(g.entitys,hd)
	return
}
All_Player_data::struct{
	players:map[u64]Entity_Handle,
}
Player_CMD::struct{
	move_vec:[2]f32,
	mouse_pos:[2]int,
	jump:bool,
	l_click_d:bool,
	l_click_p:bool,
	r_click_d:bool,
	r_click_p:bool,
}
send_player_cmd::proc(net_inst:^tg.Networking_Instance, cmd:Player_CMD){
	temp_data:=transmute([size_of(Player_CMD)]u8)cmd
	tg.send_net_command_to_server(net_inst,{type = cast(u32)Game_Net_Commands_Type.player_cmd}, temp_data[:])
}
add_player_by_id::proc(id:u64){
	player:Entity={
		pos= {},
		handle = {},
		type = .player,
		collider = {10,10},
		type_data = Player_Entitys{},
	}
	ent_hd:=spawn_entity(&g.entitys,player)
	g.all_player_data.players[id] = ent_hd
}
remove_player_by_id::proc(id:u64){
	hm.remove(&g.entitys,g.all_player_data.players[id])
	delete_key(&g.all_player_data.players, id)
}
do_players::proc(ent:^Entity,player:^Player_Entitys){

}
GRAV:[2]f32:{0,-.3}
AIR_RESIST: f32 : 0.98
do_entity_physics::proc(ent:^Entity){
	ent.velocity +=GRAV
	ent.velocity *= AIR_RESIST
	colide_whith_cells(ent,g.w_map)
	if ent.pos.x + ent.velocity.x <= 0{ // MAP_SIZE.x * CHUNCK_SIZE *CELL_SIZE
		ent.pos.x = 0
		ent.velocity.x = 0
	}
	if ent.pos.y + ent.velocity.y >= 0{
		ent.pos.y = 0
		ent.velocity.x = 0
	}
	if ent.pos.x + ent.velocity.x >= cast(f32)FULL_MAP_SIZE.x{
		ent.pos.x = cast(f32)FULL_MAP_SIZE.x
		ent.velocity.y = 0
	}
	if ent.pos.y + ent.velocity.y <= cast(f32)-FULL_MAP_SIZE.y{
		ent.pos.y = cast(f32)-FULL_MAP_SIZE.y
		ent.velocity.y = 0
	}
	// ent.pos.xy += ent.velocity
}
EPS :: 0.001 // this is to help whith flouting point errs
is_coliding_on_x::proc(ent:^Entity, w_map:^Map, offset:[2]f32 = {})->(left:bool,right:bool,cell_pos:[2]int,){


	
	min_y := cast(int)math.floor(((-ent.pos.y + offset.y) - ent.collider.y) / CELL_SIZE)
	max_y := cast(int)math.floor((-ent.pos.y + offset.y) / CELL_SIZE)

	if ent.velocity.x > 0{
		cell_x :=  math.floor(((ent.pos.x + offset.x + ent.collider.x * 0.5) / CELL_SIZE))
		for y := min_y; y <= max_y; y += 1 {
			cell := get_cell({cast(int)cell_x, y}, w_map)
			if .is_solid in cell.flags  {
				right = true
				cell_pos = {cast(int)cell_x, y}
		        // ent.pos.x = (cell_x * CELL_SIZE) - ent.collider.x * 0.5 - EPS
		        // ent.velocity.x = 0
		        return
		    }
		}
	}
	if ent.velocity.x < 0{
		cell_x := math.floor(((ent.pos.x + offset.x - ent.collider.x * 0.5) / CELL_SIZE))
		for y := min_y; y <= max_y; y += 1 {
			cell := get_cell({cast(int)cell_x, y}, w_map)
			if .is_solid in cell.flags  {
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

is_coliding_on_y::proc(ent:^Entity, w_map:^Map, offset:[2]f32 = {})->(up:bool,down:bool,cell_pos:[2]int,){

	min_x :=  cast(int)math.floor(((ent.pos.x + offset.x - ent.collider.x/2) / CELL_SIZE))
	max_x := cast(int)math.floor(((ent.pos.x + offset.x + ent.collider.x/2) / CELL_SIZE))

	if ent.velocity.y > 0{

		cell_y := math.floor((((-ent.pos.y + offset.y) - ent.collider.y) / CELL_SIZE))
		for x := min_x; x <= max_x; x += 1 {
			cell := get_cell({x, cast(int)cell_y}, w_map)
			if .is_solid in cell.flags  {
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
			if .is_solid in cell.flags  {
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

colide_whith_cells::proc(ent:^Entity,w_map:^Map){
	steps_x := max(1,cast(int)math.ceil(math.abs(ent.velocity.x) / CELL_SIZE),)
	step_x := ent.velocity.x / cast(f32)steps_x
	step_up_hight_incriment:f32=CELL_SIZE * 3
	x_step_loop:for i := 0; i < steps_x; i += 1 {
		ent.pos.x += step_x
		left,right,cell_pos_x:=is_coliding_on_x(ent,w_map)
		if left{
			step_up_loop_l:for step_up_hight :f32= CELL_SIZE; step_up_hight < step_up_hight_incriment+CELL_SIZE; step_up_hight += CELL_SIZE {
				j_left,j_right,j_cell_pos:=is_coliding_on_x(ent,w_map,{0,-step_up_hight})
				fmt.print(step_up_hight," l\n")
				if !j_left && !j_right {
					ent.pos.y += step_up_hight
					break x_step_loop
				}
			}
        	ent.pos.x = (cast(f32)(cell_pos_x.x + 1) * CELL_SIZE) + ent.collider.x * 0.5 + EPS
        	ent.velocity.x = 0
			break x_step_loop
		}
		if right{
			
			step_up_loop_r:for step_up_hight :f32= CELL_SIZE; step_up_hight < step_up_hight_incriment+CELL_SIZE; step_up_hight += CELL_SIZE {
				j_left,j_right,j_cell_pos:=is_coliding_on_x(ent,w_map,{0,-step_up_hight})
				fmt.print(step_up_hight," r\n")
				if !j_left && !j_right {
					ent.pos.y += step_up_hight
					break x_step_loop
				}
			}
			ent.pos.x = (cast(f32)cell_pos_x.x * CELL_SIZE) - ent.collider.x * 0.5 - EPS
			ent.velocity.x = 0
			break x_step_loop
		}
	}

	steps_y := max(1,cast(int)math.ceil(math.abs(ent.velocity.y) / CELL_SIZE),)
	step_y := ent.velocity.y / cast(f32)steps_y
	y_step_loop:for i := 0; i < steps_y; i += 1 {

	ent.pos.y += step_y
	up,down,cell_pos_y:=is_coliding_on_y(ent,w_map)

		if up{
			ent.pos.y = -(cast(f32)(cell_pos_y.y + 1) * CELL_SIZE) + ent.collider.y - EPS
			ent.velocity.y = 0
			break y_step_loop
		}
		if down{
			ent.pos.y = -(cast(f32)cell_pos_y.y * CELL_SIZE) + EPS
			ent.velocity.y = 0
			break y_step_loop
		}
	}
	// fmt.print(ent.pos,"\n")
}


do_player_inputs::proc(){

	cmd:Player_CMD
	mouse_pos:=get_cell_pos_by_pos(g.input_events.mouse_pos)
	cmd.mouse_pos = mouse_pos
	if is_input_event(.move_l){
		cmd.move_vec+={-1,0}
	}
	if is_input_event(.move_r){
		cmd.move_vec+={1,0}
	}
	if is_input_event(.jump){
		cmd.jump = true
	}
	if is_input_event(.fire){
		cmd.l_click_d = true
	}
	if is_input_event(.fire_p){
		cmd.l_click_p = true
	}
	if is_input_event(.alt_fire){
		cmd.r_click_d = true
	}
	if is_input_event(.alt_fire_p){
		cmd.r_click_p = true
	}
	send_player_cmd(&g.server, cmd)
}

do_player_cmd::proc(cmd:^tg.Server_CMD){

	player_e_hd:=g.all_player_data.players[cmd.net_command.id]
	player:=get_entity(player_e_hd)
	if player == nil {
		log.logf(.Warning, "invalid player sent: ",player_e_hd,)
		return
	}
	temp:[size_of(Player_CMD)]u8
	copy(temp[:],cmd.buf[:size_of(Player_CMD)])
	player_cmd:=transmute(Player_CMD)temp
	move_speed:f32=.4
	if player_cmd.jump{
		player.velocity.y += 10
	}
	player.velocity +=player_cmd.move_vec * move_speed
	if player_cmd.l_click_d {
		server_set_cell_by_id(player_cmd.mouse_pos,.water,g.w_map)
	}
}
