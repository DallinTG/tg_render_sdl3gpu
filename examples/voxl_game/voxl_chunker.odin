package voxl_game

import "base:runtime"

import "core:time"
import tg"../../../tg_render_sdl3gpu"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:math"
import "core:math/rand"
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
import atom "core:sync"
import nos "core:math/noise"

Vox_Render_Settings::struct{
	do_chunk_back_face_culling:bool,
	do_chunk_frustum_culling:bool,
}
DF_VOX_RENDER_SETTINGS:Vox_Render_Settings:{
	do_chunk_back_face_culling = true,
	do_chunk_frustum_culling = true,
}
Vox_Render_Debug_Info::struct{

	chunks_map_len:			int,
	chunks_len:				int,
	chunks_voxel_data_len:	int,
	chunks_mesh_data_len:	int,

	// draw_cmd_buf_hd:tg.Mesh_Handle,
	// map_mesh_hd:tg.Mesh_Handle,
	// chunk_shader_data:tg.Indexed_GPU_Data,


	// Map Qs_____________________________________
	gen_chunk_q_len:		int,
	destroy_chunk_q_len:	int,
	gen_vox_data_q_len:		int,
	destroy_vox_data_q_len:	int,
	gen_mesh_data_q_len:	int,
	destroy_mesh_data_q_len:int,
	upload_mesh_data_q_len:	int,

}

// CHUNK_SIZE::32
// MAX_NUM_CHUNKS::1000 * 7
// MAX_FACE_COUNT::MAX_NUM_CHUNKS * CHUNK_MAX_FACE_NUM
// CHUNK_MAX_FACE_NUM:: CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE

// MAX_NUM_OF_MAP_MESH_SECTIONS ::  NUM_OF_FACES_PER_MAP_MESH_SECTIONS * 2 * CHUNK_SIZE * MAX_NUM_CHUNKS
// NUM_OF_FACES_PER_MAP_MESH_SECTIONS :: CHUNK_SIZE * CHUNK_SIZE / 2
// 
CHUNK_SIZE::32
MAX_NUM_CHUNKS::35000 * 7
MAX_FACE_COUNT::MAX_NUM_CHUNKS * CHUNK_MAX_FACE_NUM
CHUNK_MAX_FACE_NUM::  CHUNK_SIZE * CHUNK_SIZE / 2
MAX_NUM_DRAW_CMD_BUF::MAX_NUM_CHUNKS / 8
// MAX_NUM_OF_MAP_MESH_SECTIONS ::  NUM_OF_FACES_PER_MAP_MESH_SECTIONS * 2 * CHUNK_SIZE * MAX_NUM_CHUNKS
// NUM_OF_FACES_PER_MAP_MESH_SECTIONS :: CHUNK_SIZE * CHUNK_SIZE / 2
Map::struct{
	chunks_map:map[[3]int]Chunk_HD,
	chunks:Chunks_Handle_Map,
	chunks_voxel_data:Chunks_Vox_Data_Handle_Map,
	chunks_mesh_data:Chunks_Mesh_Data_Handle_Map,

	draw_cmd_buf_hd:tg.Mesh_Handle,
	map_mesh_hd:tg.Mesh_Handle,
	chunk_shader_data:tg.Indexed_GPU_Data,

	// chunks_in_mesh: xar.Freelist_Array(int, 8),
	chunks_in_mesh:tg.Free_List,

	chunck_transfer_buffer:^sdl.GPUTransferBuffer,

	// Map Qs_____________________________________
	gen_chunk_q:Gen_Chunk_Q,
	destroy_chunk_q:Destroy_Chunk_Q, 

	gen_vox_data_q:Gen_Vox_Data_Q,
	destroy_vox_data_q:Destroy_Vox_Data_Q,
	gen_mesh_data_q:Gen_Mesh_Data_Q,
	destroy_mesh_data_q:Destroy_Mesh_Data_Q,
	upload_mesh_data_q:Upload_Mesh_Data_Q
}


Chunks_Handle_Map::hm.Dynamic_Handle_Map(Chunk,Chunk_HD)
Chunk_HD::distinct hm.Handle32
Chunk::struct{
	handle:				Chunk_HD,
	vox_data_hd:		Chunk_Vox_Data_HD,
	draw_cmd:			[Model_Sides]sdl.GPUIndirectDrawCommand,
	// offset_in_map_mesh:	[Model_Sides]int,
	range_in_map_mesh:	[Model_Sides]tg.Free_List_Range,
	mesh_data:			[Model_Sides]Chunk_Mesh_Data_HD,
	chunk_shader_data:Chunk_Shader_Data,
	// chunk_shader_data_index:int,
}

Chunk_Shader_Data::struct{
	pos:[4]i32,
}

Chunks_Mesh_Data_Handle_Map::hm.Dynamic_Handle_Map(Chunk_Mesh_Data,Chunk_Mesh_Data_HD)
Chunk_Mesh_Data_HD::distinct hm.Handle32

Chunk_Mesh_Data::struct{
	handle:Chunk_Mesh_Data_HD,
	data:Chunk_Mesh_Data_Raw,
	face_count:int
}

Chunk_Mesh_Data_Raw::[CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE]tg.Vert_Face


Chunks_Vox_Data_Handle_Map::hm.Dynamic_Handle_Map(Chunk_Vox_Data,Chunk_Vox_Data_HD)
Chunk_Vox_Data_HD::distinct hm.Handle32

Chunk_Vox_Data_Raw::[CHUNK_SIZE][CHUNK_SIZE][CHUNK_SIZE]Voxel

Voxel::struct{
	item_hd:Item_HD,
}

