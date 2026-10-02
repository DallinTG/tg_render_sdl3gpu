package voxl_game

import "core:testing"
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
import "core:sync"
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
	lod_levels = 14,
	lod_depth = 4,
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

}

// CHUNK_SIZE::32
// MAX_NUM_CHUNKS::1000 * 7
// MAX_FACE_COUNT::MAX_NUM_CHUNKS * CHUNK_MAX_FACE_NUM
// CHUNK_MAX_FACE_NUM:: CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE

// MAX_NUM_OF_MAP_MESH_SECTIONS ::  NUM_OF_FACES_PER_MAP_MESH_SECTIONS * 2 * CHUNK_SIZE * MAX_NUM_CHUNKS
// NUM_OF_FACES_PER_MAP_MESH_SECTIONS :: CHUNK_SIZE * CHUNK_SIZE / 2
// 
CHUNK_SIZE::32
MAX_NUM_CHUNKS::350000 * 7
MAX_FACE_COUNT::MAX_NUM_CHUNKS * CHUNK_MAX_FACE_NUM
CHUNK_MAX_FACE_NUM::  CHUNK_SIZE * CHUNK_SIZE / 2
MAX_NUM_DRAW_CMD_BUF::MAX_NUM_CHUNKS / 8
// MAX_NUM_OF_MAP_MESH_SECTIONS ::  NUM_OF_FACES_PER_MAP_MESH_SECTIONS * 2 * CHUNK_SIZE * MAX_NUM_CHUNKS
// NUM_OF_FACES_PER_MAP_MESH_SECTIONS :: CHUNK_SIZE * CHUNK_SIZE / 2
Map::struct{
	did_work:bool,
	renderer_saw_work:bool,

	stream_chunk_pos: [3]int,
	stream_chunk_pos_valid: bool,
	chunks_map:map[[4]int]Chunk_HD,
	chunks:Chunks_Handle_Map,
	backing_world_vox_data:Backing_Vox_World_Data, 
	vox_chunk_hm:Vox_Chunk_Data_HM,
	vox_mask_hm:Vox_Mask_HM,
	chunks_mesh_data:Chunks_Mesh_Data_Handle_Map,
	gpu_mesh_data_hm:GPU_Mesh_Data_HM,

	draw_cmd_buf_hd:tg.Mesh_Handle,
	map_mesh_hd:tg.Mesh_Handle,
	chunk_shader_data:tg.Indexed_GPU_Data,


	

	chunks_in_mesh:tg.Free_List,

	chunck_transfer_buffer:^sdl.GPUTransferBuffer,

	// Map Qs_____________________________________
	gen_chunk_q:Gen_Chunk_Q,
	destroy_chunk_q:Destroy_Chunk_Q, 

	gen_vox_data_q:Gen_Vox_Data_Q,
	destroy_vox_data_q:Destroy_Vox_Data_Q,
	gen_mesh_data_q:Gen_Mesh_Data_Q,
	destroy_mesh_data_q:Destroy_Mesh_Data_Q,
	upload_mesh_data_q:Upload_Mesh_Data_Q,
	unload_mesh_data_q:Unload_Mesh_Data_Q,
}


Chunks_Handle_Map::hm.Dynamic_Handle_Map(Chunk,Chunk_HD)
Chunk_HD::distinct hm.Handle64
Chunk::struct{
	handle:				Chunk_HD,
	pos:				[4]int,
	vox_data_hd:		Vox_Chunk_Data_HD,
	// offset_in_map_mesh:	[Model_Sides]int,
	// draw_cmd:			[Model_Sides]sdl.GPUIndirectDrawCommand,
	// range_in_map_mesh:	[Model_Sides]tg.Free_List_Range,
	gpu_mesh_data_hd:GPU_Mesh_Data_HD,
	mesh_data:		 [Model_Sides]Chunk_Mesh_Data_HD,
	chunk_shader_data:Chunk_Shader_Data,
	// chunk_shader_data_index:int,
	// is_solid_mask: [CHUNK_SIZE][CHUNK_SIZE]bit_set[u32(0)..<CHUNK_SIZE; u32],//TODO THIS NEEDS TO BE MOVED INTO THE PALET CHUNK ? VOX DATA
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

Chunk_Mesh_Data_Raw::[CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE]tg.Vert_Face

GPU_Mesh_Data_HM::hm.Dynamic_Handle_Map(GPU_Mesh_Data,GPU_Mesh_Data_HD)
GPU_Mesh_Data_HD::distinct hm.Handle64
GPU_Mesh_Data::struct{
	handle:GPU_Mesh_Data_HD,
	chunk_shader_data:Chunk_Shader_Data,
	draw_cmd:			[Model_Sides]sdl.GPUIndirectDrawCommand,
	range_in_map_mesh:	[Model_Sides]tg.Free_List_Range,
	face_count:int
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
	tg.free_list_init(&w_map.chunks_in_mesh,MAX_NUM_CHUNKS)
	w_map.draw_cmd_buf_hd = tg.create_mesh(sdl.GPUIndirectDrawCommand,MAX_NUM_CHUNKS,{},type = .indirect_cmd_buff, debug_name = "w_map GPUIndirectDrawCommand buffer")
	w_map.chunk_shader_data.mesh_hd = tg.create_mesh(Chunk_Shader_Data,MAX_NUM_CHUNKS,{},type = .dynamic_buff, debug_name = "Chunk shader data buffer")
	w_map.map_mesh_hd = tg.create_mesh(tg.Vert_Face,MAX_FACE_COUNT,{},type = .no_tranfer_buff, debug_name = "w_map Chunk buffer mesh")
	w_map.chunck_transfer_buffer = sdl.CreateGPUTransferBuffer(s.gpu_device,{
		usage = .UPLOAD,
		size = cast(u32)(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE * size_of(tg.Vert_Face)),
	})
}

MAX_CHUNKS_TO_Q_AT_ONE_TIME :: 100
// adding_chunks_around_pos::proc(w_map:^Map,pos:[3]f32)->(did_work:bool){

// 	chunk_pos:=pos_to_chunck_pos(pos)
// 	// if !w_map.stream_chunk_pos_valid ||  chunk_pos != w_map.stream_chunk_pos{
	
// 	// }else{
// 	// 	return
// 	// }
// 	xz_rad:=g.settings.xz_render_distance
// 	y_rad:=g.settings.y_render_distance

// 	min_x:=(-1*xz_rad) + chunk_pos.x
// 	max_x:=xz_rad + chunk_pos.x
// 	min_y:=(-1*y_rad) + chunk_pos.y
// 	max_y:=y_rad + chunk_pos.y
// 	min_z:=(-1*xz_rad) + chunk_pos.z
// 	max_z:=xz_rad + chunk_pos.z

// 	q_count:int

// 	for radius:=0; radius<=max(xz_rad,y_rad); radius+=1 {
// 		for x:=-radius; x<=radius; x+=1 {
// 			for y:=-min(radius,y_rad); y<=min(radius,y_rad); y+=1 {
// 				for z:=-radius; z<=radius; z+=1 {
// 					if abs(x)!=radius && abs(y)!=radius && abs(z)!=radius {
// 						continue
// 					}
	
// 					key:[4]int={
// 						chunk_pos.x+x,
// 						chunk_pos.y+y,
// 						chunk_pos.z+z,
// 						1,// this represens the size of the lod
// 					}
	
// 					if ok:=key in w_map.chunks_map; !ok {
// 						add_to_gen_chunk_q(w_map,key)
// 						did_work=true
// 						q_count+=1
	
// 						if q_count>=MAX_CHUNKS_TO_Q_AT_ONE_TIME {
// 							return
// 						}
// 					}
// 				}
// 			}
// 		}
// 	}



// 	return
// }

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
			did_work = true
			// q_count+=1
			// if q_count>=MAX_CHUNKS_TO_Q_AT_ONE_TIME{return}
			// return
		}
	}
	return
}

