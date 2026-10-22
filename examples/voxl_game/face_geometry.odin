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
import cl"../../clay-odin"
import st"core:strings"
import steam "../../steamworks"
import reg "../../registry"
import "base:intrinsics"


Block_Model_HD::hm.Handle32
Block_Model_ID::reg.Reg_ID
Block_Model_Reg::reg.Registry(Block_Model,Block_Model_HD)

Block_Model::struct{
	handle:Block_Model_HD,
	reg_id:Block_Model_ID,
	model_count:u8,
	start:int,
	end:int,
}
DF_Block_Model_Types::enum{
	Bace_Block_State,
	Rot_XZ_Block_State,
	Rot_XYZ_Block_State,
	Slab_States,
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
Model_Data :: struct {
	cube_indices:[Model_Sides]int,
	extra_count:int,
	hit_boxes:[dynamic;6]Hit_Box,
}
Hit_Box::struct{
	box:[6]f32,
	can_occlude:bool,
	can_colide:bool,
}
Face_Data::struct{
	pos:[4][4]f32,
}

face_is_fully_occluded :: proc(face_pos: [4][4]f32, neighbor_model: ^Model_Data, side: Model_Sides, own_hit_box_index: int) -> bool {
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
	offset: [3]f32
	extra := side == .extra

	switch side {
	case .pos_x:
		axis,u_axis,v_axis,boundary,offset = 0,2,1,1,{1,0,0}
	case .neg_x:
		axis,u_axis,v_axis,boundary,offset = 0,2,1,0,{-1,0,0}
	case .pos_y:
		axis,u_axis,v_axis,boundary,offset = 1,0,2,1,{0,1,0}
	case .neg_y:
		axis,u_axis,v_axis,boundary,offset = 1,0,2,0,{0,-1,0}
	case .pos_z:
		axis,u_axis,v_axis,boundary,offset = 2,0,1,1,{0,0,1}
	case .neg_z:
		axis,u_axis,v_axis,boundary,offset = 2,0,1,0,{0,0,-1}
	case .extra:
		offset = {}
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
		for hit_box,i in neighbor_model.hit_boxes {
			if !hit_box.can_occlude || (extra && i == own_hit_box_index) {continue}
			box := hit_box.box
			n_min_axis := box[axis]+offset[axis]
			n_max_axis := box[axis+3]+offset[axis]
			if n_min_axis > boundary || n_max_axis < boundary {continue}

			n_min_u := box[u_axis]+offset[u_axis]
			n_max_u := box[u_axis+3]+offset[u_axis]
			if n_min_u > u0 && n_min_u < u1 {u1 = n_min_u}
			if n_max_u > u0 && n_max_u < u1 {u1 = n_max_u}
		}

		mid_u := (u0+u1)*0.5
		v0 := min_v
		for v0 < max_v {
			v1 := max_v
			for hit_box,i in neighbor_model.hit_boxes {
				if !hit_box.can_occlude || (extra && i == own_hit_box_index) {continue}
				box := hit_box.box
				n_min_axis := box[axis]+offset[axis]
				n_max_axis := box[axis+3]+offset[axis]
				if n_min_axis > boundary || n_max_axis < boundary {continue}

				n_min_v := box[v_axis]+offset[v_axis]
				n_max_v := box[v_axis+3]+offset[v_axis]
				if n_min_v > v0 && n_min_v < v1 {v1 = n_min_v}
				if n_max_v > v0 && n_max_v < v1 {v1 = n_max_v}
			}

			mid_v := (v0+v1)*0.5
			covered := false
			for hit_box,i in neighbor_model.hit_boxes {
				if !hit_box.can_occlude || (extra && i == own_hit_box_index) {continue}
				box := hit_box.box
				n_min_axis := box[axis]+offset[axis]
				n_max_axis := box[axis+3]+offset[axis]
				if n_min_axis > boundary || n_max_axis < boundary {continue}

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
create_vox_face::proc(vert_data:tg.Vert_Face_Geometry)->(index:int){
	index=tg.add_indexed_gpu_data(
		&g.geometry_facees,
		vert_data,
	)
	resize_dynamic_array(&g.all_face_data,max(index,len(g.all_face_data))+1)
	g.all_face_data[index].pos = vert_data.pos
	return
}
create_cube_face_geometry :: proc() -> Block_Model_HD {

	data: Model_Data
	block_model:Block_Model


	data.cube_indices[.pos_x] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 1, 1, 1, 1},
				{ 1, 0, 1, 1},
				{ 1, 0, 0, 1},
				{ 1, 1, 0, 1},
			},
			starting_shade = .65
		},
	)

	data.cube_indices[.neg_x] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 0, 1, 0, 1},
				{ 0, 0, 0, 1},
				{ 0, 0, 1, 1},
				{ 0, 1, 1, 1},
			},
			starting_shade = .65
		},
	)

	data.cube_indices[.pos_y] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 0, 1, 0, 1},
				{ 0, 1, 1, 1},
				{ 1, 1, 1, 1},
				{ 1, 1, 0, 1},
			},
			starting_shade = 1
		},
	)

	data.cube_indices[.neg_y] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 1, 0, 0, 1},
				{ 1, 0, 1, 1},
				{ 0, 0, 1, 1},
				{ 0, 0, 0, 1},
			},
			starting_shade = .5
		},
	)

	data.cube_indices[.pos_z] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 0, 1, 1, 1},
				{ 0, 0, 1, 1},
				{ 1, 0, 1, 1},
				{ 1, 1, 1, 1},
			},
			starting_shade = .8
		},
	)

	data.cube_indices[.neg_z] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 1, 1, 0, 1},
				{ 1, 0, 0, 1},
				{ 0, 0, 0, 1},
				{ 0, 1, 0, 1},
			},
			starting_shade = .8
		},
	)
	tg.update_indexed_gpu_data(&g.geometry_facees)


	start:= len(g.all_block_models)
	append(&g.all_block_models,data)
	end:= len(g.all_block_models)

	block_model.start = start
	block_model.end = end
	block_model.model_count = cast(u8)(end - start)


	hd:=reg.add(&g.block_model_reg,block_model,reg.id(DF_Block_Model_Types.Bace_Block_State))
	return 	hd
}


