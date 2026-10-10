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
	xz_render_distance = 8,
	y_render_distance = 8,
	lod_levels = 10,
	lod_depth = 2,
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

	pool_num_waiting:	int,
	pool_num_in_processing:	int,
	pool_num_outstanding:	int,
	pool_num_done:	int,

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


// Task_Data :: struct {
// 	link: ^Task_Data,
// 	el_1:rawptr,
// 	el_2:rawptr,
// 	el_3:rawptr,
// }

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
	map_mesh_hd:tg.Mesh_Handle,
	chunk_shader_data:tg.Indexed_GPU_Data,
	
	chunks_in_mesh:tg.Free_List,
	chunck_transfer_buffer:^sdl.GPUTransferBuffer,

	t_pool:thread.Pool,
	pool_tasks:Pool_Tasks_HM,


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
	vox_q_state:	Q_State,
	vox_data_hd:	Vox_Chunk_Data_HD,
	light_data_hd:	Light_Chunk_Data_HD,

	mesh_q_state:[Model_Sides]Q_State,
	

	gpu_mesh_data_hd:GPU_Mesh_Data_HD,
	// mesh_data:		 [Model_Sides]Chunk_Mesh_Data_HD,
	chunk_shader_data:Chunk_Shader_Data,
}

Chunk_Shader_Data::struct{
	pos:[4]i32,
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
	chunk_shader_data:Chunk_Shader_Data,
	draw_cmd:			[Model_Sides]sdl.GPUIndirectDrawCommand,
	range_in_map_mesh:	[Model_Sides]tg.Free_List_Range,
	face_count:int
}

Pool_Tasks_HM::hm.Dynamic_Handle_Map(Pool_Task,Pool_Task_HD)
Pool_Task_HD::distinct hm.Handle64
Pool_Task::struct{
	handle:Pool_Task_HD,
	task:All_Tasks,
}
All_Tasks::union{
	Gen_Vox_Data_Task,
	Mesh_Chunk_Task,
}
Gen_Vox_Data_Task::struct{
	w_map:^Map,
	vox_data_hd:Vox_Chunk_Data_HD,
}
Mesh_Chunk_Task::struct{
	w_map: ^Map,
	chunk_hd:Chunk_HD,
	vox_data_hd: Vox_Chunk_Data_HD,
	neighbor_vox_hd: [4]Vox_Chunk_Data_HD,
	mesh_hd: Chunk_Mesh_Data_HD,
	has_4_neighbors:bool,
	side: Model_Sides,
}

start_gen_vox_dat_task::proc(w_map:^Map, task:Gen_Vox_Data_Task){
	task_hd,err:=hm.add(&w_map.pool_tasks,Pool_Task{task=task})
	assert(err == .None)
	task_ptr,task_ok:=hm.get(&w_map.pool_tasks,task_hd)
	assert(task_ok)
	
	thread.pool_add_task(&w_map.t_pool,context.allocator,do_task,task_ptr,cast(int)task_hd.idx)
	
}

start_mesh_chunk_task::proc(w_map:^Map, task:Mesh_Chunk_Task){
	task_hd,err:=hm.add(&w_map.pool_tasks,Pool_Task{task=task})
	assert(err == .None)
	task_ptr,task_ok:=hm.get(&w_map.pool_tasks,task_hd)
	assert(task_ok)
	
	thread.pool_add_task(&w_map.t_pool,context.allocator,do_task,task_ptr,cast(int)task_hd.idx)
	
}


do_task::proc(task: thread.Task){
	// tg.name_thread("Gen Vox Data Task",task.user_index)
	// tracking_allocator:mem.Tracking_Allocator
	// context.logger = tg.create_tg_console_logger(opt = {.Thread_Id,.Level,.Short_File_Path,.Line,.Procedure,.Terminal_Color})
	// context.allocator = tg.init_tracking_allocator(&tracking_allocator)
	// defer tg.end_tracking_allocator(&tracking_allocator)
	// defer tg.destroy_tg_console_logger(context.logger)
	new_task:=cast(^Pool_Task)task.data
	switch t in new_task.task {
		case Gen_Vox_Data_Task:
		gen_vox_data(t.w_map,t.vox_data_hd)
		case Mesh_Chunk_Task:
		mesh_by_bit_mask(t.w_map,t.chunk_hd,t.vox_data_hd,t.neighbor_vox_hd,t.mesh_hd,t.has_4_neighbors,t.side)
	}
}

fin_pool_tasks::proc(w_map:^Map){
	for {
		task_raw, ok := thread.pool_pop_done(&w_map.t_pool)
		if !ok {break}
		task:=cast(^Pool_Task)task_raw.data
		switch t in task.task{
		case Gen_Vox_Data_Task:
			
			vox_chunk,vox_chunk_ok:=hm.get(&w_map.vox_chunk_hm,t.vox_data_hd)
			assert(vox_chunk_ok)
			atom.atomic_store(&vox_chunk.vox_gened,true)
			add_to_chunk_needs_meshing_q(w_map,vox_chunk.pos)
		case Mesh_Chunk_Task:
			chunk,chunk_ok:=hm.get(&w_map.chunks,t.chunk_hd)
			assert(chunk_ok)

			mesh,mesh_ok:=hm.get(&w_map.chunks_mesh_data,t.mesh_hd)
			assert(mesh_ok)
			// if !mesh_ok {
			// 	chunk.mesh_q_state[t.side] = .usable
			// 	return
			// }
			// assert(mesh_ok)

			face_count :=mesh.face_count

			chunk.mesh_q_state[t.side] = .usable
			if face_count <= 0 {
				add_to_destroy_mesh_data_q(w_map,t.mesh_hd)
			}else{
				add_to_upload_mesh_data_q(w_map,t.chunk_hd,t.mesh_hd,t.side)
			}
			
		}
		hm.remove(&w_map.pool_tasks,task.handle)
	}
}


