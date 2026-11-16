
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
import "base:intrinsics"

Vert_Face_Geometry::struct{
	uv:[4][2]f32,
	pos:[4][4]f32,
	normal: [4]f32,
	starting_shade:f32,
	sides:Model_Sides,
	_pading:[2]f32,
}


Block_Model_HD::hm.Handle32
Block_Model_ID::reg.Reg_ID

DF_Block_Model_Types::enum{
	Bace_Block_State,
	Rot_XZ_Block_State,
	Rot_XYZ_Block_State,
	Rot_XYZR_Block_State,
	Rot_XYZRM_Block_State,
	Slab_States,
	Stair_State,
}

Bace_Block_State::enum{
	non,
}
Rot_XZ_Block_State::enum{
	pos_x,
	neg_x,
	pos_z,
	neg_z,
}

Rot_XYZ_Block_State::enum{
	pos_x,
	neg_x,
	pos_y,
	neg_y,
	pos_z,
	neg_z,
}
Slab_States::enum{
	pos_x,
	neg_x,
	pos_y,
	neg_y,
	pos_z,
	neg_z,
}
Stair_Shape :: enum u8 {
	straight,
	inner_left,
	inner_right,
	outer_left,
	outer_right,
}
Stair_Sub_Model_State :: enum u8 {
	straight,
	inner_corner,
	outer_corner,
}
Stair_Facing :: enum u8 {
	pos_z,
	pos_x,
	neg_z,
	neg_x,
}

Stair_State :: struct {
	facing: Stair_Facing,
	shape: Stair_Shape,
	upside_down: bool,
}
Model_Data :: struct {
	cube_indices:[Model_Sides]int,
	extra_count:int,
	hit_boxes:[dynamic;6]Hit_Box,
}
Mount_Type::enum u8 {
	all,
	floor,
	wall,
	hang,
}

Sub_Model::struct{
	is_used:bool,
	sub_model:[][]Model_Data, // [sub_model_state][orientation]
	type:DF_Block_Model_Types,
}

Block_Model::struct{
	handle:Block_Model_HD,
	reg_id:Block_Model_ID,
	model_count:u8, // Highest populated sub-model state index + 1.
	Sub_Models:[Mount_Type]Sub_Model,
}

Block_Model_Reg::reg.Registry(Block_Model,Block_Model_HD)

model_data_init :: proc()->(model_data:Model_Data) {
	for side_index in 0..<6 {
		model_data.cube_indices[cast(Model_Sides)side_index]=-1
	}
	model_data.cube_indices[.extra]=-1
	return
}

model_data_has_geometry :: proc(model_data:Model_Data)->bool {
	if model_data.extra_count > 0 {return true}

	// A zero-initialized Model_Data is an unused source slot. Valid sources
	// should be initialized with model_data_init() before assigning faces.
	all_indices_zero:=model_data.cube_indices[.extra] == 0
	for side_index in 0..<6 {
		if model_data.cube_indices[cast(Model_Sides)side_index] != 0 {
			all_indices_zero=false
			break
		}
	}
	if all_indices_zero {return false}

	for side_index in 0..<6 {
		if model_data.cube_indices[cast(Model_Sides)side_index] >= 0 {
			return true
		}
	}

	return false
}

get_block_sub_model :: proc(
	model:^Block_Model,
	mount:Mount_Type,
	sub_model_state:u8,
)->(sub_model:Sub_Model,selected_mount:Mount_Type,ok:bool) {

	if mount > .hang {return}
	state_index:=cast(int)sub_model_state

	candidate:=model.Sub_Models[mount]
	if candidate.is_used && state_index < len(candidate.sub_model) && len(candidate.sub_model[state_index]) > 0 {
		return candidate,mount,true
	}

	if mount != .all {
		candidate=model.Sub_Models[.all]
		if candidate.is_used && state_index < len(candidate.sub_model) && len(candidate.sub_model[state_index]) > 0 {
			return candidate,.all,true
		}
	}

	return
}

get_block_model_data_from_model :: proc(
	model:^Block_Model,
	block_state:Block_State,
)->(model_data:^Model_Data,ok:bool) {

	sub_model,selected_mount,sub_model_ok:=get_block_sub_model(model,block_state.Mount_type,block_state.Sub_model_state)
	if !sub_model_ok {return}

	state_index:=cast(int)block_state.Sub_model_state
	orientation:=cast(int)block_state.Orientation

	if orientation >= len(sub_model.sub_model[state_index]) && selected_mount != .all {
		sub_model=model.Sub_Models[.all]
		if !sub_model.is_used || state_index >= len(sub_model.sub_model) || orientation >= len(sub_model.sub_model[state_index]) {return}
	}

	if orientation >= len(sub_model.sub_model[state_index]) {return}

	model_data=&sub_model.sub_model[state_index][orientation]
	ok=true
	return
}

get_block_model_data :: proc(
	item_hd:Item_HD,
	block_state:Block_State,
)->(model_data:^Model_Data,ok:bool) {
	item,item_ok:=reg.get(&g.item_reg,item_hd)
	if !item_ok {return}

	model,model_ok:=reg.get(&g.block_model_reg,item.model)
	if !model_ok {return}

	return get_block_model_data_from_model(model,block_state)
}
Hit_Box::struct{
	box:[6]f32,
	can_occlude:bool,
	can_colide:bool,
}
MAX_MODEL_TEXTURES :: 8
Face_Data::struct{
	pos:[4][4]f32,
	side:Model_Sides,
	uv:[4][2]f32,
	normal:[4]f32,
	starting_shade:f32,
	texture_slot:u8,
}

face_is_fully_occluded :: proc(
	face_pos:[4][4]f32,
	hit_boxes:[]Hit_Box,
	side:Model_Sides,
)->bool {
	offset:[3]f32
	switch side {
	case .pos_x: offset={1,0,0}
	case .neg_x: offset={-1,0,0}
	case .pos_y: offset={0,1,0}
	case .neg_y: offset={0,-1,0}
	case .pos_z: offset={0,0,1}
	case .neg_z: offset={0,0,-1}
	case .extra:
	}

	return face_is_fully_occluded_at_offset(face_pos,hit_boxes,side,side,offset,false)
}