// adding_chunks_around_pos :: proc(w_map:^Map,pos:[3]f32)->(did_work:bool){
// 	chunk_pos:=pos_to_chunck_pos(pos)

// 	xz_rad:=g.settings.xz_render_distance
// 	y_rad:=g.settings.y_render_distance
// 	lod_depth:=g.settings.lod_depth
// 	lod_levels:=g.settings.lod_levels

// 	q_count:=0
// 	previous_distance:=0
// 	lod:=1


// 	for i_lod in 0..<lod_levels {
// 		lod_lev := 1 << cast(u32)i_lod
// 		log.log(.Debug,lod_lev)
		
		
			
		
	

// 	}


// 	for lod_level:=0; lod_level<lod_levels; lod_level+=1 {

// 		outer_distance:int

// 		if lod==1 {
// 			outer_distance=max(xz_rad,y_rad)
// 		} else {
// 			band_width:=lod_depth*lod
// 			outer_distance=previous_distance+band_width-1
// 		}

// 		for radius:=previous_distance; radius<=outer_distance; radius+=1 {

// 			y_radius:=min(radius,y_rad*lod)

// 			for x:=-radius; x<=radius; x+=1 {

// 				world_x:=chunk_pos.x+x

// 				if lod>1 && world_x%lod!=0 {
// 					continue
// 				}

// 				for y:=-y_radius; y<=y_radius; y+=1 {

// 					world_y:=chunk_pos.y+y

// 					if lod>1 && world_y%lod!=0 {
// 						continue
// 					}

// 					for z:=-radius; z<=radius; z+=1 {

// 						if abs(x)!=radius && abs(y)!=y_radius && abs(z)!=radius {
// 							continue
// 						}

// 						world_z:=chunk_pos.z+z

// 						if lod>1 && world_z%lod!=0 {
// 							continue
// 						}

// 						key:[4]int={
// 							world_x,
// 							world_y,
// 							world_z,
// 							lod,
// 						}

// 						if ok:=key in w_map.chunks_map; !ok {
// 							add_to_gen_chunk_q(w_map,key)
// 							did_work=true

// 							q_count+=1
// 							if q_count>=MAX_CHUNKS_TO_Q_AT_ONE_TIME {
// 								return
// 							}
// 						}
// 					}
// 				}
// 			}
// 		}

// 		previous_distance=outer_distance+1
// 		lod*=2
// 	}

// 	return
// }
	
// adding_chunks_around_pos :: proc(w_map:^Map,pos:[3]f32)->(did_work:bool){
// 	chunk_pos:=pos_to_chunck_pos(pos)

// 	xz_rad:=g.settings.xz_render_distance
// 	y_rad:=g.settings.y_render_distance
// 	lod_depth:=g.settings.lod_depth
// 	lod_levels:=g.settings.lod_levels

// 	q_count:=0
// 	previous_distance:=0
// 	lod:=1


// 	for i_lod in 0..<lod_levels {
// 		lod_lev := 1 << cast(u32)i_lod
// 		log.log(.Debug,lod_lev)
		
		
			
		
	

// 	}

// 	return
// }


// adding_chunks_around_pos :: proc(w_map:^Map,pos:[3]f32)->(did_work:bool){
// 	chunk_pos:=pos_to_chunck_pos(pos)
// 	xz_rad:=g.settings.xz_render_distance
// 	y_rad:=g.settings.y_render_distance
// 	lod_depth:=g.settings.lod_depth

// 	q_count:=0
// 	previous_distance:=0

// 	for i_lod in 0..<g.settings.lod_levels {
// 		lod_lev:=1 << cast(u32)i_lod
// 		band_width:=lod_depth*lod_lev

// 		outer_distance:=max(xz_rad,y_rad)
// 		if lod_lev > 1 {
// 			outer_distance=previous_distance+band_width
// 		}

// 		x_start:=chunk_pos.x-outer_distance
// 		x_start-=x_start%lod_lev
// 		x_start-=chunk_pos.x

// 		y_start:=chunk_pos.y-min(outer_distance,y_rad*lod_lev)
// 		y_start-=y_start%lod_lev
// 		y_start-=chunk_pos.y

// 		z_start:=chunk_pos.z-outer_distance
// 		z_start-=z_start%lod_lev
// 		z_start-=chunk_pos.z

// 		for x:=x_start; x<=outer_distance; x+=lod_lev {
// 			for y:=y_start; y<=min(outer_distance,y_rad*lod_lev); y+=lod_lev {
// 				for z:=z_start; z<=outer_distance; z+=lod_lev {

// 					distance:=max(abs(x),abs(y),abs(z))
// 					if distance < previous_distance || distance > outer_distance-lod_lev {
// 						continue
// 					}

// 					key:[4]int={
// 						chunk_pos.x+x,
// 						chunk_pos.y+y,
// 						chunk_pos.z+z,
// 						lod_lev,
// 					}

// 					if ok:=key in w_map.chunks_map; !ok {
// 						add_to_gen_chunk_q(w_map,key)
// 						did_work=true
// 						q_count+=1
// 						log.log(.Debug,"chunk",key)
// 						if q_count>=MAX_CHUNKS_TO_Q_AT_ONE_TIME {
// 							return
// 						}
// 					}
// 				}
// 			}
// 		}

// 		previous_distance=outer_distance
// 	}

// 	return
// }



// adding_chunks_around_pos :: proc(w_map:^Map,pos:[3]f32)->(did_work:bool){
// 	chunk_pos:=pos_to_chunck_pos(pos)
// 	xz_rad:=g.settings.xz_render_distance
// 	y_rad:=g.settings.y_render_distance
// 	lod_depth:=g.settings.lod_depth

// 	q_count:=0
// 	previous_radius:=0

// 	for i_lod in 0..<g.settings.lod_levels {
// 		lod_lev:=1 << cast(u32)i_lod

// 		outer_radius:=xz_rad
// 		if i_lod > 0 {
// 			outer_radius=previous_radius+lod_depth*lod_lev
// 		}

// 		// Convert the normal-chunk distances into LOD-grid coordinates.
// 		inner_grid:=previous_radius/lod_lev
// 		outer_grid:=outer_radius/lod_lev

// 		y_outer:=min(outer_radius,y_rad*lod_lev)
// 		y_inner:=min(previous_radius,y_rad*lod_lev)

// 		x_min:=chunk_pos.x/lod_lev-outer_grid
// 		x_max:=chunk_pos.x/lod_lev+outer_grid
// 		y_min:=chunk_pos.y/lod_lev-(y_outer/lod_lev)
// 		y_max:=chunk_pos.y/lod_lev+(y_outer/lod_lev)
// 		z_min:=chunk_pos.z/lod_lev-outer_grid
// 		z_max:=chunk_pos.z/lod_lev+outer_grid

// 		for gx:=x_min; gx<=x_max; gx+=1 {
// 			for gy:=y_min; gy<=y_max; gy+=1 {
// 				for gz:=z_min; gz<=z_max; gz+=1 {
// 					x:=gx*lod_lev
// 					y:=gy*lod_lev
// 					z:=gz*lod_lev

