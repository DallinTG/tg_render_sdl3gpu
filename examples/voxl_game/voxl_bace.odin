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


draw_block_by_faces_item::proc(
	mesh:^tg.Mesh_CPU,
	pos:[3]f32,
	item_hd:Item_HD,
	block_state:Block_State={},
	col:[4]f32={1,1,1,.1},
){
	faces:[6]tg.Dynamic_Vert_Face

	item,i_ok:=reg.get(&g.item_reg,item_hd)
	if !i_ok{return}

	model,ok:=reg.get(&g.block_model_reg,item.model)
	if !ok{return}

	model_data:=&g.all_block_models[model.start+cast(int)block_state.state]
	block_pos:=pos+block_offset_from_u16(block_state.offset)

	full_light := (u32(31) << 25) | (u32(31) << 20) | (u32(31) << 15) | (u32(31) << 10) | (u32(31) << 5) | u32(31)

	face_count:=0
	for i in 0..<6 {
		side:=cast(Model_Sides)i
		geometry_index:=model_data.cube_indices[side]
		if geometry_index < 0 {continue}

		face:=&faces[face_count]
		face.light={full_light,full_light,full_light,full_light}
		face.pos.xyz=block_pos
		face.texture_face_index=cast(u32)item.texture_data.sides[side]
		face.col=col
		face.geometry_face_index=cast(u16)geometry_index
		face_count+=1
	}

	if face_count > 0 {
		tg.draw_feces(mesh,faces[:face_count])
	}

	if model_data.extra_count > 0 {
		extra_start:=model_data.cube_indices[.extra]
		extra_face:[1]tg.Dynamic_Vert_Face

		for extra_i in 0..<model_data.extra_count {
			geometry_index:=extra_start+extra_i
			geometry:=g.all_face_data[geometry_index]
			side:=geometry.side

			if side == .extra {continue}

			face:=&extra_face[0]
			face.light={full_light,full_light,full_light,full_light}
			face.pos.xyz=block_pos
			face.texture_face_index=cast(u32)item.texture_data.sides[side]
			face.col=col
			face.geometry_face_index=cast(u16)geometry_index

			tg.draw_feces(mesh,extra_face[:])
		}
	}
}

draw_block_outline::proc(
	mesh:^tg.Mesh_CPU,
	pos:[3]f32,
	item_hd:Item_HD,
	block_state:Block_State={},
	col:[4]f32={1,1,1,1},
){
	item,i_ok:=reg.get(&g.item_reg,item_hd)
	if !i_ok{log.log(.Error,"bad item");return}

	model,ok:=reg.get(&g.block_model_reg,item.model)
	if !ok{return}

	model_data:=&g.all_block_models[model.start+cast(int)block_state.state]
	block_pos:=pos+block_offset_from_u16(block_state.offset)

	tex:=tg.get_texture_by_id(tg.WHITE_TEX_ID)
	shift:f32=.005

	for box in model_data.hit_boxes {
		min_x:=box.box[0]-shift
		min_y:=box.box[1]-shift
		min_z:=box.box[2]-shift
		max_x:=box.box[3]+shift
		max_y:=box.box[4]+shift
		max_z:=box.box[5]+shift

		cube:tg.Cube={
			pos={block_pos.x+min_x,block_pos.y+max_y,block_pos.z+max_z},
			w_h_l={max_x-min_x,max_y-min_y,max_z-min_z},
		}

		tg.draw_cube_outline(mesh,tex,tg.Vertex_Data,col,cube)
	}
}

get_horizontal_model_side_from_look :: proc(look:tg.Look_Dir) -> Model_Sides {
	look_mat := lin.matrix3_from_yaw_pitch_roll_f32(
		lin.to_radians(look.yaw),
		lin.to_radians(look.pitch),
		0,
	)

	forward := look_mat * tg.Vec3{0,0,-1}

	abs_x:=forward.x
	abs_z:=forward.z

	if abs_x < 0 {abs_x = -abs_x}
	if abs_z < 0 {abs_z = -abs_z}

	if abs_x > abs_z {
		if forward.x > 0 {return .pos_x}
		return .neg_x
	}

	if forward.z > 0 {return .pos_z}
	return .neg_z
}