face_is_fully_occluded_at_offset :: proc(
	face_pos:[4][4]f32,
	hit_boxes:[]Hit_Box,
	plane_side:Model_Sides,
	face_direction:Model_Sides,
	offset:[3]f32,
	allow_coplanar:bool,
)->bool {
	face_aabb: [6]f32
	face_aabb = {face_pos[0][0],face_pos[0][1],face_pos[0][2],face_pos[0][0],face_pos[0][1],face_pos[0][2]}

	for p in face_pos {
		if p[0] < face_aabb[0] {face_aabb[0] = p[0]}
		if p[1] < face_aabb[1] {face_aabb[1] = p[1]}
		if p[2] < face_aabb[2] {face_aabb[2] = p[2]}
		if p[0] > face_aabb[3] {face_aabb[3] = p[0]}
		if p[1] > face_aabb[4] {face_aabb[4] = p[1]}
		if p[2] > face_aabb[5] {face_aabb[5] = p[2]}
	}

	axis,u_axis,v_axis: int
	boundary: f32

	extra := plane_side == .extra
	switch plane_side {
	case .pos_x:
		axis,u_axis,v_axis,boundary = 0,2,1,1
	case .neg_x:
		axis,u_axis,v_axis,boundary = 0,2,1,0
	case .pos_y:
		axis,u_axis,v_axis,boundary = 1,0,2,1
	case .neg_y:
		axis,u_axis,v_axis,boundary = 1,0,2,0
	case .pos_z:
		axis,u_axis,v_axis,boundary = 2,0,1,1
	case .neg_z:
		axis,u_axis,v_axis,boundary = 2,0,1,0
	case .extra:
		if face_aabb[0] == face_aabb[3] {
			axis,u_axis,v_axis,boundary = 0,2,1,face_aabb[0]
		} else if face_aabb[1] == face_aabb[4] {
			axis,u_axis,v_axis,boundary = 1,0,2,face_aabb[1]
		} else if face_aabb[2] == face_aabb[5] {
			axis,u_axis,v_axis,boundary = 2,0,1,face_aabb[2]
		} else {
			return false
		}
	}

	if !extra && (face_aabb[axis] != boundary || face_aabb[axis+3] != boundary) {return false}

	min_u,max_u := face_aabb[u_axis],face_aabb[u_axis+3]
	min_v,max_v := face_aabb[v_axis],face_aabb[v_axis+3]
	if max_u <= min_u || max_v <= min_v {return false}

	u0 := min_u
	for u0 < max_u {
		u1 := max_u
		for hit_box,i in hit_boxes {
			if !hit_box.can_occlude {continue}
			box := hit_box.box
			n_min_axis := box[axis]+offset[axis]
			n_max_axis := box[axis+3]+offset[axis]
			if face_direction == .extra {
				if n_min_axis > boundary || n_max_axis < boundary {continue}
			} else if !occlusion_box_reaches_face(n_min_axis,n_max_axis,boundary,face_direction,allow_coplanar) {
				continue
			}

			n_min_u := box[u_axis]+offset[u_axis]
			n_max_u := box[u_axis+3]+offset[u_axis]
			if n_min_u > u0 && n_min_u < u1 {u1 = n_min_u}
			if n_max_u > u0 && n_max_u < u1 {u1 = n_max_u}
		}

		mid_u := (u0+u1)*0.5
		v0 := min_v
		for v0 < max_v {
			v1 := max_v
			for hit_box,i in hit_boxes {
				if !hit_box.can_occlude  {continue}
				box := hit_box.box
				n_min_axis := box[axis]+offset[axis]
				n_max_axis := box[axis+3]+offset[axis]
				if face_direction == .extra {
					if n_min_axis > boundary || n_max_axis < boundary {continue}
				} else if !occlusion_box_reaches_face(n_min_axis,n_max_axis,boundary,face_direction,allow_coplanar) {
					continue
				}

				n_min_v := box[v_axis]+offset[v_axis]
				n_max_v := box[v_axis+3]+offset[v_axis]
				if n_min_v > v0 && n_min_v < v1 {v1 = n_min_v}
				if n_max_v > v0 && n_max_v < v1 {v1 = n_max_v}
			}

			mid_v := (v0+v1)*0.5
			covered := false
			for hit_box,i in hit_boxes {
				if !hit_box.can_occlude {continue}
				box := hit_box.box
				n_min_axis := box[axis]+offset[axis]
				n_max_axis := box[axis+3]+offset[axis]
				if face_direction == .extra {
					if n_min_axis > boundary || n_max_axis < boundary {continue}
				} else if !occlusion_box_reaches_face(n_min_axis,n_max_axis,boundary,face_direction,allow_coplanar) {
					continue
				}

				n_min_u := box[u_axis]+offset[u_axis]
				n_max_u := box[u_axis+3]+offset[u_axis]
				n_min_v := box[v_axis]+offset[v_axis]
				n_max_v := box[v_axis+3]+offset[v_axis]

				if mid_u >= n_min_u && mid_u < n_max_u && mid_v >= n_min_v && mid_v < n_max_v {
					covered = true
					break
				}
			}

			if !covered {return false}
			v0 = v1
		}
		u0 = u1
	}

	return true
}

face_is_fully_occluded_by_chain::proc(
	vox_data:^Vox_Chunk_Data,
	pal_index:u16,
	target_pal_index:u16,
	face_pos:[4][4]f32,
	plane_side:Model_Sides,
	face_direction:Model_Sides,
	offset:[3]f32,
	target_offset:[3]f32,
)->bool {
	if pal_index == 0 {return false}

	ab:=&vox_data.backing_chunk_data_abstract
	current_index:=pal_index
	target_found:=target_pal_index == 0
	chain_finished:=false
	allow_coplanar:=false

	for _ in 0..<ab.pal_count^ {
		assert(current_index < ab.pal_count^,"invalid multiblock chain")

		if current_index == target_pal_index && target_pal_index != 0 {
			target_found=true
			allow_coplanar=true
		} else {
			block:=ab.pal[current_index]
			block_offset:=block_offset_from_u16(block.state.offset)
			relative_offset:=offset+block_offset-target_offset

			model_data,model_data_ok:=get_block_model_data(block.item,block.state)
			if model_data_ok {
				if face_is_fully_occluded_at_offset(
					face_pos,
					model_data.hit_boxes[:],
					plane_side,
					face_direction,
					relative_offset,
					allow_coplanar,
				) {
					return true
				}
			}
		}

		next:=ab.pal[current_index].multy_block_index
		if next == 0 {
			chain_finished=true
			break
		}
		current_index=next
	}

	assert(target_found,"target palette entry not found in chain")
	assert(chain_finished,"cycle detected in multiblock chain")
	return false
}



