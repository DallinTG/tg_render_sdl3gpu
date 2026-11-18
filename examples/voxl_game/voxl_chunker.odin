package voxl_game

import "core:testing"
import "base:runtime"

import "core:os"
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
// import hm "../../handle_map_static_virtual"
import hm "core:container/handle_map"
import "core:container/xar"
import an"../../ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"
import st"core:strings"
import steam "../../steamworks"
import reg "../../registry"
import "core:thread"
import "core:container/pool"
import atom "core:sync"
import "core:sync/chan"
import nos "core:math/noise"
import "core:prof/spall"
import "core:math/bits"

Vox_Render_Settings::struct{
	do_chunk_back_face_culling:bool,
	do_chunk_frustum_culling:bool,
	xz_render_distance:int,
	y_render_distance:int,
	lod_levels:int,
	lod_depth:int,

}
DF_VOX_RENDER_SETTINGS:Vox_Render_Settings:{
	do_chunk_back_face_culling = true,
	do_chunk_frustum_culling = true,
	xz_render_distance = 4,
	y_render_distance = 4,
	lod_levels = 20,
	lod_depth = 8,
}
Vox_Render_Debug_Info::struct{

	chunks_map_len:			int,
	chunks_len:				int,
	chunks_voxel_data_len:	int,
	chunks_mesh_data_len:	int,
	space_lef_on_gpu_buff:	int, 

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
	light_qs_hm_len:		int,

	pool_num_waiting:	int,
	pool_num_in_processing:	int,
	pool_num_outstanding:	int,
	pool_num_done:	int,

}


CHUNK_SIZE::32
MAX_NUM_CHUNKS::35000 * 7
MAX_FACE_COUNT::MAX_NUM_CHUNKS * CHUNK_MAX_FACE_NUM
CHUNK_MAX_FACE_NUM::  CHUNK_SIZE * CHUNK_SIZE / 2
MAX_NUM_DRAW_CMD_BUF::MAX_NUM_CHUNKS / 8

// Nine levels cover chunk sizes 1, 2, 4, ..., 256.
MAX_CHUNK_STREAM_LOD_LEVELS :: 12
MAX_CHUNK_STREAM_LOD_SIZE :: 1 << (MAX_CHUNK_STREAM_LOD_LEVELS-1)
MAX_CHUNKS_TO_ADD_PER_FRAME :: 100
MAX_CHUNK_UNLOAD_CANDIDATES_PER_UPDATE :: 512

Chunk_Stream_Settings :: struct {
    lod_level_count: int,                  // Includes LOD0 (size 1).
    lod_band_width: int,                   // Nominal full ring thickness in the next LOD's chunks.
    lod0_radius_xz: int,                   // LOD0 half-extent in base chunks.
    lod0_radius_y: int,                    // LOD0 vertical half-extent in base chunks.
    max_chunk_loads_per_update: int,
    max_chunk_unloads_per_update: int,
}

DF_CHUNK_STREAM_SETTINGS: Chunk_Stream_Settings: {
    lod_level_count = 12,
    lod_band_width = 8,
    lod0_radius_xz = 8,
    lod0_radius_y = 4,
    max_chunk_loads_per_update = 50,
    max_chunk_unloads_per_update = 512,
}

// Bounds are base-chunk coordinates with an exclusive maximum.
Chunk_Stream_Bounds :: struct {
    min: [3]int,
    max: [3]int,
}

Chunk_Unload_Candidate :: struct {
    chunk_hd: Chunk_HD,
    distance: int,
}

Chunk_Stream_Cursor :: struct {
    level, shell, cell_index: int,
}

Map::struct{
	did_work:bool,
	renderer_saw_work:bool,

	stream_chunk_pos: [3]int,
	stream_chunk_pos_valid: bool,
	chunks_map_rw_mutex: atom.Atomic_RW_Mutex,
	chunks_map:map[[4]int]Chunk_HD,
	chunks:Chunks_Handle_Map,
	backing_world_vox_data:Backing_Vox_World_Data, 
	backing_world_light_data:Backing_Light_World_Data, 

	vox_chunk_hm:Vox_Chunk_Data_HM,
	light_chunk_hm:Light_Chunk_Data_HM,
	vox_mask_hm:Vox_Mask_HM,
	chunks_mesh_data:Chunks_Mesh_Data_Handle_Map,
	gpu_mesh_data_hm:GPU_Mesh_Data_HM,

	draw_cmd_buf_hd:tg.Mesh_Handle,
	draw_cmd_buf_comped_hd:tg.Mesh_Handle,
	map_mesh_hd:tg.Mesh_Handle,
	dynamic_map_mesh_hd:tg.Mesh_Handle,
	drawing_map_mesh_hd:tg.Mesh_Handle,

	light_qs_hm:Light_Q_HM,
	chunk_shader_data:tg.Indexed_GPU_Data,
	
	chunks_in_mesh:tg.Free_List,
	chunck_transfer_buffer:^sdl.GPUTransferBuffer,

	t_pool:thread.Pool,
	pool_tasks:Pool_Tasks_HM,
	chunk_stream_settings: Chunk_Stream_Settings,
	chunk_stream_cursor: Chunk_Stream_Cursor,


	set_block_chan:chan.Chan(Set_Block_CMD,.Both),
	// Map Qs_____________________________________
	gen_chunk_chan:chan.Chan(Gen_Chunk_Q_Data,.Both),
	destroy_chunk_chan:chan.Chan(Destroy_Chunk_Q_Data,.Both),
	gen_vox_data_chan:chan.Chan(Gen_Vox_Data_Q_Data,.Both),
	gen_mesh_data_chan:chan.Chan(Gen_Mesh_Data_Q_Data,.Both),
	check_needs_meshing_chan:chan.Chan(Check_Needs_Meshing_Q_Data,.Both),
	upload_mesh_data_chan:chan.Chan(Upload_Mesh_Data_Q_Data,.Both),
	destroy_vox_data_chan:chan.Chan(Destroy_Vox_Data_Q_Data,.Both),
	destroy_mesh_data_chan:chan.Chan(Destroy_Mesh_Data_Q_Data,.Both),
	// unload_mesh_data_chan:chan.Chan(Unload_Mesh_Data_Q_Data,.Both,),
}


Chunks_Handle_Map::hm.Dynamic_Handle_Map(Chunk,Chunk_HD)
Chunk_HD::distinct hm.Handle64
Chunk::struct{
	handle:			Chunk_HD,
	pos:			[4]int,
	retiring:		bool,
	// Shared by meshing/readers; exclusive for voxel generation, lighting writes,
	// block edits, retirement, and destruction.
	data_rw_mutex: atom.Atomic_RW_Mutex,

	vox_data_hd:	Vox_Chunk_Data_HD,

	// light_data_
	light_data_q_state:	Q_State,
	light_data_hd:	Light_Chunk_Data_HD,
	lighting_redy_mask:bit_set[Full_Directions],
	// light_q_hd:		Light_Q_HD,
	
	mesh_q_state:[Model_Sides]Q_State,
	mesh_gpu_ready_mask:bit_set[Model_Sides],
	gpu_mesh_data_hd:GPU_Mesh_Data_HD,

	// chunk_shader_data:Chunk_Shader_Data,
}

Chunk_Shader_Data::struct{
	pos:[4]i32,
	side:Model_Sides,
}

Chunks_Mesh_Data_Handle_Map::hm.Dynamic_Handle_Map(Chunk_Mesh_Data,Chunk_Mesh_Data_HD)
Chunk_Mesh_Data_HD::distinct hm.Handle64

Chunk_Mesh_Data::struct{
	handle:Chunk_Mesh_Data_HD,
	data:Chunk_Mesh_Data_Raw,
	face_count:int
}
// INFO we are /8 on the buffer size becus you will never have all faces filled
Chunk_Mesh_Data_Raw::[CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE/8]tg.Vert_Face

GPU_Mesh_Data_HM::hm.Dynamic_Handle_Map(GPU_Mesh_Data,GPU_Mesh_Data_HD)
GPU_Mesh_Data_HD::distinct hm.Handle64
GPU_Mesh_Data::struct{
	handle:GPU_Mesh_Data_HD,
	visible:bool,
	chunk_shader_data:	[Model_Sides]Chunk_Shader_Data,
	draw_cmd:			[Model_Sides]sdl.GPUIndirectDrawCommand,
	range_in_map_mesh:	[Model_Sides]tg.Free_List_Range,
	face_count:int
}

Pool_Tasks_HM::hm.Dynamic_Handle_Map(Pool_Task,Pool_Task_HD)
Pool_Task_HD::distinct hm.Handle64
Pool_Task::struct{
	handle:Pool_Task_HD,
	task:All_Tasks,
	// Mesh output is pool bookkeeping, not part of the compact Mesh_Chunk_Task.
	mesh_hd:Chunk_Mesh_Data_HD,
}
All_Tasks::union{
	Gen_Vox_Data_Task,
	Mesh_Chunk_Task,
	Light_Chunk_Task,
}
Gen_Vox_Data_Task::struct{
	w_map:^Map,
	chunk_hd:Chunk_HD,
	vox_data_hd:Vox_Chunk_Data_HD,
	light_q_hd:		Light_Q_HD,
}
Mesh_Light_Neighbor_Entry :: struct {
	light_hd: Light_Chunk_Data_HD,
	pos: [3]int,
	size: int,
}

Mesh_Light_Neighbor :: struct {
	same_lod: Light_Chunk_Data_HD,
	fine_lod: [4]Mesh_Light_Neighbor_Entry,
	fine_count: int,
	coarse_lod: Mesh_Light_Neighbor_Entry,
	has_coarse_lod: bool,
}

Mesh_Chunk_Task::struct{
	w_map: ^Map,
	chunk_hd: Chunk_HD,
	side: Model_Sides,
}

MESH_MAX_LOCKED_CHUNKS :: 64
// Prepared handles are kept under read locks until mesh_by_bit_mask finishes.
Mesh_Prepared_Chunk_Data :: struct {
	chunk_vox_hd: Vox_Chunk_Data_HD,
	chunk_light_hd: Light_Chunk_Data_HD,
	chunk_pos: [3]int,
	chunk_size: int,
	neighbor_vox_hd: [4]Vox_Chunk_Data_HD,
	has_4_neighbors: bool,
	neighbor_light_data: [Full_Directions]Mesh_Light_Neighbor,
	locked_chunk_hds: [MESH_MAX_LOCKED_CHUNKS]Chunk_HD,
	locked_chunk_count: int,
}
Light_Chunk_Task::struct{
	w_map: ^Map,
	chunk_hd:Chunk_HD,
	vox_data_hd:Vox_Chunk_Data_HD,
	light_q_hd:		Light_Q_HD,

	nabors_light_q_hd:[Directions]Light_Q_HD,
	nabors_chunk_hd:[Directions]Chunk_HD,
	nabors_vox_data_hd:[Directions]Vox_Chunk_Data_HD,

	calling_q:Light_Q_HD,
	calling_vox_data_hd:Vox_Chunk_Data_HD,
	calling_chunk_hd:Chunk_HD,
}



start_gen_vox_dat_task::proc(w_map:^Map, task:Gen_Vox_Data_Task){
	task_hd,err:=hm.add(&w_map.pool_tasks,Pool_Task{task=task})
	assert(err == .None)
	task_ptr,task_ok:=hm.get(&w_map.pool_tasks,task_hd)
	assert(task_ok)
	
	thread.pool_add_task(&w_map.t_pool,context.allocator,do_task,task_ptr,cast(int)task_hd.idx)
}

start_mesh_chunk_task::proc(w_map:^Map, task:Mesh_Chunk_Task, mesh_hd:Chunk_Mesh_Data_HD){
	task_hd,err:=hm.add(&w_map.pool_tasks,Pool_Task{task=task,mesh_hd=mesh_hd})
	assert(err == .None)
	task_ptr,task_ok:=hm.get(&w_map.pool_tasks,task_hd)
	assert(task_ok)
	
	thread.pool_add_task(&w_map.t_pool,context.allocator,do_task,task_ptr,cast(int)task_hd.idx)
}

start_light_chunk_task::proc(w_map:^Map, task:Light_Chunk_Task){
	new_task:=task
	dir_offsets:=DIR_OFFSETS
	chunk,chunk_ok:=hm.get(&w_map.chunks,task.chunk_hd)
	assert(chunk_ok)
	atom.atomic_rw_mutex_shared_lock(&chunk.data_rw_mutex)
	chunk_pos := chunk.pos
	atom.atomic_rw_mutex_shared_unlock(&chunk.data_rw_mutex)

	for &light_q, dir in &new_task.nabors_light_q_hd{
		err:runtime.Allocator_Error
		light_q,err = hm.dynamic_add(&w_map.light_qs_hm,Light_Q{})
		assert(err == .None)
	}

	for &vox_data_hd, dir in &new_task.nabors_vox_data_hd{
		offset:=dir_offsets[dir] * chunk_pos.w
		pos:=chunk_pos
		pos.xyz+=offset
		nab_chunk_hd,nab_chunk_hd_ok:=get_chunk_by_pos_safe(w_map,pos)
		if !nab_chunk_hd_ok {continue}
		new_task.nabors_chunk_hd[dir] = nab_chunk_hd

		nab_chunk,nab_chunk_ok:=hm.get(&w_map.chunks,nab_chunk_hd)
		if !nab_chunk_ok {continue}
		atom.atomic_rw_mutex_shared_lock(&nab_chunk.data_rw_mutex)
		if !nab_chunk.retiring { vox_data_hd = nab_chunk.vox_data_hd }
		atom.atomic_rw_mutex_shared_unlock(&nab_chunk.data_rw_mutex)
	}

	task_hd,err:=hm.add(&w_map.pool_tasks,Pool_Task{task=new_task})
	assert(err == .None)
	task_ptr,task_ok:=hm.get(&w_map.pool_tasks,task_hd)
	assert(task_ok)
	thread.pool_add_task(&w_map.t_pool,context.allocator,do_task,task_ptr,cast(int)task_hd.idx)
}

do_task::proc(task: thread.Task){
	new_task:=cast(^Pool_Task)task.data
	switch t in new_task.task {
		case Gen_Vox_Data_Task:
		gen_vox_data(t)
		case Mesh_Chunk_Task:
		mesh_by_bit_mask(t, new_task.mesh_hd)
		case Light_Chunk_Task:
		update_chunk_lighting_with_lock(t)
		
	}
}
fin_pool_tasks::proc(w_map:^Map)->(did_work:bool, mesh_changed:bool){
	for {
		task_raw, ok := thread.pool_pop_done(&w_map.t_pool)
		if !ok {break}
		task:=cast(^Pool_Task)task_raw.data
		did_work = true
		switch t in task.task{
		case Gen_Vox_Data_Task:
			vox_chunk,vox_chunk_ok:=hm.get(&w_map.vox_chunk_hm,t.vox_data_hd)
			assert(vox_chunk_ok)
			atom.atomic_store(&vox_chunk.vox_gened,true)
			chunk,chunk_ok:=hm.get(&w_map.chunks,t.chunk_hd)
			assert(chunk_ok)
			if chunk_is_retiring(chunk) {
				// A retired chunk is being discarded, so do not seed a new light task.
				set_chunk_light_q_state(chunk, .usable)
				found,err:=hm.remove(&w_map.light_qs_hm,t.light_q_hd)
				assert(err == .None && found)
			}else{
				start_light_chunk_task(w_map,Light_Chunk_Task{w_map=w_map,chunk_hd=t.chunk_hd,vox_data_hd=t.vox_data_hd,light_q_hd=t.light_q_hd})
			}
		case Mesh_Chunk_Task:
			chunk,chunk_ok:=hm.get(&w_map.chunks,t.chunk_hd)
			assert(chunk_ok)
			mesh,mesh_ok:=hm.get(&w_map.chunks_mesh_data,task.mesh_hd)
			assert(mesh_ok)
			face_count := mesh.face_count

			atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
			chunk.mesh_q_state[t.side] = .usable
			chunk_retiring := chunk.retiring
			gpu_mesh_data_hd := chunk.gpu_mesh_data_hd
			if !chunk_retiring && face_count == 0 { chunk.mesh_gpu_ready_mask += {t.side} }
			atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
			if chunk_retiring || face_count < 0 {
				add_to_destroy_mesh_data_q(w_map,task.mesh_hd)
			}else if face_count == 0 {
				add_to_destroy_mesh_data_q(w_map,task.mesh_hd)
				unload_mesh_data_by_side(t.w_map,gpu_mesh_data_hd,t.side)
				mesh_changed = true
			}else{
				add_to_upload_mesh_data_q(w_map,t.chunk_hd,task.mesh_hd,t.side)
			}
			
		case Light_Chunk_Task:

			chunk,chunk_ok:=hm.get(&w_map.chunks,t.chunk_hd)
			assert(chunk_ok)

			vox_chunk,vox_chunk_ok:=hm.get(&w_map.vox_chunk_hm,t.vox_data_hd)
			assert(vox_chunk_ok)

			q,q_ok:=hm.get(&w_map.light_qs_hm, t.calling_q)
			if q_ok{
				old_owner_count:=atom.atomic_sub(&q.owner_count,1)
				assert(old_owner_count > 0)

				calling_chunk,calling_chunk_ok:=hm.get(&w_map.chunks,t.calling_chunk_hd)
				assert(calling_chunk_ok)

				if old_owner_count == 1 {
					stuff_in_q := len(q.add_q)>0 || len(q.seed_q)>0 || len(q.remove_q)>0
					if chunk_is_retiring(calling_chunk) {
						set_chunk_light_q_state(calling_chunk, .usable)
						found,err:=hm.remove(&w_map.light_qs_hm,t.calling_q)
						assert(err == .None && found)
					}else if stuff_in_q {
						set_chunk_light_q_state(calling_chunk, .in_q)
						start_light_chunk_task(w_map,Light_Chunk_Task{
							w_map=w_map,
							chunk_hd=t.calling_chunk_hd,
							vox_data_hd=t.calling_vox_data_hd,
							light_q_hd=t.calling_q,
						})
					}else{
						set_chunk_light_q_state(calling_chunk, .usable)
						found,err:=hm.remove(&w_map.light_qs_hm,t.calling_q)
						assert(err == .None)
						if found { notify_chunk_lighting_ready(w_map,t.calling_chunk_hd) }
					}
				}
			}
			if !chunk_is_retiring(chunk) {
			for nab_light_q_hd,dir in t.nabors_light_q_hd{
				nab_chunk,nab_chunk_ok:=hm.get(&w_map.chunks,t.nabors_chunk_hd[dir])
				
				
				nab_light_q,nab_light_q_hd_ok:=hm.get(&w_map.light_qs_hm,nab_light_q_hd)
				if !nab_light_q_hd_ok {continue}

				calling_light_q,calling_light_q_hd_ok:=hm.get(&w_map.light_qs_hm,t.light_q_hd)
				if !calling_light_q_hd_ok {continue}

				if nab_chunk_ok && chunk_is_retiring(nab_chunk) {
					if atom.atomic_load(&nab_light_q.owner_count) == 0 {
						set_chunk_light_q_state(nab_chunk, .usable)
						found,err:=hm.remove(&w_map.light_qs_hm,nab_light_q_hd)
						assert(err == .None)
					}
					continue
				}

				stuff_in_q:bool
				if len(nab_light_q.add_q)>0{stuff_in_q = true}
				if len(nab_light_q.seed_q)>0{stuff_in_q = true}
				if len(nab_light_q.remove_q)>0{stuff_in_q = true}
				if stuff_in_q{
					if nab_chunk_ok {set_chunk_light_q_state(nab_chunk, .in_q)}
					atom.atomic_add(&calling_light_q.owner_count,1)
					start_light_chunk_task(w_map,
						Light_Chunk_Task{
							w_map=w_map,
							chunk_hd=t.nabors_chunk_hd[dir],
							vox_data_hd=t.nabors_vox_data_hd[dir],
							light_q_hd=nab_light_q_hd,

							calling_vox_data_hd = t.vox_data_hd,
							calling_chunk_hd = t.chunk_hd,
							calling_q = t.light_q_hd,
						}
					)
				}
				if !stuff_in_q && atom.atomic_load(&nab_light_q.owner_count) == 0 {
					if nab_chunk_ok {set_chunk_light_q_state(nab_chunk, .usable)}
					found,err:=hm.remove(&w_map.light_qs_hm,nab_light_q_hd)
					assert(err == .None)
				}
			}
			}


			own_q,own_q_ok:=hm.get(&w_map.light_qs_hm,t.light_q_hd)
			if own_q_ok {
				own_stuff_in_q:=len(own_q.add_q)>0 || len(own_q.seed_q)>0 || len(own_q.remove_q)>0
				own_owner_count:=atom.atomic_load(&own_q.owner_count)
			
				if own_owner_count == 0 {
					if chunk_is_retiring(chunk) {
						set_chunk_light_q_state(chunk, .usable)
						found,err:=hm.remove(&w_map.light_qs_hm,t.light_q_hd)
						assert(err == .None && found)
					}else if own_stuff_in_q {
						set_chunk_light_q_state(chunk, .in_q)
						start_light_chunk_task(w_map,Light_Chunk_Task{
							w_map=w_map,
							chunk_hd=t.chunk_hd,
							vox_data_hd=t.vox_data_hd,
							light_q_hd=t.light_q_hd,
						})
					}else{
						set_chunk_light_q_state(chunk, .usable)
						found,err:=hm.remove(&w_map.light_qs_hm,t.light_q_hd)
						assert(err == .None)
						if found { notify_chunk_lighting_ready(w_map,t.chunk_hd) }
					}
				}
			}
		}
		hm.remove(&w_map.pool_tasks,task.handle)

	}
	return did_work, mesh_changed
}




get_chunk::proc(w_map:^Map,chunk_hd:Chunk_HD)->(chunk:^Chunk,ok:bool){
	chunk, ok = hm.get(&w_map.chunks, chunk_hd) 
	return chunk, ok
}

Model_Sides::enum u32{
	pos_x,
	neg_x,
	pos_y,
	neg_y,
	pos_z,
	neg_z,
	extra,
}

get_chunk_mesh_data::proc(w_map:^Map, mesh_data_hd:Chunk_Mesh_Data_HD,)->(mesh_data:^Chunk_Mesh_Data,ok:bool){
	mesh_data,ok=hm.get(&w_map.chunks_mesh_data,mesh_data_hd)
	return mesh_data,ok
}