Chunk_Vox_Data::struct{
	handle:Chunk_Vox_Data_HD,
	data:Chunk_Vox_Data_Raw,
    // mask[y][z]   bit x = solid at [x][y][z]
	is_solid_mask: [CHUNK_SIZE][CHUNK_SIZE]bit_set[u32(0)..<CHUNK_SIZE; u32],
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


Model_Sides::enum{
	pos_x,
	neg_x,
	pos_y,
	neg_y,
	pos_z,
	neg_z,
	extra,
}

get_chunk_mesh_data::proc(w_map:^Map, mesh_data_hd:Chunk_Mesh_Data_HD)->(mesh_data:^Chunk_Mesh_Data,ok:bool){
	mesh_data,ok=hm.get(&w_map.chunks_mesh_data,mesh_data_hd)
	return mesh_data,ok
}

pack_block_pos :: proc(pos: [3]u16) -> u16 {
    assert(pos.x < 32)
    assert(pos.y < 32)
    assert(pos.z < 32)

	return pos.x | (pos.y << 5) | (pos.z << 10)
}

init_map::proc(w_map:^Map){
	// xar.freelist_init(&w_map.chunks_in_mesh)
	tg.free_list_init(&w_map.chunks_in_mesh,MAX_NUM_CHUNKS)
	w_map.draw_cmd_buf_hd = tg.create_mesh(sdl.GPUIndirectDrawCommand,MAX_NUM_CHUNKS,{},type = .indirect_cmd_buff, debug_name = "w_map GPUIndirectDrawCommand buffer")
	w_map.chunk_shader_data.mesh_hd = tg.create_mesh(Chunk_Shader_Data,MAX_NUM_CHUNKS,{},type = .dynamic_buff, debug_name = "Chunk shader data buffer")
	w_map.map_mesh_hd = tg.create_mesh(tg.Vert_Face,MAX_FACE_COUNT,{},type = .no_tranfer_buff, debug_name = "w_map Chunk buffer mesh")
	w_map.chunck_transfer_buffer = sdl.CreateGPUTransferBuffer(s.gpu_device,{
		usage = .UPLOAD,
		size = cast(u32)(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE * size_of(tg.Vert_Face)),
	})
	// for x in -26..=26{
	// 	for y in -1..=1{
	// 		for z in -26..=26{
	// 			add_to_gen_chunk_q(w_map,{x,y,z})
	// 		} 
	// 	} 
	// } 
}

q_up_chunks_around_pos::proc(w_map:^Map,pos:[3]f32,rad:int=6,){
	chunck_pos:=pos_to_chunck_pos(pos)
	for x in (-1*rad) + chunck_pos.x ..=rad + chunck_pos.x{
		for y in (-1*rad) + chunck_pos.y ..=rad + chunck_pos.y{
			for z in (-1*rad) + chunck_pos.z ..=rad + chunck_pos.z{
				key:[3]int={x,y,z}
				ok := key in w_map.chunks_map
				if !ok{
					add_to_gen_chunk_q(w_map,{x,y,z})
				}
			} 
		} 
	} 
}

// mesh_map::proc(w_map:^Map){
// 	itor:=hm.iterator_make(&w_map.chunks)
// 	loop:for chunk, chunk_hd in hm.iterate(&itor) {
		// mesh_chunk(w_map, chunk_hd)
// 	}
// }



update_w_map_draw_cmds_buff::proc(w_map:^Map,cam:^tg.Camera){
	itor:=hm.iterator_make(&w_map.chunks)
	mesh:=tg.get_mesh(w_map.draw_cmd_buf_hd)
	chunck_shader_data:=tg.get_mesh(w_map.chunk_shader_data.mesh_hd)
	w_map.chunk_shader_data.count = 0
	tmep_full_count:int
	tg.clear_mesh_cpu(&mesh.cpu)
	tg.clear_mesh_cpu(&chunck_shader_data.cpu)
	view_mat, proj_mat:=tg.make_view_mat_proj_mat(cam)
	frustum:=make_frustum(view_mat, proj_mat)
	loop:for chunk, chunk_hd in hm.iterate(&itor) {
		cam_chunk_pos:=pos_to_chunck_pos(cam.pos)

		if should_cull_chunk(&frustum,chunk.chunk_shader_data.pos.xyz){
			continue
		}

		for draw_cmd, side in chunk.draw_cmd{

			tmep_full_count+=1
			if draw_cmd.num_vertices == 0{
				continue
			}
			if should_cull_chunk_side(side,chunk.chunk_shader_data.pos.xyz, cast([3]i32)cam_chunk_pos){
				continue
			}
			draw_cmd_:[1]sdl.GPUIndirectDrawCommand=draw_cmd
			tg.append_to_mesh(&mesh.cpu,{},draw_cmd_[:])
			chunck_shader_data_:[1]Chunk_Shader_Data=chunk.chunk_shader_data
			tg.append_to_mesh(&chunck_shader_data.cpu,{},chunck_shader_data_[:])
			// log.log(.Debug,"draw_cmd",draw_cmd,"chunck_shader_data_",chunck_shader_data_)
			w_map.chunk_shader_data.count+=1

		}
	}
	// log.log(.Debug,"cmd count",w_map.chunk_shader_data.count,"tmep_full_count",tmep_full_count)
	tg.update_mesh(w_map.draw_cmd_buf_hd)
	tg.update_mesh(w_map.chunk_shader_data.mesh_hd)
}

should_cull_chunk_side::proc(side:Model_Sides, chunk_pos:[3]i32, cam_chunk_pos:[3]i32)->(cull:bool){
    if !g.settings.do_chunk_back_face_culling{return}

    switch side{
    case .pos_x:
        if chunk_pos.x > cam_chunk_pos.x {cull = true}

    case .neg_x:
        if chunk_pos.x < cam_chunk_pos.x {cull = true}

    case .pos_y:
        if chunk_pos.y > cam_chunk_pos.y {cull = true}

    case .neg_y:
        if chunk_pos.y < cam_chunk_pos.y {cull = true}

    case .pos_z:
        if chunk_pos.z > cam_chunk_pos.z {cull = true}

    case .neg_z:
        if chunk_pos.z < cam_chunk_pos.z {cull = true}

    case .extra:
    }

    return cull
}
pos_to_chunck_pos::proc(pos:[3]f32)->(chunk_pos:[3]int){	
	chunk_pos.x = cast(int)math.floor(pos.x / CHUNK_SIZE)
	chunk_pos.y = cast(int)math.floor(pos.y / CHUNK_SIZE)
	chunk_pos.z = cast(int)math.floor(pos.z / CHUNK_SIZE)
	return
}

Frustum_Plane :: struct {
    normal: [3]f32,
    distance: f32,
}

Frustum :: struct {
    planes: [6]Frustum_Plane,
}

make_frustum :: proc(view_mat: tg.Mat4, proj_mat: tg.Mat4) -> Frustum {
    frustum: Frustum

    vp := proj_mat * view_mat

    // Left
    frustum.planes[0].normal = {
        vp[0][3] + vp[0][0],
        vp[1][3] + vp[1][0],
        vp[2][3] + vp[2][0],
    }
    frustum.planes[0].distance = vp[3][3] + vp[3][0]

    // Right
    frustum.planes[1].normal = {
        vp[0][3] - vp[0][0],
        vp[1][3] - vp[1][0],
        vp[2][3] - vp[2][0],
    }
    frustum.planes[1].distance = vp[3][3] - vp[3][0]

    // Bottom
    frustum.planes[2].normal = {
        vp[0][3] + vp[0][1],
        vp[1][3] + vp[1][1],
        vp[2][3] + vp[2][1],
    }
    frustum.planes[2].distance = vp[3][3] + vp[3][1]

    // Top
    frustum.planes[3].normal = {
        vp[0][3] - vp[0][1],
        vp[1][3] - vp[1][1],
        vp[2][3] - vp[2][1],
    }
    frustum.planes[3].distance = vp[3][3] - vp[3][1]

    // Near
    // Vulkan / SDL_GPU depth range: 0 <= z <= w
    frustum.planes[4].normal = {
        vp[0][2],
        vp[1][2],
        vp[2][2],
    }
    frustum.planes[4].distance = vp[3][2]

    // Far
    frustum.planes[5].normal = {
        vp[0][3] - vp[0][2],
        vp[1][3] - vp[1][2],
        vp[2][3] - vp[2][2],
    }
    frustum.planes[5].distance = vp[3][3] - vp[3][2]

    // Normalize all planes.
    for &plane in &frustum.planes {
        length := math.sqrt(
            plane.normal.x * plane.normal.x +
            plane.normal.y * plane.normal.y +
            plane.normal.z * plane.normal.z,
        )

        if length > 0 {
            plane.normal /= length
            plane.distance /= length
        }
    }

    return frustum
}


should_cull_chunk :: proc(
    frustum: ^Frustum,
    chunk_pos: [3]i32,
) -> bool {
	if !g.settings.do_chunk_frustum_culling {return false}
    min_pos: [3]f32 = {
        cast(f32)chunk_pos.x * cast(f32)CHUNK_SIZE,
        cast(f32)chunk_pos.y * cast(f32)CHUNK_SIZE,
        cast(f32)chunk_pos.z * cast(f32)CHUNK_SIZE,
    }

    max_pos: [3]f32 = {
        min_pos.x + cast(f32)CHUNK_SIZE,
        min_pos.y + cast(f32)CHUNK_SIZE,
        min_pos.z + cast(f32)CHUNK_SIZE,
    }

    for plane in frustum.planes {

        p: [3]f32

        if plane.normal.x >= 0 {
            p.x = max_pos.x
        } else {
            p.x = min_pos.x
        }

        if plane.normal.y >= 0 {
            p.y = max_pos.y
        } else {
            p.y = min_pos.y
        }

        if plane.normal.z >= 0 {
            p.z = max_pos.z
        } else {
            p.z = min_pos.z
        }

        distance :=
            plane.normal.x * p.x +
            plane.normal.y * p.y +
            plane.normal.z * p.z +
            plane.distance

        if distance < 0 {
            return true
        }
    }

    return false
}

render_map::proc(w_map:^Map){
	tg.do_render_pass(&g.vox_pass, &g.cam, {w_map.map_mesh_hd},{&g.texture_facees,&g.geometry_facees, &w_map.chunk_shader_data}, {w_map.draw_cmd_buf_hd},type = .face)
}



Q_State::enum{
	building,
	usable,
	finished,
}
manage_all_w_map_q::proc(w_map:^Map){

	get_w_map_debug_info(w_map)

	manage_gen_chunk_q(w_map)
	manage_Destroy_chunk_q(w_map)
	manage_gen_vox_data_q(w_map)
	manage_Destroy_vox_data_q(w_map)
	manage_gen_mesh_data_q(w_map)
	manage_destroy_mesh_data_q(w_map)
	manage_upload_mesh_data_q(w_map)
	manage_unload_mesh_data_q(w_map)
	// log.log(.Debug,"\n",
	// 	"gen_chunk_q",hm.len(g.w_map.gen_chunk_q),"\n",
	// 	"destroy_chunk_q",hm.len(g.w_map.destroy_chunk_q),"\n",
	// 	"gen_vox_data_q",hm.len(g.w_map.gen_vox_data_q),"\n",
	// 	"destroy_vox_data_q",hm.len(g.w_map.destroy_vox_data_q),"\n",
	// 	"gen_mesh_data_q",hm.len(g.w_map.gen_mesh_data_q),"\n",
	// 	"destroy_mesh_data_q",hm.len(g.w_map.destroy_mesh_data_q),"\n",
	// 	"upload_mesh_data_q",hm.len(g.w_map.upload_mesh_data_q),"\n",
	// )
}

get_w_map_debug_info::proc(w_map:^Map){
	g.debug_info.gen_chunk_q_len 		= cast(int)hm.len(w_map.gen_chunk_q)
	g.debug_info.gen_vox_data_q_len 	= cast(int)hm.len(w_map.gen_vox_data_q)
	g.debug_info.gen_mesh_data_q_len 	= cast(int)hm.len(w_map.gen_mesh_data_q)
	g.debug_info.destroy_mesh_data_q_len= cast(int)hm.len(w_map.destroy_mesh_data_q)
	g.debug_info.upload_mesh_data_q_len = cast(int)hm.len(w_map.upload_mesh_data_q)

	g.debug_info.chunks_map_len			= cast(int)len(w_map.chunks_map)
	g.debug_info.chunks_len				= cast(int)hm.len(w_map.chunks)
	g.debug_info.chunks_voxel_data_len	= cast(int)hm.len(w_map.chunks_voxel_data)
	g.debug_info.chunks_mesh_data_len	= cast(int)hm.len(w_map.chunks_mesh_data)
}

Gen_Chunk_Q::hm.Dynamic_Handle_Map(Gen_Chunk_Q_Data,Gen_Chunk_Q_HD)
Gen_Chunk_Q_HD::distinct hm.Handle32
Gen_Chunk_Q_Data::struct{
	handle:Gen_Chunk_Q_HD,
	pos:[3]int,
	q_state:Q_State,
}
manage_gen_chunk_q::proc(w_map:^Map){

	it := hm.iterator_make(&w_map.gen_chunk_q)
	for q, q_hd in hm.iterate(&it) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .finished {
			hm.remove(&w_map.gen_chunk_q,q_hd)
		}
	}

	it_2 := hm.iterator_make(&w_map.gen_chunk_q)
	for q, q_hd in hm.iterate(&it_2) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .usable {
			do_a_gen_chunk_q(w_map,q_hd)
		}
	}
}
add_to_gen_chunk_q::proc(w_map:^Map,pos:[3]int)->(q_hd:Gen_Chunk_Q_HD){
	err:runtime.Allocator_Error
	q_hd,err=hm.add(&w_map.gen_chunk_q, Gen_Chunk_Q_Data{pos = pos})
	q,q_ok:=hm.get(&w_map.gen_chunk_q,q_hd)
	assert(q_ok,"failed to ad to q i have know idea how this culd posbly happen what did you do!!!!!!! ")
	atom.atomic_store_explicit(&q.q_state, .usable, .Release)
	return
}
do_a_gen_chunk_q::proc(w_map:^Map,hd:Gen_Chunk_Q_HD){
	q,ok:=hm.get(&w_map.gen_chunk_q,hd)
	if ok{
		add_chunck(w_map,q.pos)
		atom.atomic_store_explicit(&q.q_state, .finished, .Release)
	}
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
	add_to_gen_vox_data_q(w_map,temp_hd,pos)
	// gen_chunk_vox_data(w_map,temp_hd,pos)
	
}

