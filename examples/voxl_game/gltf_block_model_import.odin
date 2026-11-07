package voxl_game

import "core:log"
import "core:math"
import tg "../../../tg_render_sdl3gpu"
import reg "../../registry"
import cgltf "vendor:cgltf"

// WARNING THIS FILE IS AI SLOP 

// This importer intentionally handles static triangle geometry only.
// Imported geometry is stored in Model_Data's .extra range. The six
// cube_indices entries are set to -1, so the mesher/drawing code must
// skip the primary-face path when cube_indices[side] < 0.

Gltf_Import_Triangle :: struct {
	pos: [3][3]f32,
	uv: [3][2]f32,
	has_uv: bool,
}

// Reads a point from a glTF accessor, applies the node's world transform,
// then applies the requested conversion from source units to block units.
gltf_read_position :: proc(
	accessor: ^cgltf.accessor,
	index: uint,
	world: [16]f32,
	unit_scale: f32,
) -> (position: [3]f32, ok: bool) {
	p: [3]f32
	if !cgltf.accessor_read_float(accessor, index, raw_data(p[:]), 3) {
		return
	}

	// glTF matrices are column-major.
	position = {
		(world[0]*p[0] + world[4]*p[1] + world[8]*p[2] + world[12])*unit_scale,
		(world[1]*p[0] + world[5]*p[1] + world[9]*p[2] + world[13])*unit_scale,
		(world[2]*p[0] + world[6]*p[1] + world[10]*p[2] + world[14])*unit_scale,
	}
	ok = true
	return
}

gltf_read_uv :: proc(accessor: ^cgltf.accessor, index: uint) -> (uv: [2]f32, ok: bool) {
	if accessor == nil {
		return
	}
	if !cgltf.accessor_read_float(accessor, index, raw_data(uv[:]), 2) {
		return
	}
	ok = true
	return
}

gltf_stream_index :: proc(primitive: ^cgltf.primitive, stream_index: int) -> uint {
	if primitive.indices != nil {
		return cgltf.accessor_read_index(primitive.indices, uint(stream_index))
	}
	return uint(stream_index)
}

gltf_append_triangle :: proc(
	triangles: ^[dynamic]Gltf_Import_Triangle,
	position_accessor: ^cgltf.accessor,
	uv_accessor: ^cgltf.accessor,
	world: [16]f32,
	unit_scale: f32,
	i0, i1, i2: uint,
) -> bool {
	triangle: Gltf_Import_Triangle

	p0, ok0 := gltf_read_position(position_accessor, i0, world, unit_scale)
	p1, ok1 := gltf_read_position(position_accessor, i1, world, unit_scale)
	p2, ok2 := gltf_read_position(position_accessor, i2, world, unit_scale)
	if !ok0 || !ok1 || !ok2 {
		return false
	}

	triangle.pos = {p0, p1, p2}

	if uv_accessor != nil {
		uv0, uv_ok0 := gltf_read_uv(uv_accessor, i0)
		uv1, uv_ok1 := gltf_read_uv(uv_accessor, i1)
		uv2, uv_ok2 := gltf_read_uv(uv_accessor, i2)
		if !uv_ok0 || !uv_ok1 || !uv_ok2 {
			return false
		}
		triangle.uv = {uv0, uv1, uv2}
		triangle.has_uv = true
	}

	append(triangles, triangle)
	return true
}