init_map::proc(w_map:^Map){
	w_map.chunk_stream_settings = DF_CHUNK_STREAM_SETTINGS
	// w_map.t_pool
	pool_allocator: mem.Allocator
	pool_allocator = runtime.heap_allocator()
	thread.pool_init(&w_map.t_pool,pool_allocator,10)
	defer thread.pool_start(&w_map.t_pool)

	

	err:runtime.Allocator_Error
	w_map.gen_chunk_chan , err = chan.create_buffered(chan.Chan(Gen_Chunk_Q_Data),10000, context.allocator)
	assert(err == .None)
	w_map.destroy_chunk_chan , err = chan.create_buffered(chan.Chan(Destroy_Chunk_Q_Data),MAX_NUM_CHUNKS, context.allocator)
	assert(err == .None)
	w_map.gen_vox_data_chan, err = chan.create_buffered(chan.Chan(Gen_Vox_Data_Q_Data),10000, context.allocator)
	assert(err == .None)
	w_map.gen_mesh_data_chan, err = chan.create_buffered(chan.Chan(Gen_Mesh_Data_Q_Data),100000, context.allocator)
	assert(err == .None)
	w_map.check_needs_meshing_chan, err = chan.create_buffered(chan.Chan(Check_Needs_Meshing_Q_Data),100000, context.allocator)
	assert(err == .None)
	w_map.upload_mesh_data_chan, err = chan.create_buffered(chan.Chan(Upload_Mesh_Data_Q_Data),100000, context.allocator)
	assert(err == .None)
	w_map.destroy_vox_data_chan, err = chan.create_buffered(chan.Chan(Destroy_Vox_Data_Q_Data),10000, context.allocator)
	assert(err == .None)
	w_map.destroy_mesh_data_chan, err = chan.create_buffered(chan.Chan(Destroy_Mesh_Data_Q_Data),100000, context.allocator)
	assert(err == .None)
	// w_map.unload_mesh_data_chan, err = chan.create_buffered(chan.Chan(Unload_Mesh_Data_Q_Data),10000, context.allocator)
	// assert(err == .None)

	w_map.set_block_chan, err = chan.create_buffered(chan.Chan(Set_Block_CMD),10000, context.allocator)
	assert(err == .None)


	tg.free_list_init(&w_map.chunks_in_mesh,MAX_NUM_CHUNKS)
	w_map.draw_cmd_buf_hd = tg.create_mesh(sdl.GPUIndirectDrawCommand,MAX_NUM_CHUNKS,{},type = .indirect_cmd_buff, usage = {.INDIRECT,.COMPUTE_STORAGE_READ}, debug_name = "w_map GPUIndirectDrawCommand buffer")
	w_map.draw_cmd_buf_comped_hd = tg.create_mesh(sdl.GPUIndirectDrawCommand,MAX_NUM_CHUNKS,{},type = .indirect_cmd_buff, usage = {.INDIRECT,.COMPUTE_STORAGE_WRITE,}, debug_name = "w_map GPUIndirectDrawCommand comped buffer")

	w_map.chunk_shader_data.mesh_hd = tg.create_mesh(Chunk_Shader_Data,MAX_NUM_CHUNKS,{},type = .dynamic_buff, usage = {.GRAPHICS_STORAGE_READ,.COMPUTE_STORAGE_READ}, debug_name = "Chunk shader data buffer")
	w_map.chunk_shader_data.bind_to_vert = true
	w_map.chunk_shader_data.bind_to_frag = false
	w_map.map_mesh_hd = tg.create_mesh(tg.Vert_Face, MAX_FACE_COUNT,{},type = .no_tranfer_buff, usage = {.GRAPHICS_STORAGE_READ}, debug_name = "w_map Chunk buffer mesh")
	w_map.dynamic_map_mesh_hd = tg.create_mesh(tg.Dynamic_Vert_Face, type = .dynamic_buff, debug_name = "dynamic w_map Chunk buffer mesh")
	w_map.drawing_map_mesh_hd = tg.create_mesh(tg.Vertex_Data_Step, type = .dynamic_buff, debug_name = "dynamic w_map Chunk buffer mesh")
	w_map.chunck_transfer_buffer = sdl.CreateGPUTransferBuffer(s.gpu_device,{
		usage = .UPLOAD,
		size = cast(u32)(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE * size_of(tg.Vert_Face)),
	})
}

floor_div :: proc(v, divisor: int) -> int {
    assert(divisor > 0)
    q := v / divisor
    r := v % divisor
    if r < 0 { q -= 1 }
    return q
}

ceil_div :: proc(v, divisor: int) -> int {
    assert(divisor > 0)
    q := v / divisor
    r := v % divisor
    if r > 0 { q += 1 }
    return q
}

abs_int :: proc(v: int) -> int {
    if v < 0 { return -v }
    return v
}

max3_int :: proc(a, b, c: int) -> int {
    return max(a, max(b, c))
}

prepare_chunk_stream_cursor :: proc(w_map: ^Map, player_chunk: [3]int) {
    if !w_map.stream_chunk_pos_valid ||
       w_map.stream_chunk_pos.x != player_chunk.x ||
       w_map.stream_chunk_pos.y != player_chunk.y ||
       w_map.stream_chunk_pos.z != player_chunk.z {
        w_map.stream_chunk_pos = player_chunk
        w_map.stream_chunk_pos_valid = true
        w_map.chunk_stream_cursor = {}
    }
}

// Returns one coordinate on the Chebyshev shell without visiting the shell's interior.
chunk_stream_shell_cell :: proc(shell, cell_index: int) -> [3]int {
    if shell == 0 { return {} }

    width := shell*2+1
    face_count := width*width

    if cell_index < face_count*2 {
        face := cell_index/face_count
        index := cell_index%face_count
        z := -shell
        if face == 1 { z = shell }
        return {index/width-shell, index%width-shell, z}
    }

    index := cell_index-face_count*2
    inner_width := width-2
    side_face_count := width*inner_width
    if index < side_face_count*2 {
        face := index/side_face_count
        index %= side_face_count
        x := -shell
        if face == 1 { x = shell }
        return {x, index/inner_width-shell, index%inner_width-(shell-1)}
    }

    index -= side_face_count*2
    end_face_count := inner_width*inner_width
    face := index/end_face_count
    index %= end_face_count
    y := -shell
    if face == 1 { y = shell }
    return {index/inner_width-(shell-1), y, index%inner_width-(shell-1)}
}
make_chunk_stream_bounds :: proc(
    player_chunk: [3]int,
    settings: Chunk_Stream_Settings,
) -> (bounds: [MAX_CHUNK_STREAM_LOD_LEVELS]Chunk_Stream_Bounds, ok: bool) {
    if settings.lod_level_count < 1 || settings.lod_level_count > MAX_CHUNK_STREAM_LOD_LEVELS { return }
    if settings.lod_band_width < 1 || settings.lod0_radius_xz < 1 || settings.lod0_radius_y < 1 { return }
    if settings.max_chunk_loads_per_update < 1 || settings.max_chunk_unloads_per_update < 1 { return }

    radius_xz := settings.lod0_radius_xz
    radius_y := settings.lod0_radius_y

    for level := 0; level < settings.lod_level_count; level += 1 {
        size := 1 << cast(u32)level
        alignment := size
        if level + 1 < settings.lod_level_count {
            // The finer box must end on the next LOD's cell grid. Without
            // this, a coarse cell can partially overlap the finer region.
            alignment = size << 1
        }

        bounds[level].min = {
            floor_div(player_chunk.x-radius_xz, alignment)*alignment,
            floor_div(player_chunk.y-radius_y, alignment)*alignment,
            floor_div(player_chunk.z-radius_xz, alignment)*alignment,
        }
        bounds[level].max = {
            ceil_div(player_chunk.x+radius_xz, alignment)*alignment,
            ceil_div(player_chunk.y+radius_y, alignment)*alignment,
            ceil_div(player_chunk.z+radius_xz, alignment)*alignment,
        }

        if level + 1 < settings.lod_level_count {
            // This expands both sides by band_width*size. Since the next
            // LOD is twice this size, both sides together form band_width
            // chunks of thickness in that next LOD.
            radius_xz += settings.lod_band_width * size
            radius_y += settings.lod_band_width * size
        }
    }

    return bounds, true
}

chunk_key_level :: proc(key: [4]int) -> int {
    size := key.w
    if size < 1 || size > MAX_CHUNK_STREAM_LOD_SIZE { return -1 }

    expected := 1
    level := 0
    for expected < size {
        expected <<= 1
        level += 1
    }

    if expected != size { return -1 }
    if key.x%size != 0 || key.y%size != 0 || key.z%size != 0 { return -1 }

    return level
}

chunk_key_intersects_bounds :: proc(key: [4]int, bounds: Chunk_Stream_Bounds) -> bool {
    size := key.w
    return key.x < bounds.max.x && key.x+size > bounds.min.x &&
           key.y < bounds.max.y && key.y+size > bounds.min.y &&
           key.z < bounds.max.z && key.z+size > bounds.min.z
}

chunk_key_is_wanted :: proc(
    key: [4]int,
    bounds: [MAX_CHUNK_STREAM_LOD_LEVELS]Chunk_Stream_Bounds,
    lod_level_count: int,
) -> bool {
    level := chunk_key_level(key)
    if level < 0 || level >= lod_level_count { return false }

    size := key.w
    current := bounds[level]
    if key.x < current.min.x || key.x+size > current.max.x ||
       key.y < current.min.y || key.y+size > current.max.y ||
       key.z < current.min.z || key.z+size > current.max.z {
        return false
    }

    // Every coarser cell must be completely outside the previous finer box.
    // Bounds are aligned to this level's grid, so no cell can be partial.
    if level > 0 && chunk_key_intersects_bounds(key, bounds[level-1]) {
        return false
    }

    return true
}

chunk_key_intersects_chunk :: proc(a, b: [4]int) -> bool {
    return a.x < b.x+b.w && a.x+a.w > b.x &&
           a.y < b.y+b.w && a.y+a.w > b.y &&
           a.z < b.z+b.w && a.z+a.w > b.z
}

begin_chunk_retirement :: proc(w_map: ^Map, chunk_hd: Chunk_HD) -> bool {
    // Use the same lock order as destroy_chunk and mesh preparation:
    // map first, then the individual chunk. Unlinking the position here lets
    // a newly wanted chunk be created before the old chunk's tasks have drained.
    atom.atomic_rw_mutex_lock(&w_map.chunks_map_rw_mutex)
    chunk, ok := hm.get(&w_map.chunks, chunk_hd)
    if !ok {
        atom.atomic_rw_mutex_unlock(&w_map.chunks_map_rw_mutex)
        return false
    }

    atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
    if chunk.retiring {
        atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
        atom.atomic_rw_mutex_unlock(&w_map.chunks_map_rw_mutex)
        return false
    }

    chunk.retiring = true
    chunk_pos := chunk.pos
    gpu_mesh_data_hd := chunk.gpu_mesh_data_hd
    mapped_hd, mapped := w_map.chunks_map[chunk_pos]
    if mapped && mapped_hd == chunk_hd {
        delete_key(&w_map.chunks_map, chunk_pos)
    }
    atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
    atom.atomic_rw_mutex_unlock(&w_map.chunks_map_rw_mutex)

    // Hide the old GPU data immediately. Actual buffer and handle destruction
    // is deferred until no worker task can still reference the chunk.
    if hm.is_valid(&w_map.gpu_mesh_data_hm, gpu_mesh_data_hd) {
        gpu_mesh_data, gpu_mesh_ok := hm.get(&w_map.gpu_mesh_data_hm, gpu_mesh_data_hd)
        if gpu_mesh_ok { gpu_mesh_data.visible = false }
    }

    update_neighbors_after_chunk_retirement(w_map, chunk_hd)
    add_to_destroy_chunk_q(w_map, chunk_hd)
    return true
}

model_side_opposite :: proc(side: Model_Sides) -> Model_Sides {
    switch side {
    case .pos_x: return .neg_x
    case .neg_x: return .pos_x
    case .pos_y: return .neg_y
    case .neg_y: return .pos_y
    case .pos_z: return .neg_z
    case .neg_z: return .pos_z
    case .extra: return .extra
    }
    return .extra
}

chunk_stream_point_inside :: proc(point: [3]int, bounds: Chunk_Stream_Bounds) -> bool {
    return point.x >= bounds.min.x && point.x < bounds.max.x &&
           point.y >= bounds.min.y && point.y < bounds.max.y &&
           point.z >= bounds.min.z && point.z < bounds.max.z
}

chunk_stream_find_wanted_key_at_pos :: proc(
    point: [3]int,
    bounds: [MAX_CHUNK_STREAM_LOD_LEVELS]Chunk_Stream_Bounds,
    lod_level_count: int,
) -> (key: [4]int, found: bool) {
    for level := 0; level < lod_level_count; level += 1 {
        size := 1 << cast(u32)level
        candidate := [4]int{
            floor_div(point.x, size)*size,
            floor_div(point.y, size)*size,
            floor_div(point.z, size)*size,
            size,
        }
        if chunk_key_is_wanted(candidate, bounds, lod_level_count) {
            return candidate, true
        }
    }
    return
}

chunk_stream_region_has_wanted_lod :: proc(
    key: [4]int,
    bounds: [MAX_CHUNK_STREAM_LOD_LEVELS]Chunk_Stream_Bounds,
    lod_level_count: int,
) -> bool {
    if key.w <= 0 { return false }
    chunk_min := key.xyz
    chunk_max := [3]int{key.x+key.w, key.y+key.w, key.z+key.w}

    // The wanted region is the union of the nested LOD boxes, with each
    // coarser level owning only the ring outside the previous finer box.
    // This tests coverage with at most one box test per LOD, without walking
    // replacement cells or doing any chunk-handle lookups.
    for level := 0; level < lod_level_count; level += 1 {
        region := bounds[level]
        overlap_min := [3]int{
            max(chunk_min.x, region.min.x),
            max(chunk_min.y, region.min.y),
            max(chunk_min.z, region.min.z),
        }
        overlap_max := [3]int{
            min(chunk_max.x, region.max.x),
            min(chunk_max.y, region.max.y),
            min(chunk_max.z, region.max.z),
        }
        if overlap_min.x >= overlap_max.x || overlap_min.y >= overlap_max.y || overlap_min.z >= overlap_max.z {
            continue
        }
        if level == 0 { return true }

        inner := bounds[level-1]
        if overlap_min.x < inner.min.x || overlap_max.x > inner.max.x ||
           overlap_min.y < inner.min.y || overlap_max.y > inner.max.y ||
           overlap_min.z < inner.min.z || overlap_max.z > inner.max.z {
            return true
        }
    }
    return false
}

chunk_stream_voxel_lighting_ready :: proc(w_map: ^Map, chunk: ^Chunk) -> bool {
    atom.atomic_rw_mutex_shared_lock(&chunk.data_rw_mutex)
    ready := !chunk.retiring && chunk.light_data_q_state == .usable && lighting_ready_mask_complete(chunk.lighting_redy_mask)
    vox_data_hd := chunk.vox_data_hd
    atom.atomic_rw_mutex_shared_unlock(&chunk.data_rw_mutex)
    if !ready { return false }
    vox_data, vox_ok := hm.get(&w_map.vox_chunk_hm, vox_data_hd)
    return vox_ok && atom.atomic_load(&vox_data.vox_gened)
}

chunk_mesh_side_render_ready :: proc(chunk: ^Chunk, side: Model_Sides) -> bool {
    atom.atomic_rw_mutex_shared_lock(&chunk.data_rw_mutex)
    ready := chunk.mesh_q_state[side] == .usable && side in chunk.mesh_gpu_ready_mask
    atom.atomic_rw_mutex_shared_unlock(&chunk.data_rw_mutex)
    return ready
}

chunk_stream_mesh_boundary_ready :: proc(
    w_map: ^Map,
    chunk: ^Chunk,
    side: Model_Sides,
    bounds: [MAX_CHUNK_STREAM_LOD_LEVELS]Chunk_Stream_Bounds,
    lod_level_count: int,
) -> bool {
    size := chunk.pos.w
    neighbor_point := chunk.pos.xyz
    switch side {
    case .pos_x: neighbor_point.x += size
    case .neg_x: neighbor_point.x -= size
    case .pos_y: neighbor_point.y += size
    case .neg_y: neighbor_point.y -= size
    case .pos_z: neighbor_point.z += size
    case .neg_z: neighbor_point.z -= size
    case .extra: return true
    }

    // There is no replacement boundary outside the active clipbox.
    outer_bounds := bounds[lod_level_count-1]
    if !chunk_stream_point_inside(neighbor_point, outer_bounds) { return true }

    neighbor_key, wanted := chunk_stream_find_wanted_key_at_pos(neighbor_point, bounds, lod_level_count)
    if !wanted { return false }
    neighbor_hd, exists := get_chunk_by_pos_safe(w_map, neighbor_key)
    if !exists { return false }
    neighbor, neighbor_ok := hm.get(&w_map.chunks, neighbor_hd)
    if !neighbor_ok || !chunk_stream_voxel_lighting_ready(w_map, neighbor) { return false }

    opposite := model_side_opposite(side)
    if neighbor.pos.w > size {
        // A coarser neighbor owns this transition face.
        return chunk_mesh_side_render_ready(neighbor, opposite)
    }
    if neighbor.pos.w < size {
        // This chunk is coarser and owns the face against four smaller cells.
        return chunk_mesh_side_render_ready(chunk, side)
    }

    // Same-size neighbors mesh both sides of their shared boundary.
    return chunk_mesh_side_render_ready(chunk, side) && chunk_mesh_side_render_ready(neighbor, opposite)
}

chunk_stream_chunk_render_ready :: proc(
    w_map: ^Map,
    chunk: ^Chunk,
    bounds: [MAX_CHUNK_STREAM_LOD_LEVELS]Chunk_Stream_Bounds,
    lod_level_count: int,
) -> bool {
    if !chunk_stream_voxel_lighting_ready(w_map, chunk) { return false }
    for side in Model_Sides {
        if side == .extra { continue }
        if !chunk_stream_mesh_boundary_ready(w_map, chunk, side, bounds, lod_level_count) {
            return false
        }
    }
    return true
}

chunk_stream_replacement_state :: proc(
    w_map: ^Map,
    old_chunk_pos: [4]int,
    bounds: [MAX_CHUNK_STREAM_LOD_LEVELS]Chunk_Stream_Bounds,
    lod_level_count: int,
) -> (needed: bool, renderable: bool) {
    old_chunk_bounds := Chunk_Stream_Bounds{
        min = old_chunk_pos.xyz,
        max = {old_chunk_pos.x+old_chunk_pos.w, old_chunk_pos.y+old_chunk_pos.w, old_chunk_pos.z+old_chunk_pos.w},
    }
    renderable = true

    for level := 0; level < lod_level_count; level += 1 {
        size := 1 << cast(u32)level
        region := bounds[level]
        overlap_min := [3]int{
            max(old_chunk_bounds.min.x, region.min.x),
            max(old_chunk_bounds.min.y, region.min.y),
            max(old_chunk_bounds.min.z, region.min.z),
        }
        overlap_max := [3]int{
            min(old_chunk_bounds.max.x, region.max.x),
            min(old_chunk_bounds.max.y, region.max.y),
            min(old_chunk_bounds.max.z, region.max.z),
        }
        if overlap_min.x >= overlap_max.x || overlap_min.y >= overlap_max.y || overlap_min.z >= overlap_max.z {
            continue
        }

        min_cell := [3]int{
            floor_div(overlap_min.x, size),
            floor_div(overlap_min.y, size),
            floor_div(overlap_min.z, size),
        }
        max_cell := [3]int{
            ceil_div(overlap_max.x, size),
            ceil_div(overlap_max.y, size),
            ceil_div(overlap_max.z, size),
        }

        for cx := min_cell.x; cx < max_cell.x; cx += 1 {
            for cy := min_cell.y; cy < max_cell.y; cy += 1 {
                for cz := min_cell.z; cz < max_cell.z; cz += 1 {
                    key := [4]int{cx*size, cy*size, cz*size, size}
                    if !chunk_key_is_wanted(key, bounds, lod_level_count) { continue }
                    if !chunk_key_intersects_bounds(key, old_chunk_bounds) { continue }
                    needed = true

                    replacement_hd, exists := get_chunk_by_pos_safe(w_map, key)
                    if !exists { return true, false }
                    replacement, replacement_ok := hm.get(&w_map.chunks, replacement_hd)
                    if !replacement_ok || !chunk_stream_chunk_render_ready(w_map, replacement, bounds, lod_level_count) {
                        return true, false
                    }
                }
            }
        }
    }

    // No wanted LOD cell overlaps this chunk. It has no replacement to wait
    // for and must be retired instead of being kept alive indefinitely.
    return needed, true
}

removing_chunks_not_around_pos :: proc(w_map: ^Map, pos: [3]f32) -> (did_work: bool) {
    player_chunk := pos_to_chunck_pos(pos)
    settings := w_map.chunk_stream_settings
    prepare_chunk_stream_cursor(w_map, player_chunk)

    bounds, valid := make_chunk_stream_bounds(player_chunk, settings)
    if !valid { return }

    // Keep the nearest replacement-ready chunks first. This budget is
    // independent of the load budget; unloads are allowed to process far more
    // than the old 100-chunk load cap.
    unload_budget := min(settings.max_chunk_unloads_per_update, MAX_CHUNK_UNLOAD_CANDIDATES_PER_UPDATE)
    candidates: [MAX_CHUNK_UNLOAD_CANDIDATES_PER_UPDATE]Chunk_Unload_Candidate
    candidate_count := 0

    itor := hm.iterator_make(&w_map.chunks)
    for chunk, chunk_hd in hm.iterate(&itor) {
        if chunk.retiring || chunk_key_is_wanted(chunk.pos, bounds, settings.lod_level_count) {
            continue
        }

        // If no LOD level wants any part of this chunk, retire it immediately.
        // This is only a handful of bounds checks; it does not search for
        // replacement chunks or wait for lighting/meshing to finish.
        if !chunk_stream_region_has_wanted_lod(chunk.pos, bounds, settings.lod_level_count) {
            if begin_chunk_retirement(w_map, chunk_hd) { did_work = true }
            continue
        }

        dx := 0
        dy := 0
        dz := 0
        if player_chunk.x < chunk.pos.x { dx = chunk.pos.x-player_chunk.x }
        else if player_chunk.x >= chunk.pos.x+chunk.pos.w { dx = player_chunk.x-(chunk.pos.x+chunk.pos.w-1) }
        if player_chunk.y < chunk.pos.y { dy = chunk.pos.y-player_chunk.y }
        else if player_chunk.y >= chunk.pos.y+chunk.pos.w { dy = player_chunk.y-(chunk.pos.y+chunk.pos.w-1) }
        if player_chunk.z < chunk.pos.z { dz = chunk.pos.z-player_chunk.z }
        else if player_chunk.z >= chunk.pos.z+chunk.pos.w { dz = player_chunk.z-(chunk.pos.z+chunk.pos.w-1) }
        distance := dx*dx + dy*dy + dz*dz

        if candidate_count == unload_budget && distance >= candidates[candidate_count-1].distance {
            continue
        }

        // Only do the expensive replacement mesh/readiness walk for chunks
        // close enough to enter the nearest-first unload set.
        replacement_needed, replacements_renderable := chunk_stream_replacement_state(
            w_map, chunk.pos, bounds, settings.lod_level_count,
        )
        if !replacement_needed {
            if begin_chunk_retirement(w_map, chunk_hd) { did_work = true }
            continue
        }
        if !replacements_renderable { continue }

        insert_at := candidate_count
        for i := 0; i < candidate_count; i += 1 {
            if distance < candidates[i].distance {
                insert_at = i
                break
            }
        }

        if candidate_count < unload_budget { candidate_count += 1 }
        for i := candidate_count-1; i > insert_at; i -= 1 {
            candidates[i] = candidates[i-1]
        }
        candidates[insert_at] = Chunk_Unload_Candidate{chunk_hd=chunk_hd, distance=distance}
    }

    // Retire replacement-ready chunks from nearest to farthest.
    for i := 0; i < candidate_count; i += 1 {
        if begin_chunk_retirement(w_map, candidates[i].chunk_hd) {
            did_work = true
        }
    }
    return
}