ray_intersect_hit_box :: proc(
	start_pos:[3]f32,
	forward:[3]f32,
	voxel:[3]int,
	box:Hit_Box,
	block_offset:[3]f32,
	t_enter,t_exit:f32,
	enter_side:Model_Sides,
) -> (hit:bool,hit_t:f32,hit_side:Model_Sides) {

	hit_t = t_enter
	far_t := t_exit
	hit_side = enter_side

	for axis in 0..<3 {
		box_min := cast(f32)voxel[axis]+box.box[axis]+block_offset[axis]
		box_max := cast(f32)voxel[axis]+box.box[axis+3]+block_offset[axis]

		origin := start_pos[axis]
		direction := forward[axis]

		if direction > -.0000001 && direction < .0000001 {
			if origin < box_min || origin > box_max {return}
			continue
		}

		t1 := (box_min-origin)/direction
		t2 := (box_max-origin)/direction

		axis_near := min(t1,t2)
		axis_far := max(t1,t2)

		if axis_near > hit_t {
			hit_t = axis_near

			if t1 < t2 {
				switch axis {
				case 0: hit_side = .neg_x
				case 1: hit_side = .neg_y
				case 2: hit_side = .neg_z
				}
			} else {
				switch axis {
				case 0: hit_side = .pos_x
				case 1: hit_side = .pos_y
				case 2: hit_side = .pos_z
				}
			}
		}

		far_t = min(far_t,axis_far)

		if hit_t > far_t {return}
	}

	hit = true
	return
}

get_block_pos_by_ray :: proc(
	w_map: ^Map,
	start_pos: [3]f32,
	look: tg.Look_Dir,
) -> (
	chunk: [3]int,
	chunk_pos: [3]u8,
	w_pos: [3]f32,
	enter_side: Model_Sides,
	hit_box_index: int,
	hit_box: Hit_Box,
	hit_pal_index: u16,
) {

	hit_box_index=-1
	hit_pal_index=0


	look_mat := lin.matrix3_from_yaw_pitch_roll_f32(
		lin.to_radians(look.yaw),
		lin.to_radians(look.pitch),
		0,
	)

	forward := look_mat * tg.Vec3{0,0,-1}

	voxel := [3]int{
		cast(int)math.floor(start_pos.x),
		cast(int)math.floor(start_pos.y),
		cast(int)math.floor(start_pos.z),
	}

	step:[3]int
	t_max:[3]f32
	t_delta:[3]f32

	for axis in 0..<3 {
		if forward[axis] > 0 {
			step[axis] = 1
			t_max[axis] = (cast(f32)voxel[axis]+1.0-start_pos[axis])/forward[axis]
			t_delta[axis] = 1.0/forward[axis]

		} else if forward[axis] < 0 {
			step[axis] = -1
			t_max[axis] = (cast(f32)voxel[axis]-start_pos[axis])/forward[axis]
			t_delta[axis] = -1.0/forward[axis]

		} else {
			step[axis] = 0
			t_max[axis] = max(f32)
			t_delta[axis] = max(f32)
		}
	}

	enter_side = .extra
	w_pos = start_pos
	t_enter:f32 = 0

	for i := 0; i < 1024; i += 1 {
		// Current ray interval inside this voxel.
		t_exit:=min(t_max.x,min(t_max.y,t_max.z))

		best_t:=max(f32)
		best_index:=-1
		best_side:=Model_Sides.extra
		best_box:Hit_Box
		best_pal_index:u16
		best_chunk:[3]int
		best_chunk_pos:[3]u8

		// Check this voxel and all 26 neighboring owner voxels.
		for dz := -1; dz <= 1; dz += 1 {
			for dy := -1; dy <= 1; dy += 1 {
				for dx := -1; dx <= 1; dx += 1 {
					candidate_voxel:=voxel+[3]int{dx,dy,dz}

					candidate_chunk:=pos_to_chunck_pos(cast([3]f32)candidate_voxel)
					candidate_local:=candidate_voxel-candidate_chunk*CHUNK_SIZE

					candidate_pos:=[3]u8{
						cast(u8)candidate_local.x,
						cast(u8)candidate_local.y,
						cast(u8)candidate_local.z,
					}

					candidate_chunk_hd,chunk_ok:=get_chunk_by_pos_safe(
						w_map,
						{candidate_chunk.x,candidate_chunk.y,candidate_chunk.z,1},
					)
					if !chunk_ok {continue}

					candidate_chunk_data,chunk_data_ok:=get_chunk(w_map,candidate_chunk_hd)
					if !chunk_data_ok {continue}

					candidate_vox_data,vox_ok:=get_vox_chunk_data(w_map,candidate_chunk_data.vox_data_hd)
					if !vox_ok {continue}

					root_pal_index:=get_palette_index_by_pos(candidate_vox_data,candidate_pos)
					if root_pal_index == 0 {continue}

					candidate_ab:=&candidate_vox_data.backing_chunk_data_abstract
					current_pal_index:=root_pal_index
					chain_finished:=false

					for _ in 0..<candidate_ab.pal_count^ {
						assert(current_pal_index < candidate_ab.pal_count^,"invalid multiblock chain")

						palette_block:=candidate_ab.pal[current_pal_index]

						item,item_ok:=reg.get(&g.item_reg,palette_block.item)
						if item_ok {
							model,model_ok:=reg.get(&g.block_model_reg,item.model)
							if model_ok {
								model_data:=&g.all_block_models[model.start+cast(int)palette_block.state.state]
								block_offset:=block_offset_from_u16(palette_block.state.offset)

								for box,box_index in model_data.hit_boxes {
									if !box.can_colide {continue}

									hit,hit_t,hit_side:=ray_intersect_hit_box(
										start_pos,
										forward,
										candidate_voxel,
										box,
										block_offset,
										t_enter,
										t_exit,
										enter_side,
									)

									if hit && hit_t < best_t {
										best_t=hit_t
										best_index=box_index
										best_side=hit_side
										best_box=box
										best_pal_index=current_pal_index
										best_chunk=candidate_chunk
										best_chunk_pos=candidate_pos
									}
								}
							}
						}

						next:=palette_block.multy_block_index
						if next == 0 {
							chain_finished=true
							break
						}

						current_pal_index=next
					}

					assert(chain_finished,"cycle detected in raycast multiblock chain")
				}
			}
		}

		// Return the closest hit in the current DDA interval.
		if best_index >= 0 {
			chunk=best_chunk
			chunk_pos=best_chunk_pos
			w_pos=start_pos+forward*best_t
			enter_side=best_side
			hit_box_index=best_index
			hit_box=best_box
			hit_pal_index=best_pal_index
			return
		}

		// Advance to the next voxel.
		if t_max.x < t_max.y && t_max.x < t_max.z {
			t_enter=t_max.x
			voxel.x+=step.x
			t_max.x+=t_delta.x

			if step.x > 0 {
				enter_side=.neg_x
			} else {
				enter_side=.pos_x
			}

		} else if t_max.y < t_max.z {
			t_enter=t_max.y
			voxel.y+=step.y
			t_max.y+=t_delta.y

			if step.y > 0 {
				enter_side=.neg_y
			} else {
				enter_side=.pos_y
			}

		} else {
			t_enter=t_max.z
			voxel.z+=step.z
			t_max.z+=t_delta.z

			if step.z > 0 {
				enter_side=.neg_z
			} else {
				enter_side=.pos_z
			}
		}
	}

	return
}