// 					distance:=max(
// 						abs(x-chunk_pos.x),
// 						abs(y-chunk_pos.y),
// 						abs(z-chunk_pos.z),
// 					)

// 					if distance < previous_radius || distance >= outer_radius {
// 						continue
// 					}

// 					key:[4]int={x,y,z,lod_lev}

// 				if ok:=key in w_map.chunks_map; !ok {
// 						add_to_gen_chunk_q(w_map,key)
// 						did_work=true
// 						q_count+=1

// 						if q_count>=MAX_CHUNKS_TO_Q_AT_ONE_TIME {
// 							return
// 						}
// 					}
// 				}
// 			}
// 		}

// 		previous_radius=outer_radius
// 	}

// 	return
// }



// adding_chunks_around_pos :: proc(w_map:^Map,pos:[3]f32)->(did_work:bool){
// 	chunk_pos:=pos_to_chunck_pos(pos)
// 	xz_rad:=g.settings.xz_render_distance
// 	y_rad:=g.settings.y_render_distance
// 	lod_depth:=g.settings.lod_depth

// // g.settings.lod_1_scale

// 	lod_1_radius:=cast(int)(f32(xz_rad)*2)
// 	lod_1_radius=((lod_1_radius+lod_depth-1)/lod_depth)*lod_depth

// 	q_count:=0
// 	previous_distance:=0

// 	for i_lod in 0..<g.settings.lod_levels {
// 		lod_lev:=1 << cast(u32)i_lod

// 		band_width:=lod_depth*lod_lev
// 		if i_lod==0 {
// 			band_width=lod_1_radius
// 		}

// 		outer_distance:=previous_distance+band_width
// 		y_outer:=min(outer_distance,y_rad*lod_lev)

// 		x_start:=chunk_pos.x-outer_distance
// 		x_start-=x_start%lod_lev

// 		y_start:=chunk_pos.y-y_outer
// 		y_start-=y_start%lod_lev

// 		z_start:=chunk_pos.z-outer_distance
// 		z_start-=z_start%lod_lev

// 		x_end:=chunk_pos.x+outer_distance
// 		x_end-=x_end%lod_lev

// 		y_end:=chunk_pos.y+y_outer
// 		y_end-=y_end%lod_lev

// 		z_end:=chunk_pos.z+outer_distance
// 		z_end-=z_end%lod_lev

// 		for x:=x_start; x<=x_end; x+=lod_lev {
// 			for y:=y_start; y<=y_end; y+=lod_lev {
// 				for z:=z_start; z<=z_end; z+=lod_lev {
// 					distance:=max(
// 						abs(x-chunk_pos.x),
// 						abs(y-chunk_pos.y),
// 						abs(z-chunk_pos.z),
// 					)

// 					if distance<previous_distance || distance>=outer_distance {
// 						continue
// 					}

// 					key:[4]int={x,y,z,lod_lev}

// 					if ok:=key in w_map.chunks_map; !ok {
// 						add_to_gen_chunk_q(w_map,key)
// 						did_work=true
// 						q_count+=1

// 						if q_count>=MAX_CHUNKS_TO_Q_AT_ONE_TIME {
// 							return
// 						}
// 					}
// 				}
// 			}
// 		}

// 		previous_distance=outer_distance
// 	}

// 	return
// }

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

					if ok := key in w_map.chunks_map ;ok{
						continue
					}

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
// adding_chunks_around_pos :: proc(w_map:^Map,pos:[3]f32)->(did_work:bool){

// 	chunk_pos:=pos_to_chunck_pos(pos)

// 	xz_rad:=g.settings.xz_render_distance
// 	y_rad:=g.settings.y_render_distance
// 	lod_depth:=g.settings.lod_depth
// 	lod_levels:=g.settings.lod_levels

// 	q_count:int
// 	previous_distance:=0
// 	lod:=1

// 	for lod_level:=0; lod_level<lod_levels; lod_level+=1 {

// 		outer_distance:int

// 		if lod==1 {
// 			outer_distance=max(xz_rad,y_rad)
// 		} else {
// 			band_width:=lod_depth*lod
// 			outer_distance=previous_distance+band_width-1
// 		}

// 		for radius:=previous_distance; radius<=outer_distance; radius+=1 {
// 			for x:=-radius; x<=radius; x+=1 {
// 				for y:=-min(radius,y_rad*lod); y<=min(radius,y_rad*lod); y+=1 {
// 					for z:=-radius; z<=radius; z+=1 {

// 						if abs(x)!=radius && abs(y)!=radius && abs(z)!=radius {
// 							continue
// 						}

// 						world_x:=chunk_pos.x+x
// 						world_y:=chunk_pos.y+y
// 						world_z:=chunk_pos.z+z

// 						if lod>1 {
// 							if world_x%lod!=0 ||
// 							   world_y%lod!=0 ||
// 							   world_z%lod!=0 {
// 								continue
// 							}
// 						}

// 						key:[4]int={
// 							world_x,
// 							world_y,
// 							world_z,
// 							lod,
// 						}

// 						if ok:=key in w_map.chunks_map; !ok {
// 							add_to_gen_chunk_q(w_map,key)
// 							did_work=true
// 							q_count+=1
// 							if q_count>=MAX_CHUNKS_TO_Q_AT_ONE_TIME {
// 								return
// 							}
// 						}
// 					}
// 				}
// 			}
// 		}

// 		previous_distance=outer_distance+1
// 		lod*=2
// 	}

// 	return
// }


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



Q_State::enum{
	building,
	usable,
	finished,
}
manage_all_w_map_q::proc(w_map:^Map)->(did_work:bool){



    // did_work = adding_chunks_around_pos(&g.w_map,g.cam.pos)
	did_work = adding_chunks_around_pos(&g.w_map,{0,0,0})
    did_work = removing_chunks_not_around_pos(&g.w_map,g.cam.pos)
    log.log(.Debug,g.cam.pos)


    did_work = manage_gen_chunk_q(w_map)
    did_work = manage_gen_vox_data_q(w_map)
    did_work = manage_gen_mesh_data_q(w_map)


    did_work = manage_upload_mesh_data_q(w_map)


    did_work = manage_destroy_chunk_q(w_map)
    did_work = manage_destroy_vox_data_q(w_map)
    did_work = manage_destroy_mesh_data_q(w_map)


    did_work = manage_unload_mesh_data_q(w_map)

    chunk_pos:=pos_to_chunck_pos(g.cam.pos)

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
	g.debug_info.gen_chunk_q_len 		= cast(int)hm.len(w_map.gen_chunk_q)
	g.debug_info.gen_vox_data_q_len 	= cast(int)hm.len(w_map.gen_vox_data_q)
	g.debug_info.gen_mesh_data_q_len 	= cast(int)hm.len(w_map.gen_mesh_data_q)
	g.debug_info.destroy_mesh_data_q_len= cast(int)hm.len(w_map.destroy_mesh_data_q)
	g.debug_info.upload_mesh_data_q_len = cast(int)hm.len(w_map.upload_mesh_data_q)

	g.debug_info.space_lef_on_gpu_buff  = tg.free_list_space_lef(&w_map.chunks_in_mesh)

	g.debug_info.chunks_map_len			= cast(int)len(w_map.chunks_map)
	g.debug_info.chunks_len				= cast(int)hm.len(w_map.chunks)
	// g.debug_info.chunks_voxel_data_len	= cast(int)hm.len(w_map.chunks_voxel_data)
	g.debug_info.chunks_mesh_data_len	= cast(int)hm.len(w_map.chunks_mesh_data)

	
}

