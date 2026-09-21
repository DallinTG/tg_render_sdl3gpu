package voxl_game


import "core:time"
import tg"../../../tg_render_sdl3gpu"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import "core:thread"
// import hm "../../handle_map_static_virtual"
import hm "core:container/handle_map"
import "core:container/xar"
import an"../../ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"
import st"core:strings"
import steam "../../steamworks"
import reg "../../registry"


CHUNK_SIZE::32
MAX_NUM_CHUNKS::1000 * 7
MAX_FACE_COUNT::MAX_NUM_CHUNKS * CHUNK_MAX_FACE_NUM
CHUNK_MAX_FACE_NUM:: CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE
Map::struct{
	chunks_map:map[[3]int]Chunk_HD,
	chunks:Chunks_Handle_Map,
	chunks_voxel_data:Chunks_Vox_Data_Handle_Map,
	chunks_mesh_data:Chunks_Mesh_Data_Handle_Map,

	draw_cmd_buf_hd:tg.Mesh_Handle,
	map_mesh_hd:tg.Mesh_Handle,
	chunk_shader_data:tg.Indexed_GPU_Data,
	chunks_in_mesh: xar.Freelist_Array(int, 8),

	chunck_transfer_buffer:^sdl.GPUTransferBuffer,
}
Chunks_Handle_Map::hm.Dynamic_Handle_Map(Chunk,Chunk_HD)
Chunk_HD::hm.Handle32
Chunk::struct{
	handle:				Chunk_HD,
	vox_data_hd:		Chunk_Vox_Data_HD,
	draw_cmd:			[Model_Sides]sdl.GPUIndirectDrawCommand,
	offset_in_map_mesh:	[Model_Sides]int,
	mesh_data:			[Model_Sides]Chunk_Mesh_Data_HD,
	chunk_shader_data:Chunk_Shader_Data,
	// chunk_shader_data_index:int,
}

Chunk_Shader_Data::struct{
	pos:[4]i32,
}

Chunks_Mesh_Data_Handle_Map::hm.Dynamic_Handle_Map(Chunk_Mesh_Data,Chunk_Mesh_Data_HD)
Chunk_Mesh_Data_HD::hm.Handle32

Chunk_Mesh_Data::struct{
	handle:Chunk_Mesh_Data_HD,
	data:Chunk_Mesh_Data_Raw,
}

Chunk_Mesh_Data_Raw::[dynamic;CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE]tg.Vert_Face


Chunks_Vox_Data_Handle_Map::hm.Dynamic_Handle_Map(Chunk_Vox_Data,Chunk_Vox_Data_HD)
Chunk_Vox_Data_HD::hm.Handle32

Chunk_Vox_Data_Raw::[CHUNK_SIZE][CHUNK_SIZE][CHUNK_SIZE]Voxel

Voxel::struct{
	item_hd:Item_HD,
}

Chunk_Vox_Data::struct{
	handle:Chunk_Vox_Data_HD,
	data:Chunk_Vox_Data_Raw,
}

add_chunck::proc(w_map:^Map,pos:[3]int){
	chunk_hd, chunk_ok := &w_map.chunks_map[pos]
	if !chunk_ok{ // chesvks if there is a chunk in the map if not create one
		w_map.chunks_map[pos] = {}
		chunk_hd = &w_map.chunks_map[pos]
	}
	temp_hd,temp_hd_ok:=hm.add(&w_map.chunks,Chunk{})
	if temp_hd_ok != .None{
		log.log(.Error, "add_chunck() failed to add new chunck to chunck handle map")
		return
	}
	chunk_hd^ = temp_hd
	gen_chunk_vox_data(w_map,temp_hd,pos)
	
}
remove_chunck::proc(w_map:^Map,pos:[3]int){

}
get_chunk::proc(w_map:^Map,chunk_hd:Chunk_HD)->(chunk:^Chunk,ok:bool){
	chunk, ok = hm.get(&w_map.chunks, chunk_hd) 
	return chunk, ok
}