Destroy_Chunk_Q::hm.Dynamic_Handle_Map(Destroy_Chunk_Q_Data,Destroy_Chunk_HD)
Destroy_Chunk_HD::distinct hm.Handle32
Destroy_Chunk_Q_Data::struct{
	handle:Destroy_Chunk_HD,
	data_hd:Chunk_Vox_Data_HD,
	q_state:Q_State,
}
manage_Destroy_chunk_q::proc(w_map:^Map){}
add_to_destroy_chunk_q::proc(w_map:^Map){}
do_a_destroyn_chunk_q::proc(w_map:^Map,hd:Destroy_Vox_Data_HD){}


Gen_Vox_Data_Q::hm.Dynamic_Handle_Map(Gen_Vox_Data_Q_Data,Gen_Vox_Data_Q_HD)
Gen_Vox_Data_Q_HD::distinct hm.Handle32
Gen_Vox_Data_Q_Data::struct{
	handle:Gen_Vox_Data_Q_HD,
	pos:[3]int,
	data_hd:Chunk_HD,
	q_state:Q_State,
}
manage_gen_vox_data_q::proc(w_map:^Map){

	it := hm.iterator_make(&w_map.gen_vox_data_q)
	for q, q_hd in hm.iterate(&it) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .finished {
			hm.remove(&w_map.gen_vox_data_q,q_hd)
		}
	}

	it_2 := hm.iterator_make(&w_map.gen_vox_data_q)
	for q, q_hd in hm.iterate(&it_2) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .usable  {
			do_a_gen_vox_data_q(w_map,q_hd)
		}
	}
}
add_to_gen_vox_data_q::proc(w_map:^Map,chunk_hd:Chunk_HD,pos:[3]int)->(q_hd:Gen_Vox_Data_Q_HD){
	err:runtime.Allocator_Error
	q_hd,err=hm.add(&w_map.gen_vox_data_q, Gen_Vox_Data_Q_Data{data_hd = chunk_hd,pos = pos})
	q,q_ok:=hm.get(&w_map.gen_vox_data_q,q_hd)
	assert(q_ok,"failed to ad to q i have know idea how this culd posbly happen what did you do!!!!!!! ")
	atom.atomic_store_explicit(&q.q_state, .usable, .Release)
	return
}
do_a_gen_vox_data_q::proc(w_map:^Map,hd:Gen_Vox_Data_Q_HD){
	q,ok:=hm.get(&w_map.gen_vox_data_q,hd)
	if ok{
		gen_chunk_vox_data(w_map,q.data_hd,q.pos)
		atom.atomic_store_explicit(&q.q_state, .finished, .Release)
	}
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
	for side in Model_Sides{
		opposite_side:=side
		key:=pos
		switch side{
		case .pos_x:
			key += {1,0,0}
			opposite_side = .neg_x
		case .neg_x:
			key += {-1,0,0}
			opposite_side = .pos_x
		case .pos_y:
			key += {0,1,0}
			opposite_side = .neg_y
		case .neg_y:
			key += {0,-1,0}
			opposite_side = .pos_y
		case .pos_z:
			key += {0,0,1}
			opposite_side = .neg_z
		case .neg_z:
			key += {0,0,-1}
			opposite_side = .pos_z
		case .extra:
			return //TODO NOT USING EXTRA Sides yet
		}
		neighbor_chunk_hd, ok := w_map.chunks_map[key]
		if !ok{
			continue
		}
		neighbor_chunk,neighbor_chunk_ok:=get_chunk(w_map,neighbor_chunk_hd)
		if !neighbor_chunk_ok{
			continue
		}
		neighbor_vox_data,neighbor_vox_data_ok:=get_chunk_vox_data(w_map,neighbor_chunk.vox_data_hd)
		if !neighbor_vox_data_ok{
			continue
		}
		// when adding to the meshing q wee need to now treat the curent chunk as the neihbor and the neighbor as the curent chunk
		// and also send the opisit side of the curent side

		// Mesh the chunk itself
		add_to_gen_mesh_data_q(
		    w_map = w_map,
		    chunk_hd = chunk_hd,
		    vox_data_hd = chunk.vox_data_hd,
		    neighbor_vox_hd = neighbor_chunk.vox_data_hd,
		    side = side,
		)
		// Mesh the neighbor too
		add_to_gen_mesh_data_q(
			w_map = w_map,
			chunk_hd = neighbor_chunk_hd,
			vox_data_hd = neighbor_chunk.vox_data_hd,
			neighbor_vox_hd = chunk.vox_data_hd,
			side = opposite_side,
		)
	}
}

