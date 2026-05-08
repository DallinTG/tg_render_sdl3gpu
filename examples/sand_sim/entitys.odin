package sand_sim

import tg"../../../tg_render_sdl3"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import hm "../../handle_map_static_virtual"
import an"ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"

Entity_Handle :: distinct Handle
Entity_Handle_Map :: hm.Handle_Map(Entity, Entity_Handle, 1000)

Entity_Types::enum{
	player,
	mob,
}

Entity::struct{
	pos:[3]f32,
	handle:Entity_Handle,
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
	g.entitys_mesh = tg.create_mesh(mesh_cpu,10000)
}

spawn_entity::proc(entitys:^Entity_Handle_Map,ent:Entity={})->(hd:Entity_Handle){
	hd = hm.add(entitys,Entity{type_data = Player_Entitys{}})
	return
}

do_entitys::proc(entitys:^Entity_Handle_Map,){
	ent_iter := hm.make_iter(entitys)
	for ent in hm.iter(&ent_iter) {
		
		switch &e in &ent.type_data{
			case Player_Entitys:
			
			do_players(ent,&e)
			case Mob_Entitys:
			
		}
	}
	sink_all_entity_data()
}
sink_all_entity_data::proc(){
	items:=mem.slice_data_cast([]u8,g.entitys.items[:])
	send_net_command_to_all_clients(cmd={type = .sink_all_entity_data},buf = items)
}
render_entitys::proc(entitys:^Entity_Handle_Map,){
	
	ent_iter := hm.make_iter(entitys)
	mesh:=tg.get_mesh(g.entitys_mesh)
	tg.clear_mesh_cpu(&mesh.cpu)
	for ent in hm.iter(&ent_iter) {
		tg.draw_rect(&mesh.cpu,"",tg.Vertex_Data,{1,1,1,1},{ent.pos,{10,10}})
		
		// switch &e in &ent.type_data{
		// 	case Player_Entitys:
		// 	do_players(ent,&e)
		// 	case Mob_Entitys:
			
		// }
	}
	tg.draw_fps(&mesh.cpu,tg.Vertex_Data,{0,0,0})
	tg.draw_tps(&mesh.cpu,tg.Vertex_Data,{0,-20,0})
	tg.update_mesh(g.entitys_mesh)
	tg.do_render_pass(&g.pass, &g.cam, {g.entitys_mesh}, g.window,  load_op = .LOAD, d_load_op = .LOAD, store_op = .RESOLVE)
}
get_entity::proc(hd:Entity_Handle)->(ent:^Entity){
	ent = hm.get(g.entitys,hd)
	return
}

Player_CMDs::enum{
	left,
	right,
	up,
	down,
	jump,
}
All_Player_data::struct{
	players:map[u16]Entity_Handle,
}
Player_CMD::struct{
	cmd:Player_CMDs,
	v1:f32,
}
send_player_cmd::proc(cmd:Player_CMD){
	temp_data:=transmute([size_of(Player_CMD)]u8)cmd
	send_net_command_to_server({type = .player_cmd}, temp_data[:])
}
add_player_by_id::proc(id:u16){
	player:Entity={
		pos= {},
		handle = {},
		type = .player,
		type_data = Player_Entitys{},
	}
	g.all_player_data.players[id] = spawn_entity(&g.entitys,player)
}
remove_player_by_id::proc(id:u16){
	fmt.print("removed player\n")
	hm.remove(&g.entitys,g.all_player_data.players[id])
	delete_key(&g.all_player_data.players, id)
}
do_players::proc(ent:^Entity,player:^Player_Entitys){

}
do_player_inputs::proc(){
	if is_input_event(.move_l){
		// ent.pos.x += -1
		send_player_cmd({cmd=.left})
	}
	if is_input_event(.move_r){
		send_player_cmd({cmd=.right})
		// ent.pos.x += 1
	}
}

do_player_cmd::proc(cmd:^Server_CMD){
	player_e_hd:=g.all_player_data.players[cmd.net_command.id]
	player:=get_entity(player_e_hd)
	temp:[size_of(Player_CMD)]u8
	copy(temp[:],cmd.buf[:size_of(Player_CMD)])
	player_cmd:=transmute(Player_CMD)temp
	move_vec:[3]f32
	move_speed:f32=.5
	switch 	player_cmd.cmd{
	case .left:
		move_vec+={-1,0,0}
	case .right:
		move_vec+={1,0,0}
	case .up:
		move_vec+={0,-1,0}
	case .down:
		move_vec+={0,1,0}
	case .jump:
	}
	player.pos +=move_vec * move_speed
}