get_chunk_vox_data::proc(w_map:^Map, vox_data_hd:Chunk_Vox_Data_HD)->(vox_data:^Chunk_Vox_Data,ok:bool){
	vox_data,ok=hm.get(&w_map.chunks_voxel_data,vox_data_hd)
	return vox_data,ok
}

gen_chunk_vox_data::proc(w_map:^Map, chunk_hd:Chunk_HD,pos:[3]int){
	chunk, ok := get_chunk(w_map,chunk_hd)
	if !ok{
		log.log(.Error, "gen_chunk_vox_data() failed invalid chunk_hd(",chunk_hd,")")
		return
	}
	vox_data,vox_data_ok:=get_chunk_vox_data(w_map,chunk.vox_data_hd)
	if !vox_data_ok {
		new_vox_data_hd,err := hm.add(&w_map.chunks_voxel_data,Chunk_Vox_Data{})
		if err !=.None{
			log.log(.Error, "gen_chunk_vox_data() has failed err = ",err,)
			return
		}
		chunk.vox_data_hd = new_vox_data_hd
		vox_data,vox_data_ok=get_chunk_vox_data(w_map,chunk.vox_data_hd)
		if !vox_data_ok {
			log.log(.Error,"gen_chunk_vox_data() has completly failed it gen a chuck chunk_hd(",chunk_hd,") problobly an alocator problobm")
			return
		}
	}
	gen_vox_data(vox_data,chunk,pos)
}

gen_vox_data::proc(vox:^Chunk_Vox_Data,chunk:^Chunk,pos:[3]int){
	chunk.chunk_shader_data.pos = {cast(i32)pos.x,cast(i32)pos.y,cast(i32)pos.z,1}

	for &plane, x in &vox.data{
		for &col, y in &plane{
			for &vox, z in &col{
				vox.item_hd = sand_hd
			}
		}
	}
}

Model_Sides::enum{
	pos_x,
	neg_x,
	pos_y,
	neg_y,
	pos_z,
	neg_z,
	extra,
}

Model_Data :: struct {
	cube_indices:[Model_Sides]int,
	extra_count:int,
}

get_chunk_mesh_data::proc(w_map:^Map, mesh_data_hd:Chunk_Mesh_Data_HD)->(mesh_data:^Chunk_Mesh_Data,ok:bool){
	mesh_data,ok=hm.get(&w_map.chunks_mesh_data,mesh_data_hd)
	return mesh_data,ok
}
mesh_chunk::proc(w_map:^Map, chunk_hd:Chunk_HD){
	chunk, ok := get_chunk(w_map,chunk_hd)
	if !ok{
		log.log(.Error, "failed invalid chunk_hd(",chunk_hd,")")
		return
	}

	vox_data,vox_data_ok:=get_chunk_vox_data(w_map,chunk.vox_data_hd)
	if !vox_data_ok{
		log.log(.Error, "failed invalid vox_data_hd(",chunk.vox_data_hd,")")
		return
	}


	for side in Model_Sides{
		mesh_data,mesh_data_ok:=get_chunk_mesh_data(w_map,chunk.mesh_data[side])
		if !mesh_data_ok{
			chunk.mesh_data[side] = hm.add(&w_map.chunks_mesh_data,Chunk_Mesh_Data{})
		}
		mesh_chunk_side(w_map,chunk.mesh_data[side], chunk.vox_data_hd,side)
	}
}


mesh_chunk_side::proc(w_map:^Map,mesh_hd:Chunk_Mesh_Data_HD, vox_data_hd:Chunk_Vox_Data_HD, side:Model_Sides){
	chunk_vox,vox_ok:=get_chunk_vox_data(w_map,vox_data_hd)
	if !vox_ok {
		log.log(.Error,"mesh_chunk_side() has failed, vox_data_hd not valid")
		return
	}
	chuck_mesh,mesh_ok:=get_chunk_mesh_data(w_map,mesh_hd)
	if !mesh_ok {
		log.log(.Error,"mesh_chunk_side() has failed, mesh_hd not valid")
		return
	}
	mesh_by_side_all(w_map,chunk_vox,chuck_mesh,side)
}

