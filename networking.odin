package tg_render

import "core:fmt"
import "core:net"
import "core:os"
import "core:mem"
import st"core:strings"
import steam "steamworks"
import vmem "core:mem/virtual"
import "core:thread"
import hm "handle_map_static_virtual"
import "core:math/rand"
import "core:time"

Networking_State::struct{
	is_up:bool,
	type:Server_Types,
	ip: string,
	port: int,
	endpoint: Endpoint,
	sock: net.UDP_Socket,
	buffer:[256]u8,

	st_sock:^steam.INetworkingMessages,
	// st_endpoint:^steam.SteamNetworkingIdentity,
	// buffer:[256]u8,
}
Server_Types::enum{
	nil,
	host,
	client,
}
Endpoint::union{
	net.Endpoint,
	steam.SteamNetworkingIdentity,
}
	
init_udp_echo_server :: proc(ip: string, port: int) ->(server:Networking_State){
	// resize(&server.buffer,1000 )
	local_addr, ok := net.parse_ip4_address(ip)
	if !ok {
		fmt.println("Failed to parse IP address")
		return
	}
	endpoint := net.Endpoint {
		address = local_addr,
		port    = port,
	}
	// for the server, we create a *bound* UDP socket,
	// because we want to start listen the port immediately
	sock, err := net.make_bound_udp_socket(endpoint.address, endpoint.port)
	
	if err != nil {
		fmt.println("Failed to make bound UDP socket", err)
		return
	}
	fmt.printfln("Listening on UDP: %s", net.endpoint_to_string(endpoint))
	net.set_blocking(sock, false)
	if s.steam.is_using_steam{
		server.st_sock = steam.NetworkingMessages_SteamAPI()
	}
	server.is_up = true
	server.ip = ip
	server.port = port
	server.endpoint = endpoint
	server.sock = sock
	// buffer: [256]u8
	
	server.type = .host
	return
}

// do_udp_echo_server:: proc(server:^Networking_State) {
// 	bytes_recv, remote_endpoint, err_recv := recv_udp(server)
// 	received := server.buffer[:bytes_recv]
// 	fmt.printfln("Server received from %s", net.endpoint_to_string(remote_endpoint))
// 	fmt.printfln("Received data [ %d bytes ]: %s", len(received), received)
// 	if len(received) == 0 {return}
// 	bytes_sent, err_send := send_udp(server,remote_endpoint,received)
// 	sent := received[:bytes_sent]
// 	fmt.printfln("Server sent [ %d bytes ]: %s", len(sent), sent)
// 	free_all(context.temp_allocator)
// }

// stop_udp_echo_server:: proc(server:^Networking_State) {
// 	net.close(server.sock)
// 	fmt.println("Closed socket")
// }


is_lf :: proc(bytes : []u8) -> bool {
	return len(bytes) == 1 && bytes[0] == '\n'
}

is_crlf :: proc(bytes : []u8) -> bool {
	return len(bytes) == 2 && bytes[0] == '\r' && bytes[1] == '\n'
}

is_eol :: proc(bytes : []u8) -> bool {
	return is_lf(bytes) || is_crlf(bytes)
}

init_udp_echo_client :: proc(ip: string, port: int) ->(client:Networking_State){
	// resize(&client.buffer,1000 )
	local_addr, ok := net.parse_ip4_address(ip)
	if !ok {
		fmt.println("Failed to parse IP address")
		return
	}
	server_endpoint := net.Endpoint {
		address = local_addr,
		port    = port,
	}

	sock, err := net.make_unbound_udp_socket(net.family_from_address(local_addr))
	if err != nil {
		fmt.println("Failed to make unbound UDP socket", err)
		return
	}
	fmt.println("Client is ready")

	if s.steam.is_using_steam{
		client.st_sock = steam.NetworkingMessages_SteamAPI()
	}
	
	net.set_blocking(sock, false)
	client.is_up = true
	client.ip = ip
	client.port = port
	client.sock = sock
	client.endpoint = server_endpoint

	client.type = .client
	return
}

