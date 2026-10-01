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
import an"../../ansi"
import lin"core:math/linalg"
import "core:math"
import cl"../../clay-odin"
import st"core:strings"
import steam "../../steamworks"
import reg "../../registry"


CHUNK_VERTEX_TYPE::tg.Vert_Face

render_map_debug_overlay::proc(w_map:^Map){
	// tg.do_render_pass(&g.pass, &g.cam, {w_map.overlay_mesh},)
}

pos_to_chunck_pos::proc(pos:[3]f32)->(chunk_pos:[3]int){	
	chunk_pos.x = cast(int)math.floor(pos.x / CHUNK_SIZE)
	chunk_pos.y = cast(int)math.floor(pos.y / CHUNK_SIZE)
	chunk_pos.z = cast(int)math.floor(pos.z / CHUNK_SIZE)
	return
}


pack_block_pos :: proc(pos: [3]u16) -> u16 {
    assert(pos.x < 32)
    assert(pos.y < 32)
    assert(pos.z < 32)

	return pos.x | (pos.y << 5) | (pos.z << 10)
}

draw_cube_by_face_item::proc(
	mesh: ^tg.Mesh_CPU,
	pos:[3]u16,
	item_hd:Item_HD,
){
	faces:[6]tg.Vert_Face
	item,i_ok:=reg.get(&g.item_reg,item_hd)
	if !i_ok{log.log(.Error,"bad item");return}

	packed_pos := pack_block_pos(pos)

	for &face,i in &faces{
		face.block_pos = packed_pos
		face.texture_face_index = cast(u32)item.texture_data.sides[cast(Model_Sides)i]
	}
	for &face,i in &faces{
		face.geometry_face_index = cast(u16)item.model_data.cube_indices[cast(Model_Sides)i]
	}
	
	tg.draw_feces(mesh,faces[:])
}

get_block_pos_by_ray::proc(w_map:^Map,start_pos:[3]f32,look:tg.Look_Dir,)->(chunk:[3]int,chunk_pos:[3]u8,w_pos:[3]f32,enter_side:Model_Sides){
	look_mat:=lin.matrix3_from_yaw_pitch_roll_f32(
		lin.to_radians(look.yaw),
		lin.to_radians(look.pitch),
		0,
	)

	forward:=look_mat * tg.Vec3{0,0,-1}

	voxel:=[3]int{
		cast(int)math.floor(start_pos.x),
		cast(int)math.floor(start_pos.y),
		cast(int)math.floor(start_pos.z),
	}

	step:[3]int
	t_max:[3]f32
	t_delta:[3]f32

	for axis in 0..<3{
		if forward[axis] > 0 {
			step[axis]=1
			t_max[axis]=(cast(f32)voxel[axis]+1-start_pos[axis])/forward[axis]
			t_delta[axis]=1/forward[axis]
		}else if forward[axis] < 0 {
			step[axis]=-1
			t_max[axis]=(cast(f32)voxel[axis]-start_pos[axis])/forward[axis]
			t_delta[axis]=-1/forward[axis]
		}else{
			step[axis]=0
			t_max[axis]=max(f32)
			t_delta[axis]=max(f32)
		}
	}

	for i:=0;i<1024;i+=1{
		chunk=pos_to_chunck_pos({
			cast(f32)voxel.x,
			cast(f32)voxel.y,
			cast(f32)voxel.z,
		})

		local:=voxel-chunk*CHUNK_SIZE

		chunk_hd,ok:=w_map.chunks_map[{chunk.x,chunk.y,chunk.z,1}]
		if ok{
			chunk_data,chunk_ok:=get_chunk(w_map,chunk_hd)
			if chunk_ok{
				vox_data,vox_ok:=get_vox_chunk_data(w_map,chunk_data.vox_data_hd)
				if vox_ok{
					chunk_pos={
						cast(u8)local.x,
						cast(u8)local.y,
						cast(u8)local.z,
					}

					block:=get_vox_in_chunk(vox_data,chunk_pos)
					item,i_ok:=reg.get(&g.item_reg,block)
					if !i_ok{ return}

					if item != nil{
						w_pos={
							cast(f32)voxel.x,
							cast(f32)voxel.y,
							cast(f32)voxel.z,
						}
						return
					}
				}
			}
		}

		if t_max.x < t_max.y && t_max.x < t_max.z {
			w_pos += forward*t_max.x
			voxel.x += step.x
			t_max.x += t_delta.x

			if step.x > 0 {
				enter_side=.neg_x
			}else{
				enter_side=.pos_x
			}
		}else if t_max.y < t_max.z {
			w_pos += forward*t_max.y
			voxel.y += step.y
			t_max.y += t_delta.y

			if step.y > 0 {
				enter_side=.neg_y
			}else{
				enter_side=.pos_y
			}
		}else{
			w_pos += forward*t_max.z
			voxel.z += step.z
			t_max.z += t_delta.z

			if step.z > 0 {
				enter_side=.neg_z
			}else{
				enter_side=.pos_z
			}
		}
	}
	return
}

get_block_by_ray::proc(w_map:^Map,start_pos:[3]f32,look:tg.Look_Dir,)->(chunk:[3]int,chunk_pos:[3]u8,w_pos:[3]f32,block:Item_HD,enter_side:Model_Sides){
	chunk,chunk_pos,w_pos,enter_side=get_block_pos_by_ray(w_map,start_pos,look)

	chunk_hd,chunk_hd_ok:=w_map.chunks_map[{chunk.x,chunk.y,chunk.z,1}]
	if !chunk_hd_ok {log.log(.Warning,"ray failed bad chunk",chunk_hd);return}

	chunk_data,chunk_data_ok:=get_chunk(w_map,chunk_hd)
	if !chunk_data_ok{log.log(.Warning,"ray failed bad chunk_hd",chunk_hd);return}

	vox_data,vox_data_ok:=get_vox_chunk_data(w_map,chunk_data.vox_data_hd)
	if !vox_data_ok{log.log(.Warning,"ray failed bad vox_data_hd",chunk_data.vox_data_hd);return}

	block=get_vox_in_chunk(vox_data,chunk_pos)
	return
}