mesh_by_side_all::proc(w_map:^Map,voxls:^Chunk_Vox_Data,mesh:^Chunk_Mesh_Data,side:Model_Sides){
	clear(&mesh.data)
	for plane, x in voxls.data{
		for col, y in plane{
			for vox, z in col{
				item:=reg.get(&g.item_reg,vox.item_hd)
				if item == nil{
					log.log(.Error, "item == nil, invalid item or registry is borked item_hd(", vox.item_hd,")")
					continue
				}
				face:tg.Vert_Face
				packed_pos := pack_block_pos({cast(u16)x,cast(u16)y,cast(u16)z})
				face.block_pos = packed_pos
				face.texture_face_index = cast(u32)item.texture_face_index
				face.geometry_face_index = cast(u16)item.model_data.cube_indices[side]
				append(&mesh.data,face)
			}
		}
	}
}
pack_block_pos :: proc(pos: [3]u16) -> u16 {
    assert(pos.x < 32)
    assert(pos.y < 32)
    assert(pos.z < 32)

	return pos.x | (pos.y << 5) | (pos.z << 10)
}

init_map::proc(w_map:^Map){
	xar.freelist_init(&w_map.chunks_in_mesh)
	w_map.draw_cmd_buf_hd = tg.create_mesh(sdl.GPUIndirectDrawCommand,MAX_NUM_CHUNKS,{},type = .indirect_cmd_buff, debug_name = "w_map GPUIndirectDrawCommand buffer")
	w_map.chunk_shader_data.mesh_hd = tg.create_mesh(Chunk_Shader_Data,MAX_NUM_CHUNKS,{},type = .dynamic_buff, debug_name = "Chunk shader data buffer")
	w_map.map_mesh_hd = tg.create_mesh(tg.Vert_Face,MAX_FACE_COUNT,{},type = .no_tranfer_buff, debug_name = "w_map Chunk buffer mesh")
	w_map.chunck_transfer_buffer = sdl.CreateGPUTransferBuffer(s.gpu_device,{
		usage = .UPLOAD,
		size = cast(u32)(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE * size_of(tg.Vert_Face)),
	})
	for x in -4..=4{
		for y in -4..=4{
			for z in -4..=4{
				add_chunck(w_map,{x,y,z})
			} 
		} 
	} 
}

mesh_map::proc(w_map:^Map){
	itor:=hm.iterator_make(&w_map.chunks)
	loop:for chunk, chunk_hd in hm.iterate(&itor) {
		mesh_chunk(w_map, chunk_hd)
	}
}

upload_chunks_to_gpu::proc(w_map:^Map){
	itor:=hm.iterator_make(&w_map.chunks)
	loop:for chunk, chunk_hd in hm.iterate(&itor) {
		upload_chunk_to_gpu(w_map, chunk_hd)
	}
}

upload_chunk_to_gpu::proc(w_map:^Map, chunk_hd:Chunk_HD){
	chunk, ok := get_chunk(w_map,chunk_hd)
	if !ok{
		log.log(.Error, "failed invalid chunk_hd(",chunk_hd,")")
		return
	}
	for mesh_hd, side in chunk.mesh_data{
		chunk_mesh,mesh_ok:=get_chunk_mesh_data(w_map,mesh_hd)
		if !mesh_ok {continue}
		upload_chunk_side_to_gpu(w_map,chunk,chunk_mesh,side)
	}
}

