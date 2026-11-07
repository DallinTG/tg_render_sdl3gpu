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
Block_Model_Reg::reg.Registry(Block_Model,Block_Model_HD)

Block_Model::struct{
	handle:Block_Model_HD,
	reg_id:Block_Model_ID,
	model_count:u8,
	start:int,
	end:int,
	type:DF_Block_Model_Types,
}
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
Hit_Box::struct{
	box:[6]f32,
	can_occlude:bool,
	can_colide:bool,
}
Face_Data::struct{
	pos:[4][4]f32,
	side:Model_Sides,
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

			item,item_ok:=reg.get(&g.item_reg,block.item)
			if item_ok {
				model,model_ok:=reg.get(&g.block_model_reg,item.model)
				if model_ok {
					model_data:=&g.all_block_models[model.start+cast(int)block.state.state]

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

// create_vox_face::proc(vert_data:Vert_Face_Geometry)->(index:int){
// 	index=tg.add_indexed_gpu_data(
// 		&g.geometry_facees,
// 		vert_data,
// 	)
// 	resize_dynamic_array(&g.all_face_data,max(index,len(g.all_face_data))+1)
// 	g.all_face_data[index].pos = vert_data.pos
// 	g.all_face_data[index].side = vert_data.sides
// 	return
// }

create_vox_face :: proc(vert_data:Vert_Face_Geometry)->(index:int){
	index=tg.add_indexed_gpu_data(&g.geometry_facees,vert_data)

	assert(index == len(g.all_face_data),"geometry face data out of sync")

	append(&g.all_face_data,Face_Data{
		pos = vert_data.pos,
		side = vert_data.sides,
	})

	return
}

create_cube_face_geometry :: proc() -> Block_Model_HD {

	data: Model_Data
	block_model:Block_Model


	data.cube_indices[.pos_x] = create_vox_face(
		Vert_Face_Geometry{
			sides = .pos_x,
			uv =  {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 1, 1, 1, 1},
				{ 1, 0, 1, 1},
				{ 1, 0, 0, 1},
				{ 1, 1, 0, 1},
			},
			starting_shade = .65,
		},
	)

	data.cube_indices[.neg_x] = create_vox_face(
		Vert_Face_Geometry{
			sides = .neg_x,
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
		Vert_Face_Geometry{
			sides = .pos_y,
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
		Vert_Face_Geometry{
			sides = .neg_y,
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
		Vert_Face_Geometry{
			sides = .pos_z,
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
		Vert_Face_Geometry{
			sides = .neg_z,
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
	
	start:= len(g.all_block_models)
	block_model.type = .Bace_Block_State
	
	append(&data.hit_boxes,Hit_Box{can_colide = true, can_occlude = true,box={0,0,0,1,1,1}})
	append(&g.all_block_models,data)
	end:= len(g.all_block_models)

	tg.update_indexed_gpu_data(&g.geometry_facees)
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
		Vert_Face_Geometry{
			sides = .pos_x,
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
		Vert_Face_Geometry{
			sides = .neg_x,
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
		Vert_Face_Geometry{
			sides = .pos_y,
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
		Vert_Face_Geometry{
			sides = .neg_y,
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
		Vert_Face_Geometry{
			sides = .pos_z,
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
		Vert_Face_Geometry{
			sides = .neg_z,
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

	block_model.type = .Slab_States
	append(&neg_y.hit_boxes,Hit_Box{can_colide = true, can_occlude = true,box={0,0,0,1,.5,1}})
	append(&g.all_block_models,neg_y)
	end= len(g.all_block_models)

	pos_y: Model_Data

	pos_y.cube_indices[.pos_x] = create_vox_face(
		Vert_Face_Geometry{
			sides = .pos_x,
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
		Vert_Face_Geometry{
			sides = .neg_x,
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
		Vert_Face_Geometry{
			sides = .pos_y,
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
		Vert_Face_Geometry{
			sides = .neg_y,
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
		Vert_Face_Geometry{
			sides = .pos_z,
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
		Vert_Face_Geometry{
			sides = .neg_z,
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

	block_model.type = .Slab_States
	append(&pos_y.hit_boxes,Hit_Box{can_colide = true, can_occlude = true,box={0,.5,0,1,1,1}})
	append(&g.all_block_models,pos_y)
	end= len(g.all_block_models)


	tg.update_indexed_gpu_data(&g.geometry_facees)
	block_model.start = start
	block_model.end = end
	block_model.model_count = cast(u8)(end - start)


	hd:=reg.add(&g.block_model_reg,block_model,reg.id(DF_Block_Model_Types.Slab_States))
	return 	hd

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

create_stair_face_geometry :: proc() -> Block_Model_HD {

	start:=len(g.all_block_models)

	for upside_down in 0..<2 {
		for rotation in 0..<4 {
			for shape in 0..<5 {

				// Canonical facing: +Z.
				// z=0 is the raised/rear half.
				// x=0 is left, x=1 is right.

				shape_cells:[2][2]bool

				switch shape {
				case 0: // Straight
					shape_cells[0][0]=true
					shape_cells[1][0]=true

				case 1: // Inner left
					shape_cells[0][0]=true
					shape_cells[1][0]=true
					shape_cells[0][1]=true

				case 2: // Inner right
					shape_cells[0][0]=true
					shape_cells[1][0]=true
					shape_cells[1][1]=true

				case 3: // Outer left
					shape_cells[0][0]=true

				case 4: // Outer right
					shape_cells[1][0]=true
				}

				// Rotate the footprint.
				rotated_cells:[2][2]bool

				for x in 0..<2 {
					for z in 0..<2 {
						if !shape_cells[x][z] {continue}

						rx,rz:=x,z

						switch rotation {
						case 1:
							rx=z
							rz=1-x
						case 2:
							rx=1-x
							rz=1-z
						case 3:
							rx=1-z
							rz=x
						}

						rotated_cells[rx][rz]=true
					}
				}

				// Build the actual stair volume.
				solid:[2][2][2]bool

				for x in 0..<2 {
					for z in 0..<2 {
						if upside_down==0 {
							solid[x][0][z]=true
							solid[x][1][z]=rotated_cells[x][z]
						} else {
							solid[x][1][z]=true
							solid[x][0][z]=rotated_cells[x][z]
						}
					}
				}

				surfaces:=stair_collect_surfaces(solid)
				model:Model_Data
				primary:[6]int

				// Select the largest EXTERIOR face for each direction.
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
					model.cube_indices[side]=create_vox_face(stair_make_face(side,surfaces.rects[si][best]))
				}

				// Add all remaining faces to the contiguous extra range.
				first_extra:=-1

				for si in 0..<6 {
					side:=cast(Model_Sides)si

					for i in 0..<surfaces.counts[si] {
						if i==primary[si] {continue}

						face_hd:=create_vox_face(stair_make_face(side,surfaces.rects[si][i]))

						if first_extra<0 {
							first_extra=face_hd
						}

						model.extra_count+=1
					}
				}

				if model.extra_count>0 {
					model.cube_indices[.extra]=first_extra
				}

				// stair_make_hit_boxes(&model,rotated_cells,upside_down!=0)

				// stair_make_hit_boxes(&model,solid)

				// Full half of the stair.
				step_y0:f32
				step_y1:f32
				
				if upside_down == 0 {
					// Normal stair: full lower half.
					append(&model.hit_boxes,Hit_Box{
						can_colide=true,
						can_occlude=true,
						box={0,0,0,1,.5,1},
					})
				
					// Raised portion occupies upper half.
					step_y0=.5
					step_y1=1
				} else {
					// Upside-down stair: full upper half.
					append(&model.hit_boxes,Hit_Box{
						can_colide=true,
						can_occlude=true,
						box={0,.5,0,1,1,1},
					})
				
					// Raised portion occupies lower half.
					step_y0=0
					step_y1=.5
				}
				
				// Add the raised footprint.
				for z in 0..<2 {
					z0:=f32(z)*.5
					z1:=z0+.5
				
					if rotated_cells[0][z] && rotated_cells[1][z] {
						// Both X halves occupied.
						append(&model.hit_boxes,Hit_Box{
							can_colide=true,
							can_occlude=true,
							box={0,step_y0,z0,1,step_y1,z1},
						})
					} else if rotated_cells[0][z] {
						append(&model.hit_boxes,Hit_Box{
							can_colide=true,
							can_occlude=true,
							box={0,step_y0,z0,.5,step_y1,z1},
						})
					} else if rotated_cells[1][z] {
						append(&model.hit_boxes,Hit_Box{
							can_colide=true,
							can_occlude=true,
							box={.5,step_y0,z0,1,step_y1,z1},
						})
					}
				}
				append(&g.all_block_models,model)
			}
		}
	}

	end:=len(g.all_block_models)

	tg.update_indexed_gpu_data(&g.geometry_facees)

	block_model:Block_Model
	block_model.start=start
	block_model.end=end
	block_model.model_count=cast(u8)(end-start)
	block_model.type = .Stair_State

	hd:=reg.add(&g.block_model_reg,block_model,reg.id(DF_Block_Model_Types.Stair_State))
	return hd
}


stair_state_index :: proc(state:Stair_State) -> int {
	index:=int(state.facing)*5+int(state.shape)
	if state.upside_down {
		index+=20
	}
	return index
}

import_test_gltf_model::proc()->(model_hd:Block_Model_HD){
	ok:bool
	model_hd,ok=create_block_model_from_gltf_file("assets/test.glb",.Rot_XYZRM_Block_State, reg.id("test"))

	if !ok {
		log.log(.Error,"Failed to import test.glb")
		return
	}

	log.log(.Info,"Successfully imported test.glb")
	return
}
