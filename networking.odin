package tg_render

import "core:fmt"
import "core:net"
import "core:os"
import "core:mem"
import st"core:strings"
import steam "steamworks"

Networking_State::struct{
	is_up:bool,
	type:Server_Types,
	ip: string,
	port: int,
	endpoint: Endpoint,
	sock: net.UDP_Socket,
	buffer:[256]u8,

	st_sock:^steam.INetworkingMessages,
	st_endpoint:^steam.SteamNetworkingIdentity,
	// buffer:[256]u8,
}
Server_Types::enum{
	nil,
	host,
	client,
}
Endpoint::union{
	net.Endpoint,
	^steam.SteamNetworkingIdentity,
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

stop_udp_echo_server:: proc(server:^Networking_State) {
	net.close(server.sock)
	fmt.println("Closed socket")
}


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

do_udp_echo_client :: proc(client:^Networking_State) {

	str_builder:=st.builder_from_bytes(client.buffer[:])
	n :=st.write_string(&str_builder,"waffles")

	data := client.buffer[:n]
	if n == 0 || is_eol(data)  {
		return
	}

	bytes_sent, err_send :=send_udp(client,client.endpoint, data)

	sent := data[:bytes_sent]
	fmt.printfln("Client sent [ %d bytes ]: %s", len(sent), sent)
	bytes_recv, _, err_recv  := recv_udp(client, client.buffer[:])
	if err_recv != nil {
		fmt.println("Failed to receive data", err_recv)
		return
	}

	received := client.buffer[:bytes_recv]
	fmt.printfln("Client received [ %d bytes ]: %s", len(received), received)
}

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
	case ^steam.SteamNetworkingIdentity:
	}
}

do_udp_server::proc(server:^Networking_State){
	bytes_recv, remote_endpoint, err_recv := recv_udp(server, server.buffer[:])
	received := server.buffer[:bytes_recv]
	if len(received) == 0 {return}
	free_all(context.temp_allocator)
}
send_udp::proc(net_st:^Networking_State, endpoint:Endpoint, data:[]u8)->(bytes_sent:int, err_send:net.UDP_Send_Error){
	switch ep in endpoint{
		case  net.Endpoint:
			bytes_sent, err_send = net.send_udp(net_st.sock, data[:], ep)
			if err_send != nil {
				fmt.println("Failed to send data", err_send)
				return
			}
		case  ^steam.SteamNetworkingIdentity:
	}

	return
}
recv_udp::proc(net_st:^Networking_State,buff:[]u8)->(bytes_recv: int, remote_endpoint:Endpoint, err_recv: net.UDP_Recv_Error){
	bytes_recv, remote_endpoint, err_recv = net.recv_udp(net_st.sock, buff)
	if err_recv != nil {
		// fmt.println("Failed to receive data", err_recv)
		return
	}
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