get_chunk::proc(w_map:^Map,chunk_hd:Chunk_HD)->(chunk:^Chunk,ok:bool){
	chunk, ok = hm.get(&w_map.chunks, chunk_hd) 
	return chunk, ok
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

get_chunk_mesh_data::proc(w_map:^Map, mesh_data_hd:Chunk_Mesh_Data_HD,)->(mesh_data:^Chunk_Mesh_Data,ok:bool){
	mesh_data,ok=hm.get(&w_map.chunks_mesh_data,mesh_data_hd)
	return mesh_data,ok
}

init_map::proc(w_map:^Map){
	// w_map.t_pool
	pool_allocator: mem.Allocator
	pool_allocator = runtime.heap_allocator()
	thread.pool_init(&w_map.t_pool,pool_allocator,10)
	defer thread.pool_start(&w_map.t_pool)

	

	err:runtime.Allocator_Error
	w_map.gen_chunk_chan , err = chan.create_buffered(chan.Chan(Gen_Chunk_Q_Data),10000, context.allocator)
	assert(err == .None)
	w_map.destroy_chunk_chan , err = chan.create_buffered(chan.Chan(Destroy_Chunk_Q_Data),10000, context.allocator)
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
	w_map.draw_cmd_buf_hd = tg.create_mesh(sdl.GPUIndirectDrawCommand,MAX_NUM_CHUNKS,{},type = .indirect_cmd_buff, debug_name = "w_map GPUIndirectDrawCommand buffer")
	w_map.chunk_shader_data.mesh_hd = tg.create_mesh(Chunk_Shader_Data,MAX_NUM_CHUNKS,{},type = .dynamic_buff, debug_name = "Chunk shader data buffer")
	w_map.chunk_shader_data.bind_to_vert = true
	w_map.chunk_shader_data.bind_to_frag = false
	w_map.map_mesh_hd = tg.create_mesh(tg.Vert_Face,MAX_FACE_COUNT,{},type = .no_tranfer_buff, debug_name = "w_map Chunk buffer mesh")
	w_map.chunck_transfer_buffer = sdl.CreateGPUTransferBuffer(s.gpu_device,{
		usage = .UPLOAD,
		size = cast(u32)(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE * size_of(tg.Vert_Face)),
	})
}

MAX_CHUNKS_TO_Q_AT_ONE_TIME :: 500


removing_chunks_not_around_pos::proc(w_map:^Map,pos:[3]f32,)->(did_work:bool){

	chunk_pos:=pos_to_chunck_pos(pos)
	if !w_map.stream_chunk_pos_valid ||  chunk_pos != w_map.stream_chunk_pos{

	}else{
		return
	}

	xz_rad:=g.settings.xz_render_distance+3
	y_rad:=g.settings.y_render_distance+3
	
	min_x:=(-1*xz_rad) + chunk_pos.x
	max_x:=xz_rad + chunk_pos.x
	min_y:=(-1*y_rad) + chunk_pos.y
	max_y:=y_rad + chunk_pos.y
	min_z:=(-1*xz_rad) + chunk_pos.z
	max_z:=xz_rad + chunk_pos.z

	q_count:int

	itor:=hm.iterator_make(&w_map.chunks)
	loop:for chunk, chunk_hd in hm.iterate(&itor) {
		remove_chunk:bool
		if chunk.pos.x > max_x {remove_chunk = true}
		if chunk.pos.y > max_y {remove_chunk = true}
		if chunk.pos.z > max_z {remove_chunk = true}

		if chunk.pos.x < min_x {remove_chunk = true}
		if chunk.pos.y < min_y {remove_chunk = true}
		if chunk.pos.z < min_z {remove_chunk = true}
		if remove_chunk {
			// log.log(.Debug,chunk.pos,"min_x",min_x,"max_x",max_x,"min_y",min_y,"max_y",max_y,"min_z",min_z,"max_z",max_z,remove_chunk)
			// add_to_destroy_chunk_q(w_map,chunk_hd)
			// did_work = true
			// q_count+=1
			// if q_count>=MAX_CHUNKS_TO_Q_AT_ONE_TIME {return}
			// return
		}
	}
	return
}

next_power_of_two :: proc(v:int) -> int {
	result := 1

	for result < v {
		result <<= 1
	}

	return result
}


nearest_valid_chunk_pos :: proc(v, lod_lev:int) -> int {
	q := v / lod_lev
	r := v % lod_lev

	// Odin integer division truncates toward zero.
	if r < 0 {
		r += lod_lev
		q -= 1
	}

	// Round to the nearest valid LOD position.
	if r*2 >= lod_lev {
		q += 1
	}

	return q * lod_lev
}


adding_chunks_around_pos :: proc(w_map:^Map, pos:[3]f32) -> (did_work:bool) {
	chunk_pos := pos_to_chunck_pos(pos)

	xz_rad := g.settings.xz_render_distance
	y_rad := g.settings.y_render_distance
	lod_depth := g.settings.lod_depth

	// Your original desired first LOD radius.
	lod_1_radius := cast(int)(f32(xz_rad) * 2)
	lod_1_radius = ((lod_1_radius + lod_depth - 1) / lod_depth) * lod_depth

	// The first box must contain the desired radius.
	//
	// We make the FULL box size a power of 2.
	// Minimum 4 cells is important because the next LOD's
	// larger cells must be able to line up against this box.
	xz_radius := max(2, lod_1_radius)
	y_radius := max(2, min(lod_1_radius, y_rad))

	base_xz_box_cells := next_power_of_two(xz_radius * 2)
	base_y_box_cells := next_power_of_two(y_radius * 2)

	if base_xz_box_cells < 4 {
		base_xz_box_cells = 4
	}

	if base_y_box_cells < 4 {
		base_y_box_cells = 4
	}

	q_count := 0

	// Previous LOD box.
	prev_x_start := 0
	prev_x_end := 0
	prev_y_start := 0
	prev_y_end := 0
	prev_z_start := 0
	prev_z_end := 0

	has_previous_box := false

	for i_lod in 0..<g.settings.lod_levels {
		lod_lev := 1 << cast(u32)i_lod

		// Find the nearest chunk coordinate that is valid
		// for this LOD's grid.
		center_x := nearest_valid_chunk_pos(chunk_pos.x, lod_lev)
		center_y := nearest_valid_chunk_pos(chunk_pos.y, lod_lev)
		center_z := nearest_valid_chunk_pos(chunk_pos.z, lod_lev)

		// Same number of LOD cells every level.
		// Each cell is twice as large, so the physical box
		// doubles in size every LOD.
		xz_box_size := base_xz_box_cells * lod_lev
		y_box_size := base_y_box_cells * lod_lev

		x_start := center_x - xz_box_size/2
		x_end := center_x + xz_box_size/2

		y_start := center_y - y_box_size/2
		y_end := center_y + y_box_size/2

		z_start := center_z - xz_box_size/2
		z_end := center_z + xz_box_size/2

		for x := x_start; x < x_end; x += lod_lev {
			x_cell_end := x + lod_lev

			for y := y_start; y < y_end; y += lod_lev {
				y_cell_end := y + lod_lev

				for z := z_start; z < z_end; z += lod_lev {
					z_cell_end := z + lod_lev

					// A coarse cell is skipped ONLY if the
					// entire coarse cell is inside the
					// previous finer LOD box.
					inside_previous := false

					if has_previous_box {
						inside_previous =
							x >= prev_x_start &&
							x_cell_end <= prev_x_end &&
							y >= prev_y_start &&
							y_cell_end <= prev_y_end &&
							z >= prev_z_start &&
							z_cell_end <= prev_z_end
					}

					if inside_previous {
						continue
					}

					key := [4]int{x, y, z, lod_lev}

					if _,ok := get_chunk_by_pos_safe(w_map,key);ok{
						continue
					}
					// log.log(.Debug,"add_chunck",key)
					add_to_gen_chunk_q(w_map, key)

					did_work = true
					q_count += 1

					if q_count >= MAX_CHUNKS_TO_Q_AT_ONE_TIME {
						return
					}
				}
			}
		}

		prev_x_start = x_start
		prev_x_end = x_end
		prev_y_start = y_start
		prev_y_end = y_end
		prev_z_start = z_start
		prev_z_end = z_end

		has_previous_box = true
	}

	return
}

update_w_map_draw_cmds_buff::proc(w_map:^Map,cam:^tg.Camera){
	mesh:=tg.get_mesh(w_map.draw_cmd_buf_hd)
	chunck_shader_data:=tg.get_mesh(w_map.chunk_shader_data.mesh_hd)
	w_map.chunk_shader_data.count = 0
	tmep_full_count:int
	tg.clear_mesh_cpu(&mesh.cpu)
	tg.clear_mesh_cpu(&chunck_shader_data.cpu)

	view_mat, proj_mat:=tg.make_view_mat_proj_mat(cam)
	frustum:=make_frustum(view_mat, proj_mat)



	itor:=hm.iterator_make(&w_map.gpu_mesh_data_hm)
	loop:for gpu_mesh, gpu_mesh_hd in hm.iterate(&itor) {
		cam_chunk_pos:=pos_to_chunck_pos(cam.pos)
		if should_cull_chunk(&frustum,gpu_mesh.chunk_shader_data.pos){
			continue
		}
		for draw_cmd, side in gpu_mesh.draw_cmd{

			tmep_full_count+=1
			if draw_cmd.num_vertices == 0{
				continue
			}
			if should_cull_chunk_side(side,gpu_mesh.chunk_shader_data.pos, cast([3]i32)cam_chunk_pos){
				continue
			}
			draw_cmd_:[1]sdl.GPUIndirectDrawCommand=draw_cmd
			tg.append_to_mesh(&mesh.cpu,{},draw_cmd_[:])
			chunck_shader_data_:[1]Chunk_Shader_Data=gpu_mesh.chunk_shader_data
			tg.append_to_mesh(&chunck_shader_data.cpu,{},chunck_shader_data_[:])
			// log.log(.Debug,"draw_cmd",draw_cmd,)
			w_map.chunk_shader_data.count+=1
			// log.log(.Debug,gpu_mesh.chunk_shader_data)

		}
	}
	tg.update_mesh(w_map.draw_cmd_buf_hd)
	tg.update_mesh(w_map.chunk_shader_data.mesh_hd)
}

should_cull_chunk_side :: proc(
	side: Model_Sides,
	chunk_pos: [4]i32,
	cam_chunk_pos: [3]i32,
) -> (cull: bool) {

	if !g.settings.do_chunk_back_face_culling {
		return false
	}

	size := chunk_pos.w

	min_x := chunk_pos.x
	min_y := chunk_pos.y
	min_z := chunk_pos.z

	max_x := chunk_pos.x + size - 1
	max_y := chunk_pos.y + size - 1
	max_z := chunk_pos.z + size - 1

	switch side {
	case .pos_x:
		cull = cam_chunk_pos.x < min_x
	case .neg_x:
		cull = cam_chunk_pos.x > max_x
	case .pos_y:
		cull = cam_chunk_pos.y < min_y
	case .neg_y:
		cull = cam_chunk_pos.y > max_y
	case .pos_z:
		cull = cam_chunk_pos.z < min_z
	case .neg_z:
		cull = cam_chunk_pos.z > max_z
	case .extra:
	}
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


should_cull_chunk :: proc(frustum: ^Frustum, chunk_pos: [4]i32) -> bool {
	if !g.settings.do_chunk_frustum_culling {return false}

	min_x := cast(f32)chunk_pos.x * CHUNK_SIZE
	min_y := cast(f32)chunk_pos.y * CHUNK_SIZE
	min_z := cast(f32)chunk_pos.z * CHUNK_SIZE

	max_x := min_x + CHUNK_SIZE * cast(f32)chunk_pos.w
	max_y := min_y + CHUNK_SIZE * cast(f32)chunk_pos.w
	max_z := min_z + CHUNK_SIZE * cast(f32)chunk_pos.w

	for plane in frustum.planes {
		x := min_x
		y := min_y
		z := min_z

		if plane.normal.x >= 0 {x = max_x}
		if plane.normal.y >= 0 {y = max_y}
		if plane.normal.z >= 0 {z = max_z}

		if plane.normal.x*x +
		   plane.normal.y*y +
		   plane.normal.z*z +
		   plane.distance < 0 {
			return true
		}
	}

	return false
}

render_map::proc(w_map:^Map){
	tg.do_render_pass(&g.vox_pass, &g.cam, {w_map.map_mesh_hd},{&g.texture_facees,&g.geometry_facees, &w_map.chunk_shader_data}, {w_map.draw_cmd_buf_hd},type = .face)
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
manage_all_w_map_q::proc(w_map:^Map)->(did_work:bool){
	// did_work = adding_chunks_around_pos(&g.w_map,g.cam.pos)
	did_work = adding_chunks_around_pos(&g.w_map,{0,0,0})
	did_work = removing_chunks_not_around_pos(&g.w_map,g.cam.pos)
	// log.log(.Debug,g.cam.pos)

	did_work = manage_gen_chunk_q(w_map)

	did_work = manage_gen_vox_data_q(w_map)

	did_work = manage_set_block_cmd_q(w_map)

	did_work = manage_chunk_needs_meshing_q(w_map)

	did_work = manage_gen_mesh_data_q(w_map)


	did_work = manage_upload_mesh_data_q(w_map)

	did_work = manage_destroy_chunk_q(w_map)
	did_work = manage_destroy_vox_data_q(w_map)
	did_work = manage_destroy_mesh_data_q(w_map)


	// did_work = manage_unload_mesh_data_q(w_map)
	
	chunk_pos:=pos_to_chunck_pos(g.cam.pos)


    fin_pool_tasks(w_map)




    get_w_map_debug_info(w_map)
	if !w_map.stream_chunk_pos_valid ||  chunk_pos != w_map.stream_chunk_pos{
		w_map.stream_chunk_pos = chunk_pos
		w_map.stream_chunk_pos_valid = true
	}else{
		return
	}

	return

// 
}

get_w_map_debug_info::proc(w_map:^Map){
	g.debug_info.gen_chunk_q_len 		= cast(int)chan.len(w_map.gen_chunk_chan)
	g.debug_info.destroy_chunk_q_len 	= cast(int)chan.len(w_map.destroy_chunk_chan)
	g.debug_info.gen_vox_data_q_len 	= cast(int)chan.len(w_map.gen_vox_data_chan)
	g.debug_info.gen_mesh_data_q_len 	= cast(int)chan.len(w_map.gen_mesh_data_chan)
	g.debug_info.destroy_mesh_data_q_len= cast(int)chan.len(w_map.destroy_mesh_data_chan)
	g.debug_info.upload_mesh_data_q_len = cast(int)chan.len(w_map.upload_mesh_data_chan)

	g.debug_info.space_lef_on_gpu_buff  = tg.free_list_space_lef(&w_map.chunks_in_mesh)

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

	for {
		value, ok := chan.try_recv(w_map.gen_chunk_chan)
		if !ok {
			break // More idiomatic than return here
		}
		did_work=true
		do_a_gen_chunk_q(w_map,value)
	}
	return
}
add_to_gen_chunk_q::proc(w_map:^Map,pos:[4]int){
	chan.send(w_map.gen_chunk_chan,Gen_Chunk_Q_Data{pos = pos})
	return
}
do_a_gen_chunk_q::proc(w_map:^Map,q:Gen_Chunk_Q_Data){
	add_chunck(w_map,q.pos)
}
add_chunck::proc(w_map:^Map,pos:[4]int){
	atom.atomic_rw_mutex_guard(&w_map.chunks_map_rw_mutex)
	chunk_hd, chunk_ok := &w_map.chunks_map[pos]
	if !chunk_ok{ // chesvks if there is a chunk in the map if not create one

		w_map.chunks_map[pos] = {}
		chunk_hd = &w_map.chunks_map[pos]
	}else{
		log.log(.Warning, "chunk allredy exsists at pos",pos)
		return
	}
	new_chunk_hd,new_chunk_hd_ok:=hm.add(&w_map.chunks,Chunk{pos = pos})
	if new_chunk_hd_ok != .None{
		log.log(.Error, "add_chunck() failed to add new chunck to chunck handle map")
		return
	}
	chunk_hd^ = new_chunk_hd
	add_to_gen_vox_data_q(w_map,new_chunk_hd,pos)
}

Destroy_Chunk_Q_Data::struct{
	data_hd:Chunk_HD,
}
manage_destroy_chunk_q::proc(w_map:^Map)->(did_work:bool){
	for {
		value, ok := chan.try_recv(w_map.destroy_chunk_chan)
		if !ok {
			break // More idiomatic than return here
		}
		did_work=true
		do_a_destroy_chunk_q(w_map,value)
	}
	return
}
add_to_destroy_chunk_q::proc(w_map:^Map,chunk_hd:Chunk_HD){
	chan.send(w_map.destroy_chunk_chan,Destroy_Chunk_Q_Data{data_hd = chunk_hd})
	return
}
do_a_destroy_chunk_q::proc(w_map:^Map,q:Destroy_Chunk_Q_Data){
	destroy_chunck(w_map,q.data_hd)
}
destroy_chunck::proc(w_map:^Map,hd:Chunk_HD){
	log.log(.Debug,"testing if destroy_chunck working")
	chunk,ok:=hm.get(&w_map.chunks,hd)
	if !ok{
		log.log(.Warning,"cant find chunk",hd,"to destroy")
		return
	}

	add_to_destroy_vox_data_q(w_map, chunk.vox_data_hd)

	// for mesh_hd in chunk.mesh_data{
	// 	mesh_valid:=hm.is_valid(&w_map.chunks_mesh_data, mesh_hd)
	// 	if mesh_valid{
	// 		add_to_destroy_mesh_data_q(w_map, mesh_hd)
	// 	}
	// }
	
	valid:=hm.is_valid(&w_map.gpu_mesh_data_hm,chunk.gpu_mesh_data_hd)
	if valid{
		// add_to_unload_mesh_data_q(w_map,chunk.gpu_mesh_data_hd)
		unload_mesh_data(w_map,chunk.gpu_mesh_data_hd)
	}
	atom.atomic_rw_mutex_lock(&w_map.chunks_map_rw_mutex)
	delete_key(&w_map.chunks_map, chunk.pos)
	atom.atomic_rw_mutex_unlock(&w_map.chunks_map_rw_mutex)
	found,err:=hm.remove(&w_map.chunks,hd)
	if err !=.None{
		log.log(.Error, "failed to remove chunk",err,hd)
		return
	}
	if !found {
		log.log(.Error, "failed to remove chunk cant find",hd)
		return
	}
	
}

Gen_Vox_Data_Q_Data::struct{
	pos:[4]int,
	data_hd:Chunk_HD,
}
manage_gen_vox_data_q::proc(w_map:^Map)->(did_work:bool){
	index:int
	for {
		value, ok := chan.try_recv(w_map.gen_vox_data_chan)
		if !ok {
			break // More idiomatic than return here
		}
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

	gen_chunk_vox_data(w_map,q.data_hd,q.pos,index)
}
gen_chunk_vox_data::proc(w_map:^Map, chunk_hd:Chunk_HD,pos:[4]int,index:int){
	// log.log(.Error,"GEN VOX CALLED chunk=",chunk_hd," pos=",pos)
	chunk, ok := get_chunk(w_map,chunk_hd)
	assert(ok)

	vox_chunk_hd:=make_new_vox_chunk_data(w_map, .u0)
	chunk.vox_data_hd = vox_chunk_hd
	vox_chunk,vox_chunk_ok:=get_vox_chunk_data(w_map,vox_chunk_hd)
	assert(vox_chunk_ok)

	light_chunk_hd:=make_new_light_chunk_data(w_map, .u0)
	chunk.light_data_hd = light_chunk_hd
	light_chunk,light_chunk_ok:=get_light_chunk_data(w_map,light_chunk_hd)
	assert(light_chunk_ok)


	vox_chunk.pos = pos
	chunk.chunk_shader_data.pos = {
		cast(i32)pos.x,
		cast(i32)pos.y,
		cast(i32)pos.z,
		cast(i32)pos.w,
	}

	start_gen_vox_dat_task(w_map,Gen_Vox_Data_Task{w_map = w_map,vox_data_hd=vox_chunk_hd})

	
}




gen_vox_data :: proc(
	w_map:^Map,
	vox_chunk_hd:Vox_Chunk_Data_HD,
	// chunk:^Chunk,
){
	vox_chunk,vox_chunk_ok:=hm.get(&w_map.vox_chunk_hm,vox_chunk_hd)
	assert(vox_chunk_ok)
	pos:=vox_chunk.pos
	vox_chunk.pos = pos
	lod_lev := pos.w


	xz_scl:f64 = 0.001
	y_scl:f64 = 600.0

	world_x_start := pos.x * CHUNK_SIZE
	world_y_start := pos.y * CHUNK_SIZE
	world_z_start := pos.z * CHUNK_SIZE

	
	grass_pal_index := get_or_add_palette_index_by_item_hd(vox_chunk, g.df_items[.grass])
	stone_pal_index := get_or_add_palette_index_by_item_hd(vox_chunk, g.df_items[.stone_slate])

	for x := 0; x < CHUNK_SIZE; x += 1 {
		world_x := world_x_start + x * lod_lev + lod_lev / 2

		for z := 0; z < CHUNK_SIZE; z += 1 {
			world_z := world_z_start + z * lod_lev + lod_lev / 2

			height := nos.noise_2d(
				6223378936854776807,
				{
					cast(f64)world_x * xz_scl,
					cast(f64)world_z * xz_scl,
				},
			)

			height_x := nos.noise_2d(
				6223378936854776807,
				{
					cast(f64)(world_x + lod_lev) * xz_scl,
					cast(f64)world_z * xz_scl,
				},
			)

			height_z := nos.noise_2d(
				6223378936854776807,
				{
					cast(f64)world_x * xz_scl,
					cast(f64)(world_z + lod_lev) * xz_scl,
				},
			)

			change_x := math.abs(height_x - height)
			change_z := math.abs(height_z - height)

			height_change := max(change_x/cast(f32)lod_lev, change_z/cast(f32)lod_lev)
			is_steep := height_change > 0.003

			height = (height + 1.0) * 0.5
			height = math.pow(height, 2.5)

			world_height := cast(int)(height * cast(f32)y_scl)
			solid_height := (world_height - world_y_start) / lod_lev

			if solid_height <= 0 {
				continue
			}

			if solid_height > CHUNK_SIZE {
				solid_height = CHUNK_SIZE
			}

			if is_steep {
				set_blocks_in_chunk_by_col_pal_index(
					vox_chunk,
					stone_pal_index,
					{cast(u8)x, cast(u8)z},
					cast(u8)solid_height,
				)
			} else {
				set_blocks_in_chunk_by_col_pal_index(
					vox_chunk,
					grass_pal_index,
					{cast(u8)x, cast(u8)z},
					cast(u8)solid_height,
				)
			}
		}
	}
	
	// defer add_to_chunk_needs_meshing_q(w_map,pos)
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


check_if_chunk_needs_meshing::proc(w_map:^Map,pos:[4]int){
	chunk_hd,ok:= get_chunk_by_pos_safe(w_map,pos)
	assert(ok)
	chunk_data,chunk_data_ok:=hm.dynamic_get(&w_map.chunks,chunk_hd)
	assert(chunk_data_ok)
	vox_hd:=chunk_data.vox_data_hd
	vox_data,vox_data_ok:=hm.dynamic_get(&w_map.vox_chunk_hm,vox_hd)
	assert(vox_data_ok)
	if atom.atomic_load(&vox_data.vox_gened) == false {return}
	next_side:for side in Model_Sides{
		opposite_side:=side
		key:=pos
		lower_lod_key:[4][4]int={pos,pos,pos,pos,}
		lod_size:= pos.w
		switch side {
		case .pos_x:
			opposite_side = .neg_x
			key += {lod_size,0,0,0}
			lower_lod_key = key
		
			if lod_size > 1 {
				half := lod_size/2
		
				lower_lod_key[0][3] = half
				lower_lod_key[1] = lower_lod_key[0] + {0,half,0,0}
				lower_lod_key[1][3] = half
				lower_lod_key[2] = lower_lod_key[1] + {0,0,half,0}
				lower_lod_key[2][3] = half
				lower_lod_key[3] = lower_lod_key[0] + {0,0,half,0}
				lower_lod_key[3][3] = half
			}
		
		case .neg_x:
			opposite_side = .pos_x
			key += {-lod_size,0,0,0}
			lower_lod_key = key
		
			if lod_size > 1 {
				half := lod_size/2
		
				lower_lod_key[0][3] = half
				lower_lod_key[1] = lower_lod_key[0] + {0,half,0,0}
				lower_lod_key[1][3] = half
				lower_lod_key[2] = lower_lod_key[1] + {0,0,half,0}
				lower_lod_key[2][3] = half
				lower_lod_key[3] = lower_lod_key[0] + {0,0,half,0}
				lower_lod_key[3][3] = half
			}
		
		case .pos_y:
			opposite_side = .neg_y
			key += {0,lod_size,0,0}
			lower_lod_key = key
		
			if lod_size > 1 {
				half := lod_size/2
		
				lower_lod_key[0][3] = half
				lower_lod_key[1] = lower_lod_key[0] + {half,0,0,0}
				lower_lod_key[1][3] = half
				lower_lod_key[2] = lower_lod_key[1] + {0,0,half,0}
				lower_lod_key[2][3] = half
				lower_lod_key[3] = lower_lod_key[0] + {0,0,half,0}
				lower_lod_key[3][3] = half
			}
		
		case .neg_y:
			opposite_side = .pos_y
			key += {0,-lod_size,0,0}
			lower_lod_key = key
		
			if lod_size > 1 {
				half := lod_size/2
		
				lower_lod_key[0][3] = half
				lower_lod_key[1] = lower_lod_key[0] + {half,0,0,0}
				lower_lod_key[1][3] = half
				lower_lod_key[2] = lower_lod_key[1] + {0,0,half,0}
				lower_lod_key[2][3] = half
				lower_lod_key[3] = lower_lod_key[0] + {0,0,half,0}
				lower_lod_key[3][3] = half
			}
		
		case .pos_z:
			opposite_side = .neg_z
			key += {0,0,lod_size,0}
			lower_lod_key = key
		
			if lod_size > 1 {
				half := lod_size/2
		
				lower_lod_key[0][3] = half
				lower_lod_key[1] = lower_lod_key[0] + {half,0,0,0}
				lower_lod_key[1][3] = half
				lower_lod_key[2] = lower_lod_key[1] + {0,half,0,0}
				lower_lod_key[2][3] = half
				lower_lod_key[3] = lower_lod_key[0] + {0,half,0,0}
				lower_lod_key[3][3] = half
			}
		
		case .neg_z:
			opposite_side = .pos_z
			key += {0,0,-lod_size,0}
			lower_lod_key = key
		
			if lod_size > 1 {
				half := lod_size/2
		
				lower_lod_key[0][3] = half
				lower_lod_key[1] = lower_lod_key[0] + {half,0,0,0}
				lower_lod_key[1][3] = half
				lower_lod_key[2] = lower_lod_key[1] + {0,half,0,0}
				lower_lod_key[2][3] = half
				lower_lod_key[3] = lower_lod_key[0] + {0,half,0,0}
				lower_lod_key[3][3] = half
			}
		
		case .extra:
			continue next_side
		}


		has_4_neighbors:bool
		neighbor_chunk_hds:[4]Chunk_HD
		chunk_hd_ok:bool
		neighbor_chunk_ok:bool
		neighbor_chunk_hds[0], neighbor_chunk_ok = get_chunk_by_pos_safe(w_map,key)
		if !neighbor_chunk_ok{
			if lod_size > 1{
				has_4_neighbors = true
				nab_lod_0_ok:bool
				nab_lod_1_ok:bool
				nab_lod_2_ok:bool
				nab_lod_3_ok:bool
				neighbor_chunk_hds[0], nab_lod_0_ok = get_chunk_by_pos_safe(w_map,lower_lod_key[0])
				neighbor_chunk_hds[1], nab_lod_1_ok = get_chunk_by_pos_safe(w_map,lower_lod_key[1])
				neighbor_chunk_hds[2], nab_lod_2_ok = get_chunk_by_pos_safe(w_map,lower_lod_key[2])
				neighbor_chunk_hds[3], nab_lod_3_ok = get_chunk_by_pos_safe(w_map,lower_lod_key[3])
				if !nab_lod_0_ok  {continue next_side}
				if !nab_lod_1_ok  {continue next_side}
				if !nab_lod_2_ok  {continue next_side}
				if !nab_lod_3_ok  {continue next_side}
				
			}else{
				continue next_side
			}
		}

		neighbor_chunks:[4]^Chunk
		if !has_4_neighbors{
			neighbor_chunk_ok:bool
			neighbor_chunks[0],neighbor_chunk_ok=get_chunk(w_map,neighbor_chunk_hds[0])
			if !neighbor_chunk_ok {continue next_side}
		}else{
			for &neighbor_chunk,i in &neighbor_chunks{
				neighbor_chunk_ok:bool
				neighbor_chunk,neighbor_chunk_ok=get_chunk(w_map,neighbor_chunk_hds[i])
				
				if !neighbor_chunk_ok {continue next_side}
				
			}
		}

		neighbor_vox_chunks:[4]^Vox_Chunk_Data
		if  !has_4_neighbors{
			neighbor_vox_data,neighbor_vox_data_ok:=get_vox_chunk_data(w_map,neighbor_chunks[0].vox_data_hd)
			if  !neighbor_vox_data.vox_gened{
				continue next_side
			}
			if !neighbor_vox_data_ok {
				continue next_side
			}
		}else{
			for &neighbor_chunk,i in &neighbor_chunks{
				neighbor_vox_data_ok:bool
				neighbor_vox_chunks[i],neighbor_vox_data_ok=get_vox_chunk_data(w_map,neighbor_chunk.vox_data_hd)
				if !neighbor_vox_chunks[i].vox_gened  {continue next_side}
				if !neighbor_vox_data_ok {continue next_side}
				
			}
		}
		// Mesh the chunk itself
		// if true {return}
		if !has_4_neighbors {
			add_to_gen_mesh_data_q(
			    w_map = w_map,
			    chunk_hd = chunk_hd,
				// neighbor_chunk_hd =	neighbor_chunk_hd,
			    vox_chunk_hd = chunk_data.vox_data_hd,
			    neighbor_vox_chunk_hd = {neighbor_chunks[0].vox_data_hd,neighbor_chunks[0].vox_data_hd,neighbor_chunks[0].vox_data_hd,neighbor_chunks[0].vox_data_hd},
				has_4_neighbors = has_4_neighbors,
			    side = side,
			)

			add_to_gen_mesh_data_q(
				w_map = w_map,
				chunk_hd = neighbor_chunk_hds[0],
				// neighbor_chunk_hd = chunk_hd,
				vox_chunk_hd = neighbor_chunks[0].vox_data_hd,
				neighbor_vox_chunk_hd ={chunk_data.vox_data_hd,chunk_data.vox_data_hd,chunk_data.vox_data_hd,chunk_data.vox_data_hd,},
				has_4_neighbors = has_4_neighbors,
				side = opposite_side,
			)
		// Mesh the neighbor too
		}else if has_4_neighbors{	
			add_to_gen_mesh_data_q(
				w_map = w_map,
				chunk_hd = chunk_hd,
				// neighbor_chunk_hd = chunk_hd,
				vox_chunk_hd = chunk_data.vox_data_hd,
				neighbor_vox_chunk_hd = {neighbor_chunks[0].vox_data_hd,neighbor_chunks[1].vox_data_hd,neighbor_chunks[2].vox_data_hd,neighbor_chunks[3].vox_data_hd},
				has_4_neighbors = has_4_neighbors,
				side = side,
			)
		}
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

	data_hd:Chunk_HD,
	vox_chunk_hd:Vox_Chunk_Data_HD,
	neighbor_vox_chunk_hd:[4]Vox_Chunk_Data_HD,
	has_4_neighbors:bool,
	side:Model_Sides,
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
add_to_gen_mesh_data_q::proc(
	w_map:^Map,
	chunk_hd:Chunk_HD,
	vox_chunk_hd:Vox_Chunk_Data_HD,
	neighbor_vox_chunk_hd:[4]Vox_Chunk_Data_HD,
	has_4_neighbors:bool,
	side:Model_Sides
){
	chunk, chunk_ok:=hm.get(&w_map.chunks,chunk_hd)
	assert(chunk_ok)

	if chunk.mesh_q_state[side] == .in_q {return}
	chunk.mesh_q_state[side] = .in_q
	chan.send(w_map.gen_mesh_data_chan,Gen_Mesh_Data_Q_Data{chunk_hd,vox_chunk_hd,neighbor_vox_chunk_hd,has_4_neighbors,side})
	return
}
do_a_gen_mesh_data_q::proc(w_map:^Map,q:Gen_Mesh_Data_Q_Data){

	mesh_chunk_side(
		w_map = w_map, 
		chunk_hd=q.data_hd, 
		// neighbor_chunk_hd=q.neighbor_data_hd, 
		vox_data_hd=q.vox_chunk_hd, 
		neighbor_vox_hd = q.neighbor_vox_chunk_hd,
		has_4_neighbors= q.has_4_neighbors,
		side = q.side
	)

}

// do_gen_mesh_data_task::proc(task: thread.Task){
// 	vox_data:=cast(^Chunk_Mesh_Data)task.data
// 	w_map:=w_map_thread_data
// 	mesh_chunk_side(w_map,vox_data)
// }


mesh_chunk_side::proc(
	w_map:^Map,
	chunk_hd:Chunk_HD, 
	// neighbor_chunk_hd:Chunk_HD, 
	vox_data_hd:Vox_Chunk_Data_HD, 
	neighbor_vox_hd:[4]Vox_Chunk_Data_HD,
	has_4_neighbors:bool,
	side:Model_Sides
){

	chunk, ok := get_chunk(w_map,chunk_hd)
	if !ok{
		log.log(.Error, "failed invalid chunk_hd(",chunk_hd,")")
		return
	}

	chunk_vox,vox_ok:=get_vox_chunk_data(w_map,vox_data_hd)
	if !vox_ok{log.log(.Warning,"get_vox_chunk_data(w_map,chunk.vox_data_hd)", vox_data_hd);return}

	neighbor_vox,neighbor_vox_ok:=get_vox_chunk_data(w_map,neighbor_vox_hd[0])
	if !neighbor_vox_ok{log.log(.Warning,"get_vox_chunk_data(w_map,neighbor_vox_hd)",neighbor_vox_hd);return}

	// mesh_data,mesh_data_ok:=get_chunk_mesh_data(w_map,chunk.mesh_data[side])
	// if !mesh_data_ok{
		// err:runtime.Allocator_Error
		// chunk.mesh_data[side],err= hm.add(&w_map.chunks_mesh_data,Chunk_Mesh_Data{})
		mesh_data_hd,err:= hm.add(&w_map.chunks_mesh_data,Chunk_Mesh_Data{})
		if err != .None{
			log.log(.Error,"failed to add mesh_hd to chunk.mesh_data[side] err = {",err,"}",mesh_data_hd)
			return
		}
		mesh_data,mesh_data_ok:=get_chunk_mesh_data(w_map,mesh_data_hd,)
		if !mesh_data_ok {
			log.log(.Error,"failed, mesh_hd not valid",mesh_data_hd)
			return
		}
	// }
	start_mesh_chunk_task(w_map,Mesh_Chunk_Task{w_map,chunk_hd,vox_data_hd,neighbor_vox_hd,mesh_data_hd,has_4_neighbors,side})
}

//WARN this one is very slow and is just for debuging
// mesh_by_side_all::proc(
// 	w_map:^Map,
// 	voxls:^Chunk_Vox_Data,
// 	mesh:^Chunk_Mesh_Data,
// 	side:Model_Sides
// )->(face_count:int){
// 	// clear(&mesh.data)
// 	mesh.face_count = 0
// 	for plane, x in voxls.data{
// 		for col, y in plane{
// 			for vox, z in col{
// 				item:=reg.get(&g.item_reg,vox.item_hd)
// 				if item == nil{
// 					//this should be air
// 					// log.log(.Error, "item == nil, invalid item or registry is borked item_hd(", vox.item_hd,")")
// 					continue
// 				}
// 				face:tg.Vert_Face
// 				packed_pos := pack_block_pos({cast(u16)x,cast(u16)y,cast(u16)z})
// 				face.block_pos = packed_pos
// 				face.texture_face_index = cast(u32)item.texture_data.sides[side]
// 				face.geometry_face_index = cast(u16)item.model_data.cube_indices[side]
// 				// append(&mesh.data,face)
// 				mesh.data[face_count] = face
// 				face_count+=1
// 			}
// 		}
// 	}
// 	mesh.face_count = face_count
// 	return face_count
// }

// do_mesh_chunk_side_task::proc(task: thread.Task){

// 	tg.name_thread("mesh_chunk_side_task",task.user_index)
// 	context.logger = tg.create_tg_console_logger(opt = {.Thread_Id,.Level,.Short_File_Path,.Line,.Procedure,.Terminal_Color})
// 	defer tg.destroy_tg_console_logger(context.logger)

// 	vox_data:=cast(^Vox_Chunk_Data)task.data
// 	w_map:=w_map_thread_data
// 	// mesh_by_bit_mask(w_map,vox_data)
// }

mesh_by_bit_mask :: proc(
	w_map: ^Map,
	chunk_hd:Chunk_HD,
	vox_data_hd: Vox_Chunk_Data_HD,
	neighbor_vox_hd: [4]Vox_Chunk_Data_HD,
	mesh_hd: Chunk_Mesh_Data_HD,
	has_4_neighbors:bool,
	side: Model_Sides,
) -> (face_count: int) {

	chunk_vox_data, vox_ok := get_vox_chunk_data(w_map, vox_data_hd)
	if !vox_ok {log.log(.Error, "failed, vox_data_hd not valid", vox_data_hd);return}
	
	neighbor_vox, neighbor_vox_ok := get_vox_chunk_data(w_map, neighbor_vox_hd[0])
	if !neighbor_vox_ok {log.log(.Error, "failed, neighbor_vox_data_hd not valid", neighbor_vox_hd);return}
	mesh,mesh_ok:=hm.get(&w_map.chunks_mesh_data,mesh_hd)
	// if !mesh_ok{
	// 	return
	// }
	assert(mesh_ok)
	
	neighbors_vox:[4]^Vox_Chunk_Data
	if has_4_neighbors{
		for hd,i in neighbor_vox_hd{
			neighbor_vox_4_ok:bool
			neighbors_vox[i] ,neighbor_vox_4_ok = get_vox_chunk_data(w_map, hd)
			if !neighbor_vox_4_ok {log.log(.Error, "failed, neighbor_vox_data_hd not valid", neighbor_vox_hd);return}
		}
	}
	chunk_ab := &chunk_vox_data.backing_chunk_data_abstract
	assert(chunk_ab.pal_count != nil)
	chunk_pal_count := chunk_ab.pal_count^
	assert(chunk_vox_data.backing_mask_data != nil)
	assert(chunk_vox_data.backing_world_data != nil)

	texture_cache: []u32
	geometry_cache: []u16
	switch chunk_ab.palette_size{
	case .u0, .u1, .u2, .u4, .u8:
		t_texture_cache:[255]u32
		t_geometry_cache:[255]u16
		texture_cache  = t_texture_cache[:]
		geometry_cache = t_geometry_cache[:]
	case .u16:
		t_texture_cache:[CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE]u32
		t_geometry_cache:[CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE]u16
		texture_cache  = t_texture_cache[:]
		geometry_cache = t_geometry_cache[:]
	}

	for i in 0..<chunk_pal_count {
		item, ok := reg.get(&g.item_reg, chunk_ab.pal[i].item)
		if ok {
			texture_cache[i] = cast(u32)item.texture_data.sides[side]
			geometry_cache[i] = cast(u16)item.model_data.cube_indices[side]
		}
	}
	mesh.face_count = 0
	chunk_mask, chunk_mask_ok := hm.get(&chunk_vox_data.backing_mask_data.hm,chunk_vox_data.vox_mask_hd,)
	// assert(chunk_mask_ok)
	neighbor_mask, neighbor_mask_ok := hm.get(&neighbor_vox.backing_mask_data.hm,neighbor_vox.vox_mask_hd,)
	// assert(neighbor_mask_ok)
	cur_neighbor_mask:[CHUNK_SIZE * CHUNK_SIZE]u32
	if neighbor_mask != nil{
		cur_neighbor_mask=neighbor_mask.is_opaque_mask
	}


	current_masks: [CHUNK_SIZE * CHUNK_SIZE]u32
	neighbor_masks: [CHUNK_SIZE * CHUNK_SIZE]u32
	
	if has_4_neighbors {
		n_mask_0,n_mask_0_ok := hm.get(&neighbors_vox[0].backing_mask_data.hm,neighbors_vox[0].vox_mask_hd);
		assert(n_mask_0_ok)
		n_mask_1,n_mask_1_ok := hm.get(&neighbors_vox[1].backing_mask_data.hm,neighbors_vox[1].vox_mask_hd)
		assert(n_mask_1_ok)
		n_mask_2,n_mask_2_ok := hm.get(&neighbors_vox[2].backing_mask_data.hm,neighbors_vox[2].vox_mask_hd)
		assert(n_mask_2_ok)
		n_mask_3,n_mask_3_ok := hm.get(&neighbors_vox[3].backing_mask_data.hm,neighbors_vox[3].vox_mask_hd)
		assert(n_mask_3_ok)
	
		masks := [4][CHUNK_SIZE*CHUNK_SIZE]u32{
			n_mask_0.is_opaque_mask,
			n_mask_1.is_opaque_mask,
			n_mask_2.is_opaque_mask,
			n_mask_3.is_opaque_mask,
		}

	
		#partial switch side {
		case .pos_x, .neg_x:
			cur_neighbor_mask = sample_4_neighbor_masks_x(masks,side)
		case .pos_y, .neg_y:
			cur_neighbor_mask = sample_4_neighbor_masks_y(masks,side)
		case .pos_z, .neg_z:
			cur_neighbor_mask = sample_4_neighbor_masks_z(masks,side)
		}

	}
	switch side {
	case .pos_x:
		for i := 0; i < CHUNK_SIZE * CHUNK_SIZE; i += 1 {
			current_masks[i] = chunk_mask.is_occupied_mask[i]

			if i % CHUNK_SIZE == CHUNK_SIZE - 1 {
				neighbor_masks[i] = cur_neighbor_mask[i-CHUNK_SIZE+1]
			} else {
				neighbor_masks[i] = chunk_mask.is_opaque_mask[i+1]
			}
		}

	case .neg_x:
		for i := 0; i < CHUNK_SIZE * CHUNK_SIZE; i += 1 {
			current_masks[i] = chunk_mask.is_occupied_mask[i]

			if i % CHUNK_SIZE == 0 {
				neighbor_masks[i] = cur_neighbor_mask[i+CHUNK_SIZE-1]
			} else {
				neighbor_masks[i] = chunk_mask.is_opaque_mask[i-1]
			}
		}

	case .pos_y:
		for i := 0; i < CHUNK_SIZE * CHUNK_SIZE; i += 1 {
			current_masks[i] = chunk_mask.is_occupied_mask[i]
			neighbor_masks[i] = chunk_mask.is_opaque_mask[i] >> 1

			if neighbor_mask_ok {
				neighbor_masks[i] |= (cur_neighbor_mask[i] & 1) << 31
			} else {
				neighbor_masks[i] |= u32(1) << 31
			}
		}

	case .neg_y:
		for i := 0; i < CHUNK_SIZE * CHUNK_SIZE; i += 1 {
			current_masks[i] = chunk_mask.is_occupied_mask[i]
			neighbor_masks[i] = chunk_mask.is_opaque_mask[i] << 1

			if neighbor_mask_ok {
				neighbor_masks[i] |= cur_neighbor_mask[i] >> 31
			} else {
				neighbor_masks[i] |= 1
			}
		}

	case .pos_z:
		for i := 0; i < CHUNK_SIZE * CHUNK_SIZE; i += 1 {
			current_masks[i] = chunk_mask.is_occupied_mask[i]

			if i >= CHUNK_SIZE * (CHUNK_SIZE-1) {
				neighbor_masks[i] = cur_neighbor_mask[i % CHUNK_SIZE]
			} else {
				neighbor_masks[i] = chunk_mask.is_opaque_mask[i+CHUNK_SIZE]
			}
		}

	case .neg_z:
		for i := 0; i < CHUNK_SIZE * CHUNK_SIZE; i += 1 {
			current_masks[i] = chunk_mask.is_occupied_mask[i]

			if i < CHUNK_SIZE {
				neighbor_masks[i] = cur_neighbor_mask[i + CHUNK_SIZE * (CHUNK_SIZE-1)]
			} else {
				neighbor_masks[i] = chunk_mask.is_opaque_mask[i-CHUNK_SIZE]
			}
		}

	case .extra:
		log.log(.Warning, "ono")
		return
	}

	for index := 0; index < CHUNK_SIZE * CHUNK_SIZE; index += 1 {
		visible_mask := current_masks[index] & ~neighbor_masks[index]

		x := index % CHUNK_SIZE
		z := index / CHUNK_SIZE
		for visible_mask != 0 {
			y := bits.count_trailing_zeros(visible_mask)
			visible_mask &= visible_mask - 1


			vox_index := cast(u16)(cast(u16)y + cast(u16)x * CHUNK_SIZE + cast(u16)z * CHUNK_SIZE * CHUNK_SIZE)

			pal_index := get_palette_index(chunk_vox_data, vox_index)

			face: tg.Vert_Face
			face.block_pos = pack_block_pos({cast(u16)x,cast(u16)y,cast(u16)z,})
			face.texture_face_index = texture_cache[pal_index]
			face.geometry_face_index = geometry_cache[pal_index]

			for corner_id in 0..<4 {

		
				face.light[corner_id] = sample_corner_light(
					&chunk_mask.is_opaque_mask,
					&cur_neighbor_mask,
					side,
					x, cast(int)y, z,
					corner_id,
				)
			}


			mesh.data[face_count] = face
			face_count += 1
		}
	}
	mesh.face_count = face_count
	return face_count
}




transpose_32x32 :: proc(m: ^[32]u32) {
 for k := 0; k < 16; k += 1 {
		a := k
		b := k + 16
		t := (m^[a] ~ (m^[b] >> 16)) & 0x0000FFFF
		m^[a] = m^[a] ~ t
		m^[b] = m^[b] ~ (t << 16)
	}

	for k := 0; k < 16; k += 1 {
		a := (k & 7) + ((k & 8) << 1)
		b := a + 8
		t := (m^[a] ~ (m^[b] >> 8)) & 0x00FF00FF
		m^[a] = m^[a] ~ t
		m^[b] = m^[b] ~ (t << 8)
	}

	for k := 0; k < 16; k += 1 {
		a := (k & 3) + ((k & 12) << 1)
		b := a + 4
		t := (m^[a] ~ (m^[b] >> 4)) & 0x0F0F0F0F
		m^[a] = m^[a] ~ t
		m^[b] = m^[b] ~ (t << 4)
	}

	for k := 0; k < 16; k += 1 {
		a := (k & 1) + ((k & 14) << 1)
		b := a + 2
		t := (m^[a] ~ (m^[b] >> 2)) & 0x33333333
		m^[a] = m^[a] ~ t
		m^[b] = m^[b] ~ (t << 2)
	}

	for k := 0; k < 16; k += 1 {
		a := k << 1
		b := a + 1
		t := (m^[a] ~ (m^[b] >> 1)) & 0x55555555
		m^[a] = m^[a] ~ t
		m^[b] = m^[b] ~ (t << 1)
	}
}
swizzle_mask_x :: proc(src: []u32, dst: []u32) {
	for z := 0; z < CHUNK_SIZE; z += 1 {
		rows: [CHUNK_SIZE]u32
		base := z * CHUNK_SIZE

		for x := 0; x < CHUNK_SIZE; x += 1 {
			rows[x] = src[base + x]
		}

		transpose_32x32(&rows)

		for y := 0; y < CHUNK_SIZE; y += 1 {
			dst[base + (CHUNK_SIZE - 1 - y)] = rows[y]
		}
	}
}

swizzle_mask_z :: proc(src: []u32, dst: []u32) {
	for x := 0; x < CHUNK_SIZE; x += 1 {
		rows: [CHUNK_SIZE]u32

		for z := 0; z < CHUNK_SIZE; z += 1 {
			rows[z] = src[x + z*CHUNK_SIZE]
		}

		transpose_32x32(&rows)

		for y := 0; y < CHUNK_SIZE; y += 1 {
			dst[x + (CHUNK_SIZE - 1 - y)*CHUNK_SIZE] = rows[y]
		}
	}
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
LIGHT_CORNER_POSITIONS :: [6][4][3]int{
	// .pos_x — matches pos0, pos1, pos2, pos3
	{{1, 1, 1},{1, 0, 1},{1, 0, 0},{1, 1, 0},},

	// .neg_x
	{{0, 1, 0},{0, 0, 0},{0, 0, 1},{0, 1, 1},},
	// .pos_y
	{{0, 1, 0},{0, 1, 1},{1, 1, 1},{1, 1, 0},},
	// .neg_y
	{{1, 0, 0},{1, 0, 1},{0, 0, 1},{0, 0, 0},},
	// .pos_z
	{{0, 1, 1},{0, 0, 1},{1, 0, 1},{1, 1, 1},},
	// .neg_z
	{{1, 1, 0},{1, 0, 0},{0, 0, 0},{0, 1, 0},},
}

LIGHT_FACE_NORMALS_r:=LIGHT_FACE_NORMALS
LIGHT_FACE_NORMALS :: [6][3]int{
	{ 1,  0,  0},
	{-1,  0,  0},
	{ 0,  1,  0},
	{ 0, -1,  0},
	{ 0,  0,  1},
	{ 0,  0, -1},
}
LIGHT_FACE_TANGENTS_r:=LIGHT_FACE_TANGENTS
LIGHT_FACE_TANGENTS :: [6][2]int{
	{1, 2},
	{1, 2},
	{0, 2},
	{0, 2},
	{0, 1},
	{0, 1},
}

LIGHT_MAX_PACKED : u32: 0x3fff_ffff

// @(inline)
light_sample_is_opaque :: proc(
	current: ^[CHUNK_SIZE * CHUNK_SIZE]u32,
	across_face: ^[CHUNK_SIZE * CHUNK_SIZE]u32,
	side: Model_Sides,
	sx, sy, sz: int,
) -> bool {
	if sx >= 0 && sx < CHUNK_SIZE &&
	   sy >= 0 && sy < CHUNK_SIZE &&
	   sz >= 0 && sz < CHUNK_SIZE {
		return (current[sx + sz * CHUNK_SIZE] & (u32(1) << u32(sy))) != 0
	}

	// Only handle samples crossing this face's normal boundary.
	switch side {
	case .pos_x:
		if sx != CHUNK_SIZE || sy < 0 || sy >= CHUNK_SIZE ||
		   sz < 0 || sz >= CHUNK_SIZE {
			return false
		}
		return (across_face[sz * CHUNK_SIZE] & (u32(1) << u32(sy))) != 0

	case .neg_x:
		if sx != -1 || sy < 0 || sy >= CHUNK_SIZE ||
		   sz < 0 || sz >= CHUNK_SIZE {
			return false
		}
		return (across_face[CHUNK_SIZE - 1 + sz * CHUNK_SIZE] & (u32(1) << u32(sy))) != 0

	case .pos_y:
		if sy != CHUNK_SIZE || sx < 0 || sx >= CHUNK_SIZE ||
		   sz < 0 || sz >= CHUNK_SIZE {
			return false
		}
		return (across_face[sx + sz * CHUNK_SIZE] & 1) != 0

	case .neg_y:
		if sy != -1 || sx < 0 || sx >= CHUNK_SIZE ||
		   sz < 0 || sz >= CHUNK_SIZE {
			return false
		}
		return (across_face[sx + sz * CHUNK_SIZE] & (u32(1) << 31)) != 0

	case .pos_z:
		if sz != CHUNK_SIZE || sx < 0 || sx >= CHUNK_SIZE ||
		   sy < 0 || sy >= CHUNK_SIZE {
			return false
		}
		return (across_face[sx] & (u32(1) << u32(sy))) != 0

	case .neg_z:
		if sz != -1 || sx < 0 || sx >= CHUNK_SIZE ||
		   sy < 0 || sy >= CHUNK_SIZE {
			return false
		}
		return (across_face[sx + (CHUNK_SIZE - 1) * CHUNK_SIZE] & (u32(1) << u32(sy))) != 0

	case .extra:
		return false
	}

	return false
}

// @(inline)
sample_corner_light :: proc(
	current: ^[CHUNK_SIZE * CHUNK_SIZE]u32,
	across_face: ^[CHUNK_SIZE * CHUNK_SIZE]u32,
	side: Model_Sides,
	x, y, z: int,
	corner_id: int,
) -> u32 {
	if side == .extra {
		return LIGHT_MAX_PACKED
	}

	si := int(side)
	corner := LIGHT_CORNER_POSITIONS_r[si][corner_id]
	normal := LIGHT_FACE_NORMALS_r[si]
	tangents := LIGHT_FACE_TANGENTS_r[si]

	// Start one block outside the face.
	base := [3]int{
		x + normal[0],
		y + normal[1],
		z + normal[2],
	}

	// Sample the four voxels surrounding this face corner.
	sign_a := corner[tangents[0]] * 2 - 1
	sign_b := corner[tangents[1]] * 2 - 1

	a := base
	a[tangents[0]] += sign_a

	b := base
	b[tangents[1]] += sign_b

	ab := base
	ab[tangents[0]] += sign_a
	ab[tangents[1]] += sign_b

	samples := [4][3]int{base, a, b, ab}

	// Temporary lighting: opaque = 0, non-opaque = 31.
	lit_samples := 0
	for p in samples {
		if !light_sample_is_opaque(current, across_face, side, p[0], p[1], p[2]) {
			lit_samples += 1
		}
	}

	// Average the four samples into one 5-bit brightness value.
	v := u32(lit_samples * 31 / 4)

	// Pack RGB sunlight and RGB block light.
	return (v << 25) | (v << 20) | (v << 15) |
	       (v << 10) | (v << 5)  | v
}



Destroy_Mesh_Data_Q_Data::struct{
	mesh_data_hd:Chunk_Mesh_Data_HD,
}
manage_destroy_mesh_data_q::proc(w_map:^Map)->(did_work:bool){
	for {
		value, ok := chan.try_recv(w_map.destroy_mesh_data_chan)
		if !ok {
			break // More idiomatic than return here
		}
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
	if err != .None{
		log.log(.Error,"destroy_mesh_data() err",err,hd)
	}
	
	if !found{
		log.log(.Warning,"cant find mesh data to destroy",hd)
	}
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
		if !ok {
			break // More idiomatic than return here
		}
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
	upload_chunk_side_to_gpu(w_map,q.data_hd,q.mesh_hd,q.side,copy_pass)
}

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
		add_to_destroy_mesh_data_q(w_map,mesh_hd)
		return
	}
	gpu_data,gpu_data_ok:=hm.get(&w_map.gpu_mesh_data_hm,chunk.gpu_mesh_data_hd)
	if !gpu_data_ok{
		// err:runtime.Allocator_Error
		gpu_data_hd,err:=hm.dynamic_add(&w_map.gpu_mesh_data_hm,GPU_Mesh_Data{chunk_shader_data=chunk.chunk_shader_data})
		if err != .None{log.log(.Warning,"bad aloc");return}
		gpu_data,gpu_data_ok=hm.get(&w_map.gpu_mesh_data_hm,gpu_data_hd)
		assert(gpu_data_ok," i do not know how this hapend problobly hm full or somthing stupid like that this hould never triger")
		chunk.gpu_mesh_data_hd = gpu_data_hd
	}else{
		tg.free_list_free(&w_map.chunks_in_mesh,gpu_data.range_in_map_mesh[side])
		// unload_mesh_data(w_map,chunk.gpu_mesh_data_hd)
	}

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
	gpu_data.draw_cmd[side].num_vertices = cast(u32)mesh.face_count * 6
	gpu_data.draw_cmd[side].first_vertex = first_face * 6
	gpu_data.draw_cmd[side].num_instances = 1 
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


Set_Block_CMD::struct{
	chunk_pos:[4]int,
	pos_in_chunk:[3]u8,
	new_block:Block_Palette_Data,
}

manage_set_block_cmd_q::proc(w_map:^Map)->(did_work:bool){
	for {
		value, ok := chan.try_recv(w_map.set_block_chan)
		if !ok {
			break // More idiomatic than return here
		}
		did_work=true
		do_a_set_block_cmd_q(w_map, value)
	}

	return
}
add_to_set_block_cmd_q::proc(w_map:^Map,cmd:Set_Block_CMD){
	chan.send(w_map.set_block_chan, cmd)
	return
}
do_a_set_block_cmd_q::proc(w_map:^Map,q:Set_Block_CMD){
	chunk_hd,chunk_hd_ok:=get_chunk_by_pos_safe(w_map,q.chunk_pos)
	if !chunk_hd_ok {return}
	chunk,chunk_ok:=hm.get(&w_map.chunks,chunk_hd)
	if !chunk_ok {return}
	chunk_vox,chunk_vox_ok:=hm.get(&w_map.vox_chunk_hm,chunk.vox_data_hd)
	if !chunk_vox_ok {return}
	if !chunk_vox.vox_gened{return}
	m_qs:=&chunk.mesh_q_state
	if m_qs[.pos_x]!=.usable{return}
	if m_qs[.neg_x]!=.usable{return}
	if m_qs[.pos_y]!=.usable{return}
	if m_qs[.neg_y]!=.usable{return}
	if m_qs[.pos_z]!=.usable{return}
	if m_qs[.neg_z]!=.usable{return}
	// if m_qs[.extra]!=.usable{return}

	
	p_index:=get_or_add_palette_index(chunk_vox,q.new_block)
	pos_index:=pos_to_vox_index(q.pos_in_chunk)
	set_palette_index(chunk_vox,pos_index,p_index)

	add_to_chunk_needs_meshing_q(w_map,q.chunk_pos)
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

		// did_render_see:=!atom.atomic_load_explicit(&g.w_map.did_work,.Acquire)
		// if did_render_see{
		did_work:=manage_all_w_map_q(&g.w_map)
		if did_work{
			atom.atomic_store_explicit(&g.w_map.did_work, did_work, .Release)
		}
		// }else{
		// }
            time.sleep(1 * time.Millisecond)
	
		
		// if did_work {
  //           // Only signal if work was actually processed
  //           atom.atomic_store_explicit(&g.w_map.atomic_new_data, true, .Release)
  //       } else {
  //           // Yield CPU time so it doesn't spin at 100% when idle
        // }

		// time.sleep(50000000)
	}
}
