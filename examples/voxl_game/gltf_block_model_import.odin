


package voxl_game

import "core:log"
import "core:math"
import tg "../../../tg_render_sdl3gpu"
import reg "../../registry"
import cgltf "vendor:cgltf"
import "core:strings"

// WARNING THIS FILE IS AI SLOP 

// This importer intentionally handles static triangle geometry only.
// Imported geometry is stored in Model_Data's .extra range. The six
// cube_indices entries are set to -1, so the mesher/drawing code must
// skip the primary-face path when cube_indices[side] < 0.

Gltf_Import_Triangle :: struct {
	pos:[3][3]f32,
	uv:[3][2]f32,
	texture_slot:u8,
	has_uv:bool,
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
	texture_slot:u8
) -> bool {
	triangle: Gltf_Import_Triangle
	triangle.texture_slot=texture_slot

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
	hit_boxes: ^[dynamic;6]Hit_Box,
	texture_slots:^Gltf_Texture_Slots,
) -> bool {
	if gltf_cstring_equals(node.name,"#hitboxes") {
		for child in node.children {
			if len(hit_boxes^) >= cap(hit_boxes^) {break}
			if !gltf_collect_hitbox_entry(child,hit_boxes) {return false}
		}
		return true
	}

	if node.mesh != nil {
		world: [16]f32
		cgltf.node_transform_world(node, raw_data(world[:]))

		for primitive_index in 0..<len(node.mesh.primitives) {
			primitive := &node.mesh.primitives[primitive_index]

			texture_slot:u8
			texcoord_index:=0
			
			if primitive.material != nil && primitive.material.has_pbr_metallic_roughness {
				base_color_texture:=primitive.material.pbr_metallic_roughness.base_color_texture
			
				texcoord_index=int(base_color_texture.texcoord)
			
				slot,slot_ok:=gltf_get_texture_slot(base_color_texture.texture,texture_slots)
				if !slot_ok {return false}
			
				texture_slot=slot
			}

			if primitive.has_draco_mesh_compression {
				log.log(.Error, "GLTF importer: Draco-compressed primitives are not supported")
				return false
			}

			position_accessor:=gltf_find_accessor(primitive,.position)
			if position_accessor == nil || position_accessor.type != .vec3 {
				log.log(.Error, "GLTF importer: primitive is missing a VEC3 POSITION accessor")
				return false
			}

			uv_accessor:=gltf_find_accessor(primitive,.texcoord,texcoord_index)
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
						texture_slot,
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
						texture_slot,
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
						texture_slot,
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
		if !gltf_collect_node_triangles(child,unit_scale,triangles,hit_boxes,texture_slots) {
			return false
		}
	}

	return true
}

gltf_find_accessor :: proc(
	primitive:^cgltf.primitive,
	wanted_type:cgltf.attribute_type,
	attribute_index:int=0,
)->(^cgltf.accessor) {
	for attribute in primitive.attributes {
		if attribute.type == wanted_type && attribute.index == cast(i32)attribute_index {
			return attribute.data
		}
	}
	return nil
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

Gltf_Texture_Slots :: struct {
	textures:[MAX_MODEL_TEXTURES]^cgltf.texture,
	count:u8,
}

gltf_get_texture_slot :: proc(
	texture:^cgltf.texture,
	slots:^Gltf_Texture_Slots,
)->(slot:u8,ok:bool) {
	if texture == nil {
		return 0,true
	}

	for i in 0..<int(slots.count) {
		if slots.textures[i] == texture {
			return cast(u8)i,true
		}
	}

	if slots.count >= MAX_MODEL_TEXTURES {
		log.log(.Error,"GLTF importer: model uses more than 8 textures")
		return
	}

	slot=slots.count
	slots.textures[slot]=texture
	slots.count+=1

	ok=true
	return
}

// Imports one GLTF source state and returns its generated orientation models.
// Faces are stored in the shared face/GPU geometry arrays; Model_Data stays in
// the owning Block_Model.Sub_Models slices.
gltf_create_model_data_variants :: proc(
	data:^cgltf.data,
	model_type:DF_Block_Model_Types,
	unit_scale:f32,
	pivot:[3]f32,
	add_bounds_hitbox:bool,
	custom_hit_boxes:[]Hit_Box,
	world_aligned_uvs:bool=false,
)->(models:[]Model_Data,ok:bool) {
	texture_slots:Gltf_Texture_Slots

	_,variant_ok:=model_orientation_count(model_type)
	if !variant_ok || model_type == .Stair_State {return}
	if data == nil || unit_scale == 0 {return}

	triangles:[dynamic]Gltf_Import_Triangle
	defer delete(triangles)

	source_hit_boxes:[dynamic;6]Hit_Box

	for hit_box in custom_hit_boxes {
		if len(source_hit_boxes) >= cap(source_hit_boxes) {break}
		append(&source_hit_boxes,hit_box)
	}

	if data.scene != nil {
		for root in data.scene.nodes {
			if !gltf_collect_node_triangles(root,unit_scale,&triangles,&source_hit_boxes,&texture_slots) {return}
		}
	} else {
		for node_index in 0..<len(data.nodes) {
			node:=&data.nodes[node_index]
			if node.parent == nil {
				if !gltf_collect_node_triangles(node,unit_scale,&triangles,&source_hit_boxes,&texture_slots) {return}
			}
		}
	}

	if len(triangles) == 0 {
		log.log(.Error,"GLTF importer: no triangle geometry found")
		return
	}

	source_bounds_min:[3]f32={max(f32),max(f32),max(f32)}
	source_bounds_max:[3]f32={min(f32),min(f32),min(f32)}

	for triangle in triangles {
		for point in triangle.pos {
			for axis in 0..<3 {
				source_bounds_min[axis]=min(source_bounds_min[axis],point[axis])
				source_bounds_max[axis]=max(source_bounds_max[axis],point[axis])
			}
		}
	}

	center_offset:[3]f32
	center_offset[0]=pivot[0]-(source_bounds_min[0]+source_bounds_max[0])*.5
	center_offset[1]=-source_bounds_min[1]
	center_offset[2]=pivot[2]-(source_bounds_min[2]+source_bounds_max[2])*.5

	source_model:=model_data_init()

	for triangle in triangles {
		p0:=triangle.pos[0]+center_offset
		p1:=triangle.pos[1]+center_offset
		p2:=triangle.pos[2]+center_offset

		e1:[3]f32={p1[0]-p0[0],p1[1]-p0[1],p1[2]-p0[2]}
		e2:[3]f32={p2[0]-p0[0],p2[1]-p0[1],p2[2]-p0[2]}
		normal:[3]f32={
			e1[1]*e2[2]-e1[2]*e2[1],
			e1[2]*e2[0]-e1[0]*e2[2],
			e1[0]*e2[1]-e1[1]*e2[0],
		}

		normal_length:=math.sqrt(normal[0]*normal[0]+normal[1]*normal[1]+normal[2]*normal[2])
		if normal_length <= .000001 {continue}
		normal[0]/=normal_length
		normal[1]/=normal_length
		normal[2]/=normal_length

		side:=get_model_side_from_direction(normal)
		uv0:=triangle.uv[0]
		uv1:=triangle.uv[1]
		uv2:=triangle.uv[2]

		if !triangle.has_uv {
			uv0=gltf_project_uv(p0,side)
			uv1=gltf_project_uv(p1,side)
			uv2=gltf_project_uv(p2,side)
		}

		face_index:=create_vox_face(Vert_Face_Geometry{
			uv={uv0,uv1,uv2,uv2},
			pos={
				{p0[0],p0[1],p0[2],1},
				{p1[0],p1[1],p1[2],1},
				{p2[0],p2[1],p2[2],1},
				{p2[0],p2[1],p2[2],1},
			},
			normal={normal[0],normal[1],normal[2],0},
			starting_shade=model_side_shade(side),
			sides=side,
		},triangle.texture_slot)

		if source_model.extra_count == 0 {source_model.cube_indices[.extra]=face_index}
		source_model.extra_count+=1
	}

	if source_model.extra_count == 0 {
		log.log(.Error,"GLTF importer: no usable triangles found")
		return
	}

	for hit_box in source_hit_boxes {
		if len(source_model.hit_boxes) >= cap(source_model.hit_boxes) {break}
		append(&source_model.hit_boxes,transform_model_hit_box(hit_box,center_offset,{},.Bace_Block_State,0,unit_scale))
	}

	models,ok=generate_model_data_variants(
		source_model,
		model_type,
		model_type,
		pivot,
		nil,
		add_bounds_hitbox && len(source_model.hit_boxes) == 0,
		world_aligned_uvs,
	)
	return
}

gltf_make_cstring :: proc(value:string)->(bytes:[]u8,value_c:cstring) {
	bytes=make([]u8,len(value)+1)
	copy(bytes[:len(value)],transmute([]u8)value)
	bytes[len(value)]=0
	value_c=cast(cstring)raw_data(bytes)
	return
}

gltf_import_file_state :: proc(
	path:string,
	model_type:DF_Block_Model_Types,
	unit_scale:f32,
	pivot:[3]f32,
	add_bounds_hitbox:bool,
	custom_hit_boxes:[]Hit_Box,
	world_aligned_uvs:bool=false,
)->(models:[]Model_Data,ok:bool) {
	if len(path) == 0 {return}

	path_bytes,path_cstr:=gltf_make_cstring(path)
	defer delete(path_bytes)

	options:cgltf.options
	data,result:=cgltf.parse_file(options,path_cstr)
	if result != .success || data == nil {
		log.log(.Error,"GLTF importer: parse_file failed",path,result)
		return
	}
	defer cgltf.free(data)

	result=cgltf.load_buffers(options,data,path_cstr)
	if result != .success {
		log.log(.Error,"GLTF importer: load_buffers failed",path,result)
		return
	}

	result=cgltf.validate(data)
	if result != .success {
		log.log(.Error,"GLTF importer: validation failed",path,result)
		return
	}

	return gltf_create_model_data_variants(data,model_type,unit_scale,pivot,add_bounds_hitbox,custom_hit_boxes,world_aligned_uvs)
}

// Single-source data loader retained for callers that already parsed cgltf data.
// It registers the imported model as state 0 of the .all mount form.
create_block_model_from_gltf_data :: proc(
	data:^cgltf.data,
	model_type:DF_Block_Model_Types,
	registry_id:reg.Reg_ID,
	unit_scale:f32=1.0,
	pivot:[3]f32={0.5,0.5,0.5},
	add_bounds_hitbox:bool=true,
	custom_hit_boxes:[]Hit_Box=nil,
)->(hd:Block_Model_HD,ok:bool) {

	models,models_ok:=gltf_create_model_data_variants(data,model_type,unit_scale,pivot,add_bounds_hitbox,custom_hit_boxes)
	if !models_ok {return}

	state_models:=make([][]Model_Data,1)
	state_models[0]=models

	block_model:Block_Model
	block_model.model_count=1
	block_model.Sub_Models[.all]=Sub_Model{
		is_used=true,
		sub_model=state_models,
		type=model_type,
	}

	tg.update_indexed_gpu_data(&g.geometry_facees)

	hd=reg.add(&g.block_model_reg,block_model,registry_id)
	ok=true
	return
}

// Each outer entry is one Sub_model_state. Each inner enum entry is the path
// for that state and Mount_Type. An empty path means that mount/state is absent.
create_block_model_from_gltf_file :: proc(
	paths:[][Mount_Type]string,
	model_type:DF_Block_Model_Types,
	registry_id:reg.Reg_ID,
	unit_scale:f32=1.0,
	pivot:[3]f32={0.5,0.5,0.5},
	add_bounds_hitbox:bool=true,
	custom_hit_boxes:[]Hit_Box=nil,
	world_aligned_uvs:bool=false,
)->(hd:Block_Model_HD,ok:bool) {

	if len(paths) == 0 || len(paths) > 255 || unit_scale == 0 {return}

	variant_count,variant_ok:=model_orientation_count(model_type)
	if !variant_ok || model_type == .Stair_State {return}

	block_model:Block_Model
	state_count:=0

	for mount_index in 0..<4 {
		mount:=cast(Mount_Type)mount_index
		state_models:[][]Model_Data
		is_used:=false

		for state_index in 0..<len(paths) {
			path:=paths[state_index][mount]
			if len(path) == 0 {continue}

			models,models_ok:=gltf_import_file_state(path,model_type,unit_scale,pivot,add_bounds_hitbox,custom_hit_boxes,world_aligned_uvs)
			if !models_ok {return}
			if len(models) != variant_count {return}

			if !is_used {state_models=make([][]Model_Data,len(paths))}
			state_models[state_index]=models
			is_used=true
			state_count=max(state_count,state_index+1)
		}

		if is_used {
			block_model.Sub_Models[mount]=Sub_Model{
				is_used=true,
				sub_model=state_models,
				type=model_type,
			}
		}
	}

	any_form:=false
	for mount_index in 0..<4 {
		if block_model.Sub_Models[cast(Mount_Type)mount_index].is_used {
			any_form=true
			break
		}
	}

	if !any_form {
		log.log(.Error,"GLTF importer: no model paths were supplied")
		return
	}

	block_model.model_count=cast(u8)state_count

	tg.update_indexed_gpu_data(&g.geometry_facees)

	hd=reg.add(&g.block_model_reg,block_model,registry_id)
	ok=true
	return
}

gltf_import_raw_state :: proc(
	source_bytes:[]u8,
	reference_path:string,
	model_type:DF_Block_Model_Types,
	unit_scale:f32,
	pivot:[3]f32,
	add_bounds_hitbox:bool,
	custom_hit_boxes:[]Hit_Box,
)->(models:[]Model_Data,ok:bool) {
	if len(source_bytes) == 0 {return}

	options:cgltf.options
	data,result:=cgltf.parse(options,cast(rawptr)raw_data(source_bytes),uint(len(source_bytes)))
	if result != .success || data == nil {
		log.log(.Error,"GLTF importer: parse(raw) failed",result)
		return
	}
	defer cgltf.free(data)

	reference_path_cstr:cstring
	reference_path_bytes:[]u8

	if len(reference_path) > 0 {
		reference_path_bytes,reference_path_cstr=gltf_make_cstring(reference_path)
	}
	defer delete(reference_path_bytes)

	result=cgltf.load_buffers(options,data,reference_path_cstr)
	if result != .success {
		log.log(.Error,"GLTF importer: load_buffers(raw) failed",result)
		return
	}

	result=cgltf.validate(data)
	if result != .success {
		log.log(.Error,"GLTF importer: validation(raw) failed",result)
		return
	}

	return gltf_create_model_data_variants(data,model_type,unit_scale,pivot,add_bounds_hitbox,custom_hit_boxes)
}

// Raw loader with the same [state][Mount_Type] layout as the file loader.
// `reference_paths` is optional; supply the corresponding .gltf path for
// entries that reference external .bin buffers.
create_block_model_from_gltf_raw_forms :: proc(
	bytes:[][Mount_Type][]u8,
	model_type:DF_Block_Model_Types,
	registry_id:reg.Reg_ID,
	reference_paths:[][Mount_Type]string=nil,
	unit_scale:f32=1.0,
	pivot:[3]f32={0.5,0.5,0.5},
	add_bounds_hitbox:bool=true,
	custom_hit_boxes:[]Hit_Box=nil,
)->(hd:Block_Model_HD,ok:bool) {

	if len(bytes) == 0 || len(bytes) > 255 || unit_scale == 0 {return}

	variant_count,variant_ok:=model_orientation_count(model_type)
	if !variant_ok || model_type == .Stair_State {return}

	block_model:Block_Model
	state_count:=0

	for mount_index in 0..<4 {
		mount:=cast(Mount_Type)mount_index
		state_models:[][]Model_Data
		is_used:=false

		for state_index in 0..<len(bytes) {
			source_bytes:=bytes[state_index][mount]
			if len(source_bytes) == 0 {continue}

			reference_path: string
			if state_index < len(reference_paths) {
				reference_path=reference_paths[state_index][mount]
			}

			models,models_ok:=gltf_import_raw_state(source_bytes,reference_path,model_type,unit_scale,pivot,add_bounds_hitbox,custom_hit_boxes)
			if !models_ok {return}
			if len(models) != variant_count {return}

			if !is_used {state_models=make([][]Model_Data,len(bytes))}
			state_models[state_index]=models
			is_used=true
			state_count=max(state_count,state_index+1)
		}

		if is_used {
			block_model.Sub_Models[mount]=Sub_Model{
				is_used=true,
				sub_model=state_models,
				type=model_type,
			}
		}
	}

	any_form:=false
	for mount_index in 0..<4 {
		if block_model.Sub_Models[cast(Mount_Type)mount_index].is_used {
			any_form=true
			break
		}
	}

	if !any_form {
		log.log(.Error,"GLTF importer: no raw model data was supplied")
		return
	}

	block_model.model_count=cast(u8)state_count

	tg.update_indexed_gpu_data(&g.geometry_facees)

	hd=reg.add(&g.block_model_reg,block_model,registry_id)
	ok=true
	return
}

// Single-source raw loader retained for callers that already have one GLTF/GLB buffer.
create_block_model_from_gltf_raw :: proc(
	bytes:[]u8,
	model_type:DF_Block_Model_Types,
	registry_id:reg.Reg_ID,
	reference_path:cstring=nil,
	unit_scale:f32=1.0,
	pivot:[3]f32={0.5,0.5,0.5},
	add_bounds_hitbox:bool=true,
	custom_hit_boxes:[]Hit_Box=nil,
)->(hd:Block_Model_HD,ok:bool) {

	if len(bytes) == 0 {return}

	raw_models:[1][Mount_Type][]u8
	raw_models[0][.all]=bytes

	reference_paths:[1][Mount_Type]string
	if reference_path != nil {
		reference_paths[0][.all]=string(reference_path)
	}

	return create_block_model_from_gltf_raw_forms(raw_models[:],model_type,registry_id,reference_paths[:],unit_scale,pivot,add_bounds_hitbox,custom_hit_boxes)
}


gltf_collect_hitbox_bounds :: proc(
	node:^cgltf.node,
	bounds_min:^[3]f32,
	bounds_max:^[3]f32,
	found:^bool,
)->bool {
	if node.mesh != nil {
		world:[16]f32
		cgltf.node_transform_world(node,raw_data(world[:]))

		for primitive_index in 0..<len(node.mesh.primitives) {
			primitive:=&node.mesh.primitives[primitive_index]

			

			if primitive.has_draco_mesh_compression {
				log.log(.Warning,"GLTF importer: skipping Draco-compressed hitbox mesh",node.name)
				continue
			}

			position_accessor:=gltf_find_accessor(primitive,.position)
			if position_accessor == nil || position_accessor.type != .vec3 {
				log.log(.Warning,"GLTF importer: hitbox mesh is missing POSITION",node.name)
				continue
			}

			for vertex_index in 0..<int(position_accessor.count) {
				position,position_ok:=gltf_read_position(position_accessor,uint(vertex_index),world,1.0)
				if !position_ok {
					log.log(.Error,"GLTF importer: failed reading hitbox vertex",node.name)
					return false
				}

				for axis in 0..<3 {
					bounds_min^[axis]=min(bounds_min^[axis],position[axis])
					bounds_max^[axis]=max(bounds_max^[axis],position[axis])
				}

				found^=true
			}
		}
	}

	for child in node.children {
		if !gltf_collect_hitbox_bounds(child,bounds_min,bounds_max,found) {return false}
	}

	return true
}

gltf_collect_hitbox_entry :: proc(
	node:^cgltf.node,
	hit_boxes:^[dynamic;6]Hit_Box,
)->bool {
	if len(hit_boxes^) >= cap(hit_boxes^) {return true}

	bounds_min:[3]f32={max(f32),max(f32),max(f32)}
	bounds_max:[3]f32={min(f32),min(f32),min(f32)}
	found:=false

	if !gltf_collect_hitbox_bounds(node,&bounds_min,&bounds_max,&found) {
		return false
	}

	if found && len(hit_boxes^) < cap(hit_boxes^) {
		append(hit_boxes,Hit_Box{
			box={
				bounds_min[0],bounds_min[1],bounds_min[2],
				bounds_max[0],bounds_max[1],bounds_max[2],
			},
			can_occlude=!gltf_cstring_contains(node.name,"#o"),
			can_colide=!gltf_cstring_contains(node.name,"#c"),
		})
	}

	return true
}

gltf_cstring_contains :: proc(value:cstring,needle:string)->bool {
	if value == nil {return false}
	return strings.contains(string(value),needle)
}

gltf_cstring_equals :: proc(value:cstring,expected:string)->bool {
	if value == nil {return false}
	return string(value) == expected
}


import_test_gltf_model::proc()->(model_hd:Block_Model_HD){
	test_paths:[1][Mount_Type]string
	test_paths[0][.all]="assets/lantern_floor_model.glb"

	variant_ok:bool
	model_hd,variant_ok=create_block_model_from_gltf_file(test_paths[:],.Rot_XYZRM_Block_State,reg.id("test"))

	if !variant_ok {
		log.log(.Error,"Failed to import test.glb")
		return
	}

	log.log(.Info,"Successfully imported test.glb")
	return
}