create_vox_face :: proc(vert_data:Vert_Face_Geometry,texture_slot:u8=0,)->(index:int){
	index=tg.add_indexed_gpu_data(&g.geometry_facees,vert_data)

	assert(index == len(g.all_face_data),"geometry face data out of sync")

	append(&g.all_face_data,Face_Data{
		pos=vert_data.pos,
		side=vert_data.sides,
		uv=vert_data.uv,
		normal=vert_data.normal,
		starting_shade=vert_data.starting_shade,
		texture_slot=texture_slot,
	})

	return
}

model_orientation_count :: proc(model_type:DF_Block_Model_Types)->(count:int,ok:bool) {
	#partial switch model_type {
	case .Bace_Block_State:
		return 1,true
	case .Rot_XZ_Block_State:
		return 4,true
	case .Rot_XYZ_Block_State,.Slab_States:
		return 6,true
	case .Rot_XYZR_Block_State:
		return 24,true
	case .Rot_XYZRM_Block_State:
		return 48,true
	// Stair_State has per-sub-model orientation counts (8, 16, 16),
	// so it is not a generic transform type with one fixed orientation count.
	}
	return 0,false
}

decode_model_variant :: proc(model_type:DF_Block_Model_Types,variant:int)->(face_index,rotation:int,mirror:bool) {
	#partial switch model_type {
	case .Rot_XYZ_Block_State,.Slab_States:
		face_index=variant
	case .Rot_XYZR_Block_State:
		face_index=variant/4
		rotation=variant%4
	case .Rot_XYZRM_Block_State:
		face_index=variant/8
		selector:=variant%8
		rotation=selector/2
		mirror=(selector&1)!=0
	}
	return
}

orientation_basis :: proc(face_index:int)->(right,up,forward:[3]f32) {
	switch face_index {
	case 0: // pos_x
		right={0,0,-1}
		up={0,1,0}
		forward={1,0,0}
	case 1: // neg_x
		right={0,0,1}
		up={0,1,0}
		forward={-1,0,0}
	case 2: // pos_y
		right={1,0,0}
		up={0,0,-1}
		forward={0,1,0}
	case 3: // neg_y
		right={1,0,0}
		up={0,0,1}
		forward={0,-1,0}
	case 4: // pos_z
		right={1,0,0}
		up={0,1,0}
		forward={0,0,1}
	case 5: // neg_z
		right={-1,0,0}
		up={0,1,0}
		forward={0,0,-1}
	}
	return
}

positive_mod_int :: proc(value,divisor:int)->int {
	result:=value%divisor
	if result < 0 {
		result+=divisor
	}
	return result
}

transform_model_vec :: proc(p:[3]f32,face_index,rotation:int,mirror:bool)->[3]f32 {
	right,up,forward:=orientation_basis(face_index)
	old_right:=right

	switch positive_mod_int(rotation,4) {
	case 0:
	case 1:
		right=up
		up={-old_right[0],-old_right[1],-old_right[2]}
	case 2:
		right={-right[0],-right[1],-right[2]}
		up={-up[0],-up[1],-up[2]}
	case 3:
		right={-up[0],-up[1],-up[2]}
		up=old_right
	}

	if mirror {
		right={-right[0],-right[1],-right[2]}
	}

	return {
		p[0]*right[0]+p[1]*up[0]+p[2]*forward[0],
		p[0]*right[1]+p[1]*up[1]+p[2]*forward[1],
		p[0]*right[2]+p[1]*up[2]+p[2]*forward[2],
	}
}

// Source model forward is +Z. Rotations are around pivot, normally {0.5,0.5,0.5}.
transform_model_point :: proc(
	p:[3]f32,
	pivot:[3]f32,
	model_type:DF_Block_Model_Types,
	variant:int,
)->[3]f32 {
	dx:=p[0]-pivot[0]
	dy:=p[1]-pivot[1]
	dz:=p[2]-pivot[2]

	#partial switch model_type {
	case .Bace_Block_State:
		return p
	case .Rot_XZ_Block_State:
		switch variant {
		case 0: return p
		case 1: return {pivot[0]+dz,pivot[1]+dy,pivot[2]-dx}
		case 2: return {pivot[0]-dx,pivot[1]+dy,pivot[2]-dz}
		case 3: return {pivot[0]-dz,pivot[1]+dy,pivot[2]+dx}
		}
	case .Rot_XYZ_Block_State,.Rot_XYZR_Block_State,.Rot_XYZRM_Block_State,.Slab_States:
		face_index,rotation,mirror:=decode_model_variant(model_type,variant)
		rotated:=transform_model_vec({dx,dy,dz},face_index,rotation,mirror)
		return {pivot[0]+rotated[0],pivot[1]+rotated[1],pivot[2]+rotated[2]}
	case .Stair_State:
		return p
	}

	return p
}

model_side_shade :: proc(side:Model_Sides)->f32 {
	switch side {
	case .pos_x,.neg_x: return .65
	case .pos_y: return 1
	case .neg_y: return .5
	case .pos_z,.neg_z: return .8
	case .extra: return 1
	}
	return 1
}

transform_model_hit_box :: proc(
	hit_box:Hit_Box,
	center_offset:[3]f32,
	pivot:[3]f32,
	model_type:DF_Block_Model_Types,
	variant:int,
	unit_scale:f32,
)->Hit_Box {
	result:=hit_box

	bounds_min:[3]f32={max(f32),max(f32),max(f32)}
	bounds_max:[3]f32={min(f32),min(f32),min(f32)}

	for corner_index in 0..<8 {
		corner:[3]f32={
			hit_box.box[(corner_index&1)*3]*unit_scale,
			hit_box.box[1+((corner_index>>1)&1)*3]*unit_scale,
			hit_box.box[2+((corner_index>>2)&1)*3]*unit_scale,
		}

		for axis in 0..<3 {
			corner[axis]+=center_offset[axis]
		}

		corner=transform_model_point(corner,pivot,model_type,variant)

		for axis in 0..<3 {
			bounds_min[axis]=min(bounds_min[axis],corner[axis])
			bounds_max[axis]=max(bounds_max[axis],corner[axis])
		}
	}

	result.box={
		bounds_min[0],bounds_min[1],bounds_min[2],
		bounds_max[0],bounds_max[1],bounds_max[2],
	}

	return result
}