Gen_Chunk_Q::hm.Dynamic_Handle_Map(Gen_Chunk_Q_Data,Gen_Chunk_Q_HD)
Gen_Chunk_Q_HD::distinct hm.Handle64
Gen_Chunk_Q_Data::struct{
	handle:Gen_Chunk_Q_HD,
	pos:[4]int,
	q_state:Q_State,
}
manage_gen_chunk_q::proc(w_map:^Map)->(did_work:bool){

	it := hm.iterator_make(&w_map.gen_chunk_q)
	for q, q_hd in hm.iterate(&it) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .finished {
			hm.remove(&w_map.gen_chunk_q,q_hd)
		}
	}

	it_2 := hm.iterator_make(&w_map.gen_chunk_q)
	for q, q_hd in hm.iterate(&it_2) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .usable {
			did_work=true
			do_a_gen_chunk_q(w_map,q_hd)
		}
	}
	return
}
add_to_gen_chunk_q::proc(w_map:^Map,pos:[4]int)->(q_hd:Gen_Chunk_Q_HD){
	err:runtime.Allocator_Error
	q_hd,err=hm.add(&w_map.gen_chunk_q, Gen_Chunk_Q_Data{pos = pos})
	q,q_ok:=hm.get(&w_map.gen_chunk_q,q_hd)
	if err != .None{
		log.log(.Error, err )
	}
	if !q_ok{
		log.log(.Error, "err",err,"q",q,"q_hd",q_hd )
	}
	assert(q_ok,"failed to ad to q i have know idea how this culd posbly happen what did you do!!!!!!! ")
	atom.atomic_store_explicit(&q.q_state, .usable, .Release)
	return
}
do_a_gen_chunk_q::proc(w_map:^Map,hd:Gen_Chunk_Q_HD){
	q,ok:=hm.get(&w_map.gen_chunk_q,hd)
	if !ok{
		log.log(.Warning, "cant find item in q to destroy")
		atom.atomic_store_explicit(&q.q_state, .finished, .Release)
	}
	if ok{
		add_chunck(w_map,q.pos)
		atom.atomic_store_explicit(&q.q_state, .finished, .Release)
	}
}
add_chunck::proc(w_map:^Map,pos:[4]int){

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
	// gen_chunk_vox_data(w_map,temp_hd,pos)
	
}