create_slab_face_geometry :: proc() -> Block_Model_HD  {

	end:int
	start:= len(g.all_block_models)
	block_model:Block_Model

	neg_y: Model_Data

	neg_y.cube_indices[.pos_x] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,.5},{1,.5},{1,0}},
			pos = {
				{ 1, .5, 1, 1},
				{ 1, 0, 1, 1},
				{ 1, 0, 0, 1},
				{ 1, .5, 0, 1},
			},
			starting_shade = .65
		},
	)

	neg_y.cube_indices[.neg_x] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,.5},{1,.5},{1,0}},
			pos = {
				{ 0, .5, 0, 1},
				{ 0, 0, 0, 1},
				{ 0, 0, 1, 1},
				{ 0, .5, 1, 1},
			},
			starting_shade = .65
		},
	)

	neg_y.cube_indices[.pos_y] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 0, .5, 0, 1},
				{ 0, .5, 1, 1},
				{ 1, .5, 1, 1},
				{ 1, .5, 0, 1},
			},
			starting_shade = 1
		},
	)

	neg_y.cube_indices[.neg_y] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 1, 0, 0, 1},
				{ 1, 0, 1, 1},
				{ 0, 0, 1, 1},
				{ 0, 0, 0, 1},
			},
			starting_shade = .5
		},
	)

	neg_y.cube_indices[.pos_z] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,.5},{1,.5},{1,0}},
			pos = {
				{ 0, .5, 1, 1},
				{ 0, 0, 1, 1},
				{ 1, 0, 1, 1},
				{ 1, .5, 1, 1},
			},
			starting_shade = .8
		},
	)

	neg_y.cube_indices[.neg_z] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,.5},{1,.5},{1,0}},
			pos = {
				{ 1, .5, 0, 1},
				{ 1, 0, 0, 1},
				{ 0, 0, 0, 1},
				{ 0, .5, 0, 1},
			},
			starting_shade = .8
		},
	)

	append(&g.all_block_models,neg_y)
	end= len(g.all_block_models)

	pos_y: Model_Data

	pos_y.cube_indices[.pos_x] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv = {{0,.5},{0,1},{1,1},{1,.5}},
			pos = {
				{ 1, 1, 1, 1},
				{ 1, .5, 1, 1},
				{ 1, .5, 0, 1},
				{ 1, 1, 0, 1},
			},
			starting_shade = .65
		},
	)
	
	pos_y.cube_indices[.neg_x] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv = {{0,.5},{0,1},{1,1},{1,.5}},
			pos = {
				{ 0, 1, 0, 1},
				{ 0, .5, 0, 1},
				{ 0, .5, 1, 1},
				{ 0, 1, 1, 1},
			},
			starting_shade = .65
		},
	)
	
	pos_y.cube_indices[.pos_y] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv = {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 0, 1, 0, 1},
				{ 0, 1, 1, 1},
				{ 1, 1, 1, 1},
				{ 1, 1, 0, 1},
			},
			starting_shade = 1
		},
	)
	
	pos_y.cube_indices[.neg_y] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv = {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 1, .5, 0, 1},
				{ 1, .5, 1, 1},
				{ 0, .5, 1, 1},
				{ 0, .5, 0, 1},
			},
			starting_shade = .5
		},
	)
	
	pos_y.cube_indices[.pos_z] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv = {{0,.5},{0,1},{1,1},{1,.5}},
			pos = {
				{ 0, 1, 1, 1},
				{ 0, .5, 1, 1},
				{ 1, .5, 1, 1},
				{ 1, 1, 1, 1},
			},
			starting_shade = .8
		},
	)
	
	pos_y.cube_indices[.neg_z] = create_vox_face(
		tg.Vert_Face_Geometry{
			uv = {{0,.5},{0,1},{1,1},{1,.5}},
			pos = {
				{ 1, 1, 0, 1},
				{ 1, .5, 0, 1},
				{ 0, .5, 0, 1},
				{ 0, 1, 0, 1},
			},
			starting_shade = .8
		},
	)


	append(&g.all_block_models,pos_y)
	end= len(g.all_block_models)


	tg.update_indexed_gpu_data(&g.geometry_facees)
	block_model.start = start
	block_model.end = end
	block_model.model_count = cast(u8)(end - start)


	hd:=reg.add(&g.block_model_reg,block_model,reg.id(DF_Block_Model_Types.Slab_States))
	return 	hd

}