transform_model_variant_face :: proc(
	source:Face_Data,
	model_type:DF_Block_Model_Types,
	variant:int,
	pivot:[3]f32,
	world_aligned_uvs:bool=false,
)->(face:Vert_Face_Geometry,ok:bool) {

	face=Vert_Face_Geometry{
		pos=source.pos,
		uv=source.uv,
		normal=source.normal,
		starting_shade=source.starting_shade,
		sides=source.side,
	}

	for i in 0..<4 {
		p:=[3]f32{face.pos[i][0],face.pos[i][1],face.pos[i][2]}
		p=transform_model_point(p,pivot,model_type,variant)
		face.pos[i][0]=p[0]
		face.pos[i][1]=p[1]
		face.pos[i][2]=p[2]
	}

	_,_,mirror:=decode_model_variant(model_type,variant)

	if mirror {
		is_triangle:=true

		for axis in 0..<3 {
			if math.abs(face.pos[2][axis]-face.pos[3][axis]) > .000001 {
				is_triangle=false
				break
			}
		}

		if is_triangle {
			face.pos[1],face.pos[2]=face.pos[2],face.pos[1]
			face.uv[1],face.uv[2]=face.uv[2],face.uv[1]
			face.pos[3]=face.pos[2]
			face.uv[3]=face.uv[2]
		} else {
			face.pos[1],face.pos[3]=face.pos[3],face.pos[1]
			face.uv[1],face.uv[3]=face.uv[3],face.uv[1]
		}
	}

	e1:[3]f32={face.pos[1][0]-face.pos[0][0],face.pos[1][1]-face.pos[0][1],face.pos[1][2]-face.pos[0][2]}
	e2:[3]f32={face.pos[2][0]-face.pos[0][0],face.pos[2][1]-face.pos[0][1],face.pos[2][2]-face.pos[0][2]}
	normal:[3]f32={
		e1[1]*e2[2]-e1[2]*e2[1],
		e1[2]*e2[0]-e1[0]*e2[2],
		e1[0]*e2[1]-e1[1]*e2[0],
	}

	normal_length:=math.sqrt(normal[0]*normal[0]+normal[1]*normal[1]+normal[2]*normal[2])
	if normal_length <= .000001 {return}

	normal[0]/=normal_length
	normal[1]/=normal_length
	normal[2]/=normal_length

	face.normal={normal[0],normal[1],normal[2],0}
	face.sides=get_model_side_from_direction(normal)
	face.starting_shade=model_side_shade(face.sides)

	// Recalculate UVs using the final transformed positions.
	if world_aligned_uvs {
		for i in 0..<4 {
			p:=[3]f32{face.pos[i][0],face.pos[i][1],face.pos[i][2]}
			face.uv[i]=model_project_world_uv(p,face.sides)
		}
	}

	ok=true
	return
}

model_project_world_uv :: proc(p:[3]f32,side:Model_Sides)->[2]f32 {
	switch side {
	case .pos_x,.neg_x: return {p[2],p[1]}
	case .pos_y,.neg_y: return {p[0],p[2]}
	case .pos_z,.neg_z: return {p[0],p[1]}
	case .extra: return {p[0],p[1]}
	}
	return {}
}

// When variant_indices is supplied, each raw transform index is emitted in
// that order, allowing a smaller compact orientation array than the full rotator set.
generate_model_data_variants :: proc(
	source:Model_Data,
	variant_type:DF_Block_Model_Types,
	result_type:DF_Block_Model_Types,
	pivot:[3]f32,
	variant_indices:[]int=nil,
	add_bounds_hitbox:bool=false,
	world_aligned_uvs:bool=false,
)->(models:[]Model_Data,ok:bool) {

	variant_count,variant_ok:=model_orientation_count(variant_type)
	if !variant_ok || variant_type == .Stair_State {return}

	for variant in variant_indices {
		if variant < 0 || variant >= variant_count {return}
	}

	output_count:=variant_count
	if len(variant_indices) > 0 {output_count=len(variant_indices)}

	has_faces:=false

	for side_index in 0..<6 {
		geometry_index:=source.cube_indices[cast(Model_Sides)side_index]
		if geometry_index < -1 || geometry_index >= len(g.all_face_data) {
			log.log(.Error,"Model variant generator: invalid primary geometry index",geometry_index)
			return
		}
		if geometry_index >= 0 {has_faces=true}
	}

	if source.extra_count < 0 {return}

	extra_start:=source.cube_indices[.extra]
	if source.extra_count > 0 {
		if extra_start < 0 || extra_start+source.extra_count > len(g.all_face_data) {
			log.log(.Error,"Model variant generator: invalid extra geometry range",extra_start,source.extra_count)
			return
		}
		has_faces=true
	}

	if !has_faces {
		log.log(.Error,"Model variant generator: source model has no geometry")
		return
	}

	models=make([]Model_Data,output_count)

	df_var:=[6]int{2,3,0,1,4,5}

	for model_index in 0..<output_count {
		transform_variant:=model_index
		if len(variant_indices) > 0 {
			transform_variant=variant_indices[model_index]
		} else if result_type == .Slab_States {
			if variant_count != 6 {return}
			transform_variant=df_var[model_index]
		}

		model_data:=model_data_init()
		bounds_min:[3]f32={max(f32),max(f32),max(f32)}
		bounds_max:[3]f32={min(f32),min(f32),min(f32)}
		has_bounds:=false

		for side_index in 0..<6 {
			side:=cast(Model_Sides)side_index
			geometry_index:=source.cube_indices[side]
			if geometry_index < 0 {continue}
			source_face:=g.all_face_data[geometry_index]
			transformed,face_ok:=transform_model_variant_face(source_face,variant_type,transform_variant,pivot,world_aligned_uvs)



			// transformed,face_ok:=transform_model_variant_face(g.all_face_data[geometry_index],variant_type,transform_variant,pivot)
			if !face_ok {
				log.log(.Error,"Model variant generator: invalid primary face",geometry_index,transform_variant)
				return
			}

			if add_bounds_hitbox && len(source.hit_boxes) == 0 {
				for vertex_index in 0..<4 {
					for axis in 0..<3 {
						position:=transformed.pos[vertex_index][axis]
						bounds_min[axis]=min(bounds_min[axis],position)
						bounds_max[axis]=max(bounds_max[axis],position)
					}
					has_bounds=true
				}
			}

			new_side:=transformed.sides
			assert(model_data.cube_indices[new_side] < 0,"multiple primary faces transformed to the same side")
			model_data.cube_indices[new_side]=create_vox_face(transformed,source_face.texture_slot)
		}

		if source.extra_count > 0 {
			first_extra:=-1

			for extra_i in 0..<source.extra_count {
				geometry_index:=extra_start+extra_i

				source_face:=g.all_face_data[geometry_index]
				transformed,face_ok:=transform_model_variant_face(source_face,variant_type,transform_variant,pivot,world_aligned_uvs)
				// transformed,face_ok:=transform_model_variant_face(g.all_face_data[geometry_index],variant_type,transform_variant,pivot)
				if !face_ok {
					log.log(.Error,"Model variant generator: invalid extra face",geometry_index,transform_variant)
					return
				}

				if add_bounds_hitbox && len(source.hit_boxes) == 0 {
					for vertex_index in 0..<4 {
						for axis in 0..<3 {
							position:=transformed.pos[vertex_index][axis]
							bounds_min[axis]=min(bounds_min[axis],position)
							bounds_max[axis]=max(bounds_max[axis],position)
						}
						has_bounds=true
					}
				}

				new_index:=create_vox_face(transformed,source_face.texture_slot)
				if first_extra < 0 {first_extra=new_index}
				model_data.extra_count+=1
			}

			model_data.cube_indices[.extra]=first_extra
		}

		for hit_box in source.hit_boxes {
			if len(model_data.hit_boxes) >= cap(model_data.hit_boxes) {break}
			append(&model_data.hit_boxes,transform_model_hit_box(hit_box,{},pivot,variant_type,transform_variant,1.0))
		}

		if add_bounds_hitbox && len(source.hit_boxes) == 0 && has_bounds && len(model_data.hit_boxes) < cap(model_data.hit_boxes) {
			append(&model_data.hit_boxes,Hit_Box{
				box={bounds_min[0],bounds_min[1],bounds_min[2],bounds_max[0],bounds_max[1],bounds_max[2]},
				can_occlude=false,
				can_colide=true,
			})
		}

		models[model_index]=model_data
	}

	ok=true
	return
}