// Collects a node's mesh and all children. node_transform_world includes
// parent transforms, so geometry is baked into one model-local coordinate space.
gltf_collect_node_triangles :: proc(
	node: ^cgltf.node,
	unit_scale: f32,
	triangles: ^[dynamic]Gltf_Import_Triangle,
) -> bool {
	if node.mesh != nil {
		world: [16]f32
		cgltf.node_transform_world(node, raw_data(world[:]))

		for primitive_index in 0..<len(node.mesh.primitives) {
			primitive := &node.mesh.primitives[primitive_index]

			if primitive.has_draco_mesh_compression {
				log.log(.Error, "GLTF importer: Draco-compressed primitives are not supported")
				return false
			}

			position_accessor:=gltf_find_accessor(primitive,.position)
			if position_accessor == nil || position_accessor.type != .vec3 {
				log.log(.Error, "GLTF importer: primitive is missing a VEC3 POSITION accessor")
				return false
			}

			uv_accessor:=gltf_find_accessor(primitive,.texcoord)
			if uv_accessor != nil && uv_accessor.type != .vec2 {
				log.log(.Error, "GLTF importer: TEXCOORD_0 is not VEC2")
				return false
			}

			vertex_count := int(position_accessor.count)
			index_count := vertex_count
			if primitive.indices != nil {
				index_count = int(primitive.indices.count)
			}

			switch primitive.type {
			case .triangles:
				for i := 0; i+2 < index_count; i += 3 {
					if !gltf_append_triangle(
						triangles, position_accessor, uv_accessor, world, unit_scale,
						gltf_stream_index(primitive, i),
						gltf_stream_index(primitive, i+1),
						gltf_stream_index(primitive, i+2),
					) {
						log.log(.Error, "GLTF importer: failed reading triangle attributes")
						return false
					}
				}

			case .triangle_strip:
				for i := 0; i+2 < index_count; i += 1 {
					i0 := i
					i1 := i+1
					i2 := i+2
					if (i&1) != 0 {
						i0, i1 = i1, i0
					}
					if !gltf_append_triangle(
						triangles, position_accessor, uv_accessor, world, unit_scale,
						gltf_stream_index(primitive, i0),
						gltf_stream_index(primitive, i1),
						gltf_stream_index(primitive, i2),
					) {
						log.log(.Error, "GLTF importer: failed reading triangle-strip attributes")
						return false
					}
				}

			case .triangle_fan:
				for i := 1; i+1 < index_count; i += 1 {
					if !gltf_append_triangle(
						triangles, position_accessor, uv_accessor, world, unit_scale,
						gltf_stream_index(primitive, 0),
						gltf_stream_index(primitive, i),
						gltf_stream_index(primitive, i+1),
					) {
						log.log(.Error, "GLTF importer: failed reading triangle-fan attributes")
						return false
					}
				}

			case .points, .lines, .line_loop, .line_strip:
				log.log(.Warning, "GLTF importer: skipping non-triangle primitive")
			case .invalid:
				log.log(.Error, "GLTF importer: primitive has invalid topology")
				return false
			}
		}
	}

	for child in node.children {
		if !gltf_collect_node_triangles(child, unit_scale, triangles) {
			return false
		}
	}

	return true
}

gltf_find_accessor :: proc(primitive:^cgltf.primitive,wanted_type:cgltf.attribute_type)->(^cgltf.accessor){
	for attribute in primitive.attributes {
		if attribute.type == wanted_type && attribute.index == 0 {
			return attribute.data
		}
	}
	return nil
}

// Source model forward is +Z. Rotations are around pivot, normally {0.5,0.5,0.5}.
gltf_rotate_point :: proc(
	p: [3]f32,
	pivot: [3]f32,
	model_type: DF_Block_Model_Types,
	variant: int,
) -> [3]f32 {
	dx := p[0]-pivot[0]
	dy := p[1]-pivot[1]
	dz := p[2]-pivot[2]

	#partial switch model_type {
	case .Bace_Block_State:
		return p

	case .Rot_XZ_Block_State:
		switch variant {
		case 0: // pos_x: +Z -> +X
			return {pivot[0]+dz, pivot[1]+dy, pivot[2]-dx}
		case 1: // neg_x: +Z -> -X
			return {pivot[0]-dz, pivot[1]+dy, pivot[2]+dx}
		case 2: // pos_z
			return p
		case 3: // neg_z
			return {pivot[0]-dx, pivot[1]+dy, pivot[2]-dz}
		}

	case .Rot_XYZ_Block_State, .Rot_XYZR_Block_State, .Rot_XYZRM_Block_State, .Slab_States:
		face_index, rotation, mirror := gltf_decode_variant(model_type, variant)
		rotated := gltf_transform_vec({dx, dy, dz}, face_index, rotation, mirror)
		return {pivot[0]+rotated[0], pivot[1]+rotated[1], pivot[2]+rotated[2]}

	case .Stair_State:
		// Stair_State has shape/upside-down variants as well as facing.
		// A single imported mesh cannot correctly synthesize those shapes.
		return p
	}

	return p
}