Block_Ray_Cast_Info :: struct {
	chunk_pos:[3]int,
	pos_in_chunk:[3]u8,
	w_pos:[3]f32,
	look:tg.Look_Dir,
	block:Block_Palette_Data,
	hit_pal_index:u16,
	enter_side:Model_Sides,
	hit_box_index:int,
	hit_box:Hit_Box,
}

get_block_by_ray :: proc(
	w_map: ^Map,
	start_pos: [3]f32,
	look: tg.Look_Dir,
) -> (info:Block_Ray_Cast_Info,ok:bool) {

	chunk_pos,pos_in_chunk,w_pos,enter_side,hit_box_index,hit_box,hit_pal_index:=get_block_pos_by_ray(w_map,start_pos,look)

	if hit_box_index < 0 {return}

	chunk_hd,chunk_hd_ok:=get_chunk_by_pos_safe(w_map,{chunk_pos.x,chunk_pos.y,chunk_pos.z,1})
	if !chunk_hd_ok {return}

	chunk_data,chunk_data_ok:=get_chunk(w_map,chunk_hd)
	if !chunk_data_ok {return}

	vox_data,vox_data_ok:=get_vox_chunk_data(w_map,chunk_data.vox_data_hd)
	if !vox_data_ok {return}

	info.block=get_palette_by_index(vox_data,hit_pal_index)
	info.hit_pal_index=hit_pal_index
	info.chunk_pos=chunk_pos
	info.enter_side=enter_side
	info.pos_in_chunk=pos_in_chunk
	info.w_pos=w_pos
	info.hit_box_index=hit_box_index
	info.hit_box=hit_box
	info.look=look

	ok=true
	return
}
DF_AIR_BLOCK::Block_Palette_Data{
	item = {},
	// is_occupied = false,
	// is_opaque = false,
	// is_solid = false,
}