// `sources[state][mount]` contains the unrotated Model_Data for that state and mount.
// Missing states must be initialized with model_data_init() so their face indices are -1.
generate_block_model_variants :: proc(
	sources:[][Mount_Type]Model_Data,
	variant_type:DF_Block_Model_Types,
	result_type:DF_Block_Model_Types,
	registry_id:reg.Reg_ID,
	pivot:[3]f32={0.5,0.5,0.5},
)->(hd:Block_Model_HD,ok:bool) {

	if len(sources) == 0 || len(sources) > 255 {return}

	variant_count,variant_ok:=model_orientation_count(variant_type)
	result_count,result_ok:=model_orientation_count(result_type)
	if !variant_ok || !result_ok || variant_type == .Stair_State || result_type == .Stair_State || variant_count != result_count {return}

	block_model:Block_Model
	state_count:=0

	for mount_index in 0..<4 {
		mount:=cast(Mount_Type)mount_index
		state_models:[][]Model_Data
		is_used:=false

		for state_index in 0..<len(sources) {
			source:=sources[state_index][mount]
			if !model_data_has_geometry(source) {continue}

			variants,variants_ok:=generate_model_data_variants(source,variant_type,result_type,pivot)
			if !variants_ok {return}

			if !is_used {state_models=make([][]Model_Data,len(sources))}
			state_models[state_index]=variants
			is_used=true
			state_count=max(state_count,state_index+1)
		}

		if is_used {
			block_model.Sub_Models[mount]=Sub_Model{
				is_used=true,
				sub_model=state_models,
				type=result_type,
			}
		}
	}

	if state_count == 0 {return}

	block_model.model_count=cast(u8)state_count

	tg.update_indexed_gpu_data(&g.geometry_facees)

	hd=reg.add(&g.block_model_reg,block_model,registry_id)
	ok=true
	return
}

generate_rot_xz_variants :: proc(
	sources:[][Mount_Type]Model_Data,
	registry_id:reg.Reg_ID,
	pivot:[3]f32={0.5,0.5,0.5},
)->(hd:Block_Model_HD,ok:bool) {
	return generate_block_model_variants(sources,.Rot_XZ_Block_State,.Rot_XZ_Block_State,registry_id,pivot)
}

generate_rot_xyz_variants :: proc(
	sources:[][Mount_Type]Model_Data,
	registry_id:reg.Reg_ID,
	pivot:[3]f32={0.5,0.5,0.5},
)->(hd:Block_Model_HD,ok:bool) {
	return generate_block_model_variants(sources,.Rot_XYZ_Block_State,.Rot_XYZ_Block_State,registry_id,pivot)
}

generate_rot_xyzr_variants :: proc(
	sources:[][Mount_Type]Model_Data,
	registry_id:reg.Reg_ID,
	pivot:[3]f32={0.5,0.5,0.5},
)->(hd:Block_Model_HD,ok:bool) {
	return generate_block_model_variants(sources,.Rot_XYZR_Block_State,.Rot_XYZR_Block_State,registry_id,pivot)
}