// do_udp_echo_client :: proc(client:^Networking_State) {

// 	str_builder:=st.builder_from_bytes(client.buffer[:])
// 	n :=st.write_string(&str_builder,"waffles")

// 	data := client.buffer[:n]
// 	if n == 0 || is_eol(data)  {
// 		return
// 	}

// 	bytes_sent, err_send :=send_udp(client,client.endpoint, data)

// 	sent := data[:bytes_sent]
// 	fmt.printfln("Client sent [ %d bytes ]: %s", len(sent), sent)
// 	bytes_recv, _, err_recv  := recv_udp(client, client.buffer[:])
// 	if err_recv != nil {
// 		fmt.println("Failed to receive data", err_recv)
// 		return
// 	}

// 	received := client.buffer[:bytes_recv]
// 	fmt.printfln("Client received [ %d bytes ]: %s", len(received), received)
// }

do_udp_print_server::proc(server:^Networking_State){
	bytes_recv, remote_endpoint, err_recv := recv_udp(server, server.buffer[:])
	switch ep in remote_endpoint{
	case  net.Endpoint:
		received := server.buffer[:bytes_recv]
		fmt.printfln("Server received from %s", net.endpoint_to_string(ep))
		fmt.printfln("Received data [ %d bytes ]: %s", len(received), received)
	
		if len(received) == 0 {return}
		// bytes_sent, err_send := send_udp(server,remote_endpoint,received)
		// sent := received[:bytes_sent]
		// fmt.printfln("Server sent [ %d bytes ]: %s", len(sent), sent)
		free_all(context.temp_allocator)
	case steam.SteamNetworkingIdentity:
	}
}

do_udp_server::proc(server:^Networking_State){
	bytes_recv, remote_endpoint, err_recv := recv_udp(server, server.buffer[:])
	received := server.buffer[:bytes_recv]
	if len(received) == 0 {return}
	free_all(context.temp_allocator)
}
send_udp::proc(net_st:^Networking_State, endpoint:Endpoint, data:[]u8)->(bytes_sent:int, err_send:net.UDP_Send_Error){
	switch &ep in endpoint{
		case  net.Endpoint:
			bytes_sent, err_send = net.send_udp(net_st.sock, data[:], ep)
			if err_send != nil {
				fmt.println("Failed to send data", err_send)
				return
			}
		case  steam.SteamNetworkingIdentity:
		steam.NetworkingMessages_SendMessageToUser(net_st.st_sock,&ep,raw_data(data[:]),cast(u32)len(data[:]),0,0)
	}

	return
}
recv_udp::proc(net_st:^Networking_State,buff:[]u8)->(bytes_recv: int, remote_endpoint:Endpoint, err_recv: net.UDP_Recv_Error){
	steam_msg:^^steam.SteamNetworkingMessage
	mesg_count:=steam.NetworkingMessages_ReceiveMessagesOnChannel(self = net_st.st_sock, nLocalChannel = 0, ppOutMessages = steam_msg, nMaxMessages = 0)
	if mesg_count > 0{
		remote_endpoint=steam_msg^^.identityPeer
		bytes_recv = cast(int)steam_msg^^.cbSize
		if cast(int)steam_msg^^.cbSize<len(buff){
			mem.copy(raw_data(buff),steam_msg^^.pData,cast(int)steam_msg^^.cbSize)
		}else{
			fmt.print("recv_udp buff to small\n")
		}
		steam.NetworkingMessage_t_Release(steam_msg^)
	}else{
		bytes_recv, remote_endpoint, err_recv = net.recv_udp(net_st.sock, buff)
		if err_recv != nil {
			// fmt.println("Failed to receive data", err_recv)
			return
		}
	}
	// st_msg:steam.SteamNetworkingMessage
	// st_msg_pt:=&st_msg
	// steam.NetworkingMessages_ReceiveMessagesOnChannel(net_st.st_sock,0,&st_msg_pt,1)
	// received := net_st.buffer[:bytes_recv]
	

	return
}