Stair_Neighbor_Info :: struct {
	is_stair:bool,
	state:Block_State,
}

stair_rotation_to_model_side :: proc(rotation:int)->Model_Sides {
	switch rotation {
	case 0: return .pos_z
	case 1: return .pos_x
	case 2: return .neg_z
	case 3: return .neg_x
	}
	return .pos_z
}

model_side_to_offset :: proc(side:Model_Sides)->[3]int {
	switch side {
	case .pos_x: return {1,0,0}
	case .neg_x: return {-1,0,0}
	case .pos_y: return {0,1,0}
	case .neg_y: return {0,-1,0}
	case .pos_z: return {0,0,1}
	case .neg_z: return {0,0,-1}
	case .extra: return {0,0,0}
	}
	return {}
}

offset_chunk_and_local_pos::proc(
	chunk_pos:[3]int,
	pos_in_chunk:[3]u8,
	offset:[3]int,
)->(new_chunk_pos:[3]int,new_pos_in_chunk:[3]u8){
	new_chunk_pos=chunk_pos
	local_pos:=cast([3]int)pos_in_chunk+offset

	if local_pos.x < 0 {
		local_pos.x+=CHUNK_SIZE
		new_chunk_pos.x-=1
	} else if local_pos.x >= CHUNK_SIZE {
		local_pos.x-=CHUNK_SIZE
		new_chunk_pos.x+=1
	}

	if local_pos.y < 0 {
		local_pos.y+=CHUNK_SIZE
		new_chunk_pos.y-=1
	} else if local_pos.y >= CHUNK_SIZE {
		local_pos.y-=CHUNK_SIZE
		new_chunk_pos.y+=1
	}

	if local_pos.z < 0 {
		local_pos.z+=CHUNK_SIZE
		new_chunk_pos.z-=1
	} else if local_pos.z >= CHUNK_SIZE {
		local_pos.z-=CHUNK_SIZE
		new_chunk_pos.z+=1
	}

	new_pos_in_chunk=cast([3]u8)local_pos
	return
}

get_vox_chunk_at_placement_offset::proc(
	w_map:^Map,
	chunk_pos:[3]int,
	pos_in_chunk:[3]u8,
	offset:[3]int,
)->(vox_data:^Vox_Chunk_Data,neighbor_pos:[3]u8,ok:bool){
	neighbor_chunk_pos:[3]int
	neighbor_chunk_pos,neighbor_pos=offset_chunk_and_local_pos(chunk_pos,pos_in_chunk,offset)

	chunk_hd,chunk_ok:=get_chunk_by_pos_safe(w_map,{neighbor_chunk_pos.x,neighbor_chunk_pos.y,neighbor_chunk_pos.z,1})
	if !chunk_ok {return}

	chunk_data,chunk_data_ok:=get_chunk(w_map,chunk_hd)
	if !chunk_data_ok {return}

	vox_data,ok=get_vox_chunk_data(w_map,chunk_data.vox_data_hd)
	return
}

stair_neighbor_matches :: proc(neighbor:Stair_Neighbor_Info,facing:Model_Sides,upside_down:bool)->bool {
	if !neighbor.is_stair {return false}
	if (neighbor.state.state >= 20) != upside_down {return false}

	neighbor_facing:=stair_rotation_to_model_side(int(neighbor.state.state%20)/5)
	return neighbor_facing == facing
}


