package sand_sim

import tg"../../../tg_render_sdl3gpu"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import "core:math"
// import hm "../../handle_map_static_virtual"
import hm "core:container/handle_map"
import an"../../ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"

Entity_Handle :: distinct Handle
// Entity_Handle_Map :: hm.Handle_Map(Entity, Entity_Handle, 1000)
Entity_Handle_Map :: hm.Static_Handle_Map(MAX_PLAYERS * 2, Entity, Entity_Handle)


Entity_Types::enum{
	player,
	mob,
}
DEFALT_STATS:Stats:{
	hp = 100,
	max_hp = 100,
	max_speed = 1,
	acceleration = 1,
}
Stats::struct{
	hp:f32,
	max_hp:f32,
	
	max_speed:f32,
	acceleration:f32,
	
}
Damage_types::enum{
	flat,
	hot,
	cold,

}

Entity::struct{
	is_dead:bool,
	handle:Entity_Handle,
	pos:[3]f32,
	velocity:[2]f32,
	collider:[2]f32,
	type:Entity_Types,
	type_data:Entitys_Union,
	stats:Stats,
}

Entitys_Union::union{
	Player_Entitys,
	Mob_Entitys,
}

Player_Entitys::struct{
	id:u64,
}

Mob_Entitys::struct{

}

init_entitys_mesh::proc(){
	mesh_cpu:tg.Mesh_CPU={attribute_type = tg.Vertex_Data}
	mesh_attribute_info:=type_info_of(mesh_cpu.attribute_type)
	g.entitys_mesh = tg.create_mesh(mesh_cpu,10000 ,debug_name = "entitys")
}

spawn_entity::proc(entitys:^Entity_Handle_Map,ent:Entity={})->(hd:Entity_Handle){
	new_ent:=ent
	hd = hm.add(entitys,new_ent)
	return
}

do_entitys::proc(entitys:^Entity_Handle_Map,){
	// ent_iter := hm.make_iter(entitys)
	ent_iter := hm.iterator_make(entitys)
	// for ent in hm.iter(&ent_iter) {
	for ent,hd in hm.iterate(&ent_iter) {
		do_entity_physics(ent)
		do_entity_environment_check(ent)
		do_entity_management(ent)
		switch &e in &ent.type_data{
			case Player_Entitys:
			
			do_players(ent,&e)
			case Mob_Entitys:
			
		}
	}
	sink_all_entity_data(&g.server)
}

//this is for doing calculations that a entity needs every frame like checking whether or not it is alive
do_entity_management::proc(ent:^Entity){
	fmt.print(ent.stats.hp,"\n")
	if ent.stats.hp <= 0{
		ent.is_dead = true
	}else{
		ent.is_dead = false
	}
}

do_entity_environment_check::proc(ent:^Entity){
	if ent.is_dead{return}
	cell:=get_cell({cast(int)ent.pos.x/ CELL_SIZE, cast(int)-ent.pos.y/ CELL_SIZE}, g.w_map)
	entity_in_contact_whith_cell(ent,cell)

}
entity_in_contact_whith_cell::proc(ent:^Entity,cell:^Cell){
	fmt.print(cell.temperature,cell.id,"\n")
	if cell.temperature <=.Freezing{
		damage_entity(ent,1,.cold)
	}
	if cell.temperature >=.Melting{
		damage_entity(ent,1,.hot)
	}
}

damage_entity::proc(ent:^Entity,damage:f32,dam_type:Damage_types){
	ent.stats.hp -= damage
}