adding_chunks_around_pos :: proc(w_map: ^Map, pos: [3]f32) -> (did_work: bool) {
    player_chunk := pos_to_chunck_pos(pos)
    settings := w_map.chunk_stream_settings
    prepare_chunk_stream_cursor(w_map, player_chunk)
    cursor := &w_map.chunk_stream_cursor

    // The LOD scan is complete until the player enters a different chunk.
    if cursor.level >= settings.lod_level_count { return }

    if thread.pool_num_waiting(&w_map.t_pool) > 0 { return }
    if chan.len(w_map.gen_chunk_chan) > 0 { return }
    if hm.len(w_map.chunks_mesh_data) > 0 { return }

    itor := hm.iterator_make(&w_map.chunks)
    for chunk, _ in hm.iterate(&itor) {
        for state in chunk.mesh_q_state {
            if state == .in_q { return }
        }
    }

    bounds, valid := make_chunk_stream_bounds(player_chunk, settings)
    if !valid { return }

    queued := 0
    load_budget := min(settings.max_chunk_loads_per_update, MAX_CHUNKS_TO_ADD_PER_FRAME)

    // Use the current player chunk as the scan center. The cursor is reset
    // whenever that chunk changes, so no center needs to be stored in it.
    for level := cursor.level; level < settings.lod_level_count; level += 1 {
        size := 1 << cast(u32)level
        region := bounds[level]

        min_x := region.min.x / size
        min_y := region.min.y / size
        min_z := region.min.z / size
        max_x := region.max.x / size
        max_y := region.max.y / size
        max_z := region.max.z / size

        center_x := floor_div(player_chunk.x, size)
        center_y := floor_div(player_chunk.y, size)
        center_z := floor_div(player_chunk.z, size)

        max_shell := max3_int(
            max(abs_int(center_x-min_x), abs_int(max_x-1-center_x)),
            max(abs_int(center_y-min_y), abs_int(max_y-1-center_y)),
            max(abs_int(center_z-min_z), abs_int(max_z-1-center_z)),
        )

        start_shell := 0
        if level == cursor.level { start_shell = cursor.shell }
        for shell := start_shell; shell <= max_shell; shell += 1 {
            shell_cell_count := 1
            if shell > 0 {
                width := shell*2+1
                inner_width := width-2
                shell_cell_count = 2*width*width + 2*width*inner_width + 2*inner_width*inner_width
            }

            start_cell := 0
            if level == cursor.level && shell == cursor.shell { start_cell = cursor.cell_index }
            for cell_index := start_cell; cell_index < shell_cell_count; cell_index += 1 {
                offset := chunk_stream_shell_cell(shell, cell_index)
                cx := center_x+offset.x
                cy := center_y+offset.y
                cz := center_z+offset.z

                if cx < min_x || cx >= max_x || cy < min_y || cy >= max_y || cz < min_z || cz >= max_z { continue }

                key := [4]int{cx*size, cy*size, cz*size, size}
                if !chunk_key_is_wanted(key, bounds, settings.lod_level_count) { continue }
                if _, exists := get_chunk_by_pos_safe(w_map, key); exists { continue }

                add_to_gen_chunk_q(w_map, key)
                did_work = true
                queued += 1
                if queued >= load_budget {
                    cursor.level = level
                    cursor.shell = shell
                    cursor.cell_index = cell_index+1
                    return
                }
            }
            cursor.shell = shell+1
            cursor.cell_index = 0
        }

        cursor.level = level+1
        cursor.shell = 0
        cursor.cell_index = 0
    }

    cursor.level = settings.lod_level_count
    cursor.shell = 0
    cursor.cell_index = 0
    return
}

pool_task_references_chunk :: proc(
    task: All_Tasks,
    chunk_hd: Chunk_HD,
    vox_data_hd: Vox_Chunk_Data_HD,
    has_vox_data: bool,
    light_data_hd: Light_Chunk_Data_HD,
    has_light_data: bool,
) -> bool {
    switch t in task {
    case Gen_Vox_Data_Task:
        return t.chunk_hd == chunk_hd || (has_vox_data && t.vox_data_hd == vox_data_hd)
    case Mesh_Chunk_Task:
        return t.chunk_hd == chunk_hd
    case Light_Chunk_Task:
        if t.chunk_hd == chunk_hd || t.calling_chunk_hd == chunk_hd { return true }
        if has_vox_data {
            if t.vox_data_hd == vox_data_hd || t.calling_vox_data_hd == vox_data_hd { return true }
            for hd in t.nabors_vox_data_hd { if hd == vox_data_hd { return true } }
        }
        for hd in t.nabors_chunk_hd { if hd == chunk_hd { return true } }
    }
    return false
}

update_neighbors_after_chunk_retirement :: proc(w_map: ^Map, chunk_hd: Chunk_HD) {
    chunk, ok := hm.get(&w_map.chunks, chunk_hd)
    if !ok { return }

    for offset, direction in FULL_DIR_OFFSETS_r {
        neighbor_pos := chunk.pos
        neighbor_pos.xyz += offset * chunk.pos.w

        neighbor_hd, exists := get_chunk_by_pos_safe(w_map, neighbor_pos)
        if !exists { continue }

        neighbor, neighbor_ok := hm.get(&w_map.chunks, neighbor_hd)
        if !neighbor_ok { continue }

        opposite_direction := OPPOITE_FULL_DIR_OFFSETS_r[direction]
        atom.atomic_rw_mutex_lock(&neighbor.data_rw_mutex)
        neighbor.lighting_redy_mask += {opposite_direction}
        atom.atomic_rw_mutex_unlock(&neighbor.data_rw_mutex)
    }
}

update_w_map_draw_cmds_buff::proc(w_map:^Map){
	mesh:=tg.get_mesh(w_map.draw_cmd_buf_hd)
	mesh_2:=tg.get_mesh(w_map.draw_cmd_buf_comped_hd)
	chunck_shader_data:=tg.get_mesh(w_map.chunk_shader_data.mesh_hd)
	w_map.chunk_shader_data.count = 0
	tmep_full_count:int
	tg.clear_mesh_cpu(&mesh.cpu)
	tg.clear_mesh_cpu(&chunck_shader_data.cpu)

	itor:=hm.iterator_make(&w_map.gpu_mesh_data_hm)
	loop:for gpu_mesh, gpu_mesh_hd in hm.iterate(&itor) {
		if !gpu_mesh.visible { continue }
		for draw_cmd, side in gpu_mesh.draw_cmd{

			tmep_full_count+=1
			draw_cmd_:[1]sdl.GPUIndirectDrawCommand=draw_cmd
			tg.append_to_mesh(&mesh.cpu,{},draw_cmd_[:])
			chunck_shader_data_:[1]Chunk_Shader_Data=gpu_mesh.chunk_shader_data[side]
			tg.append_to_mesh(&chunck_shader_data.cpu,{},chunck_shader_data_[:])
			w_map.chunk_shader_data.count+=1
		}
	}

	tg.update_mesh(w_map.draw_cmd_buf_hd, false)
	tg.update_mesh(w_map.chunk_shader_data.mesh_hd, false )
	mesh.gpu.index_count = cast(u32)w_map.chunk_shader_data.count
	mesh_2.gpu.index_count =  cast(u32)w_map.chunk_shader_data.count
}

render_map::proc(w_map:^Map){
	tg.do_render_pass(&g.vox_pass, &g.cam, {w_map.map_mesh_hd},{&g.texture_facees,&g.geometry_facees, &w_map.chunk_shader_data}, {w_map.draw_cmd_buf_comped_hd},type = .face)
}

get_chunk_by_pos_safe::proc(w_map:^Map,pos:[4]int)->(chunk_hd:Chunk_HD, chunk_ok:bool){
	atom.atomic_rw_mutex_shared_lock(&w_map.chunks_map_rw_mutex)
	chunk_hd, chunk_ok = w_map.chunks_map[pos]
	atom.atomic_rw_mutex_shared_unlock(&w_map.chunks_map_rw_mutex)
	return
}


Q_State::enum{
	newver_qed,
	in_q,
	usable,
	// finished,
}

set_chunk_light_q_state :: proc(chunk: ^Chunk, state: Q_State) {
	atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
	chunk.light_data_q_state = state
	atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
}

chunk_is_retiring :: proc(chunk: ^Chunk) -> bool {
	atom.atomic_rw_mutex_shared_lock(&chunk.data_rw_mutex)
	retiring := chunk.retiring
	atom.atomic_rw_mutex_shared_unlock(&chunk.data_rw_mutex)
	return retiring
}

chunk_is_mesh_side_queued :: proc(chunk: ^Chunk, side: Model_Sides) -> bool {
	atom.atomic_rw_mutex_shared_lock(&chunk.data_rw_mutex)
	queued := !chunk.retiring && chunk.mesh_q_state[side] == .in_q
	atom.atomic_rw_mutex_shared_unlock(&chunk.data_rw_mutex)
	return queued
}
manage_all_w_map_q::proc(w_map:^Map)->(did_work:bool){
    // Drain completed worker tasks before deciding what can be retired.
    fin_work, fin_mesh_changed := fin_pool_tasks(w_map)
    did_work = fin_work || did_work
    mesh_changed := fin_mesh_changed

    // Keep old chunks only where a wanted LOD replacement covers them, and
    // only until those replacement meshes are uploaded. Chunks with no wanted
    // LOD coverage are retired immediately by removing_chunks_not_around_pos.
    remove_work := removing_chunks_not_around_pos(w_map, tg.get_cam_pos_f32(&g.cam))
    did_work = remove_work || did_work

    did_work = adding_chunks_around_pos(w_map, tg.get_cam_pos_f32(&g.cam)) || did_work
    did_work = manage_gen_chunk_q(w_map) || did_work
    did_work = manage_gen_vox_data_q(w_map) || did_work
    did_work = manage_set_block_cmd_q(w_map) || did_work
    did_work = manage_chunk_needs_meshing_q(w_map) || did_work
    did_work = manage_gen_mesh_data_q(w_map) || did_work

    // Lighting completion can enqueue more meshing work. Process that work
    // before upload and before testing retired chunks for final destruction.
    fin_work, fin_mesh_changed = fin_pool_tasks(w_map)
    did_work = fin_work || did_work
    mesh_changed = fin_mesh_changed || mesh_changed
    did_work = manage_chunk_needs_meshing_q(w_map) || did_work
    did_work = manage_gen_mesh_data_q(w_map) || did_work

    upload_work := manage_upload_mesh_data_q(w_map)
    did_work = upload_work || did_work
    did_work = manage_destroy_mesh_data_q(w_map) || did_work

    // A retired chunk is freed only after every task and queue message that
    // can reference its voxel, lighting, or mesh data has drained.
    destroy_work := manage_destroy_chunk_q(w_map)
    did_work = destroy_work || did_work
    did_work = manage_destroy_vox_data_q(w_map) || did_work
    did_work = manage_destroy_mesh_data_q(w_map) || did_work

    if upload_work || remove_work || mesh_changed {
        update_w_map_draw_cmds_buff(w_map)
    }

    get_w_map_debug_info(w_map)
    return
}

get_w_map_debug_info::proc(w_map:^Map){
	g.debug_info.gen_chunk_q_len 		= cast(int)chan.len(w_map.gen_chunk_chan)
	g.debug_info.destroy_chunk_q_len 	= cast(int)chan.len(w_map.destroy_chunk_chan)
	g.debug_info.gen_vox_data_q_len 	= cast(int)chan.len(w_map.gen_vox_data_chan)
	g.debug_info.gen_mesh_data_q_len 	= cast(int)chan.len(w_map.gen_mesh_data_chan)
	g.debug_info.destroy_mesh_data_q_len= cast(int)chan.len(w_map.destroy_mesh_data_chan)
	g.debug_info.upload_mesh_data_q_len = cast(int)chan.len(w_map.upload_mesh_data_chan)

	g.debug_info.space_lef_on_gpu_buff  = tg.free_list_space_lef(&w_map.chunks_in_mesh)

	g.debug_info.light_qs_hm_len  		= cast(int)hm.len(w_map.light_qs_hm)
	g.debug_info.chunks_map_len			= cast(int)len(w_map.chunks_map)
	g.debug_info.chunks_len				= cast(int)hm.len(w_map.chunks)
	// g.debug_info.chunks_voxel_data_len	= cast(int)hm.len(w_map.chunks_voxel_data)
	g.debug_info.chunks_mesh_data_len	= cast(int)hm.len(w_map.chunks_mesh_data)

	g.debug_info.pool_num_waiting = thread.pool_num_waiting(&w_map.t_pool)
	g.debug_info.pool_num_in_processing = thread.pool_num_in_processing(&w_map.t_pool)
	g.debug_info.pool_num_outstanding = thread.pool_num_outstanding(&w_map.t_pool)
	g.debug_info.pool_num_done = thread.pool_num_done(&w_map.t_pool)


	
}

// Gen_Chunk_Q::hm.Dynamic_Handle_Map(Gen_Chunk_Q_Data,Gen_Chunk_Q_HD)
// Gen_Chunk_Q_HD::distinct hm.Handle64
Gen_Chunk_Q_Data::struct{
	// handle:Gen_Chunk_Q_HD,
	pos:[4]int,
	// q_state:Q_State,
}
manage_gen_chunk_q::proc(w_map:^Map)->(did_work:bool){
	queued_count := min(cast(int)chan.len(w_map.gen_chunk_chan), MAX_CHUNKS_TO_ADD_PER_FRAME)
	for i := 0; i < queued_count; i += 1 {
		value, ok := chan.try_recv(w_map.gen_chunk_chan)
		if !ok { break }
		did_work = true
		do_a_gen_chunk_q(w_map, value)
	}
	return
}
add_to_gen_chunk_q::proc(w_map:^Map,pos:[4]int){
	chan.send(w_map.gen_chunk_chan,Gen_Chunk_Q_Data{pos = pos})
	return
}
do_a_gen_chunk_q::proc(w_map:^Map,q:Gen_Chunk_Q_Data){
    // A request can sit in the channel while the viewer moves. Revalidate it
    // so an obsolete LOD cell is never created after a clipbox change.
    player_chunk := cast([3]int)g.cam.w_pos.step
    bounds, valid := make_chunk_stream_bounds(player_chunk, w_map.chunk_stream_settings)
    if !valid || !chunk_key_is_wanted(q.pos, bounds, w_map.chunk_stream_settings.lod_level_count) {
        return
    }
    add_chunk(w_map,q.pos)
}
add_chunk::proc(w_map:^Map,pos:[4]int){
	atom.atomic_rw_mutex_lock(&w_map.chunks_map_rw_mutex)
	_, exists := w_map.chunks_map[pos]
	if exists {
		atom.atomic_rw_mutex_unlock(&w_map.chunks_map_rw_mutex)
		return
	}
	new_chunk_hd, err := hm.add(&w_map.chunks, Chunk{pos=pos})
	if err != .None {
		atom.atomic_rw_mutex_unlock(&w_map.chunks_map_rw_mutex)
		log.log(.Error, "add_chunk() failed to add chunk to handle map", err, pos)
		return
	}
	w_map.chunks_map[pos] = new_chunk_hd
	atom.atomic_rw_mutex_unlock(&w_map.chunks_map_rw_mutex)
	add_to_gen_vox_data_q(w_map, new_chunk_hd, pos)
}

Destroy_Chunk_Q_Data::struct{
	data_hd:Chunk_HD,
}
manage_destroy_chunk_q::proc(w_map:^Map)->(did_work:bool){
    // Keep deferred destruction bounded. Unsafe chunks are requeued instead
    // of spinning, while later entries get a chance on the next update.
    destroy_budget := min(w_map.chunk_stream_settings.max_chunk_unloads_per_update, MAX_CHUNK_UNLOAD_CANDIDATES_PER_UPDATE)
    if destroy_budget < 1 { destroy_budget = 1 }
    queued_count := cast(int)chan.len(w_map.destroy_chunk_chan)
    if queued_count > destroy_budget { queued_count = destroy_budget }
    for i := 0; i < queued_count; i += 1 {
        value, ok := chan.try_recv(w_map.destroy_chunk_chan)
        if !ok { break }
        if chunk_can_be_destroyed(w_map, value.data_hd) {
            destroy_chunk(w_map, value.data_hd)
            did_work = true
        } else {
            chan.send(w_map.destroy_chunk_chan, value)
        }
    }
    return
}

add_to_destroy_chunk_q::proc(w_map:^Map,chunk_hd:Chunk_HD){
    chan.send(w_map.destroy_chunk_chan,Destroy_Chunk_Q_Data{data_hd = chunk_hd})
    return
}

chunk_can_be_destroyed :: proc(w_map: ^Map, chunk_hd: Chunk_HD) -> bool {
	chunk, chunk_ok := hm.get(&w_map.chunks, chunk_hd)
	if !chunk_ok { return true }
	atom.atomic_rw_mutex_shared_lock(&chunk.data_rw_mutex)
	light_state := chunk.light_data_q_state
	vox_data_hd := chunk.vox_data_hd
	light_data_hd := chunk.light_data_hd
	mesh_states := chunk.mesh_q_state
	atom.atomic_rw_mutex_shared_unlock(&chunk.data_rw_mutex)
	if light_state != .usable { return false }
	for state in mesh_states { if state == .in_q { return false } }

	has_vox_data := hm.is_valid(&w_map.vox_chunk_hm, vox_data_hd)
	has_light_data := hm.is_valid(&w_map.light_chunk_hm, light_data_hd)
	itor := hm.iterator_make(&w_map.pool_tasks)
	for pool_task, _ in hm.iterate(&itor) {
		if pool_task_references_chunk(pool_task.task, chunk_hd, vox_data_hd, has_vox_data, light_data_hd, has_light_data) {
			return false
		}
	}
	return true
}


destroy_chunk::proc(w_map:^Map,hd:Chunk_HD){
	// The map lock prevents new meshing preparations from discovering this
	// chunk while its data lock drains already-running readers.
	atom.atomic_rw_mutex_lock(&w_map.chunks_map_rw_mutex)
	chunk,ok:=hm.get(&w_map.chunks,hd)
	if !ok{
		atom.atomic_rw_mutex_unlock(&w_map.chunks_map_rw_mutex)
		log.log(.Warning,"cant find chunk",hd,"to destroy")
		return
	}

	atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
	chunk_pos := chunk.pos
	vox_data_hd := chunk.vox_data_hd
	gpu_mesh_data_hd := chunk.gpu_mesh_data_hd
	mapped_hd, mapped := w_map.chunks_map[chunk_pos]
	if mapped && mapped_hd == hd { delete_key(&w_map.chunks_map, chunk_pos) }
	atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)

	found,err:=hm.remove(&w_map.chunks,hd)
	atom.atomic_rw_mutex_unlock(&w_map.chunks_map_rw_mutex)
	if err !=.None{
		log.log(.Error, "failed to remove chunk",err,hd)
		return
	}
	if !found {
		log.log(.Error, "failed to remove chunk cant find",hd)
		return
	}

	add_to_destroy_vox_data_q(w_map, vox_data_hd)
	if hm.is_valid(&w_map.gpu_mesh_data_hm,gpu_mesh_data_hd) { unload_mesh_data(w_map,gpu_mesh_data_hd) }
}

Gen_Vox_Data_Q_Data::struct{
	pos:[4]int,
	data_hd:Chunk_HD,
}
manage_gen_vox_data_q::proc(w_map:^Map)->(did_work:bool){
	index:int
	for {
		value, ok := chan.try_recv(w_map.gen_vox_data_chan)
		if !ok {break }
		did_work=true
		index+=1
		do_a_gen_vox_data_q(w_map,value,index)
	}
	return

}
add_to_gen_vox_data_q::proc(w_map:^Map,chunk_hd:Chunk_HD,pos:[4]int){
	chan.send(w_map.gen_vox_data_chan,Gen_Vox_Data_Q_Data{data_hd = chunk_hd,pos = pos})
	return
}
do_a_gen_vox_data_q::proc(w_map:^Map,q:Gen_Vox_Data_Q_Data,index:int){
	chunk, chunk_ok := get_chunk(w_map, q.data_hd)
	if !chunk_ok { return }
	if chunk_is_retiring(chunk) {
		set_chunk_light_q_state(chunk, .usable)
		return
	}
	gen_chunk_vox_data(w_map,q,index)
}

gen_chunk_vox_data::proc(w_map:^Map,q:Gen_Vox_Data_Q_Data,index:int){
	// log.log(.Error,"GEN VOX CALLED chunk=",chunk_hd," pos=",pos)
	chunk, ok := get_chunk(w_map,q.data_hd)
	assert(ok)

	vox_chunk_hd:=make_new_vox_chunk_data(w_map, .u0)
	atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
	chunk.vox_data_hd = vox_chunk_hd
	atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
	vox_chunk,vox_chunk_ok:=get_vox_chunk_data(w_map,vox_chunk_hd)
	assert(vox_chunk_ok)

	init_chunk_lighting_ready_mask(w_map, q.data_hd)

	light_chunk_hd:=make_new_light_chunk_data(w_map, .u0)
	atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
	chunk.light_data_hd = light_chunk_hd
	atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
	light_chunk,light_chunk_ok:=get_light_chunk_data(w_map,light_chunk_hd)
	assert(light_chunk_ok)

	light_q_hd:=hm.add(&w_map.light_qs_hm,Light_Q{})
	new_light_q,light_q_ok:=hm.get(&w_map.light_qs_hm,light_q_hd)
	assert(light_q_ok)

	vox_chunk.pos = q.pos
	// chunk.chunk_shader_data.pos = {
	// 	cast(i32)q.pos.x,
	// 	cast(i32)q.pos.y,
	// 	cast(i32)q.pos.z,
	// 	cast(i32)q.pos.w,
	// }

	start_gen_vox_dat_task(w_map,Gen_Vox_Data_Task{w_map = w_map,vox_data_hd=vox_chunk_hd,chunk_hd = q.data_hd,light_q_hd = light_q_hd })
}