stop_udp_echo_client:: proc(client:^Networking_State) {
	net.close(client.sock)
	fmt.println("Closed socket")
}

// steam_recv_messag::proc(net_st:^Networking_State, endpoint:net.Endpoint, data:[]u8)->(bytes_sent:int, err_send:net.UDP_Send_Error){
// 	steam.NetworkingMessages_ReceiveMessagesOnChannel(net_st.st_sock, 0 ,cast(steam.SteamNetworkingMessage)cast(rawptr)raw_data(data),cast(i32)len(data))
// }
// steam_send_messag::proc(net_st:^Networking_State,buff:[]u8)->(bytes_recv: int, remote_endpoint: net.Endpoint, err_recv: net.UDP_Recv_Error){
// 	steam.NetworkingMessages_SendMessageToUser(net_st.st_sock, 0 ,)
// 	steam.User_GetSteamID(steam_user)
// }






// _____________________________________
// 
Server_CMD_Handle :: distinct Handle
Server_CMD_Handle_Map :: hm.Handle_Map(Server_CMD, Server_CMD_Handle, 1000)

Net_Commands_Type::enum u32 {
	join,
	accept_join,
	regect_join,
	leave,
	server_shutdown,
	
}

Net_Flags::enum{
	force_process,
}

Net_Command::struct{
	count:u32,
	data_len:u32,
	flags:bit_set[Net_Flags],
	id:u64,
	type:u32,// this is a Net_Commands_Type or a custom one created by the game that starts at len(Net_Commands_Type)
}
Networking_Type::enum{
	raw,
	steam,
}

Networking_Instance::struct{
	net_state:Networking_State,
	status:Server_Status,
	id:u64, //this is this game inst id
	clients:map[u64]Client,//This is only used if you are the server
	last_time_steam_updated_lobby:u32,//this is just some book keeping for whether or not to recheck steam lobby data
	server:Server,//This is only used if you are a Client
	lobby:Lobby,//this is data about other players everyone should have
	cmd_q:Server_CMD_Handle_Map,
	cmd_q_extra_data:vmem.Arena,
	cmd_q_extra_arena_alloc:mem.Allocator,
	net_thread:^thread.Thread,
	networking_type:Networking_Type,

	temp_buff_s:[30000]u8,
	temp_buff_r:[30000]u8,

	cb_pros_server_cmd:proc(net_inst:^Networking_Instance, server_cmd:^Server_CMD),
	cb_start_server:proc(net_inst:^Networking_Instance,)
}
Lobby::struct{
	is_using_steame_lobby:bool,
	players:[dynamic]player_info,
}
player_info::struct{
	id:u64,
	name:string,
}
Client::struct{
	id:u64,
	endpoint: Endpoint,
	last_resv_cmd:u32,
	last_sent_cmd:u32,
	last_time_steam_updated_lobby:u32,//this is just some book keeping for whether or not to recheck steam lobby data is only used when steam server
}

