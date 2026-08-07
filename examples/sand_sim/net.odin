package sand_sim

import tg"../../../tg_render_sdl3gpu"
// import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
// import "core:hash"
// import "core:c"
// import "core:fmt"
// import hm "../../handle_map_static_virtual"
// import hm "core:container/handle_map"
// import an"../../ansi"
// import lin"core:math/linalg"
// import cl"../../clay-odin"
// import st"core:strings"
// import "core:net"
// import "core:thread"
// import "core:time"
// import "core:math/rand"

// import vmem "core:mem/virtual"

Game_Net_Commands_Type::enum u32{
	player_cmd = len(tg.Net_Commands_Type),
	sink_all_entity_data,
	sink_chunck,
	sink_cell_cmds,
	sink_w_map_info,
	sink_game_info,
}

start_server::proc(net_inst:^tg.Networking_Instance){
	add_player_by_id(net_inst.id)
}


pros_server_cmd::proc(net_inst:^tg.Networking_Instance,server_cmd:^tg.Server_CMD){
	cmd:=server_cmd.net_command
	endpoint :=server_cmd.endpoint
	cmd_type:=cast(tg.Net_Commands_Type)cmd.type
	switch net_inst.net_state.type{
	case .nil:

	case .host:

	switch cmd_type{
	case .join:
		client_data:=&net_inst.clients[cmd.id]
		sink_all_chuncks(&g.server, g.w_map)
		add_player_by_id(client_data.id)

	case .leave:
		client_data:=&net_inst.clients[cmd.id]
		remove_player_by_id(client_data.id)
		delete_key(&net_inst.clients, cmd.id)
	case .accept_join,.regect_join,.server_shutdown:
		log.logf(.Warning, "Server Received Server Commands")
	}
	case .client:
		switch cmd_type{
		case .accept_join:
			// net_inst.status = .joined
			// net_inst.server.endpoint = server_cmd.endpoint
		case .regect_join:
			// net_inst.status = .regected
		case .server_shutdown:
			g.info.curent_game_mode = .start
			g.info.next_game_mode = .start
		case .join,.leave:

			log.logf(.Warning, "Client Received Client Commands",cmd.type,)
		}
	}

	// spusific to the game __________________________________________________________________
	cmd_type_game:=cast(Game_Net_Commands_Type)server_cmd.net_command.type
	switch net_inst.net_state.type{
	case .nil:

	case .host:
		switch cmd_type_game{
	
		case .player_cmd:
			do_player_cmd(server_cmd)
		case .sink_all_entity_data,.sink_chunck,.sink_cell_cmds,.sink_w_map_info,.sink_game_info:
			log.logf(.Warning, "Server Received Server Commands")
		}
			
	case .client:
		switch cmd_type_game{

		case .sink_all_entity_data:
									//TODO BROKE THIS WHEN CHANGING HANDLE MAPS ENTITYS WILL NO LONGER WORK
			items:=mem.slice_data_cast([]Entity,server_cmd.buf)
			// resize_dynamic_array(&g.entitys.items,len(items))
			// reserve_dynamic_array(&g.entitys.items,len(items))
			// copy( g.entitys.items[:],items[:])
		case .sink_chunck:
			resv_sink_chunck(server_cmd)
		case .sink_cell_cmds:
			resv_set_cell_cmds(server_cmd,g.w_map)
		case .sink_w_map_info:
			resv_w_map_info(server_cmd,g.w_map)
		case .player_cmd:
			log.logf(.Warning, "Client Received Client Commands",cmd.type,)
		case .sink_game_info:
			
		}
	}
}
resv_game_info::proc(server_cmd:^tg.Server_CMD){
	g.info = mem.slice_data_cast([]Game_Info,server_cmd.buf[:])[0]
}
sink_game_info::proc(net_inst:^tg.Networking_Instance,g_info:^Game_Info){
	temp_buf:=transmute([size_of(Game_Info)]u8)g_info^
	tg.send_net_command_to_all_clients(net_inst,cmd = {type=cast(u32)Game_Net_Commands_Type.sink_game_info},buf = temp_buf[:])
}