// gen_vox_data :: proc(
// 	t:Gen_Vox_Data_Task,
// 	// w_map:^Map,
// 	// vox_chunk_hd:Vox_Chunk_Data_HD,
// 	// chunk:^Chunk,
// ){
// 	chunk,chunk_ok:=hm.get(&t.w_map.chunks,t.chunk_hd)
// 	assert(chunk_ok)
// 	vox_chunk,vox_chunk_ok:=hm.get(&t.w_map.vox_chunk_hm,t.vox_data_hd)
// 	assert(vox_chunk_ok)
// 	light,light_ok:=hm.get(&t.w_map.light_chunk_hm,chunk.light_data_hd)
// 	assert(light_ok)

// 	pos:=vox_chunk.pos
// 	vox_chunk.pos = pos
// 	lod_lev := pos.w


// 	xz_scl:f64 = 0.001
// 	y_scl:f64 = 600.0

// 	world_x_start := pos.x * CHUNK_SIZE
// 	world_y_start := pos.y * CHUNK_SIZE
// 	world_z_start := pos.z * CHUNK_SIZE

	
// 	grass_pal_index := get_or_add_palette_index_by_item_hd(vox_chunk, g.df_items[.grass])
// 	stone_pal_index := get_or_add_palette_index_by_item_hd(vox_chunk, g.df_items[.stone_slate])

// 	chunk_has_changed:bool

// 	sun_masks:[CHUNK_SIZE * CHUNK_SIZE]u32
// 	sun_count:=0

// 	for x := 0; x < CHUNK_SIZE; x += 1 {
// 		world_x := world_x_start + x * lod_lev + lod_lev / 2

// 		for z := 0; z < CHUNK_SIZE; z += 1 {
// 			world_z := world_z_start + z * lod_lev + lod_lev / 2

// 			height := nos.noise_2d(
// 				6223378936854776807,
// 				{
// 					cast(f64)world_x * xz_scl,
// 					cast(f64)world_z * xz_scl,
// 				},
// 			)

// 			height_x := nos.noise_2d(
// 				6223378936854776807,
// 				{
// 					cast(f64)(world_x + lod_lev) * xz_scl,
// 					cast(f64)world_z * xz_scl,
// 				},
// 			)

// 			height_z := nos.noise_2d(
// 				6223378936854776807,
// 				{
// 					cast(f64)world_x * xz_scl,
// 					cast(f64)(world_z + lod_lev) * xz_scl,
// 				},
// 			)

// 			change_x := math.abs(height_x - height)
// 			change_z := math.abs(height_z - height)

// 			height_change := max(change_x/cast(f32)lod_lev, change_z/cast(f32)lod_lev)
// 			is_steep := height_change > 0.003

// 			height = (height + 1.0) * 0.5
// 			height = math.pow(height, 2.5)

// 			world_height := cast(int)(height * cast(f32)y_scl)
// 			solid_height := (world_height - world_y_start) / lod_lev

// 			mask_index := x + z*CHUNK_SIZE
			
// 			if solid_height <= 0 {
// 				sun_masks[mask_index] = 0xFFFF_FFFF
// 				sun_count += CHUNK_SIZE
// 				continue
// 			}
			
// 			if solid_height > CHUNK_SIZE {
// 				solid_height = CHUNK_SIZE
// 			}
			
// 			if solid_height < CHUNK_SIZE {
// 				sun_masks[mask_index] = 0xFFFF_FFFF << u32(solid_height)
// 				sun_count += CHUNK_SIZE-solid_height
// 			}

// 			if is_steep {
// 				set_blocks_in_chunk_by_col_pal_index(
// 					vox_chunk,
// 					stone_pal_index,
// 					{cast(u8)x, cast(u8)z},
// 					cast(u8)solid_height,
// 				)
// 			} else {
// 				set_blocks_in_chunk_by_col_pal_index(
// 					vox_chunk,
// 					grass_pal_index,
// 					{cast(u8)x, cast(u8)z},
// 					cast(u8)solid_height,
// 				)
// 			}
// 		}
// 	}

// 	init_worldgen_sun_light(light,sun_masks[:],sun_count)

	
// }

gen_vox_data :: proc(
	t:Gen_Vox_Data_Task,
){
	chunk,chunk_ok:=hm.get(&t.w_map.chunks,t.chunk_hd)
	assert(chunk_ok)
	atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
	defer atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
	vox_chunk,vox_chunk_ok:=hm.get(&t.w_map.vox_chunk_hm,t.vox_data_hd)
	assert(vox_chunk_ok)
	light,light_ok:=hm.get(&t.w_map.light_chunk_hm,chunk.light_data_hd)
	assert(light_ok)

	pos:=vox_chunk.pos
	lod_lev := pos.w
	assert(lod_lev > 0)

	// Keep the original terrain noise and its original height range. The new
	// low-frequency fields only decide where broad flatlands and rare large
	// mountain systems occur; they must not replace the original terrain.
	local_noise_scale:f64 = 0.0012
	flatland_noise_scale:f64 = 0.00001
	mountain_region_noise_scale:f64 = 0.000006
	mountain_ridge_noise_scale:f64 = 0.00002

	original_terrain_height:f64 = 90.0
	flatland_base_height:f64 = 300.0
	flatland_variation:f64 = 18.0
	massive_mountain_height:f64 = 30000.0

	world_x_start := pos.x * CHUNK_SIZE
	world_y_start := pos.y * CHUNK_SIZE
	world_z_start := pos.z * CHUNK_SIZE

	// Cache final world heights, including the extra row and column required
	// to classify slopes without sampling noise again in the voxel loop.
	height_samples:[CHUNK_SIZE+1][CHUNK_SIZE+1]f32

	for z := 0; z <= CHUNK_SIZE; z += 1 {
		world_z := world_z_start + z * lod_lev + lod_lev / 2

		for x := 0; x <= CHUNK_SIZE; x += 1 {
			world_x := world_x_start + x * lod_lev + lod_lev / 2
			noise_x := cast(f64)world_x
			noise_z := cast(f64)world_z

			// Original terrain: preserve the old 0..600 height contribution.
			local_noise := nos.noise_2d(
				6223378936854776807,
				{noise_x * local_noise_scale, noise_z * local_noise_scale},
			)
			original_height := math.pow((local_noise + 1.0) * 0.5, 2.5) * cast(f32)original_terrain_height

			// Large-scale flatland selector. Only regions where this field is
			// high are flattened; all other regions keep the original terrain.
			flatland_noise := nos.noise_2d(
				1384739205847381021,
				{noise_x * flatland_noise_scale, noise_z * flatland_noise_scale},
			)
			flatland_mask := max(0.0, min(1.0, (flatland_noise + 0.15) / 0.60))
			flatland_mask = flatland_mask * flatland_mask * (3.0 - 2.0 * flatland_mask)
			flatland_height := cast(f32)flatland_base_height + cast(f32)flatland_noise * cast(f32)flatland_variation
			base_height := original_height * (1.0 - flatland_mask) + flatland_height * flatland_mask

			// Low-frequency selector creates uncommon, very large mountain systems.
			// Its higher frequency than before makes mountain regions appear more often.
			mountain_region_noise := nos.noise_2d(
				7960286522194355707,
				{noise_x * mountain_region_noise_scale, noise_z * mountain_region_noise_scale},
			)
			mountain_mask := max(0.0, min(1.0, (mountain_region_noise - 0.48) / 0.42))
			mountain_mask = mountain_mask * mountain_mask * (3.0 - 2.0 * mountain_mask)

			// Broad ridge field shapes the interior of each mountain region.
			// It remains much larger than the local terrain, but has enough variation
			// to form multiple visible ridges instead of one nearly featureless dome.
			mountain_ridge_noise := nos.noise_2d(
				4127505447032374729,
				{noise_x * mountain_ridge_noise_scale, noise_z * mountain_ridge_noise_scale},
			)
			ridge := max(0.0, 1.0 - math.abs(mountain_ridge_noise))
			ridge = math.pow(ridge, 1.5)
			mountain_height := cast(f32)ridge * cast(f32)massive_mountain_height * cast(f32)mountain_mask

			final_height := base_height + mountain_height
			height_samples[z][x] = cast(f32)final_height
		}
	}

	sun_masks:[CHUNK_SIZE * CHUNK_SIZE]u32
	sun_count:=0

	grass_pal_index:u16
	stone_pal_index:u16
	has_grass_pal:=false
	has_stone_pal:=false

	grass_count:=0
	stone_count:=0
	solid_count:=0

	air_pal_index:u16
	has_air_pal:=false

	// X is the inner loop so column writes remain contiguous in memory.
	for z := 0; z < CHUNK_SIZE; z += 1 {
		for x := 0; x < CHUNK_SIZE; x += 1 {
			height := height_samples[z][x]
			height_x := height_samples[z][x+1]
			height_z := height_samples[z+1][x]

			// Use the final world-height gradient. This keeps broad flat regions
			// grassy while the much steeper mountain ridges become stone.
			change_x := math.abs(height_x - height)
			change_z := math.abs(height_z - height)
			height_change := max(change_x/cast(f32)lod_lev, change_z/cast(f32)lod_lev)
			is_steep := height_change > 0.003

			world_height := cast(int)height
			solid_height := (world_height - world_y_start) / lod_lev

			mask_index := x + z*CHUNK_SIZE
			sun_masks[mask_index] = 0

			if solid_height <= 0 {
				sun_masks[mask_index] = 0xFFFF_FFFF
				sun_count += CHUNK_SIZE

				if !has_air_pal {
					air_pal_index = get_or_add_palette_index(vox_chunk,Block_Palette_Data{item=g.df_items[.air],state={},})
					has_air_pal = true
				}
				continue
			}

			if solid_height > CHUNK_SIZE {
				solid_height = CHUNK_SIZE
			}

			if solid_height < CHUNK_SIZE {
				sun_masks[mask_index] = 0xFFFF_FFFF << u32(solid_height)
				sun_count += CHUNK_SIZE-solid_height
			}

			if is_steep {
				if !has_stone_pal {
					stone_pal_index = get_or_add_palette_index(vox_chunk,Block_Palette_Data{item=g.df_items[.stone_slate],state={},})
					has_stone_pal = true
				}

				set_blocks_in_chunk_by_col_pal_index(vox_chunk,stone_pal_index,{cast(u8)x,cast(u8)z},cast(u8)solid_height)
				stone_count += solid_height
			} else {
				if !has_grass_pal {
					grass_pal_index = get_or_add_palette_index(vox_chunk,Block_Palette_Data{item=g.df_items[.grass],state={},})
					has_grass_pal = true
				}

				set_blocks_in_chunk_by_col_pal_index(vox_chunk,grass_pal_index,{cast(u8)x,cast(u8)z},cast(u8)solid_height)
				grass_count += solid_height
			}

			solid_count += solid_height
		}
	}

	// The chunk starts uniformly as palette index 0 (air).
	// The column setter writes packed indices directly, so update counts once here.
	if solid_count > 0 {
		ab := &vox_chunk.backing_chunk_data_abstract
		vox_count := CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE

		ab.pal[0].count = cast(u16)(vox_count-solid_count)

		if has_grass_pal {
			ab.pal[grass_pal_index].count = cast(u16)grass_count
		}

		if has_stone_pal {
			ab.pal[stone_pal_index].count = cast(u16)stone_count
		}
	}

	init_worldgen_sun_light(light,sun_masks[:],sun_count)
}


Check_Needs_Meshing_Q_Data::struct{
	pos:[4]int,
}
manage_chunk_needs_meshing_q::proc(w_map:^Map)->(did_work:bool){
	for {
		value, ok := chan.try_recv(w_map.check_needs_meshing_chan)
		if !ok {
			break // More idiomatic than return here
		}
		did_work=true
		// do_a_gen_mesh_data_q(w_map,value)
		check_needs_meshing_q(w_map,value)
	}
	return
}
add_to_chunk_needs_meshing_q::proc(
	w_map:^Map,
	pos:[4]int,
){
	chan.send(w_map.check_needs_meshing_chan,Check_Needs_Meshing_Q_Data{pos})
	return
}
check_needs_meshing_q::proc(w_map:^Map,q:Check_Needs_Meshing_Q_Data){
	check_if_chunk_needs_meshing(w_map,q.pos)
}


check_if_chunk_needs_meshing :: proc(w_map:^Map,pos:[4]int) {
	chunk_hd,ok := get_chunk_by_pos_safe(w_map,pos)
	if !ok { return }

	chunk_data,chunk_data_ok := hm.dynamic_get(&w_map.chunks,chunk_hd)
	if !chunk_data_ok { return }
	atom.atomic_rw_mutex_shared_lock(&chunk_data.data_rw_mutex)
	chunk_retiring := chunk_data.retiring
	chunk_light_ready := chunk_data.light_data_q_state == .usable && lighting_ready_mask_complete(chunk_data.lighting_redy_mask)
	vox_hd := chunk_data.vox_data_hd
	atom.atomic_rw_mutex_shared_unlock(&chunk_data.data_rw_mutex)
	if chunk_retiring || !chunk_light_ready { return }

	vox_data,vox_data_ok := hm.dynamic_get(&w_map.vox_chunk_hm,vox_hd)
	assert(vox_data_ok)

	if !atom.atomic_load(&vox_data.vox_gened) { return }

	for side in Model_Sides {
		if side == .extra { continue }
		check_chunk_side_needs_meshing(w_map,chunk_hd,chunk_data,side)
	}
}

check_if_chunk_needs_meshing_side :: proc(
	w_map:^Map,
	pos:[4]int,
	side:Model_Sides,
){
	if side == .extra { return }

	chunk_hd,ok := get_chunk_by_pos_safe(w_map,pos)
	if !ok { return }

	chunk_data,chunk_data_ok := hm.dynamic_get(&w_map.chunks,chunk_hd)
	if !chunk_data_ok { return }
	atom.atomic_rw_mutex_shared_lock(&chunk_data.data_rw_mutex)
	chunk_retiring := chunk_data.retiring
	chunk_light_ready := chunk_data.light_data_q_state == .usable && lighting_ready_mask_complete(chunk_data.lighting_redy_mask)
	vox_hd := chunk_data.vox_data_hd
	atom.atomic_rw_mutex_shared_unlock(&chunk_data.data_rw_mutex)
	if chunk_retiring || !chunk_light_ready { return }

	vox_data,vox_data_ok := hm.dynamic_get(&w_map.vox_chunk_hm,vox_hd)
	assert(vox_data_ok)

	if !atom.atomic_load(&vox_data.vox_gened) { return }

	check_chunk_side_needs_meshing(w_map,chunk_hd,chunk_data,side)
}

check_chunk_side_needs_meshing :: proc(
	w_map:^Map,
	chunk_hd:Chunk_HD,
	chunk_data:^Chunk,
	side:Model_Sides,
){
	lod_size := chunk_data.pos.w
	offset := model_side_to_offset(side)
	key := chunk_data.pos
	key += {offset[0]*lod_size,offset[1]*lod_size,offset[2]*lod_size,0}

	neighbor_chunk_hd, neighbor_exists := get_chunk_by_pos_safe(w_map,key)
	has_4_neighbors := false
	neighbor_count := 1
	neighbor_chunk_hds: [4]Chunk_HD
	neighbor_chunk_hds[0] = neighbor_chunk_hd

	if !neighbor_exists {
		if lod_size <= 1 { return }
		half := lod_size/2
		u_offset,v_offset:[4]int
		switch side {
		case .pos_x, .neg_x:
			u_offset = {0,half,0,0}
			v_offset = {0,0,half,0}
		case .pos_y, .neg_y:
			u_offset = {half,0,0,0}
			v_offset = {0,0,half,0}
		case .pos_z, .neg_z:
			u_offset = {half,0,0,0}
			v_offset = {0,half,0,0}
		case .extra:
			return
		}

		lower_lod_base := chunk_data.pos
		lower_lod_base.w = half
		face_axis := int(side)/2
		if offset[face_axis] > 0 { lower_lod_base[face_axis] += lod_size }
		else { lower_lod_base[face_axis] -= half }

		lower_lod_key:[4][4]int
		lower_lod_key[0] = lower_lod_base
		lower_lod_key[1] = lower_lod_base + u_offset
		lower_lod_key[2] = lower_lod_base + v_offset
		lower_lod_key[3] = lower_lod_base + u_offset + v_offset

		has_4_neighbors = true
		neighbor_count = 4
		for i in 0..<4 {
			neighbor_chunk_hds[i], neighbor_exists = get_chunk_by_pos_safe(w_map,lower_lod_key[i])
			if !neighbor_exists { return }
		}
	}

	for i in 0..<neighbor_count {
		neighbor_chunk, neighbor_ok := get_chunk(w_map,neighbor_chunk_hds[i])
		if !neighbor_ok { return }
		atom.atomic_rw_mutex_shared_lock(&neighbor_chunk.data_rw_mutex)
		neighbor_ready := !neighbor_chunk.retiring && neighbor_chunk.light_data_q_state == .usable && lighting_ready_mask_complete(neighbor_chunk.lighting_redy_mask)
		neighbor_vox_hd := neighbor_chunk.vox_data_hd
		atom.atomic_rw_mutex_shared_unlock(&neighbor_chunk.data_rw_mutex)
		if !neighbor_ready { return }
		neighbor_vox_data, neighbor_vox_ok := get_vox_chunk_data(w_map,neighbor_vox_hd)
		if !neighbor_vox_ok || !atom.atomic_load(&neighbor_vox_data.vox_gened) { return }
	}

	add_to_gen_mesh_data_q(w_map,chunk_hd,side)
	if !has_4_neighbors {
		add_to_gen_mesh_data_q(w_map,neighbor_chunk_hds[0],model_side_opposite(side))
	}
}


Destroy_Vox_Data_Q_Data::struct{
	data_hd:Vox_Chunk_Data_HD,
}
manage_destroy_vox_data_q::proc(w_map:^Map)->(did_work:bool){
	for {
		value, ok := chan.try_recv(w_map.destroy_vox_data_chan)
		if !ok {
			break // More idiomatic than return here
		}
		did_work=true
		do_a_destroy_vox_data_q(w_map,value)
	}
	return
}
add_to_destroy_vox_data_q::proc(w_map:^Map,vox_data_hd:Vox_Chunk_Data_HD){
	chan.send(w_map.destroy_vox_data_chan,Destroy_Vox_Data_Q_Data{vox_data_hd})
	return
}
do_a_destroy_vox_data_q::proc(w_map:^Map,q:Destroy_Vox_Data_Q_Data){

	delete_vox_chunk_data(w_map,q.data_hd)

}


Gen_Mesh_Data_Q_Data::struct{
	data_hd: Chunk_HD,
	side: Model_Sides,
}
manage_gen_mesh_data_q::proc(w_map:^Map)->(did_work:bool){
	for {
		value, ok := chan.try_recv(w_map.gen_mesh_data_chan)
		if !ok {
			break // More idiomatic than return here
		}
		did_work=true
		do_a_gen_mesh_data_q(w_map,value)
	}
	return
}
add_to_gen_mesh_data_q::proc(w_map:^Map, chunk_hd:Chunk_HD, side:Model_Sides){
	chunk, chunk_ok:=hm.get(&w_map.chunks,chunk_hd)
	if !chunk_ok { return }
	atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
	if chunk.retiring || chunk.mesh_q_state[side] == .in_q {
		atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
		return
	}
	chunk.mesh_q_state[side] = .in_q
	// Keep the previous GPU side visible until a replacement mesh uploads.
	atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
	chan.send(w_map.gen_mesh_data_chan,Gen_Mesh_Data_Q_Data{data_hd=chunk_hd,side=side})
	return
}
do_a_gen_mesh_data_q::proc(w_map:^Map,q:Gen_Mesh_Data_Q_Data){
	chunk, chunk_ok := hm.get(&w_map.chunks, q.data_hd)
	if !chunk_ok { return }
	atom.atomic_rw_mutex_shared_lock(&chunk.data_rw_mutex)
	retiring := chunk.retiring
	atom.atomic_rw_mutex_shared_unlock(&chunk.data_rw_mutex)
	if retiring {
		atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
		chunk.mesh_q_state[q.side] = .usable
		atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
		return
	}
	mesh_chunk_side(w_map=w_map, chunk_hd=q.data_hd, side=q.side)
}

// do_gen_mesh_data_task::proc(task: thread.Task){
// 	vox_data:=cast(^Chunk_Mesh_Data)task.data
// 	w_map:=w_map_thread_data
// 	mesh_chunk_side(w_map,vox_data)
// }

Directions::enum{
	pos_x,
	neg_x,
	pos_y,
	neg_y,
	pos_z,
	neg_z,
}
DIR_OFFSETS_r:=DIR_OFFSETS
DIR_OFFSETS:[Directions][3]int:{
	.pos_x = {1,0,0},
	.neg_x = {-1,0,0},
	.pos_y = {0,1,0},
	.neg_y = {0,-1,0},
	.pos_z = {0,0,1},
	.neg_z = {0,0,-1},
}
OPPOITE_DIR_OFFSETS_r:=OPPOITE_DIR_OFFSETS
OPPOITE_DIR_OFFSETS:[Directions]Directions:{
	.pos_x = .neg_x,
	.neg_x = .pos_x,
	.pos_y = .neg_y,
	.neg_y = .pos_y,
	.pos_z = .pos_z,
	.neg_z = .neg_z,
}