generate_rot_xyzrm_variants :: proc(
	sources:[][Mount_Type]Model_Data,
	registry_id:reg.Reg_ID,
	pivot:[3]f32={0.5,0.5,0.5},
)->(hd:Block_Model_HD,ok:bool) {
	return generate_block_model_variants(sources,.Rot_XYZRM_Block_State,.Rot_XYZRM_Block_State,registry_id,pivot)
}
create_cube_face_geometry :: proc() -> Block_Model_HD {

	data:=model_data_init()

	data.cube_indices[.pos_x]=create_vox_face(Vert_Face_Geometry{
		sides=.pos_x,
		uv={{0,0},{0,1},{1,1},{1,0}},
		pos={{1,1,1,1},{1,0,1,1},{1,0,0,1},{1,1,0,1}},
		starting_shade=.65,
	},0)

	data.cube_indices[.neg_x]=create_vox_face(Vert_Face_Geometry{
		sides=.neg_x,
		uv={{0,0},{0,1},{1,1},{1,0}},
		pos={{0,1,0,1},{0,0,0,1},{0,0,1,1},{0,1,1,1}},
		starting_shade=.65,
	},1)

	data.cube_indices[.pos_y]=create_vox_face(Vert_Face_Geometry{
		sides=.pos_y,
		uv={{0,0},{0,1},{1,1},{1,0}},
		pos={{0,1,0,1},{0,1,1,1},{1,1,1,1},{1,1,0,1}},
		starting_shade=1,
	},2)

	data.cube_indices[.neg_y]=create_vox_face(Vert_Face_Geometry{
		sides=.neg_y,
		uv={{0,0},{0,1},{1,1},{1,0}},
		pos={{1,0,0,1},{1,0,1,1},{0,0,1,1},{0,0,0,1}},
		starting_shade=.5,
	},3)

	data.cube_indices[.pos_z]=create_vox_face(Vert_Face_Geometry{
		sides=.pos_z,
		uv={{0,0},{0,1},{1,1},{1,0}},
		pos={{0,1,1,1},{0,0,1,1},{1,0,1,1},{1,1,1,1}},
		starting_shade=.8,
	},4)

	data.cube_indices[.neg_z]=create_vox_face(Vert_Face_Geometry{
		sides=.neg_z,
		uv={{0,0},{0,1},{1,1},{1,0}},
		pos={{1,1,0,1},{1,0,0,1},{0,0,0,1},{0,1,0,1}},
		starting_shade=.8,
	},5)

	append(&data.hit_boxes,Hit_Box{can_colide=true,can_occlude=true,box={0,0,0,1,1,1}})

	sources:[1][Mount_Type]Model_Data
	sources[0][.all]=data

	hd,ok:=generate_block_model_variants(sources[:],.Bace_Block_State,.Bace_Block_State,reg.id(DF_Block_Model_Types.Bace_Block_State))
	if !ok {
		log.log(.Error,"Failed to create cube model")
		return {}
	}

	return hd
}
create_slab_face_geometry :: proc()->Block_Model_HD {
	source:=model_data_init()

	source_faces:[6]Vert_Face_Geometry={
		{
			sides=.pos_x,
			uv={{0,0},{0,.5},{1,.5},{1,0}},
			pos={{1,0,.5,1},{1,0,0,1},{1,1,0,1},{1,1,.5,1}},
			normal={1,0,0,0},
			starting_shade=.65,
		},
		{
			sides=.neg_x,
			uv={{0,0},{0,.5},{1,.5},{1,0}},
			pos={{0,1,.5,1},{0,1,0,1},{0,0,0,1},{0,0,.5,1}},
			normal={-1,0,0,0},
			starting_shade=.65,
		},
		{
			sides=.pos_y,
			uv={{0,0},{0,.5},{1,.5},{1,0}},
			pos={{1,1,.5,1},{1,1,0,1},{0,1,0,1},{0,1,.5,1}},
			normal={0,1,0,0},
			starting_shade=1,
		},
		{
			sides=.neg_y,
			uv={{0,0},{0,.5},{1,.5},{1,0}},
			pos={{0,0,.5,1},{0,0,0,1},{1,0,0,1},{1,0,.5,1}},
			normal={0,-1,0,0},
			starting_shade=.5,
		},
		{
			sides=.pos_z,
			uv={{0,0},{0,1},{1,1},{1,0}},
			pos={{0,1,.5,1},{0,0,.5,1},{1,0,.5,1},{1,1,.5,1}},
			normal={0,0,1,0},
			starting_shade=.8,
		},
		{
			sides=.neg_z,
			uv={{0,0},{0,1},{1,1},{1,0}},
			pos={{1,1,0,1},{1,0,0,1},{0,0,0,1},{0,1,0,1}},
			normal={0,0,-1,0},
			starting_shade=.8,
		},
	}

	for face in source_faces {
		source.cube_indices[face.sides]=create_vox_face(face,cast(u8)model_side_to_xyz_variant(face.sides))
	}

	append(&source.hit_boxes,Hit_Box{
		box={0,0,0,1,1,.5},
		can_colide=true,
		can_occlude=true,
	})

	sources:[1][Mount_Type]Model_Data
	sources[0][.all]=source

	hd,ok:=generate_block_model_variants(
		sources[:],
		.Rot_XYZ_Block_State,
		.Slab_States,
		reg.id(DF_Block_Model_Types.Slab_States),
		{.5,.5,.5},
	)

	if !ok {
		log.log(.Error,"Failed to generate slab variants")
		return {}
	}

	return hd
}

Stair_Face_Rect :: struct {
	x0,y0,z0:f32,
	x1,y1,z1:f32,
	area:f32,
	outer:bool,
}

Stair_Surface_Set :: struct {
	rects:[6][24]Stair_Face_Rect,
	counts:[6]int,
}

stair_add_plane :: proc(
	surfaces:^Stair_Surface_Set,
	side:Model_Sides,
	plane:f32,
	tiles:[2][2]bool,
) {
	si:=cast(int)side
	used:[2][2]bool

	for a in 0..<2 {
		for b in 0..<2 {
			if !tiles[a][b] || used[a][b] {continue}

			b_count:=1
			if b==0 && tiles[a][1] && !used[a][1] {
				b_count=2
			}

			a_count:=1
			if a==0 {
				can_extend:=true
				for bb in b..<b+b_count {
					if !tiles[1][bb] || used[1][bb] {
						can_extend=false
					}
				}
				if can_extend {a_count=2}
			}

			for aa in a..<a+a_count {
				for bb in b..<b+b_count {
					used[aa][bb]=true
				}
			}

			a0:=f32(a)*.5
			a1:=f32(a+a_count)*.5
			b0:=f32(b)*.5
			b1:=f32(b+b_count)*.5

			rect:Stair_Face_Rect

			switch side {
			case .pos_x,.neg_x:
				rect={plane,a0,b0,plane,a1,b1,0,false}
			case .pos_y,.neg_y:
				rect={a0,plane,b0,a1,plane,b1,0,false}
			case .pos_z,.neg_z:
				rect={b0,a0,plane,b1,a1,plane,0,false}
			case .extra:
				continue
			}

			rect.area=(a1-a0)*(b1-b0)

			switch side {
			case .pos_x,.pos_y,.pos_z:
				rect.outer=plane==1
			case .neg_x,.neg_y,.neg_z:
				rect.outer=plane==0
			case .extra:
			}

			assert(surfaces.counts[si]<24)
			surfaces.rects[si][surfaces.counts[si]]=rect
			surfaces.counts[si]+=1
		}
	}
}