// gen_vox_data::proc(vox_chunk:^Chunk_Vox_Data,chunk:^Chunk,pos:[3]int){
// 	chunk.chunk_shader_data.pos = {cast(i32)pos.x,cast(i32)pos.y,cast(i32)pos.z,1}

// 	for &plane, x in &vox_chunk.data{
// 		for &col, y in &plane{
		
// 			// vox := &col[1]
// 			// z:=1
// 			for &vox, z in &col{
// 				world_y := y + chunk_y * CHUNK_SIZE
// 				hight :=nos.noise_2d(6223378936854776807,{cast(f64)x*.1,cast(f64)z*.1}) 
// 				// fmt.print(hight,"\n")
// 				// val:=rand.int_range(0,100)
// 				if (hight*.1)+(cast(f32)y * cast(f32)pos.y)>0{

// 					vox.item_hd = sand_hd
// 					vox_chunk.is_solid_mask[y][z] += {u32(x)}
// 				}
// 			}
			
// 		}
// 	}
// }


// gen_vox_data :: proc(
// 	vox_chunk: ^Chunk_Vox_Data,
// 	chunk: ^Chunk,
// 	pos: [3]int,
// ) {
// 	chunk.chunk_shader_data.pos = {cast(i32)pos.x,cast(i32)pos.y,cast(i32)pos.z,1}
// 	scl:=.01
// 	for &plane, x in &vox_chunk.data {
// 		for &col, y in &plane {
// 			for &vox, z in &col {

