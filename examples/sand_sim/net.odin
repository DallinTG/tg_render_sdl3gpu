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

Net_Commands_Type::enum{
	join,
	accept_join,
	regect_join,
	leave,
	
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
	net_thread:^thread.Thread
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
	}
}
join_server::proc(ip:string="10.0.0.155", port:int=35823){
	if !g.server.net_state.is_up{
		fmt.print("conecting to server\n")
		g.server.net_state = tg.init_udp_echo_client(ip, port)
		send_join_request()
	}
	
}

do_networking::proc(){
	for {
		switch g.server.net_state.type{
		case .nil:
		time.sleep(10000000)
		case .host:
			if g.server.net_state.is_up {
				// tg.do_udp_print_server(&g.server.net_state)
			}
			cmd,endpoint,ok:=recv_command()
			if ok{
				switch cmd.type{
				case .join:
					has_allredy_joined := cmd.id in g.server.clients
					if !has_allredy_joined {
						g.server.clients[cmd.id] = {}
						client_data:=&g.server.clients[cmd.id]
						client_data.endpoint = endpoint
						send_net_command_to_client(client_data,Net_Command{type = .accept_join, flags = {.force_process}})
					}else{
						send_net_command(endpoint, Net_Command{type = .regect_join, flags = {.force_process}})
						fmt.print("Received multipul join reqwests\n")
					}
				case .leave:
					delete_key(&g.server.clients, cmd.id)
				case .accept_join,.regect_join:
					fmt.print("Server Received Server Commands\n")
				}
			}

			if ok{fmt.print(cmd,"\n")}
		case .client:
			cmd,endpoint,ok:=recv_command()
			if ok{
				switch cmd.type{
				case .accept_join:
					g.server.status = .joined
				case .regect_join:
					g.server.status = .regected
				case .join,.leave:
					fmt.print("Client Received Client Commands\n")
				}
				fmt.print(cmd,endpoint,ok,"\n")
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

send_net_command::proc(endpoint:net.Endpoint, cmd:Net_Command){
	cmd:=cmd
	cmd.id =  g.server.id
	command:=transmute([size_of(Net_Command)]u8)cmd
	bsent,err:=tg.send_udp(&g.server.net_state, endpoint, command[:])
}

send_net_command_to_server::proc(cmd:Net_Command){
	cmd:=cmd
	g.server.server.last_sent_cmd +=1
	cmd.count = g.server.server.last_sent_cmd
	cmd.id =  g.server.id
	command:=transmute([size_of(Net_Command)]u8)cmd
	bsent,err:=tg.send_udp(&g.server.net_state, g.server.server.endpoint, command[:])
}

send_net_command_to_client::proc(client:^Client, cmd:Net_Command){
	cmd:=cmd
	client.last_sent_cmd +=1
	cmd.count = client.last_sent_cmd
	cmd.id =  g.server.id
	command:=transmute([size_of(Net_Command)]u8)cmd
	bsent,err:=tg.send_udp(&g.server.net_state, client.endpoint, command[:])
}

recv_command::proc()->(command:Net_Command, endpoint:net.Endpoint ,ok:bool){
	raw_command:=transmute([size_of(Net_Command)]u8)command
	bytes_recv, remote_endpoint, err_recv:=tg.recv_udp(&g.server.net_state ,raw_command[:])
	endpoint = remote_endpoint
	if err_recv == nil{
		if bytes_recv != 0{
			fmt.print(bytes_recv," bytes_recv\n")
			command = transmute(Net_Command)raw_command
			ok = true
		}
	}
	return
}

init_net_thread::proc(){
	g.server.id = cast(u16)rand.uint32_range(0,4294967290)
	g.server.net_thread = thread.create_and_start(do_networking)
}