Server::struct{
	id:u64,
	endpoint: Endpoint,
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




start_server::proc(ip:string="0.0.0.0", port:int=35823, net_inst:^Networking_Instance){
	if !net_inst.net_state.is_up{
		fmt.print("starting server\n")
		net_inst.net_state = init_udp_echo_server(ip, port)
		net_inst.status = .hosting
		if net_inst.lobby.is_using_steame_lobby == true{
			create_steame_lobby()
		}
		if net_inst.cb_start_server != nil{
			net_inst.cb_start_server(net_inst)
		}
	}
}
join_server::proc(ip:string="0.0.0.0", port:int=35823, net_inst:^Networking_Instance){
	if !net_inst.net_state.is_up{
		fmt.print("conecting to server\n")
		net_inst.net_state = init_udp_echo_client(ip, port)
		send_join_request(Endpoint_String{ip,port},net_inst)
	}
	
}
leave_shutdown_server::proc(net_inst:^Networking_Instance){
	if net_inst.status == .joined{
		send_net_command_to_server(net_inst, cmd={type=cast(u32)Net_Commands_Type.leave,flags={.force_process}})
		net_inst.status = .nil
		// curent_game_mode = .start
	}
	if net_inst.status == .hosting{
		send_net_command_to_all_clients(net_inst, cmd={type=cast(u32)Net_Commands_Type.server_shutdown,flags={.force_process}})
		net_inst.status = .nil
		// g.curent_game_mode = .start
	}

	// reset_game_state()
	
}


do_networking::proc(net_inst_pt:rawptr){
	net_inst:=cast(^Networking_Instance)net_inst_pt
	for !s.app_should_close{
		switch net_inst.net_state.type{
		case .nil:
		time.sleep(10000000)
		case .host:
			cmd,endpoint,buf,ok:=recv_command(net_inst)
			if ok{
				update_network_clients_in_steam_lobby(net_inst)
				add_server_cmd_to_q(net_inst, cmd,endpoint,buf)
			}
		case .client:
			cmd,endpoint,buf,ok:=recv_command(net_inst)
			if ok{
				add_server_cmd_to_q(net_inst, cmd,endpoint,buf)
			}
		}
	}
}

update_network_clients_in_steam_lobby::proc(net_inst:^Networking_Instance){
	if s.steam.is_using_steam != true {return}
	if net_inst.networking_type != .steam {return}
	if s.steam.steam_lobby.groop.updated_count > net_inst.last_time_steam_updated_lobby {
		for player in s.steam.steam_lobby.groop.player{
			join_client(net_inst,player.cs_id,player.net_id)
		}
		net_inst.last_time_steam_updated_lobby = s.steam.steam_lobby.groop.updated_count
	}

}


Endpoint_String::struct{
	ip:string,
	port:int,
}

send_join_request::proc(endpoint:union{Endpoint_String,Endpoint}= Endpoint_String{ip="10.0.0.155", port=35823}, net_inst:^Networking_Instance){

	new_endpoint:Endpoint
	net_inst.status = .joining
	
	switch val in endpoint{
	case Endpoint_String:
		local_addr, ok := net.parse_ip4_address(val.ip)
		if !ok {
			fmt.println("Failed to parse IP address")
			return
		}
		new_endpoint = net.Endpoint {
			address = local_addr,
			port    = val.port,
		}
	case Endpoint:
		new_endpoint = val
	}
	net_inst.status = .joining
	cmd:Net_Command
	cmd.type = cast(u32)Net_Commands_Type.join
	// if new_endpoint.(^steam.steam.SteamNetworkingIdentity)
	// steam_join_lobby()
	send_net_command(net_inst, new_endpoint, cmd)
}

send_net_command::proc(net_inst:^Networking_Instance,endpoint:Endpoint, cmd:Net_Command, buf:[]u8 = {},){
	cmd:=cmd
	cmd.id =  net_inst.id
	cmd.data_len = cast(u32)len(buf)
	command:=transmute([size_of(Net_Command)]u8)cmd
	mem.copy(raw_data(&net_inst.temp_buff_s),raw_data(&command),size_of(Net_Command))
	if len(buf) > 0{
		// mem.copy(raw_data(&g.server.temp_buff_s),raw_data(buf),size_of(buf))
		copy(net_inst.temp_buff_s[size_of(Net_Command):],buf[:])
	} 
	// cmd_full[:size_of(Net_Command)] = command[:]
	bsent,err:=send_udp(&net_inst.net_state, endpoint, net_inst.temp_buff_s[:size_of(Net_Command)+len(buf)])
	
}

send_net_command_to_server::proc(net_inst:^Networking_Instance, cmd:Net_Command, buf:[]u8 = {}){
	cmd:=cmd
	net_inst.server.last_sent_cmd +=1
	cmd.count = net_inst.server.last_sent_cmd
	cmd.id =  net_inst.id
	
	if net_inst.status == .hosting{
		new_buf:[]u8
		if len(buf) >0{
			data,err:=vmem.arena_alloc(&net_inst.cmd_q_extra_data,len(buf),16)
			if err == nil{
				// mem.copy(raw_data(data),raw_data(buf),len(buf))
				copy(data[:],buf[:])
				new_buf = data
			}
		}
		add_server_cmd_to_q(net_inst,cmd,net_inst.server.endpoint,new_buf)
	}else{
		send_net_command(net_inst,net_inst.server.endpoint, cmd, buf)
	}
}

send_net_command_to_client::proc(net_inst:^Networking_Instance,client :^Client, cmd:Net_Command, buf:[]u8 = {}){

		cmd:=cmd
		client.last_sent_cmd +=1
		cmd.count = client.last_sent_cmd
		cmd.id =  net_inst.id
		// command:=transmute([size_of(Net_Command)]u8)cmd
		// bsent,err:=tg.send_udp(&g.server.net_state, client.endpoint, command[:])
		send_net_command(net_inst ,client.endpoint, cmd, buf)
	

}

send_net_command_to_all_clients::proc(net_inst:^Networking_Instance,cmd:Net_Command, buf:[]u8 = {}){
	for client_id,&client in &net_inst.clients{
		send_net_command_to_client(net_inst,&client, cmd, buf )
	}
}

recv_command::proc(net_inst:^Networking_Instance)->( command:Net_Command, endpoint:Endpoint, buf:[]u8 ,ok:bool){
	// raw_command:=transmute([size_of(Net_Command)]u8)command
	// bytes_recv, remote_endpoint, err_recv:=tg.recv_udp(&g.server.net_state ,raw_command[:])
	bytes_recv, remote_endpoint, err_recv:=recv_udp(&net_inst.net_state, net_inst.temp_buff_r[:])
	

	endpoint = remote_endpoint
	if err_recv == nil{
		if bytes_recv != 0{
			mem.copy(transmute(rawptr)(&command),raw_data(net_inst.temp_buff_r[:]),size_of(Net_Command))
			if command.data_len > 0{
				data,err:=vmem.arena_alloc(&net_inst.cmd_q_extra_data,cast(uint)command.data_len,16)
				if err == nil{
					// mem.copy(raw_data(data),raw_data(data[size_of(Net_Command):command.data_len+size_of(Net_Command)]),cast(int)command.data_len)
					copy(data[:],net_inst.temp_buff_r[size_of(Net_Command):command.data_len + size_of(Net_Command)])
					buf = data
				}
			}
			ok = true
		}
	}
	return
}

// this will init the networking instance that is passed and will allso start a new thread to handdle prosesing the server
init_networking_instance::proc(
	net_inst:^Networking_Instance,
	cb_pros_server_cmd:proc(net_inst:^Networking_Instance, server_cmd:^Server_CMD) = nil,
	cb_start_server:proc(net_inst:^Networking_Instance,) = nil,
	net_type:Networking_Type = .steam,
)->(){
	arena_err := vmem.arena_init_growing(&net_inst.cmd_q_extra_data,2000000)
	ensure(arena_err == nil)
	arena_alloc := vmem.arena_allocator(&net_inst.cmd_q_extra_data)
	net_inst.networking_type = net_type
	if s.steam.is_using_steam == true && net_inst.networking_type == .steam{
		net_inst.id = s.steam.steam_id
	}else{
		net_inst.id = cast(u64)rand.uint64_range(0,4294967290)
	}
	// net_inst.net_thread = thread.create_and_start(do_networking)
	net_inst.cb_start_server = cb_start_server
	net_inst.cb_pros_server_cmd = cb_pros_server_cmd
	thread.create_and_start_with_data(net_inst, do_networking)
}

// init_net_thread::proc(net_inst:^Networking_Instance,){
// 	arena_err := vmem.arena_init_growing(&net_inst.cmd_q_extra_data,2000000)
// 	ensure(arena_err == nil)
// 	arena_alloc := vmem.arena_allocator(&net_inst.cmd_q_extra_data)

// 	net_inst.id = cast(u16)rand.uint32_range(0,4294967290)
// 	net_inst.net_thread = thread.create_and_start(do_networking)
// }


Server_CMD::struct{
	handle:Server_CMD_Handle,
	endpoint:Endpoint,
	net_command:Net_Command,
	buf:[]u8,
}
add_server_cmd_to_q::proc(net_inst:^Networking_Instance, net_cmd:Net_Command, endpoint:Endpoint, buf:[]u8){
	server_cmd:Server_CMD={
		net_command = net_cmd,
		endpoint = endpoint,
		buf = buf
	}
	hm.add(&net_inst.cmd_q,server_cmd)
}
pros_server_cmd_q::proc(net_inst:^Networking_Instance){
	cmd_q_iter := hm.make_iter(&net_inst.cmd_q)
	for server_cmd in hm.iter(&cmd_q_iter) {
		cmd:=server_cmd.net_command
		endpoint :=server_cmd.endpoint
		cmd_type:=cast(Net_Commands_Type)cmd.type
		switch net_inst.net_state.type{
		case .nil:
		case .host:
			switch cmd_type{
			case .join:
				// has_allredy_joined := cmd.id in net_inst.clients
				// if !has_allredy_joined {
				// 	net_inst.clients[cmd.id] = {}
				// 	client_data:=&net_inst.clients[cmd.id]
				// 	client_data.id = cmd.id
				// 	client_data.endpoint = endpoint
				// 	send_net_command_to_client(net_inst,client_data,Net_Command{type = cast(u32)Net_Commands_Type.accept_join, flags = {.force_process}})
				// }else{
				// 	send_net_command(net_inst,endpoint, Net_Command{type = cast(u32)Net_Commands_Type.regect_join, flags = {.force_process}})
				// 	fmt.print("Received multipul join reqwests\n")
				// }
				join_client(net_inst,cmd.id,endpoint)
			case .leave:
			case .accept_join,.regect_join,.server_shutdown:
				fmt.print("Server Received Server Commands\n")
			}
		case .client:
			switch cmd_type{
			case .accept_join:
				net_inst.status = .joined
				net_inst.server.endpoint = server_cmd.endpoint
			case .regect_join:
				net_inst.status = .regected
			case .server_shutdown:
				net_inst.status = .nil
			case .join,.leave:
				fmt.print("Client Received Client Commands",cmd.type,"\n")
			}
		}
		if net_inst.cb_pros_server_cmd != nil{
			net_inst.cb_pros_server_cmd(net_inst,server_cmd)
		}
	}
	// fmt.print("total_reserved",g.server.cmd_q_extra_data.total_reserved,"   total_used",g.server.cmd_q_extra_data.total_used,"\n")
	vmem.arena_free_all(&net_inst.cmd_q_extra_data)
	hm.clear(&net_inst.cmd_q)
}

join_client::proc(net_inst:^Networking_Instance,client_id:u64,clients_endpoint:Endpoint){
	has_allredy_joined := client_id in net_inst.clients
	if !has_allredy_joined {
		net_inst.clients[client_id] = {}
		client_data:=&net_inst.clients[client_id]
		client_data.id = client_id
		client_data.endpoint = clients_endpoint
		send_net_command_to_client(net_inst,client_data,Net_Command{type = cast(u32)Net_Commands_Type.accept_join, flags = {.force_process}})
	}else{
		send_net_command(net_inst,clients_endpoint, Net_Command{type = cast(u32)Net_Commands_Type.regect_join, flags = {.force_process}})
		fmt.print("Received multipul join reqwests\n")
	}
}