// 				world_y := y + pos.y * CHUNK_SIZE
// 				world_x := x + pos.x * CHUNK_SIZE
// 				world_z := z + pos.z * CHUNK_SIZE

// 				height := nos.noise_2d(
// 					6223378936854776807,
// 					{
// 						cast(f64)world_x * scl,
// 						cast(f64)world_z * scl,
// 					},
// 				)

// 				terrain_height := height * 10.0

// 				if cast(f32)world_y < terrain_height {
// 					vox.item_hd = sand_hd
// 					vox_chunk.is_solid_mask[y][z] += {u32(x)}
// 				}
// 			}
// 		}
// 	}
// }


// gen_vox_data :: proc(
// 	vox_chunk: ^Chunk_Vox_Data,
// 	chunk: ^Chunk,
// 	pos: [3]int,
// ) {
// 	chunk.chunk_shader_data.pos = {
// 		cast(i32)pos.x,
// 		cast(i32)pos.y,
// 		cast(i32)pos.z,
// 		1,
// 	}
	
// 	xz_scl:=.01
// 	y_scl:f32=30

// 	world_x_start := pos.x * CHUNK_SIZE
// 	world_y_start := pos.y * CHUNK_SIZE
// 	world_z_start := pos.z * CHUNK_SIZE

// 	for x := 0; x < CHUNK_SIZE; x += 1 {
// 		world_x := world_x_start + x

// 		for z := 0; z < CHUNK_SIZE; z += 1 {
// 			world_z := world_z_start + z

// 			height := nos.noise_2d(
// 				6223378936854776807,
// 				{
// 					cast(f64)world_x * xz_scl,
// 					cast(f64)world_z * xz_scl,
// 				},
// 			)

// 			terrain_height := height * y_scl

// 			for y := 0; y < CHUNK_SIZE; y += 1 {
// 				world_y := world_y_start + y

// 				if cast(f32)world_y < terrain_height {
// 					vox_chunk.data[x][y][z].item_hd = sand_hd
// 					vox_chunk.is_solid_mask[y][z] += {u32(x)}
// 				}
// 			}
// 		}
// 	}
// }

gen_vox_data :: proc(
	vox_chunk: ^Chunk_Vox_Data,
	chunk: ^Chunk,
	pos: [3]int,
) {
	chunk.chunk_shader_data.pos = {
		cast(i32)pos.x,
		cast(i32)pos.y,
		cast(i32)pos.z,
		1,
	}

	xz_scl: f64 = 0.01
	y_scl: f64 = 30.0

	world_x_start := pos.x * CHUNK_SIZE
	world_y_start := pos.y * CHUNK_SIZE
	world_z_start := pos.z * CHUNK_SIZE

	for x := 0; x < CHUNK_SIZE; x += 1 {
		world_x := world_x_start + x
		x_bit := u32(1) << u32(x)

		for z := 0; z < CHUNK_SIZE; z += 1 {
			world_z := world_z_start + z

			height := nos.noise_2d(
				6223378936854776807,
				{
					cast(f64)world_x * xz_scl,
					cast(f64)world_z * xz_scl,
				},
			)

			// Number of solid blocks in this column.
			solid_height := cast(int)(height * cast(f32)y_scl) - world_y_start

			// Entire column is above the terrain.
			if solid_height <= 0 {
				continue
			}

			// Terrain extends through the entire chunk.
			if solid_height > CHUNK_SIZE {
				solid_height = CHUNK_SIZE
			}

			for y := 0; y < solid_height; y += 1 {
				vox_chunk.data[x][y][z].item_hd = g.df_items[.grass]
				vox_chunk.is_solid_mask[y][z] |=  {u32(x)}
			}
		}
	}
}


Destroy_Vox_Data_Q::hm.Dynamic_Handle_Map(Destroy_Vox_Data_Q_Data,Destroy_Vox_Data_HD)
Destroy_Vox_Data_HD::distinct hm.Handle32
Destroy_Vox_Data_Q_Data::struct{
	handle:Destroy_Vox_Data_HD,
	data_hd:Chunk_Vox_Data_HD,
	q_state:Q_State,
}
manage_Destroy_vox_data_q::proc(w_map:^Map){}
add_to_destroy_vox_data_q::proc(w_map:^Map){}
do_a_destroyn_vox_data_q::proc(w_map:^Map,hd:Destroy_Vox_Data_HD){}

Gen_Mesh_Data_Q::hm.Dynamic_Handle_Map(Gen_Mesh_Data_Q_Data,Gen_Mesh_Data_Q_HD)
Gen_Mesh_Data_Q_HD::distinct hm.Handle32
Gen_Mesh_Data_Q_Data::struct{
	handle:Gen_Mesh_Data_Q_HD,
	data_hd:Chunk_HD,
	vox_data_hd:Chunk_Vox_Data_HD,
	neighbor_vox_data_hd:Chunk_Vox_Data_HD,
	side:Model_Sides,
	q_state:Q_State,
}
manage_gen_mesh_data_q::proc(w_map:^Map){

	it := hm.iterator_make(&w_map.gen_mesh_data_q)
	for q, q_hd in hm.iterate(&it) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .finished {
			hm.remove(&w_map.gen_mesh_data_q,q_hd)
		}
	}

	it_2 := hm.iterator_make(&w_map.gen_mesh_data_q)
	for q, q_hd in hm.iterate(&it_2) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .usable {
			do_a_gen_mesh_data_q(w_map, q_hd)
		}
	}
}
add_to_gen_mesh_data_q::proc(w_map:^Map,chunk_hd:Chunk_HD,vox_data_hd:Chunk_Vox_Data_HD,neighbor_vox_hd:Chunk_Vox_Data_HD,side:Model_Sides)->(q_hd:Gen_Mesh_Data_Q_HD){
	err:runtime.Allocator_Error
	q_hd,err=hm.add(&w_map.gen_mesh_data_q, Gen_Mesh_Data_Q_Data{vox_data_hd=vox_data_hd, data_hd=chunk_hd, neighbor_vox_data_hd=neighbor_vox_hd,side = side})
	q,q_ok:=hm.get(&w_map.gen_mesh_data_q,q_hd)
	assert(q_ok,"failed to ad to q i have know idea how this culd posbly happen what did you do!!!!!!! ")
	atom.atomic_store_explicit(&q.q_state, .usable, .Release)
	return
}
do_a_gen_mesh_data_q::proc(w_map:^Map,hd:Gen_Mesh_Data_Q_HD){
	q,ok:=hm.get(&w_map.gen_mesh_data_q,hd)
	if !ok{
		log.log(.Warning,"invalid",hd)
	}
	if ok{
		mesh_chunk_side(w_map = w_map, chunk_hd=q.data_hd, vox_data_hd=q.vox_data_hd, neighbor_vox_hd = q.neighbor_vox_data_hd,side = q.side)
		atom.atomic_store_explicit(&q.q_state, .finished, .Release)
	}
}