gltf_side_shade :: proc(side: Model_Sides) -> f32 {
	switch side {
	case .pos_x, .neg_x: return 0.65
	case .pos_y: return 1.0
	case .neg_y: return 0.5
	case .pos_z, .neg_z: return 0.8
	case .extra: return 1.0
	}
	return 1.0
}

gltf_rotation_count :: proc(model_type: DF_Block_Model_Types) -> (count: int, ok: bool) {
	#partial switch model_type {
	case .Bace_Block_State:
		return 1, true
	case .Rot_XZ_Block_State:
		return 4, true
	case .Rot_XYZ_Block_State, .Slab_States:
		return 6, true
	case .Rot_XYZR_Block_State:
		return 24, true
	case .Rot_XYZRM_Block_State:
		return 48, true
	case .Stair_State:
		log.log(.Error, "GLTF importer: Stair_State needs separate straight/inner/outer and upside-down geometry; it cannot be generated by simple 4x rotation")
		return 0, false
	}
	return 0, false
}

gltf_project_uv :: proc(p: [3]f32, side: Model_Sides) -> [2]f32 {
	switch side {
	case .pos_x, .neg_x: return {p[2], p[1]}
	case .pos_y, .neg_y: return {p[0], p[2]}
	case .pos_z, .neg_z: return {p[0], p[1]}
	case .extra: return {p[0], p[1]}
	}
	return {p[0], p[1]}
}