Destroy_Chunk_Q::hm.Dynamic_Handle_Map(Destroy_Chunk_Q_Data,Destroy_Chunk_HD)
Destroy_Chunk_HD::distinct hm.Handle64
Destroy_Chunk_Q_Data::struct{
	handle:Destroy_Chunk_HD,
	data_hd:Chunk_HD,
	q_state:Q_State,
}
manage_destroy_chunk_q::proc(w_map:^Map)->(did_work:bool){
	it := hm.iterator_make(&w_map.destroy_chunk_q)
	for q, q_hd in hm.iterate(&it) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .finished {
			hm.remove(&w_map.destroy_chunk_q,q_hd)
		}
	}

	it_2 := hm.iterator_make(&w_map.destroy_chunk_q)
	for q, q_hd in hm.iterate(&it_2) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .usable {
			did_work = true
			do_a_destroy_chunk_q(w_map,q_hd)
		}
	}
	return
}
add_to_destroy_chunk_q::proc(w_map:^Map,chunk_hd:Chunk_HD)->(q_hd:Destroy_Chunk_HD){
	err:runtime.Allocator_Error
	q_hd,err=hm.add(&w_map.destroy_chunk_q, Destroy_Chunk_Q_Data{data_hd = chunk_hd})
	q,q_ok:=hm.get(&w_map.destroy_chunk_q,q_hd)
	if err != .None{
		log.log(.Error, err )
	}
	if !q_ok{
		log.log(.Error, "err",err,"q",q,"q_hd",q_hd )
	}
	assert(q_ok,"failed to ad to q i have know idea how this culd posbly happen what did you do!!!!!!! ")

	atom.atomic_store_explicit(&q.q_state, .usable, .Release)
	return
}
do_a_destroy_chunk_q::proc(w_map:^Map,hd:Destroy_Chunk_HD){
	q,ok:=hm.get(&w_map.destroy_chunk_q,hd)
	if ok{
		destroy_chunck(w_map,q.data_hd)
		atom.atomic_store_explicit(&q.q_state, .finished, .Release)
	}
}
destroy_chunck::proc(w_map:^Map,hd:Chunk_HD){
	chunk,ok:=hm.get(&w_map.chunks,hd)
	if !ok{
		log.log(.Warning,"cant find chunk",hd,"to destroy")
		return
	}

	add_to_destroy_vox_data_q(w_map, chunk.vox_data_hd)

	for mesh_hd in chunk.mesh_data{
		mesh_valid:=hm.is_valid(&w_map.chunks_mesh_data, mesh_hd)
		if mesh_valid{
			add_to_destroy_mesh_data_q(w_map, mesh_hd)
		}
	}
	
	valid:=hm.is_valid(&w_map.gpu_mesh_data_hm,chunk.gpu_mesh_data_hd)
	if valid{
		add_to_unload_mesh_data_q(w_map,chunk.gpu_mesh_data_hd)
	}

	delete_key(&w_map.chunks_map, chunk.pos)
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


Gen_Vox_Data_Q::hm.Dynamic_Handle_Map(Gen_Vox_Data_Q_Data,Gen_Vox_Data_Q_HD)
Gen_Vox_Data_Q_HD::distinct hm.Handle64
Gen_Vox_Data_Q_Data::struct{
	handle:Gen_Vox_Data_Q_HD,
	pos:[4]int,
	data_hd:Chunk_HD,
	q_state:Q_State,
}
manage_gen_vox_data_q::proc(w_map:^Map)->(did_work:bool){

	it := hm.iterator_make(&w_map.gen_vox_data_q)
	for q, q_hd in hm.iterate(&it) {
		// log.log(.Debug,"starting  removing and finish to gen vox data q",q)
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .finished {
			hm.remove(&w_map.gen_vox_data_q,q_hd)
			// log.log(.Debug,"removing and finish to gen vox data q",q)
		}
	}

	it_2 := hm.iterator_make(&w_map.gen_vox_data_q)
	for q, q_hd in hm.iterate(&it_2) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .usable  {
			// log.log(.Debug,"do vox data q")
			do_a_gen_vox_data_q(w_map,q_hd)
			did_work = true
		}
	}
	return
}
add_to_gen_vox_data_q::proc(w_map:^Map,chunk_hd:Chunk_HD,pos:[4]int)->(q_hd:Gen_Vox_Data_Q_HD){
	// log.log(.Debug,"added to gen vox data q")
	err:runtime.Allocator_Error
	q_hd,err=hm.add(&w_map.gen_vox_data_q, Gen_Vox_Data_Q_Data{data_hd = chunk_hd,pos = pos})
	q,q_ok:=hm.get(&w_map.gen_vox_data_q,q_hd)
	if err != .None{
		log.log(.Error, err )
	}
	if !q_ok{
		log.log(.Error, "err",err,"q",q,"q_hd",q_hd )
	}
	assert(q_ok,"failed to ad to q i have know idea how this culd posbly happen what did you do!!!!!!! ")
	atom.atomic_store_explicit(&q.q_state, .usable, .Release)
	return
}
do_a_gen_vox_data_q::proc(w_map:^Map,hd:Gen_Vox_Data_Q_HD){
	q,ok:=hm.get(&w_map.gen_vox_data_q,hd)
	if !ok{
		log.log(.Error,"failed to get",hd)
	}
	if ok{
		gen_chunk_vox_data(w_map,q.data_hd,q.pos)
		atom.atomic_store_explicit(&q.q_state, .finished, .Release)
	}
}
gen_chunk_vox_data::proc(w_map:^Map, chunk_hd:Chunk_HD,pos:[4]int){
	// log.log(.Error,"GEN VOX CALLED chunk=",chunk_hd," pos=",pos)
	chunk, ok := get_chunk(w_map,chunk_hd)
	assert(ok)

	vox_chunk_hd:=make_new_vox_chunk_data(w_map, .u0)
	chunk.vox_data_hd = vox_chunk_hd
	vox_chunk,vox_chunk_ok:=get_vox_chunk_data(w_map,vox_chunk_hd)
	assert(vox_chunk_ok)
	
	gen_vox_data(w_map,vox_chunk,chunk,pos)
	next_side:for side in Model_Sides{
		opposite_side:=side
		key:=pos
		lower_lod_key:[4][4]int={pos,pos,pos,pos,}
		lod_size:= pos.w
	// 	switch side{
	// 	case .pos_x:
	// 		opposite_side = .neg_x
	// 		key += {1*lod_size,0,0,0}
	// 		lower_lod_key = key
	// 		if lod_size > 1{
	// 			lower_lod_key -= {1*(lod_size/2),0,0,(lod_size/2)}
	// 			lower_lod_key[1] += {0,1*(lod_size/2),0,0}
	// 			lower_lod_key[2] += {0,1*(lod_size/2),1*(lod_size/2),0}
	// 			lower_lod_key[3] += {0,0,1*(lod_size/2),0}
	// 		}
	// 	case .neg_x:
	// 		opposite_side = .pos_x
	// 		key += {-1*lod_size,0,0,0}
	// 		lower_lod_key = key
	// 		if lod_size > 1{
	// 			lower_lod_key -= {-1*(lod_size/2),0,0,(lod_size/2)}
	// 			lower_lod_key[1] += {0,1*(lod_size/2),0,0}
	// 			lower_lod_key[2] += {0,1*(lod_size/2),1*(lod_size/2),0}
	// 			lower_lod_key[3] += {0,0,1*(lod_size/2),0}
	// 		}
	// 	case .pos_y:
	// 		opposite_side = .neg_y
	// 		key += {0,1*lod_size,0,0}
	// 		lower_lod_key = key
	// 		if lod_size > 1{
	// 			lower_lod_key -= {0,1*(lod_size/2),0,(lod_size/2)}
	// 			lower_lod_key[1] += {1*(lod_size/2),0,0,0}
	// 			lower_lod_key[2] += {1*(lod_size/2),0,1*(lod_size/2),0}
	// 			lower_lod_key[3] += {0,0,1*(lod_size/2),0}
	// 		}
	// 	case .neg_y:
	// 		opposite_side = .pos_y
	// 		key += {0,-1*lod_size,0,0}
	// 		lower_lod_key = key
	// 		if lod_size > 1{
	// 			lower_lod_key -= {0,-1*(lod_size/2),0,(lod_size/2)}
	// 			lower_lod_key[1] += {1*(lod_size/2),0,0,0}
	// 			lower_lod_key[2] += {1*(lod_size/2),0,1*(lod_size/2),0}
	// 			lower_lod_key[3] += {0,0,1*(lod_size/2),0}
	// 		}
	// 	case .pos_z:
	// 		opposite_side = .neg_z
	// 		key += {0,0,1*lod_size,0}
	// 		lower_lod_key = key
	// 		if lod_size > 1{
	// 			lower_lod_key -= {0,0,1*(lod_size/2),(lod_size/2)}
	// 			lower_lod_key[1] += {1*(lod_size/2),0,0,0}
	// 			lower_lod_key[2] += {1*(lod_size/2),1*(lod_size/2),0,0}
	// 			lower_lod_key[3] += {0,1*(lod_size/2),0,0}
	// 		}
	// 	case .neg_z:
	// 		opposite_side = .pos_z
	// 		key += {0,0,-1*lod_size,0}
	// 		lower_lod_key = key
	// 		if lod_size > 1{
	// 			lower_lod_key -= {0,0,-1*(lod_size/2),(lod_size/2)}
	// 			lower_lod_key[1] += {1*(lod_size/2),0,0,0}
	// 			lower_lod_key[2] += {1*(lod_size/2),1*(lod_size/2),0,0}
	// 			lower_lod_key[3] += {0,1*(lod_size/2),0,0}
	// 		}
	// 	case .extra:
	// 		continue next_side //TODO NOT USING EXTRA Sides yet
	// 	}

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
		neighbor_chunk_hds[0], ok = w_map.chunks_map[key]
		if !ok{
			if lod_size > 1{
				has_4_neighbors = true
				nab_lod_0_ok:bool
				nab_lod_1_ok:bool
				nab_lod_2_ok:bool
				nab_lod_3_ok:bool
				neighbor_chunk_hds[0], nab_lod_0_ok = w_map.chunks_map[lower_lod_key[0]]
				neighbor_chunk_hds[1], nab_lod_1_ok = w_map.chunks_map[lower_lod_key[1]]
				neighbor_chunk_hds[2], nab_lod_2_ok = w_map.chunks_map[lower_lod_key[2]]
				neighbor_chunk_hds[3], nab_lod_3_ok = w_map.chunks_map[lower_lod_key[3]]
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
			if !neighbor_vox_data_ok{
				continue next_side
			}
		}else{
			for &neighbor_chunk,i in &neighbor_chunks{
				neighbor_vox_data_ok:bool
				neighbor_vox_chunks[i],neighbor_vox_data_ok=get_vox_chunk_data(w_map,neighbor_chunk.vox_data_hd)
				if !neighbor_vox_data_ok {continue next_side}
				
			}
		}
		// Mesh the chunk itself
		if !has_4_neighbors {

		add_to_gen_mesh_data_q(
		    w_map = w_map,
		    chunk_hd = chunk_hd,
			// neighbor_chunk_hd =	neighbor_chunk_hd,
		    vox_chunk_hd = chunk.vox_data_hd,
		    neighbor_vox_chunk_hd = {neighbor_chunks[0].vox_data_hd,neighbor_chunks[0].vox_data_hd,neighbor_chunks[0].vox_data_hd,neighbor_chunks[0].vox_data_hd},
			has_4_neighbors = has_4_neighbors,
		    side = side,
		)

		add_to_gen_mesh_data_q(
			w_map = w_map,
			chunk_hd = neighbor_chunk_hds[0],
			// neighbor_chunk_hd = chunk_hd,
			vox_chunk_hd = neighbor_chunks[0].vox_data_hd,
			neighbor_vox_chunk_hd ={chunk.vox_data_hd,chunk.vox_data_hd,chunk.vox_data_hd,chunk.vox_data_hd,},
			has_4_neighbors = has_4_neighbors,
			side = opposite_side,
		)

		// Mesh the neighbor too
// 	
		}else if has_4_neighbors{

			add_to_gen_mesh_data_q(
				w_map = w_map,
				chunk_hd = chunk_hd,
				// neighbor_chunk_hd = chunk_hd,
				vox_chunk_hd = chunk.vox_data_hd,
				neighbor_vox_chunk_hd = {neighbor_chunks[0].vox_data_hd,neighbor_chunks[1].vox_data_hd,neighbor_chunks[2].vox_data_hd,neighbor_chunks[3].vox_data_hd},
				has_4_neighbors = has_4_neighbors,
				side = side,
			)
		}

	}
}

// gen_vox_data :: proc(
// 	w_map:^Map,
// 	vox_chunk:^Vox_Chunk_Data,
// 	chunk:^Chunk,
// 	pos:[4]int,
// ){
// 	vox_chunk.pos = pos
// 	lod_lev:=pos.w

// 	chunk.chunk_shader_data.pos={
// 		cast(i32)pos.x,
// 		cast(i32)pos.y,
// 		cast(i32)pos.z,
// 		cast(i32)pos.w,
// 	}

// 	xz_scl:f64=0.001
// 	y_scl:f64=600.0

// 	world_x_start:=pos.x*CHUNK_SIZE
// 	world_y_start:=pos.y*CHUNK_SIZE
// 	world_z_start:=pos.z*CHUNK_SIZE

// 	grass_pal_index:=get_or_add_palette_index(vox_chunk,g.df_items[.grass])
// 	stone_pal_index:=get_or_add_palette_index(vox_chunk,g.df_items[.stone_slate])
	
// 	for x := 0; x < CHUNK_SIZE; x += 1 {
// 		world_x := world_x_start + x
// 		x_bit := u32(1) << u32(x)
	
// 		for z := 0; z < CHUNK_SIZE; z += 1 {
// 			world_z := world_z_start + z

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
// 					cast(f64)(world_x + 1) * xz_scl,
// 					cast(f64)world_z * xz_scl,
// 				},
// 			)
			
// 			height_z := nos.noise_2d(
// 				6223378936854776807,
// 				{
// 					cast(f64)world_x * xz_scl,
// 					cast(f64)(world_z + 1) * xz_scl,
// 				},
// 			)


			
// 			change_x := math.abs(height_x - height)
// 			change_z := math.abs(height_z - height)
			
// 			height_change := max(change_x, change_z)
// 			is_steep := height_change > 0.003

// 			height = (height + 1.0) * 0.5
// 			height = math.pow(height, 2.5)
	
// 			solid_height := cast(int)(height * cast(f32)y_scl) - world_y_start
	
// 			if solid_height <= 0 {
// 				continue
// 			}
	
// 			if solid_height > CHUNK_SIZE {
// 				solid_height = CHUNK_SIZE
// 			}

// 			if is_steep{
// 				set_blocks_in_chunk_by_col_pal_index(
// 					vox_chunk,
// 					stone_pal_index,
// 					{cast(u8)x,cast(u8)z},
// 					cast(u8)solid_height,
// 				)
// 			}else{
// 				set_blocks_in_chunk_by_col_pal_index(
// 					vox_chunk,
// 					grass_pal_index,
// 					{cast(u8)x,cast(u8)z},
// 					cast(u8)solid_height,
// 				)
// 			}
// 		}
// 	}
// }

gen_vox_data :: proc(
	w_map:^Map,
	vox_chunk:^Vox_Chunk_Data,
	chunk:^Chunk,
	pos:[4]int,
){
	vox_chunk.pos = pos
	lod_lev := pos.w

	chunk.chunk_shader_data.pos = {
		cast(i32)pos.x,
		cast(i32)pos.y,
		cast(i32)pos.z,
		cast(i32)pos.w,
	}

	xz_scl:f64 = 0.001
	y_scl:f64 = 600.0

	world_x_start := pos.x * CHUNK_SIZE
	world_y_start := pos.y * CHUNK_SIZE
	world_z_start := pos.z * CHUNK_SIZE

	grass_pal_index := get_or_add_palette_index(vox_chunk, g.df_items[.grass])
	stone_pal_index := get_or_add_palette_index(vox_chunk, g.df_items[.stone_slate])

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
}

Destroy_Vox_Data_Q::hm.Dynamic_Handle_Map(Destroy_Vox_Data_Q_Data,Destroy_Vox_Data_HD)
Destroy_Vox_Data_HD::distinct hm.Handle64
Destroy_Vox_Data_Q_Data::struct{
	handle:Destroy_Vox_Data_HD,
	data_hd:Vox_Chunk_Data_HD,
	q_state:Q_State,
}
manage_destroy_vox_data_q::proc(w_map:^Map)->(did_work:bool){
	it := hm.iterator_make(&w_map.destroy_vox_data_q)
	for q, q_hd in hm.iterate(&it) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .finished {
			hm.remove(&w_map.destroy_vox_data_q,q_hd)
		}
	}

	it_2 := hm.iterator_make(&w_map.destroy_vox_data_q)
	for q, q_hd in hm.iterate(&it_2) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .usable  {
			do_a_destroy_vox_data_q(w_map,q_hd)
			did_work = true
		}
	}
	return
}
add_to_destroy_vox_data_q::proc(w_map:^Map,vox_data_hd:Vox_Chunk_Data_HD)->(q_hd:Destroy_Vox_Data_HD){
	err:runtime.Allocator_Error
	q_hd,err=hm.add(&w_map.destroy_vox_data_q, Destroy_Vox_Data_Q_Data{data_hd = vox_data_hd})
	q,q_ok:=hm.get(&w_map.destroy_vox_data_q,q_hd)
	if err != .None{
		log.log(.Error, err )
	}
	if !q_ok{
		log.log(.Error, "err",err,"q",q,"q_hd",q_hd )
	}
	assert(q_ok,"failed to ad to q i have know idea how this culd posbly happen what did you do!!!!!!! ")
	atom.atomic_store_explicit(&q.q_state, .usable, .Release)
	return
}
do_a_destroy_vox_data_q::proc(w_map:^Map,hd:Destroy_Vox_Data_HD){
	q,ok:=hm.get(&w_map.destroy_vox_data_q,hd)
	if ok{
		delete_vox_chunk_data(w_map,q.data_hd)
		atom.atomic_store_explicit(&q.q_state, .finished, .Release)
	}
}