get_stair_shape_from_neighbors :: proc(
	w_map:^Map,
	chunk_pos:[3]int,
	pos_in_chunk:[3]u8,
	facing:Model_Sides,
	upside_down:bool,
)->Stair_Shape {
	left_facing:=stair_rotation_to_model_side((cast(int)model_side_to_xz_rotation(facing).state+1)%4)
	right_facing:=OPPOSITE_MODEL_SIDE_r[left_facing]

	outer_left:=false
	outer_right:=false
	inner_left:=false
	inner_right:=false

	// Inner corners.
	front:=get_stair_neighbor_info(w_map,chunk_pos,pos_in_chunk,model_side_to_offset(facing))

	if front.is_stair && (front.state.state >= 20) == upside_down {
		front_facing:=stair_rotation_to_model_side(int(front.state.state%20)/5)

		if front_facing == left_facing {
			blocker:=get_stair_neighbor_info(w_map,chunk_pos,pos_in_chunk,model_side_to_offset(OPPOSITE_MODEL_SIDE_r[front_facing]))
			inner_left=!stair_neighbor_matches(blocker,facing,upside_down)
		} else if front_facing == right_facing {
			blocker:=get_stair_neighbor_info(w_map,chunk_pos,pos_in_chunk,model_side_to_offset(OPPOSITE_MODEL_SIDE_r[front_facing]))
			inner_right=!stair_neighbor_matches(blocker,facing,upside_down)
		}
	}

	// Outer corners.
	back:=get_stair_neighbor_info(w_map,chunk_pos,pos_in_chunk,model_side_to_offset(OPPOSITE_MODEL_SIDE_r[facing]))

	if back.is_stair && (back.state.state >= 20) == upside_down {
		back_facing:=stair_rotation_to_model_side(int(back.state.state%20)/5)

		if back_facing == left_facing {
			blocker:=get_stair_neighbor_info(w_map,chunk_pos,pos_in_chunk,model_side_to_offset(back_facing))
			outer_left=!stair_neighbor_matches(blocker,facing,upside_down)
		} else if back_facing == right_facing {
			blocker:=get_stair_neighbor_info(w_map,chunk_pos,pos_in_chunk,model_side_to_offset(back_facing))
			outer_right=!stair_neighbor_matches(blocker,facing,upside_down)
		}
	}

	// Outer corners take priority over inner corners.
	if outer_left {return .outer_left}
	if outer_right {return .outer_right}
	if inner_left {return .inner_left}
	if inner_right {return .inner_right}

	return .straight
}


get_stair_neighbor_info :: proc(
	w_map:^Map,
	chunk_pos:[3]int,
	pos_in_chunk:[3]u8,
	offset:[3]int,
)->Stair_Neighbor_Info {
	block:=get_block_at_placement_offset(w_map,chunk_pos,pos_in_chunk,offset)
	item,item_ok:=reg.get(&g.item_reg,block.item)
	if !item_ok {return {}}
	if !item.is_occupied {return {}}


	mod,mod_ok:=reg.get(&g.block_model_reg,item.model)
	if !mod_ok || mod.type != .Stair_State {return {}}

	return {is_stair=true,state=block.state}
}



get_block_at_placement_offset :: proc(
	w_map:^Map,
	chunk_pos:[3]int,
	pos_in_chunk:[3]u8,
	offset:[3]int,
)->Block_Palette_Data {
	vox_data,neighbor_pos,ok:=get_vox_chunk_at_placement_offset(w_map,chunk_pos,pos_in_chunk,offset)
	if !ok {return {}}

	return get_vox_in_chunk(vox_data,neighbor_pos)
}

Block_Placement_Info :: struct {
	chunk_pos:[3]int,
	pos_in_chunk:[3]u8,
	world_pos:[3]f32,
	state:Block_State,
	is_occupied:bool,
	is_opaque:bool,
	is_solid:bool,
	item:Item_HD,
}