Full_Directions::enum{
	pos_x,
	neg_x,
	pos_y,
	neg_y,
	pos_z,
	neg_z,

	pos_x_pos_z,
	pos_x_neg_z,
	neg_x_pos_z,
	neg_x_neg_z,

	pos_y_pos_z,
	pos_y_neg_z,
	neg_y_pos_z,
	neg_y_neg_z,

	pos_x_pos_y,
	pos_x_neg_y,
	neg_x_pos_y,
	neg_x_neg_y,

	pos_x_pos_y_pos_z,
	pos_x_neg_y_pos_z,
	neg_x_pos_y_pos_z,
	neg_x_neg_y_pos_z,
	pos_x_pos_y_neg_z,
	pos_x_neg_y_neg_z,
	neg_x_pos_y_neg_z,
	neg_x_neg_y_neg_z,
}
FULL_DIR_OFFSETS_r:=FULL_DIR_OFFSETS
FULL_DIR_OFFSETS:[Full_Directions][3]int:{
	.pos_x = { 1, 0, 0},
	.neg_x = {-1, 0, 0},
	.pos_y = { 0, 1, 0},
	.neg_y = { 0,-1, 0},
	.pos_z = { 0, 0, 1},
	.neg_z = { 0, 0,-1},

	.pos_x_pos_z = { 1, 0, 1},
	.pos_x_neg_z = { 1, 0,-1},
	.neg_x_pos_z = {-1, 0, 1},
	.neg_x_neg_z = {-1, 0,-1},

	.pos_y_pos_z = { 0, 1, 1},
	.pos_y_neg_z = { 0, 1,-1},
	.neg_y_pos_z = { 0,-1, 1},
	.neg_y_neg_z = { 0,-1,-1},

	.pos_x_pos_y = { 1, 1, 0},
	.pos_x_neg_y = { 1,-1, 0},
	.neg_x_pos_y = {-1, 1, 0},
	.neg_x_neg_y = {-1,-1, 0},

	.pos_x_pos_y_pos_z = { 1, 1, 1},
	.pos_x_neg_y_pos_z = { 1,-1, 1},
	.neg_x_pos_y_pos_z = {-1, 1, 1},
	.neg_x_neg_y_pos_z = {-1,-1, 1},
	.pos_x_pos_y_neg_z = { 1, 1,-1},
	.pos_x_neg_y_neg_z = { 1,-1,-1},
	.neg_x_pos_y_neg_z = {-1, 1,-1},
	.neg_x_neg_y_neg_z = {-1,-1,-1},
}
OPPOITE_FULL_DIR_OFFSETS_r:=OPPOITE_FULL_DIR_OFFSETS
OPPOITE_FULL_DIR_OFFSETS:[Full_Directions]Full_Directions:{
	.pos_x = .neg_x,
	.neg_x = .pos_x,
	.pos_y = .neg_y,
	.neg_y = .pos_y,
	.pos_z = .neg_z,
	.neg_z = .pos_z,

	.pos_x_pos_z = .neg_x_neg_z,
	.pos_x_neg_z = .neg_x_pos_z,
	.neg_x_pos_z = .pos_x_neg_z,
	.neg_x_neg_z = .pos_x_pos_z,

	.pos_y_pos_z = .neg_y_neg_z,
	.pos_y_neg_z = .neg_y_pos_z,
	.neg_y_pos_z = .pos_y_neg_z,
	.neg_y_neg_z = .pos_y_pos_z,

	.pos_x_pos_y = .neg_x_neg_y,
	.pos_x_neg_y = .neg_x_pos_y,
	.neg_x_pos_y = .pos_x_neg_y,
	.neg_x_neg_y = .pos_x_pos_y,

	.pos_x_pos_y_pos_z = .neg_x_neg_y_neg_z,
	.pos_x_neg_y_pos_z = .neg_x_pos_y_neg_z,
	.neg_x_pos_y_pos_z = .pos_x_neg_y_neg_z,
	.neg_x_neg_y_pos_z = .pos_x_pos_y_neg_z,
	.pos_x_pos_y_neg_z = .neg_x_neg_y_pos_z,
	.pos_x_neg_y_neg_z = .neg_x_pos_y_pos_z,
	.neg_x_pos_y_neg_z = .pos_x_neg_y_pos_z,
	.neg_x_neg_y_neg_z = .pos_x_pos_y_pos_z,
}

FULL_DIRECTION_LOOKUP_r:=FULL_DIRECTION_LOOKUP
FULL_DIRECTION_LOOKUP :: [3][3][3]Full_Directions{
	{
		{.neg_x_neg_y_neg_z, .neg_x_neg_y, .neg_x_neg_y_pos_z},
		{.neg_x_neg_z,       .neg_x,       .neg_x_pos_z},
		{.neg_x_pos_y_neg_z, .neg_x_pos_y, .neg_x_pos_y_pos_z},
	},
	{
		{.neg_y_neg_z, .neg_y, .neg_y_pos_z},
		{.neg_z,       .pos_x, .pos_z}, // Center is unused.
		{.pos_y_neg_z, .pos_y, .pos_y_pos_z},
	},
	{
		{.pos_x_neg_y_neg_z, .pos_x_neg_y, .pos_x_neg_y_pos_z},
		{.pos_x_neg_z,       .pos_x,       .pos_x_pos_z},
		{.pos_x_pos_y_neg_z, .pos_x_pos_y, .pos_x_pos_y_pos_z},
	},
}

Light_Q_HM::hm.Dynamic_Handle_Map(Light_Q,Light_Q_HD)
Light_Q_HD::distinct hm.Handle64
Light_Q_Data::[dynamic; CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8]Light_Q_CMD
Light_Seed_Q_Data::[dynamic; CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8]Light_Seed_Q_CMD
Light_Remove_Q_Data::[dynamic; CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8]Light_Remove_CMD
Light_Q::struct{
	handle:Light_Q_HD,
	add_q:Light_Q_Data,
	seed_q:Light_Seed_Q_Data,
	remove_q:Light_Remove_Q_Data,
	owner_count:int,
}
Light_Q_CMD::struct{
	light:[3]u8,
	pos:[3]u8,
	type:Light_Q_T,
}
Light_Seed_Q_CMD::struct{
	pos:[3]u8,
	type:Light_Q_T,
}
Light_Remove_CMD :: struct {
	pos:  [3]u8,
	type: Light_Q_T,
	channels: [3]bool,
}
Light_Q_T::enum u8{
	block,
	sun,
}
Light_Q_Op::enum u8{
	add,
	remove,
}
Lighting_Chunk_Info::struct{ // this is just the info needed to do lighting calculations on a chunk 

	vox_data:^Vox_Chunk_Data,
	light_chunk:^Light_Chunk_Data,
	light_q:^Light_Q,

	nabors_light_q:[Directions]^Light_Q,
	nabors_light_chunk:[Directions]^Light_Chunk_Data,
	nabors_vox_data:[Directions]^Vox_Chunk_Data,
}
fill_out_light_chunk_info::proc(t:Light_Chunk_Task)->(info:Lighting_Chunk_Info){
	chunk, chunk_ok := hm.get(&t.w_map.chunks, t.chunk_hd)
	assert(chunk_ok)

	q, q_ok := hm.get(&t.w_map.light_qs_hm, t.light_q_hd)
	assert( q_ok)

	vox_data, vox_data_ok := get_vox_chunk_data(t.w_map, t.vox_data_hd)
	assert(vox_data_ok)

	light_data, light_data_ok := get_light_chunk_data(t.w_map, chunk.light_data_hd)
	assert(light_data_ok)

	// vox_mask, mask_ok := hm.get(&vox_data.backing_mask_data.hm, vox_data.vox_mask_hd,)
	// assert(mask_ok)

	info.light_chunk = light_data
	info.light_q = q
	info.vox_data = vox_data

	for nab_chunk_hd, index in t.nabors_chunk_hd{
		nab_chunk, nab_chunk_ok := hm.get(&t.w_map.chunks, nab_chunk_hd)
		if !nab_chunk_ok {continue}
		nab_light_data, nab_light_data_ok := get_light_chunk_data(t.w_map, nab_chunk.light_data_hd)
		if !nab_light_data_ok {continue}

		info.nabors_light_chunk[index] = nab_light_data
	}

	for nab_light_q_hd, index in t.nabors_light_q_hd{
		nab_light_q, nab_light_q_ok := hm.get(&t.w_map.light_qs_hm, nab_light_q_hd)
		assert(nab_light_q_ok) 

		info.nabors_light_q[index] = nab_light_q
	}

	for nab_vox_data_hd, index in t.nabors_vox_data_hd{
		nab_vox_data, nab_vox_data_ok := hm.get(&t.w_map.vox_chunk_hm, nab_vox_data_hd)
		if !nab_vox_data_ok {continue}

		info.nabors_vox_data[index] = nab_vox_data
	}

	return
}
update_chunk_lighting_with_lock :: proc(t: Light_Chunk_Task) {
	chunk, chunk_ok := hm.get(&t.w_map.chunks, t.chunk_hd)
	if !chunk_ok { return }
	atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
	defer atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
	update_chunk_lighting(t)
}

update_chunk_lighting::proc(t:Light_Chunk_Task) {
	info:=fill_out_light_chunk_info(t)
	if len(info.light_q.remove_q) > 0 {
		update_chunk_lighting_remove(t)
	}else if len(info.light_q.add_q) > 0 ||len(info.light_q.seed_q) > 0 {
		update_chunk_lighting_add(t)
	}
}
update_chunk_lighting_remove::proc(t:Light_Chunk_Task) {
	info:=fill_out_light_chunk_info(t)

	#reverse for cmd,i in info.light_q.remove_q{
		do_remove_chunk_lighting_cmd(&info,cmd)
		unordered_remove(&info.light_q.remove_q,i)
	} 
	if  len(info.light_q.remove_q) > 0 {
		update_chunk_lighting_remove(t)
	}
}
update_chunk_lighting_add::proc(t:Light_Chunk_Task) {
	info:=fill_out_light_chunk_info(t)

	if len(info.light_q.remove_q) <= 0 {
		#reverse for cmd,i in info.light_q.add_q{
			do_add_chunk_lighting_cmd(&info,cmd)
			unordered_remove(&info.light_q.add_q,i)
		} 
		#reverse for cmd,i in info.light_q.seed_q {
			do_seed_chunk_lighting_cmd(&info,cmd)
			unordered_remove(&info.light_q.seed_q,i)
		}
	}
	if  len(info.light_q.add_q) > 0 ||len(info.light_q.seed_q) > 0 {
		update_chunk_lighting_add(t)
	}
}

do_add_chunk_lighting_cmd :: proc(
	info:^Lighting_Chunk_Info,
	cmd: Light_Q_CMD,
) {
	old_lev,ok := get_light_chan_at(info.light_chunk,cmd.pos,cmd.type)
	if !ok {return}

	new_light,changed:=create_new_light_val(old_lev,cmd.light)
	if !changed{return}

	set_light:=set_light(info.light_chunk,cmd.pos,new_light,cmd.type)
	if !set_light{return}
	
	queue_neighbor_light_cmds(info,new_light,cmd.pos,cmd.type)
}

queue_neighbor_light_cmds :: proc(
	info:^Lighting_Chunk_Info,
	new_light:[3]u8,
	og_pos:[3]u8,
	type:Light_Q_T,
	// cmd: Light_Q_CMD,
) {

	dec_light,did_dec:=dec_light_val(new_light)
	dir_loop:for offset, dir in  DIR_OFFSETS{
		neighbor_light := dec_light
		if type == .sun && dir == .neg_y {
			if new_light.r == 31 { neighbor_light.r = 31 }
			if new_light.g == 31 { neighbor_light.g = 31 }
			if new_light.b == 31 { neighbor_light.b = 31 }
		}
		if !did_dec{continue}
		pos:=cast([3]int)og_pos+offset
		vox_data,light_chunk_data,light_q,loc_pos,ok:=get_lighting_data_at_pos(info,pos,)
		if !ok {continue}

		neighbor_vox_item_hd := get_vox_in_chunk(vox_data,loc_pos).item
		neighbor_item:Item_Info
		neighbor_item_ptr,neighbor_item_ok := reg.get(&g.item_reg,neighbor_vox_item_hd)
		if neighbor_item_ok {neighbor_item = neighbor_item_ptr^}
		if neighbor_item.is_opaque{continue}

		old_nab_lev,old_nab_lev_ok := get_light_chan_at(light_chunk_data,loc_pos,type)
		if !old_nab_lev_ok {continue}

		new_nab_light,changed:=create_new_light_val(old_nab_lev,neighbor_light)
		if !changed{continue}

		append(&light_q.add_q,Light_Q_CMD{light=new_nab_light, pos = loc_pos, type = type})
	}
}

do_seed_chunk_lighting_cmd :: proc(
	info:^Lighting_Chunk_Info,
	cmd: Light_Seed_Q_CMD,
) {
	target_vox := get_vox_in_chunk(info.vox_data,cmd.pos)
	target_item: Item_Info
	target_item_ptr,target_item_ok := reg.get(&g.item_reg,target_vox.item)
	if target_item_ok { target_item = target_item_ptr^ }
	if target_item.is_opaque { return }

	dir_loop: for offset,dir in DIR_OFFSETS {
		pos := cast([3]int)cmd.pos+offset
		vox_data,light_chunk_data,light_q,loc_pos,ok:=get_lighting_data_at_pos(info,pos,)
		if !ok {continue}

		neighbor_vox := get_vox_in_chunk(vox_data,loc_pos)
		neighbor_item: Item_Info
		neighbor_item_ptr,neighbor_item_ok := reg.get(&g.item_reg,neighbor_vox.item)
		if neighbor_item_ok { neighbor_item = neighbor_item_ptr^ }

		if neighbor_item.is_opaque && (cmd.type == .sun || neighbor_item.light_emission == {}) {
			continue dir_loop
		}

		neighbor_light,neighbor_light_ok := get_light_chan_at(light_chunk_data,loc_pos,cmd.type)
		if !neighbor_light_ok || neighbor_light == {} { continue }

		seed_light,_ := dec_light_val(neighbor_light)

		if cmd.type == .sun && dir == .pos_y {
			if neighbor_light.r == 31 { seed_light.r = 31 }
			if neighbor_light.g == 31 { seed_light.g = 31 }
			if neighbor_light.b == 31 { seed_light.b = 31 }
		}

		if seed_light == {} { continue }

		append(&info.light_q.add_q,Light_Q_CMD{light=seed_light,pos=cmd.pos,type=cmd.type})
	}
}

do_remove_chunk_lighting_cmd :: proc(
	info:^Lighting_Chunk_Info,
	cmd: Light_Remove_CMD,
) {
	old_light, ok := get_light_chan_at(info.light_chunk, cmd.pos, cmd.type)
	if !ok { return }

	remove_value := old_light
	if cmd.channels[0] { remove_value.r = 0 }
	if cmd.channels[1] { remove_value.g = 0 }
	if cmd.channels[2] { remove_value.b = 0 }
	if remove_value == old_light { return }

	current_vox := get_vox_in_chunk(info.vox_data, cmd.pos).item
	current_item: Item_Info
	current_item_ptr, current_item_ok := reg.get(&g.item_reg, current_vox)
	if current_item_ok { current_item = current_item_ptr^ }

	if !set_light(info.light_chunk, cmd.pos, remove_value, cmd.type) { return }

	dir_loop: for offset, dir in DIR_OFFSETS {
		pos := cast([3]int)cmd.pos + offset
		vox_data,light_chunk_data,light_q,loc_pos,ok:=get_lighting_data_at_pos(info,pos,)
		if !ok {continue}

		neighbor_vox := get_vox_in_chunk(vox_data, loc_pos).item
		neighbor_item: Item_Info
		neighbor_item_ptr, neighbor_item_ok := reg.get(&g.item_reg, neighbor_vox)
		if neighbor_item_ok { neighbor_item = neighbor_item_ptr^ }

		if neighbor_item.is_opaque && neighbor_item.light_emission == {} {continue dir_loop}

		neighbor_light, neighbor_ok := get_light_chan_at(light_chunk_data, loc_pos, cmd.type)
		if !neighbor_ok || neighbor_light == {} { continue }

		remove_channels, relight := get_light_remove_neighbor_state(old_light,neighbor_light,cmd.type,dir,cmd.channels,)

		if remove_channels[0] || remove_channels[1] || remove_channels[2] {
			append(&light_q.remove_q, Light_Remove_CMD{pos=loc_pos,type=cmd.type,channels=remove_channels,})

			if cmd.type == .block && neighbor_item.light_emission != {} {
				emission := neighbor_item.light_emission
				append(&light_q.add_q, Light_Q_CMD{light={emission.r,emission.g,emission.b},pos=loc_pos,type=.block,})
			}
		}

		if relight != {} && !current_item.is_opaque {
			append(&info.light_q.seed_q,Light_Seed_Q_CMD{pos=cmd.pos,type=cmd.type})
		}
	}
}

get_light_remove_neighbor_state :: proc(
	old_light: [3]u8,
	neighbor_light: [3]u8,
	light_type: Light_Q_T,
	dir: Directions,
	channels: [3]bool,
) -> (remove_channels: [3]bool, relight: [3]u8) {
	if channels[0] && neighbor_light.r > 0 {
		if neighbor_light.r < old_light.r ||
			(light_type == .sun && dir == .neg_y && old_light.r == 31 && neighbor_light.r == 31) {
			remove_channels[0] = true
		} else {
			relight.r = neighbor_light.r
		}
	}

	if channels[1] && neighbor_light.g > 0 {
		if neighbor_light.g < old_light.g ||
			(light_type == .sun && dir == .neg_y && old_light.g == 31 && neighbor_light.g == 31) {
			remove_channels[1] = true
		} else {
			relight.g = neighbor_light.g
		}
	}

	if channels[2] && neighbor_light.b > 0 {
		if neighbor_light.b < old_light.b ||
			(light_type == .sun && dir == .neg_y && old_light.b == 31 && neighbor_light.b == 31) {
			remove_channels[2] = true
		} else {
			relight.b = neighbor_light.b
		}
	}

	return
}


dec_light_val::proc(val:[3]u8)->(new_val:[3]u8,did_dec:bool){
	if val.r > 1{
		new_val.r = val.r -1 
		did_dec = true
	}
	if val.g > 1{
		new_val.g = val.g -1
		did_dec = true
	}
	if val.b > 1{
		new_val.b = val.b -1
		did_dec = true
	}
	return
}
val_grater_val::proc(val_a:[3]u8,val_b:[3]u8)->(is_grater:bool){
	if val_a.r > val_b.r {return true}
	if val_a.g > val_b.g {return true}
	if val_a.b > val_b.b {return true}
	return false
}
create_new_light_val::proc(old_val:[3]u8,new_val:[3]u8)->(changed_val:[3]u8,changed:bool){
	changed_val = old_val
	if new_val.r > old_val.r {
		changed_val.r = new_val.r
		changed = true
	}
	if new_val.g > old_val.g {
		changed_val.g = new_val.g
		changed = true
	}
	if new_val.b > old_val.b {
		changed_val.b = new_val.b
		changed = true
	}
	return
}

set_light::proc(data: ^Light_Chunk_Data, pos: [3]u8, value: [3]u8, type: Light_Q_T,)->(ok:bool){
	if pos[0] >= CHUNK_SIZE || pos[1] >= CHUNK_SIZE || pos[2] >= CHUNK_SIZE { return false }

	index := pos_to_vox_index(pos)
	old_pal := get_light_palette_index(data, index)
	start_value := data.backing_light_data_abstract.pal[old_pal].light_lev

	switch type {
	case .block:
		if start_value.block == value { return false }
		start_value.block = value
	case .sun:
		if start_value.sun == value { return false }
		start_value.sun = value
	}
	new_pal_index := get_or_add_light_palette_index(data, Light_Palette_Data{light_lev = start_value})
	// fmt.print(new_pal_index,value,"\n")
	set_light_palette_index(data, index, new_pal_index)
	return true
}


get_light_at :: proc(
	data: ^Light_Chunk_Data,
	pso: [3]u8,
) ->(value: Light_Lev,ok:bool){
	index:=pos_to_vox_index(pso)
	if pso[0] >= CHUNK_SIZE || pso[1] >= CHUNK_SIZE || pso[2] >= CHUNK_SIZE { return {}, false }
	// if index > CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE{return {} , false}

	// pal_index:= get_light_palette_index(data, index)
	// return data.backing_light_data_abstract.pal[pal_index].light_lev, true 
	value = get_light_in_chunk_index(data,index)
	ok = true	
	return

}

get_light_chan_at :: proc(
	light_chunk:^Light_Chunk_Data,
	pso: [3]u8,
	type: Light_Q_T,
) ->(value: [3]u8,ok:bool){
	index:=pos_to_vox_index(pso)
	if pso[0] >= CHUNK_SIZE || pso[1] >= CHUNK_SIZE || pso[2] >= CHUNK_SIZE { return {}, false }

	// pal_index:= get_light_palette_index(light_chunk, index)
	light_lev := get_light_in_chunk_index(light_chunk,index)
	if type == .block{
		return light_lev.block, true 
	}
	return light_lev.sun, true 

}

get_lighting_data_at_pos :: proc(
	info: ^Lighting_Chunk_Info,
	pso: [3]int,
) -> (vox_data: ^Vox_Chunk_Data, light_chunk: ^Light_Chunk_Data, light_q: ^Light_Q, local_pos: [3]u8, ok: bool) {
	assert(info != nil)
	assert(info.vox_data != nil)
	assert(info.light_chunk != nil)
	assert(info.light_q != nil)

	pos := pso
	neighbor_count := 0
	neighbor_dir: Directions

	if pos.x < 0 {
		if pos.x != -1 { return nil, nil, nil, {}, false }
		neighbor_count += 1
		neighbor_dir = .neg_x
		pos.x = CHUNK_SIZE-1
	} else if pos.x >= CHUNK_SIZE {
		if pos.x != CHUNK_SIZE { return nil, nil, nil, {}, false }
		neighbor_count += 1
		neighbor_dir = .pos_x
		pos.x = 0
	}

	if pos.y < 0 {
		if pos.y != -1 { return nil, nil, nil, {}, false }
		neighbor_count += 1
		neighbor_dir = .neg_y
		pos.y = CHUNK_SIZE-1
	} else if pos.y >= CHUNK_SIZE {
		if pos.y != CHUNK_SIZE { return nil, nil, nil, {}, false }
		neighbor_count += 1
		neighbor_dir = .pos_y
		pos.y = 0
	}

	if pos.z < 0 {
		if pos.z != -1 { return nil, nil, nil, {}, false }
		neighbor_count += 1
		neighbor_dir = .neg_z
		pos.z = CHUNK_SIZE-1
	} else if pos.z >= CHUNK_SIZE {
		if pos.z != CHUNK_SIZE { return nil, nil, nil, {}, false }
		neighbor_count += 1
		neighbor_dir = .pos_z
		pos.z = 0
	}

	if neighbor_count > 1 {
		return nil, nil, nil, {}, false
	}

	if neighbor_count == 0 {
		return info.vox_data, info.light_chunk, info.light_q, cast([3]u8)pos, true
	}

	vox_data = info.nabors_vox_data[neighbor_dir]
	light_chunk = info.nabors_light_chunk[neighbor_dir]
	light_q = info.nabors_light_q[neighbor_dir]

	if vox_data == nil || light_chunk == nil || light_q == nil {
		return nil, nil, nil, {}, false
	}

	return vox_data, light_chunk, light_q, cast([3]u8)pos, true
}