mesh_chunk_side::proc(
	w_map:^Map,
	chunk_hd:Chunk_HD, 
	vox_data_hd:Chunk_Vox_Data_HD, 
	neighbor_vox_hd:Chunk_Vox_Data_HD, 
	side:Model_Sides
){

	// log.log(
	//     .Debug,
	//     "MESH JOB",
	//     "chunk=", chunk_hd,
	//     "vox=", vox_data_hd,
	//     "neighbor=", neighbor_vox_hd,
	//     "side=", side,
	// )
	chunk, ok := get_chunk(w_map,chunk_hd)
	if !ok{
		log.log(.Error, "failed invalid chunk_hd(",chunk_hd,")")
		return
	}
	chunk_vox,vox_ok:=get_chunk_vox_data(w_map,vox_data_hd)
	if !vox_ok {
		log.log(.Error,"failed, vox_data_hd not valid",vox_data_hd)
		return
	}
	neighbor_vox,neighbor_vox_ok:=get_chunk_vox_data(w_map,neighbor_vox_hd)
	if !neighbor_vox_ok {
		log.log(.Error,"failed, neighbor_vox_data_hd not valid",neighbor_vox_hd)
		return
	}
	mesh_data,mesh_data_ok:=get_chunk_mesh_data(w_map,chunk.mesh_data[side])
	if !mesh_data_ok{
		err:runtime.Allocator_Error
		chunk.mesh_data[side],err= hm.add(&w_map.chunks_mesh_data,Chunk_Mesh_Data{})
		if err != .None{
			log.log(.Error,"failed to add mesh_hd to chunk.mesh_data[side] err = {",err,"}",chunk.mesh_data[side])
			return
		}
		mesh_data,mesh_data_ok=get_chunk_mesh_data(w_map,chunk.mesh_data[side],)
		if !mesh_data_ok {
			log.log(.Error,"failed, mesh_hd not valid",chunk.mesh_data[side])
			return
		}
	}


	// face_count:=mesh_by_side_all(w_map,chunk_vox,mesh_data,side)
	face_count:=mesh_by_bit_mask(w_map,chunk_vox,neighbor_vox,mesh_data,side)
	if face_count <= 0 {
		add_to_destroy_mesh_data_q(w_map,chunk.mesh_data[side])
		return
	}
	add_to_upload_mesh_data_q(w_map,chunk_hd,chunk.mesh_data[side],side)
}

//WARN this one is very slow and is just for debuging
mesh_by_side_all::proc(
	w_map:^Map,
	voxls:^Chunk_Vox_Data,
	mesh:^Chunk_Mesh_Data,
	side:Model_Sides
)->(face_count:int){
	// clear(&mesh.data)
	mesh.face_count = 0
	for plane, x in voxls.data{
		for col, y in plane{
			for vox, z in col{
				item:=reg.get(&g.item_reg,vox.item_hd)
				if item == nil{
					//this should be air
					// log.log(.Error, "item == nil, invalid item or registry is borked item_hd(", vox.item_hd,")")
					continue
				}
				face:tg.Vert_Face
				packed_pos := pack_block_pos({cast(u16)x,cast(u16)y,cast(u16)z})
				face.block_pos = packed_pos
				face.texture_face_index = cast(u32)item.texture_data.sides[side]
				face.geometry_face_index = cast(u16)item.model_data.cube_indices[side]
				// append(&mesh.data,face)
				mesh.data[face_count] = face
				face_count+=1
			}
		}
	}
	mesh.face_count = face_count
	return face_count
}