// Converts the parsed glTF scene into the existing Model_Data / Face_Data storage.
// Imported triangles are stored in the .extra range; cube_indices for the six
// primary directions are -1 and must be checked by the mesher/drawing code.
create_block_model_from_gltf_data :: proc(
	data: ^cgltf.data,
	model_type: DF_Block_Model_Types,
	registry_id: reg.Reg_ID,
	unit_scale: f32 = 1.0,
	pivot: [3]f32 = {0.5, 0.5, 0.5},
	add_bounds_hitbox: bool = true,
) -> (hd: Block_Model_HD, ok: bool) {
	variant_count, variant_ok := gltf_rotation_count(model_type)
	
	if !variant_ok {return}
	if data == nil || unit_scale == 0 {return}

	triangles: [dynamic]Gltf_Import_Triangle
	defer delete(triangles)

	if data.scene != nil {
		for root in data.scene.nodes {
			if !gltf_collect_node_triangles(root, unit_scale, &triangles) {
				return
			}
		}
	} else {
		for node_index in 0..<len(data.nodes) {
			node := &data.nodes[node_index]
			if node.parent == nil {
				if !gltf_collect_node_triangles(node, unit_scale, &triangles) {
					return
				}
			}
		}
	}

	if len(triangles) == 0 {
		log.log(.Error, "GLTF importer: no triangle geometry found")
		return
	}
	source_bounds_min: [3]f32 = {max(f32), max(f32), max(f32)}
	source_bounds_max: [3]f32 = {min(f32), min(f32), min(f32)}
	
	for triangle in triangles {
		for point in triangle.pos {
			for axis in 0..<3 {
				source_bounds_min[axis] = min(source_bounds_min[axis],point[axis])
				source_bounds_max[axis] = max(source_bounds_max[axis],point[axis])
			}
		}
	}
	
	center_offset:[3]f32
	center_offset[0] = pivot[0]-(source_bounds_min[0]+source_bounds_max[0])*0.5
	center_offset[1] = -source_bounds_min[1]
	center_offset[2] = pivot[2]-(source_bounds_min[2]+source_bounds_max[2])*0.5

	start := len(g.all_block_models)

	for variant in 0..<variant_count {
		_, _, mirror := gltf_decode_variant(model_type, variant)
		model_data: Model_Data
		model_data.cube_indices[.pos_x] = -1
		model_data.cube_indices[.neg_x] = -1
		model_data.cube_indices[.pos_y] = -1
		model_data.cube_indices[.neg_y] = -1
		model_data.cube_indices[.pos_z] = -1
		model_data.cube_indices[.neg_z] = -1
		model_data.cube_indices[.extra] = -1

		bounds_min: [3]f32 = {max(f32), max(f32), max(f32)}
		bounds_max: [3]f32 = {min(f32), min(f32), min(f32)}

		for triangle in triangles {
			source_p0:=triangle.pos[0]
			source_p1:=triangle.pos[1]
			source_p2:=triangle.pos[2]
			if mirror {source_p1, source_p2 = source_p2, source_p1}
			
			for axis in 0..<3 {
				source_p0[axis] += center_offset[axis]
				source_p1[axis] += center_offset[axis]
				source_p2[axis] += center_offset[axis]
			}
			
			p0 := gltf_rotate_point(source_p0, pivot, model_type, variant)
			p1 := gltf_rotate_point(source_p1, pivot, model_type, variant)
			p2 := gltf_rotate_point(source_p2, pivot, model_type, variant)

			for axis in 0..<3 {
				bounds_min[axis] = min(bounds_min[axis], min(p0[axis], min(p1[axis], p2[axis])))
				bounds_max[axis] = max(bounds_max[axis], max(p0[axis], max(p1[axis], p2[axis])))
			}

			e1: [3]f32 = {p1[0]-p0[0], p1[1]-p0[1], p1[2]-p0[2]}
			e2: [3]f32 = {p2[0]-p0[0], p2[1]-p0[1], p2[2]-p0[2]}
			normal: [3]f32 = {
				e1[1]*e2[2]-e1[2]*e2[1],
				e1[2]*e2[0]-e1[0]*e2[2],
				e1[0]*e2[1]-e1[1]*e2[0],
			}
			normal_length := math.sqrt(normal[0]*normal[0]+normal[1]*normal[1]+normal[2]*normal[2])
			if normal_length <= 0.000001 {continue}
			normal[0] /= normal_length
			normal[1] /= normal_length
			normal[2] /= normal_length

			side := get_model_side_from_direction(normal)

			uv0 := triangle.uv[0]
			uv1 := triangle.uv[1]
			uv2 := triangle.uv[2]
			if !triangle.has_uv {
				uv0 = gltf_project_uv(p0, side)
				uv1 = gltf_project_uv(p1, side)
				uv2 = gltf_project_uv(p2, side)
			} else if mirror {
				uv1, uv2 = uv2, uv1
			}

			face_index := create_vox_face(Vert_Face_Geometry{
				uv = {uv0, uv1, uv2, uv2},
				pos = {
					{p0[0], p0[1], p0[2], 1},
					{p1[0], p1[1], p1[2], 1},
					{p2[0], p2[1], p2[2], 1},
					{p2[0], p2[1], p2[2], 1},
				},
				normal = {normal[0], normal[1], normal[2], 0},
				starting_shade = gltf_side_shade(side),
				sides = side,
			})

			if model_data.extra_count == 0 {
				model_data.cube_indices[.extra] = face_index
			}
			model_data.extra_count += 1
		}

		if model_data.extra_count == 0 {
			log.log(.Error, "GLTF importer: model variant contained no usable triangles")
			return
		}

		if add_bounds_hitbox {
			append(&model_data.hit_boxes, Hit_Box{
				box = {
					bounds_min[0], bounds_min[1], bounds_min[2],
					bounds_max[0], bounds_max[1], bounds_max[2],
				},
				can_occlude = false,
				can_colide = true,
			})
		}

		append(&g.all_block_models, model_data)
	}

	tg.update_indexed_gpu_data(&g.geometry_facees)

	block_model := Block_Model{
		start = start,
		end = len(g.all_block_models),
		model_count = cast(u8)variant_count,
		type = model_type,
	}

	hd = reg.add(&g.block_model_reg, block_model, registry_id)
	ok = true
	return
}