lighting_ready_mask_complete :: proc(ready_mask: bit_set[Full_Directions]) -> bool {
	return card(ready_mask) == len(FULL_DIR_OFFSETS_r)
}

notify_coarser_neighbors_for_meshing :: proc(w_map: ^Map, fine_chunk: ^Chunk) {
	// Copy the fine chunk's immutable position and readiness under its read lock.
	atom.atomic_rw_mutex_shared_lock(&fine_chunk.data_rw_mutex)
	fine_pos := fine_chunk.pos
	fine_ready := !fine_chunk.retiring && fine_chunk.light_data_q_state == .usable && lighting_ready_mask_complete(fine_chunk.lighting_redy_mask)
	atom.atomic_rw_mutex_shared_unlock(&fine_chunk.data_rw_mutex)
	if !fine_ready { return }

	fine_size := fine_pos.w
	max_lod_size := 1 << cast(u32)(w_map.chunk_stream_settings.lod_level_count-1)
	if fine_size <= 0 || fine_size >= max_lod_size { return }
	coarse_size := fine_size * 2
	seen_coarse_positions: [26][4]int
	seen_count := 0

	// A finer chunk can contribute light to a coarser chunk across a face,
	// edge, or corner. Find every adjacent coarse cell, not just six face
	// neighbors, so diagonal corner-light dependencies trigger a remesh too.
	for offset, _ in FULL_DIR_OFFSETS_r {
		coarse_pos: [4]int
		for axis in 0..<3 {
			target := fine_pos[axis]
			if offset[axis] > 0 { target -= 1 }
			else if offset[axis] < 0 { target += fine_size }
			coarse_pos[axis] = floor_div(target, coarse_size) * coarse_size
		}
		coarse_pos.w = coarse_size

		duplicate := false
		for i in 0..<seen_count {
			if seen_coarse_positions[i] == coarse_pos { duplicate = true; break }
		}
		if duplicate { continue }
		seen_coarse_positions[seen_count] = coarse_pos
		seen_count += 1

		coarse_hd, exists := get_chunk_by_pos_safe(w_map, coarse_pos)
		if !exists { continue }
		coarse_chunk, coarse_ok := hm.get(&w_map.chunks, coarse_hd)
		if !coarse_ok { continue }
		atom.atomic_rw_mutex_shared_lock(&coarse_chunk.data_rw_mutex)
		coarse_ready := !coarse_chunk.retiring && coarse_chunk.light_data_q_state == .usable && lighting_ready_mask_complete(coarse_chunk.lighting_redy_mask)
		coarse_pos_snapshot := coarse_chunk.pos
		atom.atomic_rw_mutex_shared_unlock(&coarse_chunk.data_rw_mutex)
		if coarse_ready { add_to_chunk_needs_meshing_q(w_map, coarse_pos_snapshot) }
	}
}

notify_chunk_lighting_ready :: proc(w_map:^Map, chunk_hd:Chunk_HD) {
	chunk, chunk_ok := hm.get(&w_map.chunks, chunk_hd)
	if !chunk_ok { return }
	atom.atomic_rw_mutex_shared_lock(&chunk.data_rw_mutex)
	lod_size := chunk.pos.w
	chunk_pos := chunk.pos
	is_usable := chunk.light_data_q_state == .usable
	atom.atomic_rw_mutex_shared_unlock(&chunk.data_rw_mutex)
	if !is_usable { return }

	for offset, direction in FULL_DIR_OFFSETS_r {
		neighbor_pos := chunk_pos
		neighbor_pos.xyz += offset*lod_size
		neighbor_hd, neighbor_exists := get_chunk_by_pos_safe(w_map, neighbor_pos)
		if !neighbor_exists {
			atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
			chunk.lighting_redy_mask += {direction}
			atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
			continue
		}

		neighbor_chunk, neighbor_ok := hm.get(&w_map.chunks, neighbor_hd)
		if !neighbor_ok { continue }
		opposite_direction := OPPOITE_FULL_DIR_OFFSETS_r[direction]
		atom.atomic_rw_mutex_shared_lock(&neighbor_chunk.data_rw_mutex)
		neighbor_usable := neighbor_chunk.light_data_q_state == .usable && !neighbor_chunk.retiring
		atom.atomic_rw_mutex_shared_unlock(&neighbor_chunk.data_rw_mutex)

		if neighbor_usable {
			atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
			chunk.lighting_redy_mask += {direction}
			atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
		}

		atom.atomic_rw_mutex_lock(&neighbor_chunk.data_rw_mutex)
		neighbor_was_ready := opposite_direction in neighbor_chunk.lighting_redy_mask
		neighbor_chunk.lighting_redy_mask += {opposite_direction}
		neighbor_ready := lighting_ready_mask_complete(neighbor_chunk.lighting_redy_mask)
		neighbor_retiring := neighbor_chunk.retiring
		neighbor_pos_snapshot := neighbor_chunk.pos
		atom.atomic_rw_mutex_unlock(&neighbor_chunk.data_rw_mutex)

		if !neighbor_was_ready && neighbor_ready {
			add_to_chunk_needs_meshing_q(w_map, neighbor_pos_snapshot)
			if !neighbor_retiring { notify_coarser_neighbors_for_meshing(w_map, neighbor_chunk) }
		}
	}

	atom.atomic_rw_mutex_shared_lock(&chunk.data_rw_mutex)
	chunk_ready := lighting_ready_mask_complete(chunk.lighting_redy_mask)
	chunk_retiring := chunk.retiring
	chunk_pos = chunk.pos
	atom.atomic_rw_mutex_shared_unlock(&chunk.data_rw_mutex)
	if !chunk_retiring {
		if chunk_ready { add_to_chunk_needs_meshing_q(w_map, chunk_pos) }
		notify_coarser_neighbors_for_meshing(w_map, chunk)
	}
}

init_chunk_lighting_ready_mask :: proc(w_map:^Map, chunk_hd:Chunk_HD) {
	chunk, chunk_ok := hm.get(&w_map.chunks, chunk_hd)
	if !chunk_ok { return }
	atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
	chunk.lighting_redy_mask = {}
	lod_size := chunk.pos.w
	chunk_pos := chunk.pos
	atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)

	for offset, direction in FULL_DIR_OFFSETS_r {
		neighbor_pos := chunk_pos
		neighbor_pos.xyz += offset*lod_size
		neighbor_hd, neighbor_exists := get_chunk_by_pos_safe(w_map, neighbor_pos)
		if !neighbor_exists {
			atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
			chunk.lighting_redy_mask += {direction}
			atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
			continue
		}
		neighbor_chunk, neighbor_ok := hm.get(&w_map.chunks, neighbor_hd)
		if !neighbor_ok { continue }
		opposite_direction := OPPOITE_FULL_DIR_OFFSETS_r[direction]
		atom.atomic_rw_mutex_lock(&neighbor_chunk.data_rw_mutex)
		neighbor_chunk.lighting_redy_mask -= {opposite_direction}
		neighbor_ready := neighbor_chunk.light_data_q_state == .usable && !neighbor_chunk.retiring
		atom.atomic_rw_mutex_unlock(&neighbor_chunk.data_rw_mutex)
		if neighbor_ready {
			atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
			chunk.lighting_redy_mask += {direction}
			atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
		}
	}
}

mesh_chunk_lighting_ready_locked :: proc(chunk: ^Chunk) -> bool {
	return !chunk.retiring && chunk.light_data_q_state == .usable && chunk.light_data_hd != {} && lighting_ready_mask_complete(chunk.lighting_redy_mask)
}

mesh_chunk_voxels_ready_locked :: proc(w_map: ^Map, chunk: ^Chunk) -> bool {
	if !mesh_chunk_lighting_ready_locked(chunk) || chunk.vox_data_hd == {} { return false }
	vox_data, vox_ok := get_vox_chunk_data(w_map, chunk.vox_data_hd)
	return vox_ok && atom.atomic_load(&vox_data.vox_gened)
}

mesh_add_chunk_read_lock :: proc(prepared: ^Mesh_Prepared_Chunk_Data, chunk_hd: Chunk_HD, chunk: ^Chunk) -> (locked: bool, newly_locked: bool) {
	for i in 0..<prepared.locked_chunk_count {
		if prepared.locked_chunk_hds[i] == chunk_hd { return true, false }
	}
	if prepared.locked_chunk_count >= len(prepared.locked_chunk_hds) { return false, false }
	atom.atomic_rw_mutex_shared_lock(&chunk.data_rw_mutex)
	if chunk.retiring {
		atom.atomic_rw_mutex_shared_unlock(&chunk.data_rw_mutex)
		return false, false
	}
	prepared.locked_chunk_hds[prepared.locked_chunk_count] = chunk_hd
	prepared.locked_chunk_count += 1
	return true, true
}

mesh_remove_chunk_read_lock :: proc(prepared: ^Mesh_Prepared_Chunk_Data, chunk_hd: Chunk_HD, chunk: ^Chunk) {
	for i in 0..<prepared.locked_chunk_count {
		if prepared.locked_chunk_hds[i] == chunk_hd {
			atom.atomic_rw_mutex_shared_unlock(&chunk.data_rw_mutex)
			for j in i..<prepared.locked_chunk_count-1 { prepared.locked_chunk_hds[j] = prepared.locked_chunk_hds[j+1] }
			prepared.locked_chunk_count -= 1
			prepared.locked_chunk_hds[prepared.locked_chunk_count] = {}
			return
		}
	}
}

release_mesh_chunk_data :: proc(w_map: ^Map, prepared: ^Mesh_Prepared_Chunk_Data) {
	for i := prepared.locked_chunk_count-1; i >= 0; i -= 1 {
		chunk_hd := prepared.locked_chunk_hds[i]
		chunk, chunk_ok := hm.get(&w_map.chunks, chunk_hd)
		assert(chunk_ok, "mesh read lock lost its owning chunk handle")
		atom.atomic_rw_mutex_shared_unlock(&chunk.data_rw_mutex)
	}
	prepared.locked_chunk_count = 0
}

get_chunk_by_pos_unlocked :: proc(w_map: ^Map, pos: [4]int) -> (chunk_hd: Chunk_HD, ok: bool) {
	chunk_hd, ok = w_map.chunks_map[pos]
	return
}

mesh_neighbor_is_ready :: proc(prepared: ^Mesh_Prepared_Chunk_Data, chunk_hd: Chunk_HD, chunk: ^Chunk) -> bool {
	locked, newly_locked := mesh_add_chunk_read_lock(prepared, chunk_hd, chunk)
	if !locked { return false }
	if !mesh_chunk_lighting_ready_locked(chunk) {
		if newly_locked { mesh_remove_chunk_read_lock(prepared, chunk_hd, chunk) }
		return false
	}
	return true
}

mesh_find_neighbor_chunk_locked :: proc(
	w_map: ^Map,
	prepared: ^Mesh_Prepared_Chunk_Data,
	pos: [4]int,
) -> (chunk: ^Chunk, exists: bool, ready: bool) {
	hd:Chunk_HD
	hd, exists = get_chunk_by_pos_unlocked(w_map, pos)
	if !exists { return }
	chunk_ok:bool
	chunk, chunk_ok = hm.get(&w_map.chunks, hd)
	if !chunk_ok { return nil, true, false }
	ready = mesh_neighbor_is_ready(prepared, hd, chunk)
	return
}

gather_mesh_light_neighbors_locked :: proc(
	w_map: ^Map,
	chunk: ^Chunk,
	side: Model_Sides,
	prepared: ^Mesh_Prepared_Chunk_Data,
) -> (neighbors: [Full_Directions]Mesh_Light_Neighbor, ok: bool) {
	size := chunk.pos.w
	face_axis := int(side)/2
	face_sign := 1
	if (int(side)&1) != 0 { face_sign = -1 }

	for offset, direction in FULL_DIR_OFFSETS_r {
		// A sample can cross the face-normal boundary, either tangent
		// boundary, or any combination of those. It can also cross only a
		// tangent boundary while remaining inside the face-normal axis.
		face_offset := offset[face_axis]
		if face_offset != 0 && face_offset != face_sign { continue }

		neighbor_pos := chunk.pos
		neighbor_pos.xyz += offset*size
		neighbor_chunk, same_exists, same_ready := mesh_find_neighbor_chunk_locked(w_map, prepared, neighbor_pos)
		if same_exists {
			if !same_ready { return neighbors, false }
			neighbors[direction].same_lod = neighbor_chunk.light_data_hd
			continue
		}

		zero_axis_count := 0
		for axis in 0..<3 { if offset[axis] == 0 { zero_axis_count += 1 } }
		combination_count := 1 << cast(u32)zero_axis_count
		if size > 1 {
			half_size := size/2
			for combination in 0..<combination_count {
				fine_pos := chunk.pos
				zero_axis_index := 0
				for axis in 0..<3 {
					if offset[axis] > 0 { fine_pos[axis] += size }
					else if offset[axis] < 0 { fine_pos[axis] -= half_size }
					else {
						if (combination & (1 << cast(u32)zero_axis_index)) != 0 { fine_pos[axis] += half_size }
						zero_axis_index += 1
					}
				}
				fine_pos.w = half_size
				fine_chunk, fine_exists, fine_ready := mesh_find_neighbor_chunk_locked(w_map, prepared, fine_pos)
				if !fine_exists { continue }
				if !fine_ready { return neighbors, false }
				entry_index := neighbors[direction].fine_count
				if entry_index >= len(neighbors[direction].fine_lod) { return neighbors, false }
				neighbors[direction].fine_lod[entry_index] = Mesh_Light_Neighbor_Entry{
					light_hd=fine_chunk.light_data_hd,
					pos=fine_chunk.pos.xyz,
					size=fine_chunk.pos.w,
				}
				neighbors[direction].fine_count += 1
			}
		}

		// A partially present fine set is only safe when its missing coverage
		// can be sampled from the complete coarse parent as a fallback.
		need_coarse := neighbors[direction].fine_count < combination_count
		max_lod_size := 1 << cast(u32)(w_map.chunk_stream_settings.lod_level_count-1)

		if need_coarse && size < max_lod_size {
			coarse_size := size*2
			coarse_pos := chunk.pos
			for axis in 0..<3 {
				target := chunk.pos[axis]
				if offset[axis] > 0 { target += size }
				else if offset[axis] < 0 { target -= 1 }
				else { target += size/2 }
				coarse_pos[axis] = floor_div(target,coarse_size)*coarse_size
			}
			coarse_pos.w = coarse_size
			coarse_chunk, coarse_exists, coarse_ready := mesh_find_neighbor_chunk_locked(w_map, prepared, coarse_pos)
			if coarse_exists {
				if !coarse_ready { return neighbors, false }
				neighbors[direction].coarse_lod = Mesh_Light_Neighbor_Entry{
					light_hd=coarse_chunk.light_data_hd,
					pos=coarse_chunk.pos.xyz,
					size=coarse_chunk.pos.w,
				}
				neighbors[direction].has_coarse_lod = true
			}
		}
		if neighbors[direction].fine_count > 0 && neighbors[direction].fine_count < combination_count && !neighbors[direction].has_coarse_lod {
			return neighbors, false
		}
	}
	return neighbors, true
}

// Lock order is always chunks_map_rw_mutex (shared), then Chunk.data_rw_mutex
// (shared). The map lock is dropped after discovery; chunk locks remain until
// release_mesh_chunk_data so voxel/light payload handles cannot be invalidated.
prepare_mesh_chunk_data :: proc(t: Mesh_Chunk_Task) -> (prepared: Mesh_Prepared_Chunk_Data, ok: bool) {
	w_map := t.w_map
	atom.atomic_rw_mutex_shared_lock(&w_map.chunks_map_rw_mutex)
	map_locked := true
	keep_chunk_locks := false
	defer { if map_locked { atom.atomic_rw_mutex_shared_unlock(&w_map.chunks_map_rw_mutex) } }
	defer { if !keep_chunk_locks { release_mesh_chunk_data(w_map, &prepared) } }

	chunk, chunk_ok := hm.get(&w_map.chunks, t.chunk_hd)
	if !chunk_ok { return }
	locked, _ := mesh_add_chunk_read_lock(&prepared, t.chunk_hd, chunk)
	if !locked || !mesh_chunk_voxels_ready_locked(w_map, chunk) { return }

	prepared.chunk_pos = chunk.pos.xyz
	prepared.chunk_size = chunk.pos.w
	prepared.chunk_vox_hd = chunk.vox_data_hd
	prepared.chunk_light_hd = chunk.light_data_hd

	// Resolve the voxel neighbor used by the face mask. It is either one
	// same-LOD chunk or the four half-size chunks covering the face.
	lod_size := chunk.pos.w
	offset := model_side_to_offset(t.side)
	face_pos := chunk.pos
	face_pos.xyz += offset*lod_size
	face_hd, face_exists := get_chunk_by_pos_unlocked(w_map, face_pos)
	if face_exists {
		face_chunk, face_ok := hm.get(&w_map.chunks, face_hd)
		if !face_ok || !mesh_neighbor_is_ready(&prepared, face_hd, face_chunk) || !mesh_chunk_voxels_ready_locked(w_map, face_chunk) { return }
		for i in 0..<4 { prepared.neighbor_vox_hd[i] = face_chunk.vox_data_hd }
	}else{
		if lod_size <= 1 { return }
		half := lod_size/2
		u_offset, v_offset: [4]int
		switch t.side {
		case .pos_x, .neg_x:
			u_offset = {0,half,0,0}
			v_offset = {0,0,half,0}
		case .pos_y, .neg_y:
			u_offset = {half,0,0,0}
			v_offset = {0,0,half,0}
		case .pos_z, .neg_z:
			u_offset = {half,0,0,0}
			v_offset = {0,half,0,0}
		case .extra:
			return
		}
		fine_base := chunk.pos
		fine_base.w = half
		face_axis := int(t.side)/2
		if offset[face_axis] > 0 { fine_base[face_axis] += lod_size }
		else { fine_base[face_axis] -= half }
		fine_positions: [4][4]int
		fine_positions[0] = fine_base
		fine_positions[1] = fine_base + u_offset
		fine_positions[2] = fine_base + v_offset
		fine_positions[3] = fine_base + u_offset + v_offset
		for i in 0..<4 {
			fine_hd, fine_exists := get_chunk_by_pos_unlocked(w_map, fine_positions[i])
			if !fine_exists { return }
			fine_chunk, fine_ok := hm.get(&w_map.chunks, fine_hd)
			if !fine_ok || !mesh_neighbor_is_ready(&prepared, fine_hd, fine_chunk) || !mesh_chunk_voxels_ready_locked(w_map, fine_chunk) { return }
			prepared.neighbor_vox_hd[i] = fine_chunk.vox_data_hd
		}
		prepared.has_4_neighbors = true
	}

	prepared.neighbor_light_data, ok = gather_mesh_light_neighbors_locked(w_map, chunk, t.side, &prepared)
	if !ok { return }

	// Once all required chunks are read-locked, the global map lock is no
	// longer needed. The per-chunk locks keep their handles/data alive until
	// mesh_by_bit_mask finishes.
	atom.atomic_rw_mutex_shared_unlock(&w_map.chunks_map_rw_mutex)
	map_locked = false
	keep_chunk_locks = true
	ok = true
	return
}

mesh_chunk_side :: proc(w_map: ^Map, chunk_hd: Chunk_HD, side: Model_Sides) {
	chunk, chunk_ok := hm.get(&w_map.chunks, chunk_hd)
	if !chunk_ok { return }
	atom.atomic_rw_mutex_shared_lock(&chunk.data_rw_mutex)
	can_mesh := !chunk.retiring && chunk.mesh_q_state[side] == .in_q
	atom.atomic_rw_mutex_shared_unlock(&chunk.data_rw_mutex)
	if !can_mesh {
		atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
		if chunk.mesh_q_state[side] == .in_q { chunk.mesh_q_state[side] = .usable }
		atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
		return
	}

	mesh_data_hd, err := hm.add(&w_map.chunks_mesh_data, Chunk_Mesh_Data{})
	if err != .None {
		atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
		chunk.mesh_q_state[side] = .usable
		atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
		log.log(.Error, "failed to add mesh_hd to chunk.mesh_data[side] err = ", err, mesh_data_hd)
		return
	}
	_, mesh_data_ok := get_chunk_mesh_data(w_map, mesh_data_hd)
	if !mesh_data_ok {
		atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
		chunk.mesh_q_state[side] = .usable
		atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
		log.log(.Error, "failed, mesh_hd not valid", mesh_data_hd)
		return
	}
	start_mesh_chunk_task(w_map, Mesh_Chunk_Task{
		w_map=w_map,
		chunk_hd=chunk_hd,
		side=side,
	}, mesh_data_hd)
}

Mask_Lookup :: struct {
	edge_value: int,
	edge_divisor: int,
	edge_offset: int,
	inside_offset: int,
	y_shift: int,
}

MASK_LOOKUP :[Model_Sides]Mask_Lookup: {
	.pos_x=	{edge_value=CHUNK_SIZE-1,edge_divisor=1,edge_offset=-(CHUNK_SIZE-1),inside_offset=1},
	.neg_x=	{edge_value=0,edge_divisor=1,edge_offset=CHUNK_SIZE-1,inside_offset=-1},
	.pos_y=	{y_shift=1},
	.neg_y=	{y_shift=-1},
	.pos_z=	{edge_value=CHUNK_SIZE-1,edge_divisor=CHUNK_SIZE,edge_offset=-CHUNK_SIZE*(CHUNK_SIZE-1),inside_offset=CHUNK_SIZE},
	.neg_z=	{edge_value=0,edge_divisor=CHUNK_SIZE,edge_offset=CHUNK_SIZE*(CHUNK_SIZE-1),inside_offset=-CHUNK_SIZE},
	.extra=	{},
}