Gen_Mesh_Data_Q::hm.Dynamic_Handle_Map(Gen_Mesh_Data_Q_Data,Gen_Mesh_Data_Q_HD)
Gen_Mesh_Data_Q_HD::distinct hm.Handle64
Gen_Mesh_Data_Q_Data::struct{
	handle:Gen_Mesh_Data_Q_HD,
	data_hd:Chunk_HD,
	// neighbor_data_hd:Chunk_HD,
	vox_chunk_hd:Vox_Chunk_Data_HD,
	neighbor_vox_chunk_hd:[4]Vox_Chunk_Data_HD,
	has_4_neighbors:bool,
	side:Model_Sides,
	q_state:Q_State,
}
manage_gen_mesh_data_q::proc(w_map:^Map)->(did_work:bool){

	it := hm.iterator_make(&w_map.gen_mesh_data_q)
	for q, q_hd in hm.iterate(&it) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .finished {
			hm.remove(&w_map.gen_mesh_data_q,q_hd)
		}
	}

	it_2 := hm.iterator_make(&w_map.gen_mesh_data_q)
	for q, q_hd in hm.iterate(&it_2) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .usable {
			did_work = true
			do_a_gen_mesh_data_q(w_map, q_hd)
		}
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
)->(q_hd:Gen_Mesh_Data_Q_HD){
	
	err:runtime.Allocator_Error
	q_hd,err=hm.add(&w_map.gen_mesh_data_q, Gen_Mesh_Data_Q_Data{vox_chunk_hd=vox_chunk_hd, data_hd=chunk_hd, neighbor_vox_chunk_hd=neighbor_vox_chunk_hd,has_4_neighbors=has_4_neighbors,side = side})
	q,q_ok:=hm.get(&w_map.gen_mesh_data_q,q_hd)
	if err != .None{
		log.log(.Error, err )
	}
	if !q_ok{
		log.log(.Error, "err",err,"q",q,"q_hd",q_hd )
	}
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
		mesh_chunk_side(
			w_map = w_map, 
			chunk_hd=q.data_hd, 
			// neighbor_chunk_hd=q.neighbor_data_hd, 
			vox_data_hd=q.vox_chunk_hd, 
			neighbor_vox_hd = q.neighbor_vox_chunk_hd,
			has_4_neighbors= q.has_4_neighbors,
			side = q.side
		)
		atom.atomic_store_explicit(&q.q_state, .finished, .Release)
	}
}

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
	// log.log(.Debug,"starting meshiong2")

	// face_count:=mesh_by_side_all(w_map,chunk_vox,mesh_data,side)
	face_count:=mesh_by_bit_mask(w_map,vox_data_hd,neighbor_vox_hd,mesh_data,has_4_neighbors,side)

	if face_count <= 0 {
		add_to_destroy_mesh_data_q(w_map,chunk.mesh_data[side])
		return
	}
	add_to_upload_mesh_data_q(w_map,chunk_hd,chunk.mesh_data[side],side)
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