gltf_decode_variant :: proc(model_type:DF_Block_Model_Types,variant:int)->(face_index,rotation:int,mirror:bool) {
	#partial   switch model_type {
	case .Rot_XYZ_Block_State, .Slab_States:
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

gltf_orientation_basis :: proc(face_index:int)->(right,up,forward:[3]f32) {
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

positive_mod_int :: proc(value, divisor:int)->int {
	result := value % divisor
	if result < 0 {
		result += divisor
	}
	return result
}

gltf_transform_vec :: proc(p:[3]f32,face_index,rotation:int,mirror:bool)->[3]f32 {
	right,up,forward:=gltf_orientation_basis(face_index)
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


// File path loader. External .bin buffers are resolved relative to path.
create_block_model_from_gltf_file :: proc(
	path: cstring,
	model_type: DF_Block_Model_Types,
	registry_id: reg.Reg_ID,
	unit_scale: f32 = 1.0,
	pivot: [3]f32 = {0.5, 0.5, 0.5},
	add_bounds_hitbox: bool = true,
) -> (hd: Block_Model_HD, ok: bool) {
	options: cgltf.options
	data, result := cgltf.parse_file(options, path)
	if result != .success || data == nil {
		log.log(.Error, "GLTF importer: parse_file failed", result)
		return
	}
	defer cgltf.free(data)

	result = cgltf.load_buffers(options, data, path)
	if result != .success {
		log.log(.Error, "GLTF importer: load_buffers failed", result)
		return
	}

	result = cgltf.validate(data)
	if result != .success {
		log.log(.Error, "GLTF importer: validation failed", result)
		return
	}

	return create_block_model_from_gltf_data(data, model_type, registry_id, unit_scale, pivot, add_bounds_hitbox)
}

// Raw-memory loader. For a self-contained GLB pass reference_path=nil.
// For raw .gltf JSON that references external .bin buffers, pass the original
// .gltf path so cgltf can resolve those relative buffer URIs.
create_block_model_from_gltf_raw :: proc(
	bytes: []u8,
	model_type: DF_Block_Model_Types,
	registry_id: reg.Reg_ID,
	reference_path: cstring = nil,
	unit_scale: f32 = 1.0,
	pivot: [3]f32 = {0.0, 0.0, 0.0},
	add_bounds_hitbox: bool = true,
) -> (hd: Block_Model_HD, ok: bool) {
	if len(bytes) == 0 {return}

	options: cgltf.options
	data, result := cgltf.parse(options, cast(rawptr)raw_data(bytes), uint(len(bytes)))
	if result != .success || data == nil {
		log.log(.Error, "GLTF importer: parse(raw) failed", result)
		return
	}
	defer cgltf.free(data)

	result = cgltf.load_buffers(options, data, reference_path)
	if result != .success {
		log.log(.Error, "GLTF importer: load_buffers(raw) failed", result)
		return
	}

	result = cgltf.validate(data)
	if result != .success {
		log.log(.Error, "GLTF importer: validation(raw) failed", result)
		return
	}

	return create_block_model_from_gltf_data(data, model_type, registry_id, unit_scale, pivot, add_bounds_hitbox)
}