Meshing_Chunk_Info :: struct {
	vox_data: ^Vox_Chunk_Data,
	neighbor_vox_data: [4]^Vox_Chunk_Data,
	side: Model_Sides,
	has_4_neighbors: bool,
}
get_meshing_data_at_pos :: proc(
	info: ^Meshing_Chunk_Info,
	pso: [3]int,
) -> (vox_data: ^Vox_Chunk_Data, neighbor_vox_data: ^Vox_Chunk_Data, local_pos: [3]u8, neighbor_pos: [3]u8, ok: bool) {
	assert(info != nil)

	if info.vox_data == nil {return}
	if pso.x < 0 || pso.x >= CHUNK_SIZE || pso.y < 0 || pso.y >= CHUNK_SIZE || pso.z < 0 || pso.z >= CHUNK_SIZE {return}

	local_pos = cast([3]u8)pso
	vox_data = info.vox_data

	if info.side == .extra {
		neighbor_vox_data = info.vox_data
		neighbor_pos = local_pos
		return vox_data,neighbor_vox_data,local_pos,neighbor_pos,true
	}

	pos := pso
	switch info.side {
	case .pos_x: pos.x += 1
	case .neg_x: pos.x -= 1
	case .pos_y: pos.y += 1
	case .neg_y: pos.y -= 1
	case .pos_z: pos.z += 1
	case .neg_z: pos.z -= 1
	case .extra:
	}

	crossed_boundary := pos.x < 0 || pos.x >= CHUNK_SIZE || pos.y < 0 || pos.y >= CHUNK_SIZE || pos.z < 0 || pos.z >= CHUNK_SIZE

	if !crossed_boundary {
		neighbor_vox_data = info.vox_data
		neighbor_pos = cast([3]u8)pos
		return vox_data,neighbor_vox_data,local_pos,neighbor_pos,true
	}

	if info.has_4_neighbors {
		// The face mask already combines all four fine neighbors. Keep this
		// boundary voxel on the meshing path; its light is sampled separately.
		neighbor_vox_data = info.neighbor_vox_data[0]
		if neighbor_vox_data == nil {return}
		neighbor_pos = {}
		return vox_data,neighbor_vox_data,local_pos,neighbor_pos,true
	}

	neighbor_vox_data = info.neighbor_vox_data[0]
	if neighbor_vox_data == nil {return}

	if pos.x < 0 {pos.x = CHUNK_SIZE-1} else if pos.x >= CHUNK_SIZE {pos.x = 0}
	if pos.y < 0 {pos.y = CHUNK_SIZE-1} else if pos.y >= CHUNK_SIZE {pos.y = 0}
	if pos.z < 0 {pos.z = CHUNK_SIZE-1} else if pos.z >= CHUNK_SIZE {pos.z = 0}

	neighbor_pos = cast([3]u8)pos
	return vox_data,neighbor_vox_data,local_pos,neighbor_pos,true
}



mesh_by_bit_mask :: proc(
	t:Mesh_Chunk_Task,
	mesh_hd: Chunk_Mesh_Data_HD,
) -> (face_count: int) {

	mesh,mesh_ok := hm.get(&t.w_map.chunks_mesh_data,mesh_hd)
	assert(mesh_ok)
	mesh.face_count = -1

	if t.side == .extra {return}

	prepared,prepared_ok:=prepare_mesh_chunk_data(t)
	if !prepared_ok {return}
	defer release_mesh_chunk_data(t.w_map, &prepared)

	chunk_vox_data,chunk_vox_ok:=get_vox_chunk_data(t.w_map,prepared.chunk_vox_hd)
	if !chunk_vox_ok {return}
	neighbors_vox: [4]^Vox_Chunk_Data
	neighbor_count := 1
	if prepared.has_4_neighbors { neighbor_count = 4 }
	for i in 0..<neighbor_count {
		neighbors_vox[i], _ = get_vox_chunk_data(t.w_map,prepared.neighbor_vox_hd[i])
		if neighbors_vox[i] == nil {return}
	}
	neighbor_vox:=neighbors_vox[0]
	chunk_light_data,chunk_light_ok:=get_light_chunk_data(t.w_map,prepared.chunk_light_hd)
	if !chunk_light_ok {log.log(.Error,"mesh_by_bit_mask: invalid chunk light data",prepared.chunk_light_hd);return}

	assert(chunk_vox_data.backing_mask_data != nil)
	assert(chunk_vox_data.backing_world_data != nil)

	chunk_mask,chunk_mask_ok := hm.get(&chunk_vox_data.backing_mask_data.hm,chunk_vox_data.vox_mask_hd)
	if !chunk_mask_ok {log.log(.Error,"failed, chunk mask not valid",chunk_vox_data.vox_mask_hd);return}

	neighbor_mask,neighbor_mask_ok := hm.get(&neighbor_vox.backing_mask_data.hm,neighbor_vox.vox_mask_hd)

	sampled_neighbor_mask:[CHUNK_SIZE * CHUNK_SIZE]u32
	cur_neighbor_mask:^[CHUNK_SIZE * CHUNK_SIZE]u32

	if prepared.has_4_neighbors {
		masks:[4][CHUNK_SIZE * CHUNK_SIZE]u32

		for i in 0..<4 {
			n_mask,n_mask_ok := hm.get(&neighbors_vox[i].backing_mask_data.hm,neighbors_vox[i].vox_mask_hd)
			if !n_mask_ok {log.log(.Error,"failed, neighbor mask not valid",prepared.neighbor_vox_hd[i]);return}
			masks[i] = n_mask.is_opaque_mask
		}

		switch t.side {
		case .pos_x,.neg_x:
			sampled_neighbor_mask = sample_4_neighbor_masks_x(masks,t.side)
		case .pos_y,.neg_y:
			sampled_neighbor_mask = sample_4_neighbor_masks_y(masks,t.side)
		case .pos_z,.neg_z:
			sampled_neighbor_mask = sample_4_neighbor_masks_z(masks,t.side)
		case .extra:
		}

		cur_neighbor_mask = &sampled_neighbor_mask
	}else if neighbor_mask_ok {
		cur_neighbor_mask = &neighbor_mask.is_opaque_mask
	}

	meshing_chunk_info:Meshing_Chunk_Info={
		vox_data = chunk_vox_data,
		neighbor_vox_data = neighbors_vox,
		side = t.side,
		has_4_neighbors = prepared.has_4_neighbors,
	}
	MASK_LOOKUP_r:=MASK_LOOKUP
	lookup := MASK_LOOKUP_r[t.side]

	boundary_axis := int(t.side)/2
	boundary_positive := (int(t.side)&1) == 0

	neighbor_offset:[3]f32
	neighbor_offset[boundary_axis]=1
	if !boundary_positive {
		neighbor_offset[boundary_axis]=-1
	}

	for index in 0..<CHUNK_SIZE * CHUNK_SIZE {

		current_mask := chunk_mask.is_occupied_mask[index]
		opaque_mask := chunk_mask.is_opaque_mask[index]

		neighbor_mask_value:u32

		if lookup.y_shift == 1 {
			neighbor_mask_value = opaque_mask >> 1
			if neighbor_mask_ok {
				neighbor_mask_value |= (cur_neighbor_mask[index] & 1) << 31
			}else{
				neighbor_mask_value |= u32(1) << 31
			}
		}else if lookup.y_shift == -1 {
			neighbor_mask_value = opaque_mask << 1
			if neighbor_mask_ok {
				neighbor_mask_value |= cur_neighbor_mask[index] >> 31
			}else{
				neighbor_mask_value |= 1
			}
		}else{
			edge_index := (index / lookup.edge_divisor) % CHUNK_SIZE
			if edge_index == lookup.edge_value {
				if cur_neighbor_mask != nil {
					neighbor_mask_value = cur_neighbor_mask[index+lookup.edge_offset]
				}
			}else{
				neighbor_mask_value = chunk_mask.is_opaque_mask[index+lookup.inside_offset]
			}
		}

		visible_mask := current_mask & ~(neighbor_mask_value & opaque_mask)

		x := index & (CHUNK_SIZE-1)
		z := index / CHUNK_SIZE

		for visible_mask != 0 {

			y := bits.count_trailing_zeros(visible_mask)
			visible_mask &= visible_mask-1

			vox_data,neighbor_vox_data,local_pos,neighbor_pos,ok := get_meshing_data_at_pos(&meshing_chunk_info,{x,cast(int)y,z})
			if !ok {continue}

			pal_index:=get_palette_index_by_pos(vox_data,local_pos)
			if pal_index == 0 {continue}

			nab_pal_index:=get_palette_index_by_pos(neighbor_vox_data,neighbor_pos)

			current_pal_index:=pal_index
			chain_finished:=false

			face:tg.Vert_Face
			face.block_pos=pack_block_pos({cast(u16)x,cast(u16)y,cast(u16)z})

			voxel_light:=face.light
			voxel_light_sampled:=false

			vox_ab:=&vox_data.backing_chunk_data_abstract
			for _ in 0..<vox_ab.pal_count^ {

				assert(current_pal_index < vox_ab.pal_count^,"invalid current multiblock chain")

				block_p_d:=vox_ab.pal[current_pal_index]
				block_offset:=block_offset_from_u16(block_p_d.state.offset)

				face.block_offset=block_p_d.state.offset

				item,item_ok:=reg.get(&g.item_reg,block_p_d.item)
				if item_ok {
					model,model_ok:=reg.get(&g.block_model_reg,item.model)
					if model_ok {
						// model_data:=&g.all_block_models[model.start+cast(int)block_p_d.state.state]
						// model_data:=model_data_cache[current_pal_index]
						model_data,model_data_ok:=get_block_model_data_from_model(model,block_p_d.state)
						if !model_data_ok {continue}
						
						geometry_index:=model_data.cube_indices[t.side]

						// Primary cube face. Index 0 means no face.
						if geometry_index >= 0 {

							geometry:=&g.all_face_data[geometry_index]
							face.texture_face_index=cast(u16)item.texture_data.sides[geometry.texture_slot]
						

							occluded:=face_is_fully_occluded_by_chain(
								vox_data,
								pal_index,
								current_pal_index,
								g.all_face_data[geometry_index].pos,
								.extra,
								t.side,
								{},
								block_offset,
							)

							// For a four-chunk LOD transition, the reduced neighbor
							// mask already tests all four fine voxels. Do not let one
							// selected child voxel hide the entire coarse face.
							if !occluded && nab_pal_index != 0 && !prepared.has_4_neighbors {
								occluded=face_is_fully_occluded_by_chain(
									neighbor_vox_data,
									nab_pal_index,
									0,
									g.all_face_data[geometry_index].pos,
									t.side,
									t.side,
									neighbor_offset,
									block_offset,
								)
							}

							if !occluded {
								if !voxel_light_sampled {
									for corner_id in 0..<4 {
										voxel_light[corner_id]=sample_corner_light(
											t.w_map,
											chunk_light_data,
											&prepared,
											t.side,
											x,cast(int)y,z,
											corner_id,
										)
									}
									voxel_light_sampled=true
								}

								face.light=voxel_light
								face.geometry_face_index=cast(u16)geometry_index
								assert(face_count < len(mesh.data),"mesh face buffer full")
								mesh.data[face_count]=face
								face_count+=1
							}
						}

						// Imported and other additional geometry.
						if model_data.extra_count > 0 {
							extra_start:=model_data.cube_indices[.extra]
							assert(extra_start > 0,"model has extra faces but invalid extra start")

							for extra_i in 0..<model_data.extra_count {
								extra_geometry_index:=extra_start+extra_i
								extra_geometry:=&g.all_face_data[extra_geometry_index]
								if extra_geometry.side != t.side {continue}

								face.texture_face_index=cast(u16)item.texture_data.sides[extra_geometry.texture_slot]

								on_block_boundary:=false
								if boundary_positive {
									on_block_boundary=extra_geometry.pos[0][boundary_axis] >= 1
								}else{
									on_block_boundary=extra_geometry.pos[0][boundary_axis] <= 0
								}

								extra_occluded:=face_is_fully_occluded_by_chain(
									vox_data,
									pal_index,
									current_pal_index,
									extra_geometry.pos,
									.extra,
									extra_geometry.side,
									{},
									block_offset,
								)

								if !extra_occluded && on_block_boundary && nab_pal_index != 0 && !prepared.has_4_neighbors {
									extra_occluded=face_is_fully_occluded_by_chain(
										neighbor_vox_data,
										nab_pal_index,
										0,
										extra_geometry.pos,
										.extra,
										extra_geometry.side,
										neighbor_offset,
										block_offset,
									)
								}

								if extra_occluded {continue}

								if !voxel_light_sampled {
									for corner_id in 0..<4 {
										voxel_light[corner_id]=sample_corner_light(
											t.w_map,
											chunk_light_data,
											&prepared,
											t.side,
											x,cast(int)y,z,
											corner_id,
										)
									}
									voxel_light_sampled=true
								}

								face.light=voxel_light
								face.geometry_face_index=cast(u16)extra_geometry_index
								assert(face_count < len(mesh.data),"mesh face buffer full")
								mesh.data[face_count]=face
								face_count+=1
							}
						}
					}
				}

				next:=block_p_d.multy_block_index
				if next == 0 {
					chain_finished=true
					break
				}

				current_pal_index=next
			}

			assert(chain_finished,"cycle detected in current multiblock chain")
		}
	}

	mesh.face_count = face_count
	return face_count
}


occlusion_box_reaches_face::proc(
	min_axis,max_axis,boundary:f32,
	side:Model_Sides,
	allow_coplanar:bool,
)->bool {
	switch side {
	case .pos_x,.pos_y,.pos_z:
		return (min_axis <= boundary && max_axis > boundary) ||
			(allow_coplanar && min_axis < boundary && max_axis == boundary)

	case .neg_x,.neg_y,.neg_z:
		return (min_axis < boundary && max_axis >= boundary) ||
			(allow_coplanar && min_axis == boundary && max_axis > boundary)

	case .extra:
		return false
	}
	return false
}

sample_4_neighbor_masks_y :: proc(
	m: [4][CHUNK_SIZE * CHUNK_SIZE]u32,
	side: Model_Sides,
) -> [CHUNK_SIZE * CHUNK_SIZE]u32 {
	out: [CHUNK_SIZE * CHUNK_SIZE]u32

	src_bit: u32 = 0
	if side == .neg_y {
		src_bit = 31
	}

	for z := 0; z < CHUNK_SIZE; z += 1 {
		fz := (z & 15) << 1
		qz := (z >> 4) << 1

		for x := 0; x < CHUNK_SIZE; x += 1 {
			fx := (x & 15) << 1
			q := (x >> 4) | qz

			a := (m[q][fx + fz*CHUNK_SIZE] >> src_bit) & 1
			b := (m[q][fx + 1 + fz*CHUNK_SIZE] >> src_bit) & 1
			c := (m[q][fx + (fz+1)*CHUNK_SIZE] >> src_bit) & 1
			d := (m[q][fx + 1 + (fz+1)*CHUNK_SIZE] >> src_bit) & 1

			out[x + z*CHUNK_SIZE] = (a & b & c & d) << src_bit
		}
	}

	return out
}
sample_4_neighbor_masks_x :: proc(
	m: [4][CHUNK_SIZE * CHUNK_SIZE]u32,
	side: Model_Sides,
) -> [CHUNK_SIZE * CHUNK_SIZE]u32 {
	out: [CHUNK_SIZE * CHUNK_SIZE]u32

	src_x := 0
	out_x := 0

	if side == .neg_x {
		src_x = CHUNK_SIZE - 1
		out_x = CHUNK_SIZE - 1
	}

	for z := 0; z < CHUNK_SIZE; z += 1 {
		fz := (z & 15) << 1
		qz := (z >> 4) << 1

		for y := 0; y < CHUNK_SIZE; y += 1 {
			fy := (y & 15) << 1
			q := (y >> 4) | qz

			i0 := src_x + fz*CHUNK_SIZE
			i1 := src_x + (fz+1)*CHUNK_SIZE

			a := (m[q][i0] >> u32(fy)) & 1
			b := (m[q][i0] >> u32(fy+1)) & 1
			c := (m[q][i1] >> u32(fy)) & 1
			d := (m[q][i1] >> u32(fy+1)) & 1

			out[out_x + z*CHUNK_SIZE] |=
				(a & b & c & d) << u32(y)
		}
	}

	return out
}
sample_4_neighbor_masks_z :: proc(
	m: [4][CHUNK_SIZE * CHUNK_SIZE]u32,
	side: Model_Sides,
) -> [CHUNK_SIZE * CHUNK_SIZE]u32 {
	out: [CHUNK_SIZE * CHUNK_SIZE]u32

	src_z := 0
	out_z := 0

	if side == .neg_z {
		src_z = CHUNK_SIZE - 1
		out_z = CHUNK_SIZE - 1
	}

	for x := 0; x < CHUNK_SIZE; x += 1 {
		fx := (x & 15) << 1
		qx := x >> 4

		for y := 0; y < CHUNK_SIZE; y += 1 {
			fy := (y & 15) << 1
			q := qx | ((y >> 4) << 1)

			i0 := fx + src_z*CHUNK_SIZE
			i1 := fx + 1 + src_z*CHUNK_SIZE

			a := (m[q][i0] >> u32(fy)) & 1
			b := (m[q][i1] >> u32(fy)) & 1
			c := (m[q][i0] >> u32(fy+1)) & 1
			d := (m[q][i1] >> u32(fy+1)) & 1

			out[x + out_z*CHUNK_SIZE] |=
				(a & b & c & d) << u32(y)
		}
	}

	return out
}


LIGHT_CORNER_POSITIONS_r:=LIGHT_CORNER_POSITIONS
LIGHT_CORNER_POSITIONS :: [Directions][4][3]int{
	// .pos_x — matches pos0, pos1, pos2, pos3
	.pos_x = {{1, 1, 1},{1, 0, 1},{1, 0, 0},{1, 1, 0},},
	// .neg_x
	.neg_x = {{0, 1, 0},{0, 0, 0},{0, 0, 1},{0, 1, 1},},
	// .pos_y
	.pos_y = {{0, 1, 0},{0, 1, 1},{1, 1, 1},{1, 1, 0},},
	// .neg_y
	.neg_y = {{1, 0, 0},{1, 0, 1},{0, 0, 1},{0, 0, 0},},
	// .pos_z
	.pos_z = {{0, 1, 1},{0, 0, 1},{1, 0, 1},{1, 1, 1},},
	// .neg_z
	.neg_z = {{1, 1, 0},{1, 0, 0},{0, 0, 0},{0, 1, 0},},
}

LIGHT_FACE_NORMALS_r:=LIGHT_FACE_NORMALS
LIGHT_FACE_NORMALS :: [Directions][3]int{
	.pos_x = { 1,  0,  0},
	.neg_x = {-1,  0,  0},
	.pos_y = { 0,  1,  0},
	.neg_y = { 0, -1,  0},
	.pos_z = { 0,  0,  1},
	.neg_z = { 0,  0, -1},
}


LIGHT_MAX_PACKED : u32: 0x3fff_ffff

// @(inline)
light_sample_is_opaque :: proc(
	current: ^[CHUNK_SIZE * CHUNK_SIZE]u32,
	across_face: ^[CHUNK_SIZE * CHUNK_SIZE]u32,
	side: Model_Sides,
	sx, sy, sz: int,
) -> bool {
	if sx >= 0 && sx < CHUNK_SIZE && sy >= 0 && sy < CHUNK_SIZE && sz >= 0 && sz < CHUNK_SIZE {
		return (current[sx + sz * CHUNK_SIZE] & (u32(1) << u32(sy))) != 0
	}

	// Only handle samples crossing this face's normal boundary.
	switch side {
	case .pos_x:
		if sx != CHUNK_SIZE || sy < 0 || sy >= CHUNK_SIZE || sz < 0 || sz >= CHUNK_SIZE {return false}
		return (across_face[sz * CHUNK_SIZE] & (u32(1) << u32(sy))) != 0

	case .neg_x:
		if sx != -1 || sy < 0 || sy >= CHUNK_SIZE || sz < 0 || sz >= CHUNK_SIZE {return false}
		return (across_face[CHUNK_SIZE - 1 + sz * CHUNK_SIZE] & (u32(1) << u32(sy))) != 0

	case .pos_y:
		if sy != CHUNK_SIZE || sx < 0 || sx >= CHUNK_SIZE || sz < 0 || sz >= CHUNK_SIZE {return false}
		return (across_face[sx + sz * CHUNK_SIZE] & 1) != 0

	case .neg_y:
		if sy != -1 || sx < 0 || sx >= CHUNK_SIZE || sz < 0 || sz >= CHUNK_SIZE {return false}
		return (across_face[sx + sz * CHUNK_SIZE] & (u32(1) << 31)) != 0

	case .pos_z:
		if sz != CHUNK_SIZE || sx < 0 || sx >= CHUNK_SIZE || sy < 0 || sy >= CHUNK_SIZE {return false}
		return (across_face[sx] & (u32(1) << u32(sy))) != 0

	case .neg_z:
		if sz != -1 || sx < 0 || sx >= CHUNK_SIZE || sy < 0 || sy >= CHUNK_SIZE {return false}
		return (across_face[sx + (CHUNK_SIZE - 1) * CHUNK_SIZE] & (u32(1) << u32(sy))) != 0

	case .extra:
		return false
	}

	return false
}

LIGHT_CORNER_SAMPLE_OFFSETS_r:=LIGHT_CORNER_SAMPLE_OFFSETS
LIGHT_CORNER_SAMPLE_OFFSETS :: [Directions][4][4][3]int{
	.pos_x = {
		{{1,0,0},{1,1,0},{1,0,1},{1,1,1}},
		{{1,-1,0},{1,0,0},{1,-1,1},{1,0,1}},
		{{1,-1,-1},{1,0,-1},{1,-1,0},{1,0,0}},
		{{1,0,-1},{1,1,-1},{1,0,0},{1,1,0}},
	},
	.neg_x = {
		{{-1,0,-1},{-1,1,-1},{-1,0,0},{-1,1,0}},
		{{-1,-1,-1},{-1,0,-1},{-1,-1,0},{-1,0,0}},
		{{-1,-1,0},{-1,0,0},{-1,-1,1},{-1,0,1}},
		{{-1,0,0},{-1,1,0},{-1,0,1},{-1,1,1}},
	},
	.pos_y = {
		{{-1,1,-1},{0,1,-1},{-1,1,0},{0,1,0}},
		{{-1,1,0},{0,1,0},{-1,1,1},{0,1,1}},
		{{0,1,0},{1,1,0},{0,1,1},{1,1,1}},
		{{0,1,-1},{1,1,-1},{0,1,0},{1,1,0}},
	},
	.neg_y = {
		{{0,-1,-1},{1,-1,-1},{0,-1,0},{1,-1,0}},
		{{0,-1,0},{1,-1,0},{0,-1,1},{1,-1,1}},
		{{-1,-1,0},{0,-1,0},{-1,-1,1},{0,-1,1}},
		{{-1,-1,-1},{0,-1,-1},{-1,-1,0},{0,-1,0}},
	},
	.pos_z = {
		{{-1,0,1},{0,0,1},{-1,1,1},{0,1,1}},
		{{-1,-1,1},{0,-1,1},{-1,0,1},{0,0,1}},
		{{0,-1,1},{1,-1,1},{0,0,1},{1,0,1}},
		{{0,0,1},{1,0,1},{0,1,1},{1,1,1}},
	},
	.neg_z = {
		{{0,0,-1},{1,0,-1},{0,1,-1},{1,1,-1}},
		{{0,-1,-1},{1,-1,-1},{0,0,-1},{1,0,-1}},
		{{-1,-1,-1},{0,-1,-1},{-1,0,-1},{0,0,-1}},
		{{-1,0,-1},{0,0,-1},{-1,1,-1},{0,1,-1}},
	},
}