sink_all_entity_data::proc(net_inst:^tg.Networking_Instance){
	items:=mem.slice_data_cast([]u8,g.entitys.items[:len(g.entitys.items)])
	// items:=mem.slice_data_cast([]u8,g.entitys.items.chunks[:])//TODO THIS MAY NOT WORK 
	tg.send_net_command_to_all_clients(net_inst, cmd={type = cast(u32)Game_Net_Commands_Type.sink_all_entity_data},buf = items)
}
draw_update_entitys_mesh::proc(entitys:^Entity_Handle_Map,){
	// ent_iter := hm.make_iter(entitys)
	ent_iter := hm.iterator_make(entitys)
	mesh:=tg.get_mesh(g.entitys_mesh)
	tg.clear_mesh_cpu(&mesh.cpu)
	for ent,hd in hm.iterate(&ent_iter) {
		tg.draw_rect(&mesh.cpu,tg.get_texture(s.white_texture_hd),tg.Vertex_Data,{1,1,1,1},{ent.pos,{ent.collider.x,ent.collider.y},},origin = {-ent.collider.x/2, ent.collider.y,0},)
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
	ent = hm.get(&g.entitys,hd)
	return
}
All_Player_data::struct{
	players:map[u64]Entity_Handle,
}
Player_CMD::struct{
	player_hd:Entity_Handle,
	move_vec:[2]f32,
	mouse_pos:[2]int,
	jump:bool,
	l_click_d:bool,
	l_click_p:bool,
	r_click_d:bool,
	r_click_p:bool,

	curent_cell_id:Cell_ids,
}
send_player_cmd::proc(net_inst:^tg.Networking_Instance, cmd:Player_CMD){
	temp_data:=transmute([size_of(Player_CMD)]u8)cmd
	tg.send_net_command_to_server(net_inst,{type = cast(u32)Game_Net_Commands_Type.player_cmd}, temp_data[:])
}
add_player_by_id::proc(id:u64)->(player_hd:Entity_Handle){
	player:Entity={
		pos= {},
		handle = {},
		type = .player,
		collider = {20,30},
		type_data = Player_Entitys{id = id},
		stats = DEFALT_STATS,
	}
	player_hd=spawn_entity(&g.entitys,player)
	append(&g.info.player_list,player_hd)
	// g.all_player_data.players[id] = ent_hd
	return
}
// get_player::proc(net_inst:^tg.Networking_Instance)->(ent:Entity){
// 	ent=get_entity(g.all_player_data.players[net_inst.id])
// 	return
// }
remove_player_by_id::proc(id:u64)->(suc:bool){

	player_hd,player_list_index,ok:=get_player_by_id(id)
	if ok{
		hm.remove(&g.entitys,player_hd)
		unordered_remove(&g.info.player_list,player_list_index)
		return true
	}
	return false
}
get_player_by_id::proc(id:u64)->(new_player_hd:Entity_Handle,player_list_index:int,suc:bool){
	for player_hd,index in g.info.player_list{
		player:=get_entity(player_hd)
		#partial switch player_data in player.type_data{
		case Player_Entitys:
			if player_data.id == id{
				return player_hd,index,true
			}
		case:
		} 
	}
	return {},0,false
}

get_this_player_hd::proc()->(new_player_hd:Entity_Handle,player_list_index:int,suc:bool){
	return get_player_by_id(g.server.id)
}

do_players::proc(ent:^Entity,player:^Player_Entitys){

}

GRAV:[2]f32:{0,-.3}
AIR_RESIST: f32 : 0.98
do_entity_physics::proc(ent:^Entity){
	if ent.is_dead{return}
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
}


do_player_inputs::proc(){

	cmd:Player_CMD
	mouse_pos:=get_cell_pos_by_pos(s.input_events.mouse_pos)
	cmd.player_hd,_,_ = get_this_player_hd()
	cmd.mouse_pos = mouse_pos
	cmd.curent_cell_id = g.player.curent_cell
	if tg.is_input_event(.move_l){
		cmd.move_vec+={-1,0}
	}
	if tg.is_input_event(.move_r){
		cmd.move_vec+={1,0}
	}
	if tg.is_input_event(.jump){
		cmd.jump = true
	}
	if tg.is_input_event(.fire){
		cmd.l_click_d = true
	}
	if tg.is_input_event(.fire_p){
		cmd.l_click_p = true
	}
	if tg.is_input_event(.alt_fire){
		cmd.r_click_d = true
	}
	if tg.is_input_event(.alt_fire_p){
		cmd.r_click_p = true
	}
	send_player_cmd(&g.server, cmd)
}

do_player_cmd::proc(cmd:^tg.Server_CMD){

	// player_e_hd:=g.all_player_data.players[cmd.net_command.id]
	temp:[size_of(Player_CMD)]u8
	copy(temp[:],cmd.buf[:size_of(Player_CMD)])
	player_cmd:=transmute(Player_CMD)temp
	player:=get_entity(player_cmd.player_hd)
	if player == nil {
		log.logf(.Warning, "invalid player sent: ",player_cmd.player_hd,)
		return
	}
	move_speed:f32=.4
	if player_cmd.jump{
		player.velocity.y += 10
	}
	player.velocity +=player_cmd.move_vec * move_speed

	if player_cmd.l_click_d {
		server_set_cell_by_id(player_cmd.mouse_pos,player_cmd.curent_cell_id,g.w_map)
	}
}
