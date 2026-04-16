package tg_render

import "core:fmt"
import "core:net"

udp_echo_server :: proc(ip: string, port: int) {
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
	buffer: [256]u8
	for {
		bytes_recv, remote_endpoint, err_recv := net.recv_udp(sock, buffer[:])
		if err_recv != nil {
			fmt.println("Failed to receive data", err_recv)
		}
		received := buffer[:bytes_recv]
		fmt.printfln("Server received from %s", net.endpoint_to_string(remote_endpoint))
		fmt.printfln("Received data [ %d bytes ]: %s", len(received), received)
		bytes_sent, err_send := net.send_udp(sock, received, remote_endpoint)
		if err_send != nil {
			fmt.println("Failed to send data", err_send)
		}
		sent := received[:bytes_sent]
		fmt.printfln("Server sent [ %d bytes ]: %s", len(sent), sent)
		
		// `net.endpoint_to_string` creates temporarily-allocated string
		free_all(context.temp_allocator)
	}
	net.close(sock)
	fmt.println("Closed socket")
}

Server::struct{
	is_up:bool,
	ip: string,
	port: int,
	endpoint: net.Endpoint,
	sock: net.UDP_Socket,
	buffer:[256]u8,
}

init_udp_echo_server :: proc(ip: string, port: int) ->(server:Server){

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
	server.is_up = true
	server.ip = ip
	server.port = port
	server.endpoint = endpoint
	server.sock = sock
	// buffer: [256]u8
	return
}

do_udp_echo_server:: proc(server:^Server) {
	bytes_recv, remote_endpoint, err_recv := net.recv_udp(server.sock, server.buffer[:])
	if err_recv != nil {
		fmt.println("Failed to receive data", err_recv)
	}
	received := server.buffer[:bytes_recv]
	fmt.printfln("Server received from %s", net.endpoint_to_string(remote_endpoint))
	fmt.printfln("Received data [ %d bytes ]: %s", len(received), received)
	if len(received) == 0 {return}
	bytes_sent, err_send := net.send_udp(server.sock, received, remote_endpoint)
	if err_send != nil {
		fmt.println("Failed to send data", err_send)
	}
	sent := received[:bytes_sent]
	fmt.printfln("Server sent [ %d bytes ]: %s", len(sent), sent)
	
	// `net.endpoint_to_string` creates temporarily-allocated string
	free_all(context.temp_allocator)
}

stop_udp_echo_server:: proc(server:^Server) {
	net.close(server.sock)
	fmt.println("Closed socket")
}
// main :: proc() {
// 	udp_echo_server("127.0.0.1", 8080)
// }