get_block_placement_info :: proc(
	w_map:^Map,
	ray_i:Block_Ray_Cast_Info,
	item_hd:Item_HD,
	model_variant:int=0,
	align_to_hitbox:bool=false,
)->(info:Block_Placement_Info,ok:bool) {
	ray:=ray_i
	b,b_ok:=reg.get(&g.item_reg,item_hd)
	if !b_ok {return}

	if ray.enter_side == .extra {return}
	offset:=model_side_to_offset(ray.enter_side)
	temp_chunk_pos,temp_pos_in_chunk:=offset_chunk_and_local_pos(ray.chunk_pos,ray.pos_in_chunk,offset)

	mod,mod_ok:=reg.get(&g.block_model_reg,b.model)
	if !mod_ok {return}

	facing:=OPPOSITE_MODEL_SIDE_r[get_horizontal_model_side_from_look(ray.look)]
	facing_3d:=OPPOSITE_MODEL_SIDE_r[get_model_side_from_look(ray.look)]

	hit_y:=ray.w_pos.y-math.floor(ray.w_pos.y)
	upside_down:=hit_y >= .5

	#partial switch ray.enter_side {
	case .pos_y:
		upside_down=false
	case .neg_y:
		upside_down=true
	}

	state:Block_State={}

	switch mod.type {
	case .Bace_Block_State:
		state={}

	case .Rot_XZ_Block_State:
		state=model_side_to_xz_rotation(facing)

	case .Rot_XYZ_Block_State:
		state.state=model_side_to_xyz_variant(facing_3d)

	case .Rot_XYZR_Block_State:
		state.state=model_side_to_xyz_variant(facing_3d)*4+cast(u32)positive_mod_int(model_variant,4)

	case .Rot_XYZRM_Block_State:
		state.state=model_side_to_xyz_variant(facing_3d)*8+cast(u32)positive_mod_int(model_variant,8)

	case .Slab_States:
		if upside_down {
			state.state=1
		}

	case .Stair_State:
		rotation:=model_side_to_xz_rotation(facing)
		shape:=get_stair_shape_from_neighbors(w_map,temp_chunk_pos,temp_pos_in_chunk,facing,upside_down)
		state.state=rotation.state*5+cast(u32)(shape)
		if upside_down {
			state.state+=20
		}
	}

	model_index:=mod.start+cast(int)state.state
	if model_index < mod.start || model_index >= mod.end || model_index >= len(g.all_block_models) {return}

	world_pos:=cast([3]f32)temp_chunk_pos*CHUNK_SIZE+cast([3]f32)temp_pos_in_chunk

	if align_to_hitbox {
		voxel_pos,hitbox_offset,offset_ok:=get_hitbox_placement(&g.all_block_models[model_index],ray.enter_side,ray.w_pos)
		if offset_ok {
			temp_chunk_pos=pos_to_chunck_pos(cast([3]f32)voxel_pos)
			temp_pos_in_chunk=cast([3]u8)(voxel_pos-temp_chunk_pos*CHUNK_SIZE)
			world_pos=cast([3]f32)voxel_pos
			state.offset=hitbox_offset
		}
	}

	info.chunk_pos=temp_chunk_pos
	info.pos_in_chunk=temp_pos_in_chunk
	info.world_pos=world_pos
	info.state=state
	info.is_occupied=b.is_occupied
	info.is_opaque=b.is_opaque
	info.is_solid=b.is_solid
	info.item=b.handle

	return info,true
}

// get_hitbox_placement_offset :: proc(
// 	model_data:^Model_Data,
// 	placement_side:Model_Sides,
// 	block_origin:[3]f32,
// 	hit_pos:[3]f32,
// ) -> (offset:u16,ok:bool) {

// 	axis:int
// 	positive:=false

// 	switch placement_side {
// 	case .pos_x:
// 		axis=0
// 		positive=true
// 	case .neg_x:
// 		axis=0
// 	case .pos_y:
// 		axis=1
// 		positive=true
// 	case .neg_y:
// 		axis=1
// 	case .pos_z:
// 		axis=2
// 		positive=true
// 	case .neg_z:
// 		axis=2
// 	case .extra:
// 		return
// 	}

// 	bounds_min:[3]f32 = {max(f32),max(f32),max(f32)}
// 	bounds_max:[3]f32 = {min(f32),min(f32),min(f32)}
// 	found:=false

// 	for hit_box in model_data.hit_boxes {
// 		if !hit_box.can_colide {continue}

// 		for i in 0..<3 {
// 			bounds_min[i]=min(bounds_min[i],hit_box.box[i])
// 			bounds_max[i]=max(bounds_max[i],hit_box.box[i+3])
// 		}

// 		found=true
// 	}

// 	if !found {return}

// 	offset_data:[3]f32

// 	for i in 0..<3 {
// 		if i == axis {
// 			contact_face:=bounds_max[i]
// 			if positive {
// 				contact_face=bounds_min[i]
// 			}

// 			offset_data[i]=hit_pos[i]-block_origin[i]-contact_face
// 		} else {
// 			hitbox_center:=(bounds_min[i]+bounds_max[i])*0.5
// 			offset_data[i]=hit_pos[i]-block_origin[i]-hitbox_center
// 		}

// 		if math.abs(offset_data[i]) > 15.0/16.0 {return}
// 	}

// 	offset=block_offset_to_u16(offset_data)
// 	ok=true
// 	return
// }