stair_collect_surfaces :: proc(solid:[2][2][2]bool) -> (surfaces:Stair_Surface_Set) {

	for p in 0..<3 {
		plane:=f32(p)*.5

		pos_x_tiles,neg_x_tiles:[2][2]bool
		pos_y_tiles,neg_y_tiles:[2][2]bool
		pos_z_tiles,neg_z_tiles:[2][2]bool

		for y in 0..<2 {
			for z in 0..<2 {
				if p==0 {
					neg_x_tiles[y][z]=solid[0][y][z]
				} else if p==1 {
					pos_x_tiles[y][z]=solid[0][y][z] && !solid[1][y][z]
					neg_x_tiles[y][z]=solid[1][y][z] && !solid[0][y][z]
				} else {
					pos_x_tiles[y][z]=solid[1][y][z]
				}
			}
		}

		for x in 0..<2 {
			for z in 0..<2 {
				if p==0 {
					neg_y_tiles[x][z]=solid[x][0][z]
				} else if p==1 {
					pos_y_tiles[x][z]=solid[x][0][z] && !solid[x][1][z]
					neg_y_tiles[x][z]=solid[x][1][z] && !solid[x][0][z]
				} else {
					pos_y_tiles[x][z]=solid[x][1][z]
				}
			}
		}

		for y in 0..<2 {
			for x in 0..<2 {
				if p==0 {
					neg_z_tiles[y][x]=solid[x][y][0]
				} else if p==1 {
					pos_z_tiles[y][x]=solid[x][y][0] && !solid[x][y][1]
					neg_z_tiles[y][x]=solid[x][y][1] && !solid[x][y][0]
				} else {
					pos_z_tiles[y][x]=solid[x][y][1]
				}
			}
		}

		stair_add_plane(&surfaces,.pos_x,plane,pos_x_tiles)
		stair_add_plane(&surfaces,.neg_x,plane,neg_x_tiles)
		stair_add_plane(&surfaces,.pos_y,plane,pos_y_tiles)
		stair_add_plane(&surfaces,.neg_y,plane,neg_y_tiles)
		stair_add_plane(&surfaces,.pos_z,plane,pos_z_tiles)
		stair_add_plane(&surfaces,.neg_z,plane,neg_z_tiles)
	}

	return
}

stair_make_face :: proc(
	side:Model_Sides,
	r:Stair_Face_Rect,
) -> (face:Vert_Face_Geometry) {

	v_top:=1-r.y1
	v_bottom:=1-r.y0

	switch side {
	case .pos_x:
		face.pos={
			{r.x1,r.y1,r.z1,1},
			{r.x1,r.y0,r.z1,1},
			{r.x1,r.y0,r.z0,1},
			{r.x1,r.y1,r.z0,1},
		}
		face.uv={{1-r.z1,v_top},{1-r.z1,v_bottom},{1-r.z0,v_bottom},{1-r.z0,v_top}}
		face.starting_shade=.65

	case .neg_x:
		face.pos={
			{r.x0,r.y1,r.z0,1},
			{r.x0,r.y0,r.z0,1},
			{r.x0,r.y0,r.z1,1},
			{r.x0,r.y1,r.z1,1},
		}
		face.uv={{r.z0,v_top},{r.z0,v_bottom},{r.z1,v_bottom},{r.z1,v_top}}
		face.starting_shade=.65

	case .pos_y:
		face.pos={
			{r.x0,r.y1,r.z0,1},
			{r.x0,r.y1,r.z1,1},
			{r.x1,r.y1,r.z1,1},
			{r.x1,r.y1,r.z0,1},
		}
		face.uv={{r.x0,r.z0},{r.x0,r.z1},{r.x1,r.z1},{r.x1,r.z0}}
		face.starting_shade=1

	case .neg_y:
		face.pos={
			{r.x1,r.y0,r.z0,1},
			{r.x1,r.y0,r.z1,1},
			{r.x0,r.y0,r.z1,1},
			{r.x0,r.y0,r.z0,1},
		}
		face.uv={{1-r.x1,r.z0},{1-r.x1,r.z1},{1-r.x0,r.z1},{1-r.x0,r.z0}}
		face.starting_shade=.5

	case .pos_z:
		face.pos={
			{r.x0,r.y1,r.z1,1},
			{r.x0,r.y0,r.z1,1},
			{r.x1,r.y0,r.z1,1},
			{r.x1,r.y1,r.z1,1},
		}
		face.uv={{r.x0,v_top},{r.x0,v_bottom},{r.x1,v_bottom},{r.x1,v_top}}
		face.starting_shade=.8

	case .neg_z:
		face.pos={
			{r.x1,r.y1,r.z0,1},
			{r.x1,r.y0,r.z0,1},
			{r.x0,r.y0,r.z0,1},
			{r.x0,r.y1,r.z0,1},
		}
		face.uv={{1-r.x1,v_top},{1-r.x1,v_bottom},{1-r.x0,v_bottom},{1-r.x0,v_top}}
		face.starting_shade=.8

	case .extra:
	}
	face.sides = side
	return
}


stair_append_footprint_hit_boxes :: proc(
	model:^Model_Data,
	cells:[2][2]bool,
	y0,y1:f32,
) {
	used:[2][2]bool

	for z in 0..<2 {
		for x in 0..<2 {
			if !cells[x][z] || used[x][z] {continue}

			// Merge adjacent X cells.
			x_count:=1
			if x==0 && cells[1][z] && !used[1][z] {
				x_count=2
			}

			// Extend into the next Z row when the entire width matches.
			z_count:=1
			if z==0 {
				can_extend:=true
				for xx in x..<x+x_count {
					if !cells[xx][1] || used[xx][1] {
						can_extend=false
					}
				}
				if can_extend {z_count=2}
			}

			for xx in x..<x+x_count {
				for zz in z..<z+z_count {
					used[xx][zz]=true
				}
			}

			append(&model.hit_boxes,Hit_Box{
				can_colide=true,
				can_occlude=true,
				box={
					f32(x)*0.5,
					y0,
					f32(z)*0.5,
					f32(x+x_count)*0.5,
					y1,
					f32(z+z_count)*0.5,
				},
			})
		}
	}
}

