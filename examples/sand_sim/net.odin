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
import st"core:strings"
import "core:net"
import "core:thread"
import "core:time"
import "core:math/rand"

import vmem "core:mem/virtual"

Server_CMD_Handle :: distinct Handle
Server_CMD_Handle_Map :: hm.Handle_Map(Server_CMD, Server_CMD_Handle, 1000)

Net_Commands_Type::enum{
	join,
	accept_join,
	regect_join,
	leave,
	server_shutdown,
	player_cmd,
	sink_all_entity_data,
	sink_chunck,
	sink_cell_cmds,
	sink_w_map_info,
	
}
Net_Flags::enum{
	force_process,
}

Net_Command::struct{
	count:u32,
	data_len:u32,
	flags:bit_set[Net_Flags],
	id:u16,
	type:Net_Commands_Type,
}

Net_Server_Info::struct{
	net_state:tg.Networking_State,
	status:Server_Status,
	id:u16, //this is this game inst id
	clients:map[u16]Client,//This is only used if you are the server
	server:Server,//This is only used if you are a Client
	cmd_q:Server_CMD_Handle_Map,
	cmd_q_extra_data:vmem.Arena,
	cmd_q_extra_arena_alloc:mem.Allocator,
	net_thread:^thread.Thread,

	temp_buff_s:[30000]u8,
	temp_buff_r:[30000]u8,
}


Client::struct{
	id:u16,
	endpoint: net.Endpoint,
	last_resv_cmd:u32,
	last_sent_cmd:u32,
}
Server::struct{
	id:u16,
	endpoint: net.Endpoint,
	is_in_server:bool,
	last_resv_cmd:u32,
	last_sent_cmd:u32,
}
Server_Status::enum{
	nil,
	joined,
	joining,
	regected,
	hosting,
}




start_server::proc(ip:string="10.0.0.155", port:int=35823){
	if !g.server.net_state.is_up{
		fmt.print("starting server\n")
		g.server.net_state = tg.init_udp_echo_server(ip, port)
		g.server.status = .hosting
		add_player_by_id(g.server.id)
	}
}
join_server::proc(ip:string="10.0.0.155", port:int=35823){
	if !g.server.net_state.is_up{
		fmt.print("conecting to server\n")
		g.server.net_state = tg.init_udp_echo_client(ip, port)
		send_join_request()
	}
	
}
leave_shutdown_server::proc(){
	if g.server.status == .joined{
		send_net_command_to_server(cmd={type=.leave,flags={.force_process}})
		g.server.status = .nil
		g.curent_game_mode = .start
	}
	if g.server.status == .hosting{
		send_net_command_to_all_clients(cmd={type=.server_shutdown,flags={.force_process}})
		g.server.status = .nil
		g.curent_game_mode = .start
	}

	reset_game_state()
	
}


do_networking::proc(){
	for !s.app_should_close{
		switch g.server.net_state.type{
		case .nil:
		time.sleep(10000000)
		case .host:
			cmd,endpoint,buf,ok:=recv_command()
			if ok{
				add_server_cmd_to_q(cmd,endpoint,buf)
			}
		case .client:
			cmd,endpoint,buf,ok:=recv_command()
			if ok{
				add_server_cmd_to_q(cmd,endpoint,buf)
			}
		}
	}
}

send_join_request::proc(ip:string="10.0.0.155", port:int=35823,){
	local_addr, ok := net.parse_ip4_address(ip)
	if !ok {
		fmt.println("Failed to parse IP address")
		return
	}
	g.server.status = .joining
	endpoint := net.Endpoint {
		address = local_addr,
		port    = port,
	}
	g.server.status = .joining
	cmd:Net_Command
	cmd.type = .join
	send_net_command(endpoint, cmd)
}

send_net_command::proc(endpoint:net.Endpoint, cmd:Net_Command, buf:[]u8 = {}){
	cmd:=cmd
	cmd.id =  g.server.id
	cmd.data_len = cast(u32)len(buf)
	command:=transmute([size_of(Net_Command)]u8)cmd
	mem.copy(raw_data(&g.server.temp_buff_s),raw_data(&command),size_of(Net_Command))
	if len(buf) > 0{
		// mem.copy(raw_data(&g.server.temp_buff_s),raw_data(buf),size_of(buf))
		copy(g.server.temp_buff_s[size_of(Net_Command):],buf[:])
	} 
	// cmd_full[:size_of(Net_Command)] = command[:]
	bsent,err:=tg.send_udp(&g.server.net_state, endpoint, g.server.temp_buff_s[:size_of(Net_Command)+len(buf)])
	
}

send_net_command_to_server::proc(cmd:Net_Command, buf:[]u8 = {}){
	cmd:=cmd
	g.server.server.last_sent_cmd +=1
	cmd.count = g.server.server.last_sent_cmd
	cmd.id =  g.server.id
	
	if g.server.status == .hosting{
		new_buf:[]u8
		if len(buf) >0{
			data,err:=vmem.arena_alloc(&g.server.cmd_q_extra_data,len(buf),16)
			if err == nil{
				// mem.copy(raw_data(data),raw_data(buf),len(buf))
				copy(data[:],buf[:])
				new_buf = data
			}
		}
		add_server_cmd_to_q(cmd,g.server.server.endpoint,new_buf)
	}else{
		send_net_command(g.server.server.endpoint, cmd, buf)
	}
}