get_hitbox_placement :: proc(
	model_data:^Model_Data,
	placement_side:Model_Sides,
	hit_pos:[3]f32,
) -> (voxel_pos:[3]int,offset:u16,ok:bool) {

	axis:int
	positive:=false

	switch placement_side {
	case .pos_x:
		axis=0
		positive=true
	case .neg_x:
		axis=0
	case .pos_y:
		axis=1
		positive=true
	case .neg_y:
		axis=1
	case .pos_z:
		axis=2
		positive=true
	case .neg_z:
		axis=2
	case .extra:
		return
	}

	bounds_min:[3]f32 = {max(f32),max(f32),max(f32)}
	bounds_max:[3]f32 = {min(f32),min(f32),min(f32)}
	found:=false

	for hit_box in model_data.hit_boxes {
		if !hit_box.can_colide {continue}

		for i in 0..<3 {
			bounds_min[i]=min(bounds_min[i],hit_box.box[i])
			bounds_max[i]=max(bounds_max[i],hit_box.box[i+3])
		}

		found=true
	}

	if !found {return}

	desired_origin:[3]f32

	for i in 0..<3 {
		if i == axis {
			contact_face:=bounds_max[i]
			if positive {
				contact_face=bounds_min[i]
			}
			desired_origin[i]=hit_pos[i]-contact_face
		} else {
			center:=(bounds_min[i]+bounds_max[i])*0.5
			desired_origin[i]=hit_pos[i]-center
		}

		voxel_pos[i]=cast(int)math.floor(desired_origin[i]+0.5)
	}

	offset_data:=desired_origin-cast([3]f32)voxel_pos

	if math.abs(offset_data.x) > 15.0/16.0 || math.abs(offset_data.y) > 15.0/16.0 || math.abs(offset_data.z) > 15.0/16.0 {
		return
	}

	offset=block_offset_to_u16(offset_data)
	ok=true
	return
}

brake_block_by_ray::proc(w_map:^Map,ray_i:Block_Ray_Cast_Info){
	add_to_set_block_cmd_q(w_map,Set_Block_CMD{
		chunk_pos={ray_i.chunk_pos.x,ray_i.chunk_pos.y,ray_i.chunk_pos.z,1},
		pos_in_chunk=ray_i.pos_in_chunk,
		action=.destroy_from,
		target_pal_index=ray_i.hit_pal_index,
	})
}



get_model_side_from_direction :: proc(dir:[3]f32) -> Model_Sides {
	abs_x:=dir.x
	abs_y:=dir.y
	abs_z:=dir.z

	if abs_x < 0 {abs_x = -abs_x}
	if abs_y < 0 {abs_y = -abs_y}
	if abs_z < 0 {abs_z = -abs_z}

	if abs_x >= abs_y && abs_x >= abs_z {
		if dir.x >= 0 {return .pos_x}
		return .neg_x
	}

	if abs_y >= abs_z {
		if dir.y >= 0 {return .pos_y}
		return .neg_y
	}

	if dir.z >= 0 {return .pos_z}
	return .neg_z
}

get_model_side_from_look :: proc(look:tg.Look_Dir) -> Model_Sides {
	look_mat := lin.matrix3_from_yaw_pitch_roll_f32(
		lin.to_radians(look.yaw),
		lin.to_radians(look.pitch),
		0,
	)

	forward := look_mat * tg.Vec3{0,0,-1}

	return get_model_side_from_direction({forward.x,forward.y,forward.z})
}

set_block_by_ray :: proc(w_map:^Map,ray_i:Block_Ray_Cast_Info,model_variant:int=0,align_to_hitbox:bool=true) {
	info,ok:=get_block_placement_info(w_map,ray_i,g.temp_using_item_hd,model_variant,align_to_hitbox)
	if !ok {return}

	add_to_set_block_cmd_q(w_map,Set_Block_CMD{
		chunk_pos={info.chunk_pos.x,info.chunk_pos.y,info.chunk_pos.z,1},
		pos_in_chunk=info.pos_in_chunk,
		action=.append_child,
		new_block={
			item=info.item,
			state=info.state,
		},
	})
}


OPPOSITE_MODEL_SIDE_r:=OPPOSITE_MODEL_SIDE
OPPOSITE_MODEL_SIDE:[Model_Sides]Model_Sides:{
	.pos_x = .neg_x,
	.neg_x = .pos_x,
	.pos_y = .neg_y,
	.neg_y = .pos_y,
	.pos_z = .neg_z,
	.neg_z = .pos_z,
	.extra = .extra,
}

model_side_to_xz_rotation :: proc(side:Model_Sides) -> (state:Block_State) {
	#partial switch side {
	case .pos_z:
		state.state = 0
		return 
	case .pos_x:
		state.state = 1
		return 
	case .neg_z:
		state.state = 2
		return 
	case .neg_x:
		state.state = 3
		return 
	}
	state.state = 0
	return 
}