mesh_by_bit_mask :: proc(
    w_map: 			^Map,
    voxls: 			^Chunk_Vox_Data,
	neighbor_voxls: ^Chunk_Vox_Data,
    mesh: 			^Chunk_Mesh_Data,
    side: 			Model_Sides,
)->(face_count:int) {
    // clear(&mesh.data)
	mesh.face_count = 0
    for y in 0..<CHUNK_SIZE {
        for z in 0..<CHUNK_SIZE {
            current := voxls.is_solid_mask[y][z]
            visible: bit_set[u32(0)..<CHUNK_SIZE; u32]
		switch side {
		case .pos_x:
		    current_u32 := transmute(u32)current
		    neighbor_u32 := current_u32 >> 1
		    // x = 31 has no neighbor inside this chunk.
		    // If there is a neighboring chunk, use its x = 0.
		    if neighbor_voxls != nil {
		        neighbor_u32 &= ~(u32(1) << 31)
		        neighbor_edge := transmute(u32)neighbor_voxls.is_solid_mask[y][z]
		        if (neighbor_edge & 1) != 0 {
		            neighbor_u32 |= u32(1) << 31
		        }
		    } else {
		        // No neighboring chunk = empty space.
		        // Make sure x = 31 is considered empty.
		        neighbor_u32 &= ~(u32(1) << 31)
		    }
		    visible = transmute(bit_set[u32(0)..<CHUNK_SIZE; u32])(
		        current_u32 &~ neighbor_u32
		    )

		case .neg_x:
		    current_u32 := transmute(u32)current
		    neighbor_u32 := current_u32 << 1
		    // x = 0 has no neighbor inside this chunk.
		    // If there is a neighboring chunk, use its x = 31.
		    if neighbor_voxls != nil {
		        neighbor_u32 &= ~u32(1)
		        neighbor_edge := transmute(u32)neighbor_voxls.is_solid_mask[y][z]
		        if (neighbor_edge & (u32(1) << 31)) != 0 {
		            neighbor_u32 |= u32(1)
		        }
		    } else {
		        // No neighboring chunk = empty space.
		        neighbor_u32 &= ~u32(1)
		    }
		    visible = transmute(bit_set[u32(0)..<CHUNK_SIZE; u32])(
		        current_u32 &~ neighbor_u32
		    )
		
		case .pos_y:
		    if y == CHUNK_SIZE - 1 {
		        if neighbor_voxls == nil {
		            // No +Y chunk, so boundary is exposed.
		            visible = current
		        } else {
		            neighbor := neighbor_voxls.is_solid_mask[0][z]
		            visible = current - neighbor
		        }
		    } else {
		        neighbor := voxls.is_solid_mask[y + 1][z]
		        visible = current - neighbor
		    }
		
		case .neg_y:
		    if y == 0 {
		        if neighbor_voxls == nil {
		            // No -Y chunk, so boundary is exposed.
		            visible = current
		        } else {
		            neighbor := neighbor_voxls.is_solid_mask[CHUNK_SIZE - 1][z]
		            visible = current - neighbor
		        }
		    } else {
		        neighbor := voxls.is_solid_mask[y - 1][z]
		        visible = current - neighbor
		    }
		
		case .pos_z:
	    if z == CHUNK_SIZE - 1 {
	        if neighbor_voxls == nil {
	            // No +Z chunk, so boundary is exposed.
	            visible = current
	        } else {
	            neighbor := neighbor_voxls.is_solid_mask[y][0]
	            visible = current - neighbor
	        }
	    } else {
	        neighbor := voxls.is_solid_mask[y][z + 1]
	        visible = current - neighbor
	    }

		case .neg_z:
	    if z == 0 {
	        if neighbor_voxls == nil {
	            // No -Z chunk, so boundary is exposed.
	            visible = current
	        } else {
	            neighbor := neighbor_voxls.is_solid_mask[y][CHUNK_SIZE - 1]
	            visible = current - neighbor
	        }
	    } else {
	        neighbor := voxls.is_solid_mask[y][z - 1]
	        visible = current - neighbor
	    }
		
		case .extra:
		    return
		}
            for x in visible {
                vox := voxls.data[x][y][z]
                item := reg.get(&g.item_reg, vox.item_hd)
                // log.log(.Debug,"do append",x,y,z,side,"\n")
                if item == nil {
                	// this ia air so skip
                    // log.log(.Error,"item == nil, invalid item or registry is borked item_hd(",vox.item_hd,")",)
                    continue
                }

                face: tg.Vert_Face

                face.block_pos = pack_block_pos({cast(u16)x,cast(u16)y,cast(u16)z,})
                face.texture_face_index = cast(u32)item.texture_data.sides[side]
                face.geometry_face_index = cast(u16)item.model_data.cube_indices[side]
                // log.log(.Debug,"do append",x,y,z,side,face,"\n")
                // append(&mesh.data, face)
                mesh.data[face_count] = face
                face_count+=1
            }
        }
    }
    mesh.face_count = face_count
    return face_count
}

Destroy_Mesh_Data_Q::hm.Dynamic_Handle_Map(Destroy_Mesh_Data_Q_Data,Destroy_Mesh_Data_Q_HD)
Destroy_Mesh_Data_Q_HD::distinct hm.Handle32
Destroy_Mesh_Data_Q_Data::struct{
	handle:Destroy_Mesh_Data_Q_HD,
	mesh_data_hd:Chunk_Mesh_Data_HD,
	q_state:Q_State,
}
manage_destroy_mesh_data_q::proc(w_map:^Map){

	it := hm.iterator_make(&w_map.destroy_mesh_data_q)
	for q, q_hd in hm.iterate(&it) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .finished {
			hm.remove(&w_map.destroy_mesh_data_q,q_hd)
		}
	}

	it_2 := hm.iterator_make(&w_map.destroy_mesh_data_q)
	for q, q_hd in hm.iterate(&it_2) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .usable {
			do_a_destroy_mesh_data_q(w_map, q_hd)
		}
	}
}
add_to_destroy_mesh_data_q::proc(w_map:^Map,mesh_data_hd:Chunk_Mesh_Data_HD)->(q_hd:Destroy_Mesh_Data_Q_HD){
	err:runtime.Allocator_Error
	q_hd,err=hm.add(&w_map.destroy_mesh_data_q, Destroy_Mesh_Data_Q_Data{mesh_data_hd = mesh_data_hd})
	q,q_ok:=hm.get(&w_map.destroy_mesh_data_q,q_hd)
	assert(q_ok,"failed to ad to q i have know idea how this culd posbly happen what did you do!!!!!!! ")
	atom.atomic_store_explicit(&q.q_state, .usable, .Release)
	return
}
do_a_destroy_mesh_data_q::proc(w_map:^Map,hd:Destroy_Mesh_Data_Q_HD){
	q,ok:=hm.get(&w_map.destroy_mesh_data_q,hd)
	if ok{
		destroy_mesh_data(w_map,q.mesh_data_hd)
		atom.atomic_store_explicit(&q.q_state, .finished, .Release)
	}

}
destor_count:int
destroy_mesh_data::proc(w_map:^Map,hd:Chunk_Mesh_Data_HD){

	found,err:=hm.remove(&w_map.chunks_mesh_data,hd)
	if err != .None{
		log.log(.Error,"destroy_mesh_data() err",err,hd)
	}
	
	if !found{
		log.log(.Warning,"cant find mesh data to destroy",hd)
	}
}