send_net_command_to_client::proc(client:^Client, cmd:Net_Command, buf:[]u8 = {}){
	cmd:=cmd
	client.last_sent_cmd +=1
	cmd.count = client.last_sent_cmd
	cmd.id =  g.server.id
	// command:=transmute([size_of(Net_Command)]u8)cmd
	// bsent,err:=tg.send_udp(&g.server.net_state, client.endpoint, command[:])
	send_net_command(client.endpoint, cmd, buf)
}
send_net_command_to_all_clients::proc(cmd:Net_Command, buf:[]u8 = {}){
	for client_id,&client in &g.server.clients{
		send_net_command_to_client(&client, cmd, buf )
	}
}

recv_command::proc()->(command:Net_Command, endpoint:net.Endpoint, buf:[]u8 ,ok:bool){
	// raw_command:=transmute([size_of(Net_Command)]u8)command
	// bytes_recv, remote_endpoint, err_recv:=tg.recv_udp(&g.server.net_state ,raw_command[:])
	bytes_recv, remote_endpoint, err_recv:=tg.recv_udp(&g.server.net_state, g.server.temp_buff_r[:])
	

	endpoint = remote_endpoint
	if err_recv == nil{
		if bytes_recv != 0{
			mem.copy(transmute(rawptr)(&command),raw_data(g.server.temp_buff_r[:]),size_of(Net_Command))
			if command.data_len > 0{
				data,err:=vmem.arena_alloc(&g.server.cmd_q_extra_data,cast(uint)command.data_len,16)
				if err == nil{
					// mem.copy(raw_data(data),raw_data(data[size_of(Net_Command):command.data_len+size_of(Net_Command)]),cast(int)command.data_len)
					copy(data[:],g.server.temp_buff_r[size_of(Net_Command):command.data_len + size_of(Net_Command)])
					buf = data
				}
			}
			ok = true
		}
	}
	return
}

init_net_thread::proc(){
	arena_err := vmem.arena_init_growing(&g.server.cmd_q_extra_data,2000000)
	ensure(arena_err == nil)
	arena_alloc := vmem.arena_allocator(&g.server.cmd_q_extra_data)

	g.server.id = cast(u16)rand.uint32_range(0,4294967290)
	g.server.net_thread = thread.create_and_start(do_networking)
}


Server_CMD::struct{
	handle:Server_CMD_Handle,
	endpoint:net.Endpoint,
	net_command:Net_Command,
	buf:[]u8,
}
add_server_cmd_to_q::proc(net_cmd:Net_Command, endpoint:net.Endpoint, buf:[]u8){
	server_cmd:Server_CMD={
		net_command = net_cmd,
		endpoint = endpoint,
		buf = buf
	}
	hm.add(&g.server.cmd_q,server_cmd)
}
pros_server_cmd_q::proc(){
	cmd_q_iter := hm.make_iter(&g.server.cmd_q)
	for server_cmd in hm.iter(&cmd_q_iter) {
		cmd:=server_cmd.net_command
		endpoint :=server_cmd.endpoint
		switch g.server.net_state.type{
		case .nil:
		case .host:
			switch cmd.type{
			case .join:
				has_allredy_joined := cmd.id in g.server.clients
				if !has_allredy_joined {
					g.server.clients[cmd.id] = {}
					client_data:=&g.server.clients[cmd.id]
					client_data.id = cmd.id
					client_data.endpoint = endpoint
					send_net_command_to_client(client_data,Net_Command{type = .accept_join, flags = {.force_process}})
					sink_all_chuncks(g.w_map)
					add_player_by_id(client_data.id)
				}else{
					send_net_command(endpoint, Net_Command{type = .regect_join, flags = {.force_process}})
					fmt.print("Received multipul join reqwests\n")
				}
			case .leave:
				client_data:=&g.server.clients[cmd.id]
				remove_player_by_id(client_data.id)
				delete_key(&g.server.clients, cmd.id)
			case .player_cmd:
				do_player_cmd(server_cmd)
			case .accept_join,.regect_join,.sink_all_entity_data,.sink_chunck,.sink_cell_cmds,.sink_w_map_info,.server_shutdown:
				fmt.print("Server Received Server Commands\n")
			}
			
		case .client:
			switch cmd.type{
			case .accept_join:
				g.server.status = .joined
				g.server.server.endpoint = server_cmd.endpoint
			case .regect_join:
				g.server.status = .regected
			case .sink_all_entity_data:
				items:=mem.slice_data_cast([]Entity,server_cmd.buf)
				fmt.print("bad\n")
				resize_dynamic_array(&g.entitys.items,len(items))
				// reserve_dynamic_array(&g.entitys.items,len(items))
				copy( g.entitys.items[:],items[:])
			case .sink_chunck:
				resv_sink_chunck(server_cmd)
			
			case .server_shutdown:
				g.server.status = .nil
				g.curent_game_mode = .start
				g.next_game_mode = .start
			case .sink_cell_cmds:
				resv_set_cell_cmds(server_cmd,g.w_map)
			case .sink_w_map_info:
				resv_w_map_info(server_cmd,g.w_map)
			case .join,.leave,.player_cmd:
				fmt.print("Client Received Client Commands",cmd.type,"\n")
			}

		}
	}
	// fmt.print("total_reserved",g.server.cmd_q_extra_data.total_reserved,"   total_used",g.server.cmd_q_extra_data.total_used,"\n")
	vmem.arena_free_all(&g.server.cmd_q_extra_data)
	hm.clear(&g.server.cmd_q)
}