model_side_to_xyz_variant :: proc(side:Model_Sides)->(variant:u32) {
	switch side {
	case .pos_x: variant=0
	case .neg_x: variant=1
	case .pos_y: variant=2
	case .neg_y: variant=3
	case .pos_z: variant=4
	case .neg_z: variant=5
	case .extra: return 0
	}
	return variant
}


draw_block_hylight::proc(w_map:^Map,w_pos:[3]f32,item_hd:Item_HD,block_state:Block_State={},){
	mesh:=tg.get_mesh(w_map.dynamic_map_mesh_hd)
	draw_block_by_faces_item(&mesh.cpu, w_pos, item_hd, block_state = block_state)
}

draw_ghost_block_at :: proc(
	w_map:^Map,
	w_pos:[3]f32,
	item_hd:Item_HD,
	state:Block_State={},
	draw_outline:bool=false,
	col:[4]f32={1,1,1,.3},
	out_line_col:[4]f32={1,1,1,.1},
) {
	mesh:=tg.get_mesh(w_map.dynamic_map_mesh_hd)
	draw_block_by_faces_item(&mesh.cpu,w_pos,item_hd,block_state=state,col=col)

	if draw_outline {
		draw_mesh:=tg.get_mesh(w_map.drawing_map_mesh_hd)
		draw_block_outline(&draw_mesh.cpu,w_pos,item_hd,block_state=state,col=out_line_col)
	}
}

// draw_ghost_block :: proc(w_map:^Map,w_pos:[3]f32,item_hd:Item_HD,stat:u64=0) {
// 	draw_ghost_block_at(w_map,w_pos,item_hd,stat)
// }

draw_ghost_block_by_ray_cast :: proc(w_map:^Map,ray_i:Block_Ray_Cast_Info,model_variant:int=0,align_to_hitbox:bool=true) {
	info,ok:=get_block_placement_info(w_map,ray_i,g.temp_using_item_hd,model_variant,align_to_hitbox)
	if !ok {return}

	draw_ghost_block_at(w_map,info.world_pos,g.temp_using_item_hd,info.state,true)
}


hylight_block_by_ray_cast::proc(w_map:^Map,ray_i:Block_Ray_Cast_Info){
	pos:=(cast([3]f32)ray_i.chunk_pos*CHUNK_SIZE) + cast([3]f32)ray_i.pos_in_chunk
	mesh:=tg.get_mesh(w_map.drawing_map_mesh_hd)
	draw_block_outline(&mesh.cpu,pos,ray_i.block.item,block_state = ray_i.block.state,col={1,1,1,.3})
	draw_block_hylight(w_map,pos,ray_i.block.item,block_state = ray_i.block.state)
}


draw_vox_chain_by_faces::proc(
	mesh:^tg.Mesh_CPU,
	vox_chunk:^Vox_Chunk_Data,
	pos_in_chunk:[3]u8,
	world_pos:[3]f32,
	col:[4]f32={1,1,1,1},
){
	ab:=&vox_chunk.backing_chunk_data_abstract
	pal_index:=get_palette_index_by_pos(vox_chunk,pos_in_chunk)
	if pal_index == 0 {return}

	chain_finished:=false

	for _ in 0..<ab.pal_count^ {
		assert(pal_index < ab.pal_count^,"invalid multiblock chain")

		block:=ab.pal[pal_index]
		draw_block_by_faces_item(mesh,world_pos,block.item,block.state,col)

		pal_index=block.multy_block_index
		if pal_index == 0 {
			chain_finished=true
			break
		}
	}

	assert(chain_finished,"cycle detected in drawing multiblock chain")
}


draw_vox_chain_outline::proc(
	mesh:^tg.Mesh_CPU,
	vox_chunk:^Vox_Chunk_Data,
	pos_in_chunk:[3]u8,
	world_pos:[3]f32,
	col:[4]f32={1,1,1,1},
){
	ab:=&vox_chunk.backing_chunk_data_abstract
	pal_index:=get_palette_index_by_pos(vox_chunk,pos_in_chunk)
	if pal_index == 0 {return}

	chain_finished:=false

	for _ in 0..<ab.pal_count^ {
		assert(pal_index < ab.pal_count^,"invalid multiblock chain")

		block:=ab.pal[pal_index]
		draw_block_outline(mesh,world_pos,block.item,block.state,col)

		pal_index=block.multy_block_index
		if pal_index == 0 {
			chain_finished=true
			break
		}
	}

	assert(chain_finished,"cycle detected in drawing multiblock chain")
}