upload_chunk_side_to_gpu::proc(w_map:^Map, chunk:^Chunk, mesh:^Chunk_Mesh_Data, side:Model_Sides){
	ptr,index,err := xar.freelist_push_with_index(&w_map.chunks_in_mesh,1)
	if err != .None{
		log.log(.Error, "upload_chunk_side_to_gpu() failed xar.freelist_push_with_index() alocation err")
		return
	}
	chunk.offset_in_map_mesh[side] = index
	first_face:=cast(u32)index*CHUNK_MAX_FACE_NUM

	// chunk.chunk_shader_data_index = index

	upload_data_to_mesh_by_offset(w_map.map_mesh_hd,w_map.chunck_transfer_buffer,mesh.data[:],first_face)
	chunk.draw_cmd[side].num_vertices = cast(u32)len(mesh.data[:])*6
	chunk.draw_cmd[side].first_vertex = first_face *6
	chunk.draw_cmd[side].num_instances = 1 
	// chunk.draw_cmd[side].first_instance = 0 + cast(u32)index

}

upload_data_to_mesh_by_offset::proc(mesh_hd:tg.Mesh_Handle,transfer_buffer:^sdl.GPUTransferBuffer,vertices:$T/[]$E,offset:u32){
	mesh:=tg.get_mesh(mesh_hd)
	vertices_byte_size := len(vertices)*size_of(E)
	offset_byte_size:=offset*size_of(E)
	transfer_mem := transmute([^]byte)sdl.MapGPUTransferBuffer(s.gpu_device, transfer_buffer, cycle = false)

	copy(transfer_mem[:vertices_byte_size],mem.slice_to_bytes(vertices[:]))

	sdl.UnmapGPUTransferBuffer(s.gpu_device, transfer_buffer)
	copy_cmd_buf:=sdl.AcquireGPUCommandBuffer(s.gpu_device)	
	copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)
	
	if vertices_byte_size > 0 {
		sdl.UploadToGPUBuffer(
			copy_pass = copy_pass,
			source = {
				transfer_buffer = transfer_buffer,
				offset = 0,
			},
			destination = {
				buffer = mesh.gpu.vertex_buf, 
				size = cast(u32)vertices_byte_size,
				offset = offset_byte_size,
			},
			cycle = false,
		)
	}

	sdl.EndGPUCopyPass(copy_pass)
	ok := sdl.SubmitGPUCommandBuffer(copy_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")
}

update_w_map_draw_cmds_buff::proc(w_map:^Map){
	itor:=hm.iterator_make(&w_map.chunks)
	mesh:=tg.get_mesh(w_map.draw_cmd_buf_hd)
	chunck_shader_data:=tg.get_mesh(w_map.chunk_shader_data.mesh_hd)
	w_map.chunk_shader_data.count = 0
	tg.clear_mesh_cpu(&mesh.cpu)
	tg.clear_mesh_cpu(&chunck_shader_data.cpu)
	loop:for chunk, chunk_hd in hm.iterate(&itor) {
		for draw_cmd, side in chunk.draw_cmd{
			if draw_cmd.num_vertices > 0{
				draw_cmd_:[1]sdl.GPUIndirectDrawCommand=draw_cmd
				tg.append_to_mesh(&mesh.cpu,{},draw_cmd_[:])
	
				chunck_shader_data_:[1]Chunk_Shader_Data=chunk.chunk_shader_data
				tg.append_to_mesh(&chunck_shader_data.cpu,{},chunck_shader_data_[:])
				w_map.chunk_shader_data.count+=1

			}
		}
	}
	tg.update_mesh(w_map.draw_cmd_buf_hd)
	tg.update_mesh(w_map.chunk_shader_data.mesh_hd)
}


render_map::proc(w_map:^Map){
	tg.do_render_pass(&g.vox_pass, &g.cam, {w_map.map_mesh_hd},{&g.texture_facees,&g.geometry_facees, &w_map.chunk_shader_data}, {w_map.draw_cmd_buf_hd},type = .face)
}