mesh_by_bit_mask :: proc(
	w_map: ^Map,
	vox_data_hd: Vox_Chunk_Data_HD,
	neighbor_vox_hd: [4]Vox_Chunk_Data_HD,
	mesh: ^Chunk_Mesh_Data,
	has_4_neighbors:bool,
	side: Model_Sides,
) -> (face_count: int) {

	chunk_vox_data, vox_ok := get_vox_chunk_data(w_map, vox_data_hd)
	if !vox_ok {log.log(.Error, "failed, vox_data_hd not valid", vox_data_hd);return}
	
	neighbor_vox, neighbor_vox_ok := get_vox_chunk_data(w_map, neighbor_vox_hd[0])
	if !neighbor_vox_ok {log.log(.Error, "failed, neighbor_vox_data_hd not valid", neighbor_vox_hd);return}
	
	
	neighbors_vox:[4]^Vox_Chunk_Data
	if has_4_neighbors{
		for hd,i in neighbor_vox_hd{
			neighbor_vox_4_ok:bool
			neighbors_vox[i] ,neighbor_vox_4_ok = get_vox_chunk_data(w_map, hd)
			if !neighbor_vox_4_ok {log.log(.Error, "failed, neighbor_vox_data_hd not valid", neighbor_vox_hd);return}
		}
	}

	chunk_ab := &chunk_vox_data.backing_chunk_data_abstract
	chunk_pal_count := chunk_ab.pal_count^

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
	chunk_mask, chunk_mask_ok := hm.get(chunk_vox_data.backing_mask_data,chunk_vox_data.vox_mask_hd,)
	// assert(chunk_mask_ok)
	neighbor_mask, neighbor_mask_ok := hm.get(neighbor_vox.backing_mask_data,neighbor_vox.vox_mask_hd,)
	// assert(neighbor_mask_ok)
	cur_neighbor_mask:=neighbor_mask.is_opaque_mask

	current_masks: [CHUNK_SIZE * CHUNK_SIZE]u32
	neighbor_masks: [CHUNK_SIZE * CHUNK_SIZE]u32
	
	if has_4_neighbors {
		n_mask_0,_ := hm.get(neighbors_vox[0].backing_mask_data,neighbors_vox[0].vox_mask_hd)
		n_mask_1,_ := hm.get(neighbors_vox[1].backing_mask_data,neighbors_vox[1].vox_mask_hd)
		n_mask_2,_ := hm.get(neighbors_vox[2].backing_mask_data,neighbors_vox[2].vox_mask_hd)
		n_mask_3,_ := hm.get(neighbors_vox[3].backing_mask_data,neighbors_vox[3].vox_mask_hd)
	
		masks := [4][CHUNK_SIZE*CHUNK_SIZE]u32{
			n_mask_0.is_opaque_mask,
			n_mask_1.is_opaque_mask,
			n_mask_2.is_opaque_mask,
			n_mask_3.is_opaque_mask,
		}

	
		#partial switch side {
		case .pos_x, .neg_x, .pos_z, .neg_z:
			cur_neighbor_mask = sample_4_neighbor_masks_xz(masks,side)
		case .pos_y, .neg_y:
			cur_neighbor_mask = sample_4_neighbor_masks_y(masks,side)
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

			mesh.data[face_count] = face
			face_count += 1
		}
	}

	mesh.face_count = face_count
	return face_count
}
sample_4_neighbor_masks_xz :: proc(
	m: [4][CHUNK_SIZE * CHUNK_SIZE]u32,
	side: Model_Sides,
) -> [CHUNK_SIZE * CHUNK_SIZE]u32 {
	out: [CHUNK_SIZE * CHUNK_SIZE]u32

	if side == .pos_x || side == .neg_x {
		src_x := 0
		out_x := 1

		if side == .neg_x {
			src_x = 31
			out_x = 31
		}

		for z := 0; z < 32; z += 1 {
			for y := 0; y < 32; y += 1 {
				fy := (y & 15) << 1
				fz := (z & 15) << 1
				q := (y >> 4) | ((z >> 4) << 1)

				a := (m[q][src_x + fz * 32] >> u32(fy)) & 1
				b := (m[q][src_x + fz * 32] >> u32(fy + 1)) & 1
				c := (m[q][src_x + (fz + 1) * 32] >> u32(fy)) & 1
				d := (m[q][src_x + (fz + 1) * 32] >> u32(fy + 1)) & 1

				if (a & b & c & d) != 0 {
					out[out_x + z * 32] |= u32(1) << u32(y)
				}
			}
		}
	} else {
		src_z := 0
		out_z := 0

		if side == .neg_z {
			src_z = 31
			out_z = 31
		}

		for x := 0; x < 32; x += 1 {
			for y := 0; y < 32; y += 1 {
				fx := (x & 15) << 1
				fy := (y & 15) << 1
				q := (x >> 4) | ((y >> 4) << 1)

				a := (m[q][fx + src_z * 32] >> u32(fy)) & 1
				b := (m[q][fx + 1 + src_z * 32] >> u32(fy)) & 1
				c := (m[q][fx + src_z * 32] >> u32(fy + 1)) & 1
				d := (m[q][fx + 1 + src_z * 32] >> u32(fy + 1)) & 1

				if (a & b & c & d) != 0 {
					out[x + out_z * 32] |= u32(1) << u32(y)
				}
			}
		}
	}

	return out
}

sample_4_neighbor_masks_y :: proc(
	m: [4][CHUNK_SIZE * CHUNK_SIZE]u32,
	side: Model_Sides,
) -> [CHUNK_SIZE * CHUNK_SIZE]u32 {
	out: [CHUNK_SIZE * CHUNK_SIZE]u32

	bit: u32 = 0
	if side == .neg_y {
		bit = 31
	}

	for z := 0; z < 32; z += 1 {
		for x := 0; x < 32; x += 1 {
			fx := (x & 15) << 1
			fz := (z & 15) << 1
			q := (x >> 4) | ((z >> 4) << 1)

			a := (m[q][fx + fz * 32] >> bit) & 1
			b := (m[q][fx + 1 + fz * 32] >> bit) & 1
			c := (m[q][fx + (fz + 1) * 32] >> bit) & 1
			d := (m[q][fx + 1 + (fz + 1) * 32] >> bit) & 1

			if (a & b & c & d) != 0 {
				out[x + z * 32] |= u32(1) << bit
			}
		}
	}

	return out
}