sample_corner_light :: proc(
	w_map: ^Map,
	light_data: ^Light_Chunk_Data,
	prepared: ^Mesh_Prepared_Chunk_Data,
	side: Model_Sides,
	x, y, z: int,
	corner_id: int,
) -> u32 {
	if side == .extra { return LIGHT_MAX_PACKED }

	side_index := cast(Directions)side
	corner_sample_offsets := LIGHT_CORNER_SAMPLE_OFFSETS_r[side_index][corner_id]
	neighbor_light_cache: [Full_Directions]^Light_Chunk_Data
	neighbor_light_checked: [Full_Directions]bool
	fine_light_cache: [Full_Directions][4]^Light_Chunk_Data
	fine_light_checked: [Full_Directions][4]bool
	coarse_light_cache: [Full_Directions]^Light_Chunk_Data
	coarse_light_checked: [Full_Directions]bool
	sun_light_weighted_sum: [3]int
	block_light_weighted_sum: [3]int

	for sample_index in 0..<4 {
		sample_offset := corner_sample_offsets[sample_index]
		sample_position := [3]int{x+sample_offset[0],y+sample_offset[1],z+sample_offset[2]}
		neighbor_chunk_offset: [3]int

		for axis_index in 0..<3 {
			if sample_position[axis_index] < 0 {
				neighbor_chunk_offset[axis_index] = -1
			} else if sample_position[axis_index] >= CHUNK_SIZE {
				neighbor_chunk_offset[axis_index] = 1
			}
		}

		sample_light_data := light_data
		local_sample_position := sample_position

		if neighbor_chunk_offset != {0,0,0} {
			neighbor_direction := FULL_DIRECTION_LOOKUP_r[neighbor_chunk_offset[0]+1][neighbor_chunk_offset[1]+1][neighbor_chunk_offset[2]+1]
			neighbor := &prepared.neighbor_light_data[neighbor_direction]
			found_neighbor := false

			// Prefer an equal-LOD neighbor. Resolve the handle locally and cache
			// only for this corner calculation; no pointers survive the call.
			if !neighbor_light_checked[neighbor_direction] {
				if neighbor.same_lod != {} {
					neighbor_light_cache[neighbor_direction], _ = get_light_chunk_data(w_map,neighbor.same_lod)
				}
				neighbor_light_checked[neighbor_direction] = true
			}
			if neighbor_light_cache[neighbor_direction] != nil {
				sample_light_data = neighbor_light_cache[neighbor_direction]
				for axis_index in 0..<3 {
					if local_sample_position[axis_index] < 0 { local_sample_position[axis_index] += CHUNK_SIZE }
					else if local_sample_position[axis_index] >= CHUNK_SIZE { local_sample_position[axis_index] -= CHUNK_SIZE }
				}
				found_neighbor = true
			} else {
				// Convert the source sample-cell center to world voxel coordinates.
				// This lets us select the actual fine/coarse chunk that contains it,
				// including samples that cross only a tangent chunk boundary.
				world_sample_position: [3]int
				for axis_index in 0..<3 {
					world_sample_position[axis_index] = prepared.chunk_pos[axis_index]*CHUNK_SIZE + sample_position[axis_index]*prepared.chunk_size + prepared.chunk_size/2
				}

				for fine_index in 0..<neighbor.fine_count {
					fine_neighbor := neighbor.fine_lod[fine_index]
					if fine_neighbor.size <= 0 { continue }
					candidate_local_position: [3]int
					inside_fine_neighbor := true
					for axis_index in 0..<3 {
						relative_world_position := world_sample_position[axis_index] - fine_neighbor.pos[axis_index]*CHUNK_SIZE
						if relative_world_position < 0 || relative_world_position >= CHUNK_SIZE*fine_neighbor.size {
							inside_fine_neighbor = false
							break
						}
						candidate_local_position[axis_index] = relative_world_position/fine_neighbor.size
					}
					if !inside_fine_neighbor { continue }
					if !fine_light_checked[neighbor_direction][fine_index] {
						fine_light_cache[neighbor_direction][fine_index], _ = get_light_chunk_data(w_map,fine_neighbor.light_hd)
						fine_light_checked[neighbor_direction][fine_index] = true
					}
					if fine_light_cache[neighbor_direction][fine_index] == nil { continue }
					sample_light_data = fine_light_cache[neighbor_direction][fine_index]
					local_sample_position = candidate_local_position
					found_neighbor = true
					break
				}

				if !found_neighbor && neighbor.has_coarse_lod {
					coarse_neighbor := neighbor.coarse_lod
					coarse_local_position: [3]int
					inside_coarse_neighbor := coarse_neighbor.size > 0
					for axis_index in 0..<3 {
						relative_world_position := world_sample_position[axis_index] - coarse_neighbor.pos[axis_index]*CHUNK_SIZE
						if relative_world_position < 0 || relative_world_position >= CHUNK_SIZE*coarse_neighbor.size {
							inside_coarse_neighbor = false
							break
						}
						coarse_local_position[axis_index] = relative_world_position/coarse_neighbor.size
					}
					if inside_coarse_neighbor {
						if !coarse_light_checked[neighbor_direction] {
							coarse_light_cache[neighbor_direction], _ = get_light_chunk_data(w_map,coarse_neighbor.light_hd)
							coarse_light_checked[neighbor_direction] = true
						}
						if coarse_light_cache[neighbor_direction] != nil {
							sample_light_data = coarse_light_cache[neighbor_direction]
							local_sample_position = coarse_local_position
							found_neighbor = true
						}
					}
				}
			}

			if !found_neighbor {
				// At an unloaded/world edge, clamp to this chunk's edge light instead
				// of injecting a zero-valued sample that creates a black seam.
				for axis_index in 0..<3 {
					if local_sample_position[axis_index] < 0 { local_sample_position[axis_index] = 0 }
					else if local_sample_position[axis_index] >= CHUNK_SIZE { local_sample_position[axis_index] = CHUNK_SIZE-1 }
				}
				sample_light_data = light_data
			}
		}

		voxel_index := local_sample_position[1] + local_sample_position[0]*CHUNK_SIZE + local_sample_position[2]*CHUNK_SIZE*CHUNK_SIZE
		sampled_light := get_light_in_chunk_index(sample_light_data,cast(u16)voxel_index)

		for channel_index in 0..<3 {
			sun_light_weighted_sum[channel_index] += int(sampled_light.sun[channel_index])*LIGHT_CORNER_SAMPLE_WEIGHT
			block_light_weighted_sum[channel_index] += int(sampled_light.block[channel_index])*LIGHT_CORNER_SAMPLE_WEIGHT
		}
	}

	sun_r := u32(sun_light_weighted_sum[0]/256)
	sun_g := u32(sun_light_weighted_sum[1]/256)
	sun_b := u32(sun_light_weighted_sum[2]/256)
	block_r := u32(block_light_weighted_sum[0]/256)
	block_g := u32(block_light_weighted_sum[1]/256)
	block_b := u32(block_light_weighted_sum[2]/256)

	return ((sun_r&31)<<25)|((sun_g&31)<<20)|((sun_b&31)<<15)|((block_r&31)<<10)|((block_g&31)<<5)|(block_b&31)
}

LIGHT_CORNER_SAMPLE_WEIGHT :: 64

Destroy_Mesh_Data_Q_Data::struct{
	mesh_data_hd:Chunk_Mesh_Data_HD,
}
manage_destroy_mesh_data_q::proc(w_map:^Map)->(did_work:bool){
	for {
		value, ok := chan.try_recv(w_map.destroy_mesh_data_chan)
		if !ok {break} 
		did_work=true
		do_a_destroy_mesh_data_q(w_map, value)
	}

	return
}
add_to_destroy_mesh_data_q::proc(w_map:^Map,mesh_data_hd:Chunk_Mesh_Data_HD){
	chan.send(w_map.destroy_mesh_data_chan,Destroy_Mesh_Data_Q_Data{mesh_data_hd})
	return
}
do_a_destroy_mesh_data_q::proc(w_map:^Map,q:Destroy_Mesh_Data_Q_Data){
	destroy_mesh_data(w_map,q.mesh_data_hd)
}
destor_count:int
destroy_mesh_data::proc(w_map:^Map,hd:Chunk_Mesh_Data_HD){
	found,err:=hm.remove(&w_map.chunks_mesh_data,hd)
	if err != .None{log.log(.Error,"destroy_mesh_data() err",err,hd)}

	if !found{log.log(.Warning,"cant find mesh data to destroy",hd)}
}

// Upload_Mesh_Data_Q::hm.Dynamic_Handle_Map(Upload_Mesh_Data_Q_Data,Upload_Mesh_Data_Q_HD)
// Upload_Mesh_Data_Q_HD::distinct hm.Handle64
Upload_Mesh_Data_Q_Data::struct{
	// handle:Upload_Mesh_Data_Q_HD,
	data_hd:Chunk_HD,
	mesh_hd:Chunk_Mesh_Data_HD, 
	side:Model_Sides,
	// q_state:Q_State,
}
manage_upload_mesh_data_q::proc(w_map:^Map)->(did_work:bool){
	copy_cmd_buf:=sdl.AcquireGPUCommandBuffer(s.gpu_device)	
	copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)
	for {
		value, ok := chan.try_recv(w_map.upload_mesh_data_chan)
		if !ok {break }
		did_work=true
		do_a_upload_mesh_data_q(w_map, value, copy_pass)
	}
	sdl.EndGPUCopyPass(copy_pass)
	ok := sdl.SubmitGPUCommandBuffer(copy_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")
	return
}
add_to_upload_mesh_data_q::proc(
	w_map:^Map,
	data_hd:Chunk_HD,
	mesh_hd:Chunk_Mesh_Data_HD, 
	side:Model_Sides,
){
	chan.send(w_map.upload_mesh_data_chan, Upload_Mesh_Data_Q_Data{data_hd=data_hd, mesh_hd=mesh_hd, side=side})
	return
}
do_a_upload_mesh_data_q::proc(w_map:^Map,q:Upload_Mesh_Data_Q_Data, copy_pass: ^sdl.GPUCopyPass){
	chunk, chunk_ok := hm.get(&w_map.chunks, q.data_hd)
	if !chunk_ok {
		add_to_destroy_mesh_data_q(w_map, q.mesh_hd)
		return
	}
	atom.atomic_rw_mutex_shared_lock(&chunk.data_rw_mutex)
	retiring := chunk.retiring
	atom.atomic_rw_mutex_shared_unlock(&chunk.data_rw_mutex)
	if retiring {
		add_to_destroy_mesh_data_q(w_map, q.mesh_hd)
		return
	}
	upload_chunk_side_to_gpu(w_map,q.data_hd,q.mesh_hd,q.side,copy_pass)
}

// upload_chunk_side_to_gpu::proc(w_map:^Map, chunk:^Chunk, mesh:^Chunk_Mesh_Data, side:Model_Sides, copy_pass: ^sdl.GPUCopyPass){
upload_chunk_side_to_gpu::proc(w_map:^Map, chunk_hd:Chunk_HD, mesh_hd:Chunk_Mesh_Data_HD, side:Model_Sides, copy_pass: ^sdl.GPUCopyPass){
	chunk, chunk_ok := get_chunk(w_map,chunk_hd)
	if !chunk_ok{log.log(.Error, "failed invalid chunk_hd(",chunk_hd,")") ;return}
	atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
	defer atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
	if chunk.retiring {
		add_to_destroy_mesh_data_q(w_map,mesh_hd)
		return
	}

	mesh,mesh_ok:=get_chunk_mesh_data(w_map,mesh_hd)
	if !mesh_ok {log.log(.Warning,"no mesh data found",mesh_hd) ;return}

	if mesh.face_count == 0{
		chunk.mesh_gpu_ready_mask += {side}
		add_to_destroy_mesh_data_q(w_map,mesh_hd)
		return
	}

	gpu_data,gpu_data_ok:=hm.get(&w_map.gpu_mesh_data_hm,chunk.gpu_mesh_data_hd)
	if !gpu_data_ok{
		// err:runtime.Allocator_Error
		gpu_data_hd,err:=hm.dynamic_add(&w_map.gpu_mesh_data_hm,GPU_Mesh_Data{})
		if err != .None{log.log(.Warning,"bad aloc");return}
		gpu_data,gpu_data_ok=hm.get(&w_map.gpu_mesh_data_hm,gpu_data_hd)
		assert(gpu_data_ok," i do not know how this hapend problobly hm full or somthing stupid like that this hould never triger")
		chunk.gpu_mesh_data_hd = gpu_data_hd
	}else{
		tg.free_list_free(&w_map.chunks_in_mesh,gpu_data.range_in_map_mesh[side])
		// unload_mesh_data(w_map,chunk.gpu_mesh_data_hd)
	}
	gpu_data.visible = true

	num_of_gpu_mesh_slots:=cast(u32)math.ceil(cast(f32)mesh.face_count/CHUNK_MAX_FACE_NUM)

	range,ok:=tg.free_list_alloc(&w_map.chunks_in_mesh, num_of_gpu_mesh_slots)
	if !ok{
		log.log(.Error, "failed tg.free_list_alloc(&w_map.chunks_in_mesh) !ok mega mesh problobly full")
		return
	}
	
	if gpu_data.range_in_map_mesh[side].count < 0{
		tg.free_list_free(&w_map.chunks_in_mesh,gpu_data.range_in_map_mesh[side])
	}

	gpu_data.range_in_map_mesh[side] = range
	first_face:=cast(u32) range.start * CHUNK_MAX_FACE_NUM

	upload_data_to_mesh_by_offset(w_map.map_mesh_hd,w_map.chunck_transfer_buffer,mesh.data[:mesh.face_count],first_face, copy_pass)
	gpu_data.chunk_shader_data[side].pos = cast([4]i32)chunk.pos
	gpu_data.chunk_shader_data[side].side = side

	gpu_data.draw_cmd[side].num_vertices = cast(u32)mesh.face_count * 6
	gpu_data.draw_cmd[side].first_vertex = first_face * 6
	gpu_data.draw_cmd[side].num_instances = 1 
	chunk.mesh_gpu_ready_mask += {side}

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
}

// Unload_Mesh_Data_Q_Data::struct{
// 	gpu_mesh_hd:GPU_Mesh_Data_HD,
// }
// manage_unload_mesh_data_q::proc(w_map:^Map)->(did_work:bool){
// 	for {
// 		value, ok := chan.try_recv(w_map.unload_mesh_data_chan)
// 		if !ok {
// 			break // More idiomatic than return here
// 		}
// 		did_work=true
// 		do_a_unload_mesh_data_q(w_map, value)
// 	}

// 	return
// }
// add_to_unload_mesh_data_q::proc(w_map:^Map,gpu_mesh_hd:GPU_Mesh_Data_HD){

// 	chan.send(w_map.unload_mesh_data_chan, Unload_Mesh_Data_Q_Data{gpu_mesh_hd})
// 	return
// }
// do_a_unload_mesh_data_q::proc(w_map:^Map,q:Unload_Mesh_Data_Q_Data){

// 	unload_mesh_data(w_map,q.gpu_mesh_hd)

// }
unload_mesh_data::proc(w_map:^Map,gpu_mesh_hd:GPU_Mesh_Data_HD){
	gpu_mesh,gpu_mesh_ok:=hm.get(&w_map.gpu_mesh_data_hm,gpu_mesh_hd)
	if gpu_mesh_ok{
		for side in Model_Sides{
			range:=&gpu_mesh.range_in_map_mesh[side]
			if range.count>0{
				tg.free_list_free(&w_map.chunks_in_mesh,range^)
			}
		}
		gpu_mesh.range_in_map_mesh = {}
		gpu_mesh.draw_cmd = {}
		gpu_mesh.face_count =0
		hm.remove(&w_map.gpu_mesh_data_hm,gpu_mesh_hd)
	}
}
unload_mesh_data_by_side::proc(w_map:^Map,gpu_mesh_hd:GPU_Mesh_Data_HD,side:Model_Sides){
	gpu_mesh,gpu_mesh_ok:=hm.get(&w_map.gpu_mesh_data_hm,gpu_mesh_hd)
	if gpu_mesh_ok{

		range:=&gpu_mesh.range_in_map_mesh[side]
		if range.count>0{
			tg.free_list_free(&w_map.chunks_in_mesh,range^)
		}

		gpu_mesh.range_in_map_mesh[side] = {}
		gpu_mesh.draw_cmd[side] = {}
	}
}

Set_Block_CMD_Action::enum u8{
	replace_cell,
	append_child,
	destroy_from,
}
Set_Block_CMD::struct{
	chunk_pos:[4]int,
	pos_in_chunk:[3]u8,
	new_block:Block_Palette_Data,
	action:Set_Block_CMD_Action,
	target_pal_index:u16,
}

manage_set_block_cmd_q::proc(w_map:^Map)->(did_work:bool){
	for {
		value, ok := chan.try_recv(w_map.set_block_chan)
		if !ok {break }
		did_work=true
		do_a_set_block_cmd_q(w_map, value)
	}

	return
}
add_to_set_block_cmd_q::proc(w_map:^Map,cmd:Set_Block_CMD){
	chan.send(w_map.set_block_chan, cmd)
	return
}
do_a_set_block_cmd_q::proc(w_map:^Map, q:Set_Block_CMD) {
	chunk_hd, chunk_hd_ok := get_chunk_by_pos_safe(w_map, q.chunk_pos)
	if !chunk_hd_ok { return }
	chunk, chunk_ok := hm.get(&w_map.chunks, chunk_hd)
	if !chunk_ok { return }

	atom.atomic_rw_mutex_lock(&chunk.data_rw_mutex)
	locked := true
	defer { if locked { atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex) } }
	if chunk.retiring { return }
	m_qs := &chunk.mesh_q_state
	if m_qs[.pos_x] != .usable || m_qs[.neg_x] != .usable || m_qs[.pos_y] != .usable || m_qs[.neg_y] != .usable || m_qs[.pos_z] != .usable || m_qs[.neg_z] != .usable { return }

	vox_data_hd := chunk.vox_data_hd
	chunk_vox, chunk_vox_ok := hm.get(&w_map.vox_chunk_hm, vox_data_hd)
	if !chunk_vox_ok || !atom.atomic_load(&chunk_vox.vox_gened) { return }

	old_pal_index := get_palette_index_by_pos(chunk_vox, q.pos_in_chunk)
	switch q.action {
	case .replace_cell:
		p_index := get_or_add_palette_index(chunk_vox, q.new_block)
		set_palette_index(chunk_vox, pos_to_vox_index(q.pos_in_chunk), p_index)
	case .append_child:
		set_child_block_in_chunk(chunk_vox, q.pos_in_chunk, q.new_block.item, q.new_block.state)
	case .destroy_from:
		destroyed := destroy_block_in_chunk(chunk_vox, q.pos_in_chunk, q.target_pal_index)
		if !destroyed { return }
	}

	new_pal_index := get_palette_index_by_pos(chunk_vox, q.pos_in_chunk)
	if old_pal_index == new_pal_index { return }

	light_q_hd, err := hm.add(&w_map.light_qs_hm, Light_Q{})
	assert(err == .None)
	update_block_lighting_after_set(w_map, chunk_vox, q.pos_in_chunk, light_q_hd)

	atom.atomic_rw_mutex_unlock(&chunk.data_rw_mutex)
	locked = false
	start_light_chunk_task(w_map, Light_Chunk_Task{
		w_map=w_map,
		chunk_hd=chunk_hd,
		vox_data_hd=vox_data_hd,
		light_q_hd=light_q_hd,
	})
}

update_block_lighting_after_set :: proc(
	w_map:^Map,
	vox_chunk:^Vox_Chunk_Data,
	pos:[3]u8,
	light_q_hd:Light_Q_HD,
) {
	q,q_ok:=hm.get(&w_map.light_qs_hm,light_q_hd)
	assert(q_ok)

	append(&q.remove_q,Light_Remove_CMD{pos=pos,type=.sun,channels=true})
	append(&q.remove_q,Light_Remove_CMD{pos=pos,type=.block,channels=true})

	ab:=&vox_chunk.backing_chunk_data_abstract
	pal_index:=get_palette_index_by_pos(vox_chunk,pos)

	is_opaque:=false
	emission:[3]u8

	if pal_index != 0 {
		chain_finished:=false

		for _ in 0..<ab.pal_count^ {
			assert(pal_index < ab.pal_count^,"invalid multiblock lighting chain")

			block:=ab.pal[pal_index]
			item,item_ok:=reg.get(&g.item_reg,block.item)

			if item_ok {
				is_opaque=is_opaque || item.is_opaque

				emission.r=max(emission.r,item.light_emission.r)
				emission.g=max(emission.g,item.light_emission.g)
				emission.b=max(emission.b,item.light_emission.b)
			}

			pal_index=block.multy_block_index
			if pal_index == 0 {
				chain_finished=true
				break
			}
		}

		assert(chain_finished,"cycle detected in multiblock lighting chain")
	}

	if !is_opaque {
		append(&q.seed_q,Light_Seed_Q_CMD{pos=pos,type=.sun})
		append(&q.seed_q,Light_Seed_Q_CMD{pos=pos,type=.block})
	}

	if emission != {} {
		append(&q.add_q,Light_Q_CMD{
			pos=pos,
			light=emission,
			type=.block,
		})
	}
}


init_chunker_thread::proc(){
	g.chunker_thread = thread.create_and_start(do_chunkering,self_cleanup = false)
}



do_chunkering::proc(){
	tg.name_thread("Chunkering")
	tracking_allocator:mem.Tracking_Allocator
	context.logger = tg.create_tg_console_logger(opt = {.Thread_Id,.Level,.Short_File_Path,.Line,.Procedure,.Terminal_Color})
	context.allocator = tg.init_tracking_allocator(&tracking_allocator)
	defer tg.end_tracking_allocator(&tracking_allocator)
	log.log(.Info,"starting chunker thread")
	log.log(.Info, "free GPU mesh space = ", tg.free_list_space_lef(&g.w_map.chunks_in_mesh))

	for !s.app_should_close{
		
		did_work:=manage_all_w_map_q(&g.w_map)
		if did_work{
			atom.atomic_store_explicit(&g.w_map.did_work, did_work, .Release)
		}else{
			time.sleep(1 * time.Millisecond/10)
		}
	}
}