stair_make_hit_boxes :: proc(
	model:^Model_Data,
	cells:[2][2]bool,
	upside_down:bool,
) {
	base_y0:f32
	base_y1:f32
	step_y0:f32
	step_y1:f32

	if upside_down {
		// Full upper half.
		base_y0 = .5
		base_y1 = 1

		// Stair footprint occupies lower half.
		step_y0 = 0
		step_y1 = .5
	} else {
		// Full lower half.
		base_y0 = 0
		base_y1 = .5

		// Stair footprint occupies upper half.
		step_y0 = .5
		step_y1 = 1
	}

	// Full half-block.
	append(&model.hit_boxes,Hit_Box{
		can_colide = true,
		can_occlude = true,
		box = {0,base_y0,0,1,base_y1,1},
	})

	// Add the raised footprint as horizontal runs.
	// Each run becomes one rectangular hitbox.
	for z in 0..<2 {
		x:=0

		for x < 2 {
			if !cells[x][z] {
				x+=1
				continue
			}

			x_start:=x

			for x < 2 && cells[x][z] {
				x+=1
			}

			append(&model.hit_boxes,Hit_Box{
				can_colide = true,
				can_occlude = true,
				box = {
					f32(x_start)*.5,
					step_y0,
					f32(z)*.5,
					f32(x)*.5,
					step_y1,
					f32(z+1)*.5,
				},
			})
		}
	}
}
stair_create_source_model :: proc(sub_model_state:Stair_Sub_Model_State)->Model_Data {
	shape_cells:[2][2]bool

	switch sub_model_state {
	case .straight:
		shape_cells[0][0]=true
		shape_cells[1][0]=true
	case .inner_corner:
		shape_cells[0][0]=true
		shape_cells[1][0]=true
		shape_cells[0][1]=true
	case .outer_corner:
		shape_cells[0][0]=true
	}

	solid:[2][2][2]bool
	for x in 0..<2 {
		for z in 0..<2 {
			solid[x][0][z]=true
			solid[x][1][z]=shape_cells[x][z]
		}
	}

	surfaces:=stair_collect_surfaces(solid)
	model:=model_data_init()
	primary:[6]int

	for si in 0..<6 {
		side:=cast(Model_Sides)si
		best:=-1
		best_area:f32=-1

		for i in 0..<surfaces.counts[si] {
			r:=surfaces.rects[si][i]
			if r.outer && r.area>best_area {
				best=i
				best_area=r.area
			}
		}

		assert(best>=0,"stair missing exterior directional face")
		primary[si]=best
		model.cube_indices[side]=create_vox_face(
			stair_make_face(side,surfaces.rects[si][best]),
			cast(u8)model_side_to_xyz_variant(side),
		)
	}

	first_extra:=-1
	for si in 0..<6 {
		side:=cast(Model_Sides)si
		for i in 0..<surfaces.counts[si] {
			if i==primary[si] {continue}

			face_hd:=create_vox_face(
				stair_make_face(side,surfaces.rects[si][i]),
				cast(u8)model_side_to_xyz_variant(side),
			)

			if first_extra < 0 {first_extra=face_hd}
			model.extra_count+=1
		}
	}

	if model.extra_count > 0 {
		model.cube_indices[.extra]=first_extra
	}

	stair_make_hit_boxes(&model,shape_cells,false)
	return model
}

// The Rot_XYZRM encoding is face_index*8 + rotation*2 + mirror.
// A 180-degree roll around the stair's forward axis flips both local X and Y.
// XORing the generic mirror bit cancels the unwanted local-X flip when the
// semantic stair is only being turned upside-down.
stair_rotator_variant_index :: proc(facing:Stair_Facing,upside_down,mirrored:bool)->int {
	facing_side:=stair_rotation_to_model_side(int(facing))
	face_index:=cast(int)model_side_to_xyz_variant(facing_side)
	rotation:=bool_to_int(upside_down)*2
	rotator_mirror:=mirrored != upside_down
	return face_index*8+rotation*2+bool_to_int(rotator_mirror)
}

stair_variant_indices :: proc(sub_model_state:Stair_Sub_Model_State)->(indices:[16]int,count:int) {
	for facing_index in 0..<4 {
		facing:=cast(Stair_Facing)facing_index
		for upside_down in 0..<2 {
			if sub_model_state == .straight {
				indices[count]=stair_rotator_variant_index(facing,upside_down!=0,false)
				count+=1
			} else {
				for mirrored in 0..<2 {
					indices[count]=stair_rotator_variant_index(facing,upside_down!=0,mirrored!=0)
					count+=1
				}
			}
		}
	}
	return
}

create_stair_face_geometry :: proc() -> Block_Model_HD {

	stair_models:=make([][]Model_Data,3)

	for sub_state_index in 0..<3 {
		sub_state:=cast(Stair_Sub_Model_State)sub_state_index
		source:=stair_create_source_model(sub_state)
		variant_indices,variant_count:=stair_variant_indices(sub_state)
		variants,variants_ok:=generate_model_data_variants(
			source,
			.Rot_XYZRM_Block_State,
			.Rot_XYZRM_Block_State,
			{0.5,0.5,0.5},
			variant_indices[:variant_count],
			true,
			true,
		)
		if !variants_ok {
			log.log(.Error,"Stair model variant generation failed",sub_state_index)
			return {}
		}
		stair_models[sub_state_index]=variants
	}

	tg.update_indexed_gpu_data(&g.geometry_facees)

	block_model:Block_Model
	block_model.model_count=3
	block_model.Sub_Models[.all]=Sub_Model{
		is_used=true,
		sub_model=stair_models,
		type=.Stair_State,
	}

	hd:=reg.add(&g.block_model_reg,block_model,reg.id(DF_Block_Model_Types.Stair_State))
	return hd
}

stair_sub_model_state :: proc(state:Stair_State)->u8 {
	switch state.shape {
	case .straight:
		return cast(u8)Stair_Sub_Model_State.straight
	case .inner_left,.inner_right:
		return cast(u8)Stair_Sub_Model_State.inner_corner
	case .outer_left,.outer_right:
		return cast(u8)Stair_Sub_Model_State.outer_corner
	}
	return cast(u8)Stair_Sub_Model_State.straight
}

stair_orientation :: proc(state:Stair_State)->u8 {
	facing:=int(state.facing)
	upside_down:=bool_to_int(state.upside_down)
	mirrored:=state.shape == .inner_right || state.shape == .outer_right
	if state.shape == .straight {
		return cast(u8)(facing*2+upside_down)
	}
	return cast(u8)(facing*4+upside_down*2+bool_to_int(mirrored))
}

bool_to_int :: proc(value:bool)->int {
	if value {return 1}
	return 0
}