Destroy_Mesh_Data_Q::hm.Dynamic_Handle_Map(Destroy_Mesh_Data_Q_Data,Destroy_Mesh_Data_Q_HD)
Destroy_Mesh_Data_Q_HD::distinct hm.Handle64
Destroy_Mesh_Data_Q_Data::struct{
	handle:Destroy_Mesh_Data_Q_HD,
	mesh_data_hd:Chunk_Mesh_Data_HD,
	q_state:Q_State,
}
manage_destroy_mesh_data_q::proc(w_map:^Map)->(did_work:bool){

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
			did_work = true
		}
	}
	return
}
add_to_destroy_mesh_data_q::proc(w_map:^Map,mesh_data_hd:Chunk_Mesh_Data_HD)->(q_hd:Destroy_Mesh_Data_Q_HD){
	err:runtime.Allocator_Error
	q_hd,err=hm.add(&w_map.destroy_mesh_data_q, Destroy_Mesh_Data_Q_Data{mesh_data_hd = mesh_data_hd})
	q,q_ok:=hm.get(&w_map.destroy_mesh_data_q,q_hd)
	if err != .None{
		log.log(.Error, err )
	}
	if !q_ok{
		log.log(.Error, "err",err,"q",q,"q_hd",q_hd )
	}
	assert(q_ok,"failed to ad to q i have know idea how this culd posbly happen what did you do!!!!!!! ")
	atom.atomic_store_explicit(&q.q_state, .usable, .Release)
	return
}
do_a_destroy_mesh_data_q::proc(w_map:^Map,hd:Destroy_Mesh_Data_Q_HD){
	q,ok:=hm.get(&w_map.destroy_mesh_data_q,hd)
	if !ok{
		log.log(.Warning,hd,q)
	}
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
Upload_Mesh_Data_Q_HD::distinct hm.Handle64
Upload_Mesh_Data_Q_Data::struct{
	handle:Upload_Mesh_Data_Q_HD,
	data_hd:Chunk_HD,
	mesh_hd:Chunk_Mesh_Data_HD, 
	side:Model_Sides,
	q_state:Q_State,
}
manage_upload_mesh_data_q::proc(w_map:^Map)->(did_work:bool){
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
			did_work = true
			do_a_upload_mesh_data_q(w_map, q_hd, copy_pass)
		}
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
)->(q_hd:Upload_Mesh_Data_Q_HD){
	err:runtime.Allocator_Error
	q_hd,err=hm.add(&w_map.upload_mesh_data_q, Upload_Mesh_Data_Q_Data{data_hd=data_hd, mesh_hd=mesh_hd, side=side})
	q,q_ok:=hm.get(&w_map.upload_mesh_data_q,q_hd)
	if err != .None{
		log.log(.Error, err )
	}
	if !q_ok{
		log.log(.Error, "err",err,"q",q,"q_hd",q_hd )
	}
	assert(q_ok,"failed to ad to q i have know idea how this culd posbly happen what did you do!!!!!!! ")
	atom.atomic_store_explicit(&q.q_state, .usable, .Release)
	return
}
do_a_upload_mesh_data_q::proc(w_map:^Map,hd:Upload_Mesh_Data_Q_HD, copy_pass: ^sdl.GPUCopyPass){
	q,ok:=hm.get(&w_map.upload_mesh_data_q,hd)
	if !ok{
		log.log(.Warning,hd,q)
	}
	if ok{
		upload_chunk_side_to_gpu(w_map,q.data_hd,q.mesh_hd,q.side,copy_pass)
		atom.atomic_store_explicit(&q.q_state, .finished, .Release)
	}
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
	}
	// old_range := gpu_data.range_in_map_mesh[side]
	// if old_range.count > 0 {
	// 	add_to_unload_mesh_data_q(w_map,old_range)
	// }
	num_of_gpu_mesh_slots:=cast(u32)math.ceil(cast(f32)mesh.face_count/CHUNK_MAX_FACE_NUM)

	range,ok:=tg.free_list_alloc(&w_map.chunks_in_mesh, num_of_gpu_mesh_slots)
	if !ok{
		log.log(.Error, "failed tg.free_list_alloc(&w_map.chunks_in_mesh) !ok mega mesh problobly full")
		return
	}

	// if chunk.range_in_map_mesh[side].count < 0{
	// 	tg.free_list_free(&w_map.chunks_in_mesh,chunk.range_in_map_mesh[side])
	// }

	gpu_data.range_in_map_mesh[side] = range
	first_face:=cast(u32) range.start * CHUNK_MAX_FACE_NUM

	upload_data_to_mesh_by_offset(w_map.map_mesh_hd,w_map.chunck_transfer_buffer,mesh.data[:mesh.face_count],first_face, copy_pass)
	gpu_data.draw_cmd[side].num_vertices = cast(u32)mesh.face_count*3
	gpu_data.draw_cmd[side].first_vertex = first_face *3
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

Unload_Mesh_Data_Q::hm.Dynamic_Handle_Map(Unload_Mesh_Data_Q_Data,Unload_Mesh_Data_Q_HD)
Unload_Mesh_Data_Q_HD::distinct hm.Handle64
Unload_Mesh_Data_Q_Data::struct{
	handle:Unload_Mesh_Data_Q_HD,
	gpu_mesh_hd:GPU_Mesh_Data_HD,
	// range:tg.Free_List_Range,
	q_state:Q_State,
}
manage_unload_mesh_data_q::proc(w_map:^Map)->(did_work:bool){

	it := hm.iterator_make(&w_map.unload_mesh_data_q)
	for q, q_hd in hm.iterate(&it) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .finished {
			hm.remove(&w_map.unload_mesh_data_q,q_hd)
		}
	}

	it_2 := hm.iterator_make(&w_map.unload_mesh_data_q)
	for q, q_hd in hm.iterate(&it_2) {
		if atom.atomic_load_explicit(&q.q_state,.Acquire) == .usable {
			do_a_unload_mesh_data_q(w_map, q_hd)
			did_work = true
		}
	}
	return
}
add_to_unload_mesh_data_q::proc(w_map:^Map,gpu_mesh_hd:GPU_Mesh_Data_HD)->(q_hd:Unload_Mesh_Data_Q_HD){
	err:runtime.Allocator_Error
	q_hd,err=hm.add(&w_map.unload_mesh_data_q, Unload_Mesh_Data_Q_Data{gpu_mesh_hd=gpu_mesh_hd})
	q,q_ok:=hm.get(&w_map.unload_mesh_data_q,q_hd)
	if err != .None{
		log.log(.Error, err )
	}
	if !q_ok{
		log.log(.Error, "err",err,"q",q,"q_hd",q_hd )
	}
	assert(q_ok,"failed to ad to q i have know idea how this culd posbly happen what did you do!!!!!!! ")
	atom.atomic_store_explicit(&q.q_state, .usable, .Release)
	return
}
do_a_unload_mesh_data_q::proc(w_map:^Map,hd:Unload_Mesh_Data_Q_HD){
	q,ok:=hm.get(&w_map.unload_mesh_data_q,hd)
	if !ok{
		log.log(.Warning,hd,q)
	}
	if ok{
		unload_mesh_data(w_map,q.gpu_mesh_hd)
		atom.atomic_store_explicit(&q.q_state, .finished, .Release)
	}
}
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