Upload_Mesh_Data_Q::hm.Dynamic_Handle_Map(Upload_Mesh_Data_Q_Data,Upload_Mesh_Data_Q_HD)
Upload_Mesh_Data_Q_HD::distinct hm.Handle32
Upload_Mesh_Data_Q_Data::struct{
	handle:Upload_Mesh_Data_Q_HD,
	data_hd:Chunk_HD,
	mesh_hd:Chunk_Mesh_Data_HD, 
	side:Model_Sides,
	q_state:Q_State,
}
manage_upload_mesh_data_q::proc(w_map:^Map){
	it := hm.iterator_make(&w_map.upload_mesh_data_q)
	for q, q_hd in hm.iterate(&it) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .finished {
			hm.remove(&w_map.upload_mesh_data_q,q_hd)
		}
	}
	len :=hm.len(w_map.upload_mesh_data_q)
	if len<= 0{return}
	copy_cmd_buf:=sdl.AcquireGPUCommandBuffer(s.gpu_device)	
	copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)
	it_2 := hm.iterator_make(&w_map.upload_mesh_data_q)
	for q, q_hd in hm.iterate(&it_2) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .usable {
			do_a_upload_mesh_data_q(w_map, q_hd, copy_pass)
		}
	}
	sdl.EndGPUCopyPass(copy_pass)
	ok := sdl.SubmitGPUCommandBuffer(copy_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")
	ok2:=sdl.WaitForGPUIdle(s.gpu_device)//TODO WARING this needs ro be removed
}
add_to_upload_mesh_data_q::proc(
	w_map:^Map,
	data_hd:Chunk_HD,
	mesh_hd:Chunk_Mesh_Data_HD, 
	side:Model_Sides,
)->(q_hd:Upload_Mesh_Data_Q_HD){
	err:runtime.Allocator_Error
	q_hd,err=hm.add(&w_map.upload_mesh_data_q, Upload_Mesh_Data_Q_Data{data_hd=data_hd, mesh_hd=mesh_hd, side=side})
	q,q_ok:=hm.get(&w_map.upload_mesh_data_q,q_hd)
	assert(q_ok,"failed to ad to q i have know idea how this culd posbly happen what did you do!!!!!!! ")
	atom.atomic_store_explicit(&q.q_state, .usable, .Release)
	return
}
do_a_upload_mesh_data_q::proc(w_map:^Map,hd:Upload_Mesh_Data_Q_HD, copy_pass: ^sdl.GPUCopyPass){
	q,ok:=hm.get(&w_map.upload_mesh_data_q,hd)
	if ok{
		upload_chunk_side_to_gpu(w_map,q.data_hd,q.mesh_hd,q.side,copy_pass)
		atom.atomic_store_explicit(&q.q_state, .finished, .Release)
	}
}

// upload_chunks_to_gpu::proc(w_map:^Map){
// 	copy_cmd_buf:=sdl.AcquireGPUCommandBuffer(s.gpu_device)	
// 	copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)

// 	itor:=hm.iterator_make(&w_map.chunks)
// 	loop:for chunk, chunk_hd in hm.iterate(&itor) {
// 		upload_chunk_to_gpu(w_map, chunk_hd, copy_pass)
// 	}

// 	sdl.EndGPUCopyPass(copy_pass)
// 	ok := sdl.SubmitGPUCommandBuffer(copy_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")
// }

// upload_chunk_to_gpu::proc(w_map:^Map, chunk_hd:Chunk_HD,  copy_pass: ^sdl.GPUCopyPass){
// 	chunk, ok := get_chunk(w_map,chunk_hd)
// 	if !ok{
// 		log.log(.Error, "failed invalid chunk_hd(",chunk_hd,")")
// 		return
// 	}
// 	for mesh_hd, side in chunk.mesh_data{
// 		chunk_mesh,mesh_ok:=get_chunk_mesh_data(w_map,mesh_hd)
// 		if !mesh_ok {continue}
// 		upload_chunk_side_to_gpu(w_map,chunk,chunk_mesh,side,copy_pass)
// 	}
// }

// upload_chunk_side_to_gpu::proc(w_map:^Map, chunk:^Chunk, mesh:^Chunk_Mesh_Data, side:Model_Sides, copy_pass: ^sdl.GPUCopyPass){
upload_chunk_side_to_gpu::proc(w_map:^Map, chunk_hd:Chunk_HD, mesh_hd:Chunk_Mesh_Data_HD, side:Model_Sides, copy_pass: ^sdl.GPUCopyPass){
	chunk, chunk_ok := get_chunk(w_map,chunk_hd)
	if !chunk_ok{
		log.log(.Error, "failed invalid chunk_hd(",chunk_hd,")")
		return
	}
	mesh,mesh_ok:=get_chunk_mesh_data(w_map,mesh_hd)
	if !mesh_ok {
		log.log(.Warning,"no mesh data found",mesh_hd)
		return
	}

	if mesh.face_count == 0{
		// log.log(.Error, "cant upload a mesh whith 0 data")
		add_to_destroy_mesh_data_q(w_map,mesh_hd)
		return
	}
	num_of_gpu_mesh_slots:=cast(u32)math.ceil(cast(f32)mesh.face_count/CHUNK_MAX_FACE_NUM)
	range,ok:=tg.free_list_alloc(&w_map.chunks_in_mesh, num_of_gpu_mesh_slots)
	if !ok{
		log.log(.Error, "failed tg.free_list_alloc(&w_map.chunks_in_mesh) !ok mega mesh problobly full")
		return
	}


	chunk.range_in_map_mesh[side] = range
	first_face:=cast(u32) range.start * CHUNK_MAX_FACE_NUM

	upload_data_to_mesh_by_offset(w_map.map_mesh_hd,w_map.chunck_transfer_buffer,mesh.data[:],first_face, copy_pass)
	chunk.draw_cmd[side].num_vertices = cast(u32)mesh.face_count*6
	chunk.draw_cmd[side].first_vertex = first_face *6
	chunk.draw_cmd[side].num_instances = 1 
	add_to_destroy_mesh_data_q(w_map,mesh_hd)
}

upload_data_to_mesh_by_offset::proc(mesh_hd:tg.Mesh_Handle,transfer_buffer:^sdl.GPUTransferBuffer,vertices:$T/[]$E,offset:u32, copy_pass: ^sdl.GPUCopyPass){
	mesh:=tg.get_mesh(mesh_hd)
	vertices_byte_size := len(vertices)*size_of(E)
	offset_byte_size:=offset*size_of(E)

	transfer_mem := transmute([^]byte)sdl.MapGPUTransferBuffer(s.gpu_device, transfer_buffer, cycle = true)

	copy(transfer_mem[:vertices_byte_size],mem.slice_to_bytes(vertices[:]))

	sdl.UnmapGPUTransferBuffer(s.gpu_device, transfer_buffer)
	// copy_cmd_buf:=sdl.AcquireGPUCommandBuffer(s.gpu_device)	
	// copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)
	
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
	// sdl.EndGPUCopyPass(copy_pass)
	// ok := sdl.SubmitGPUCommandBuffer(copy_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")
	// ok2:=sdl.WaitForGPUIdle(s.gpu_device)
}

Unload_Mesh_Data_Q::hm.Dynamic_Handle_Map(Unload_Mesh_Data_Q_Data,Unload_Mesh_Data_Q_HD)
Unload_Mesh_Data_Q_HD::distinct hm.Handle32
Unload_Mesh_Data_Q_Data::struct{
	handle:Unload_Mesh_Data_Q_HD,
	pos:[3]int,
	q_state:Q_State,
}
manage_unload_mesh_data_q::proc(w_map:^Map){}
add_to_unload_mesh_data_q::proc(w_map:^Map){}
do_a_unload_mesh_data_q::proc(w_map:^Map,hd:Unload_Mesh_Data_Q_HD){}
