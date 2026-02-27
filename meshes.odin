package tg_render

import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import str"core:strings"
import "core:fmt"
import "core:math"
import "core:path/filepath"
import "core:encoding/json"
import lin"core:math/linalg"
import "base:runtime"
import hm "handle_map_static_virtual"
import "core:os"
import "base:intrinsics"

import sc"shader_cross"

import "core:image"
import "core:image/jpeg"
import "core:image/bmp"
import "core:image/png"
import "core:image/tga"

Mesh_Handle :: distinct Handle

// Mesh_CPU::struct{
// 	vertex_buf:[dynamic]u8,
// 	index_buf:[dynamic]u8,
// 	attribute_type:typeid,
// }
 
// Mesh_CPU::struct{
// 	vertex_buf:[dynamic]u8,
// 	index_buf:[dynamic]u32,
// 	attribute_type:typeid,
// }

Mesh_CPU::struct{
	vertex_buf:[dynamic]u8,
	vertex_buf_used:u32,
	vertex_count:u32,
	index_buf:[dynamic]u32,
	index_buf_used:u32,
	attribute_type:typeid,
}


Mesh_GPU::struct{
	is_good:bool,
	vertex_buf:^sdl.GPUBuffer,
	index_buf:^sdl.GPUBuffer,
	transfer_buf:^sdl.GPUTransferBuffer,
	index_count:u32,
	attribute_type:typeid,
}
Mesh::struct{
	handle:Mesh_Handle,
	cpu:Mesh_CPU,
	gpu:Mesh_GPU,
}

TRIANGLE_INDEXES:[]u32:{
	0+4*0, 1+4*0, 2+4*0,
}
QUAD_INDEXES:[]u32:{
	0+4*0, 1+4*0, 2+4*0, 0+4*0, 2+4*0, 3+4*0,
}
CUBE_INDEXES:[]u32:{
	0+4*0, 1+4*0, 2+4*0, 0+4*0, 2+4*0, 3+4*0,
	0+4*1, 1+4*1, 2+4*1, 0+4*1, 2+4*1, 3+4*1,
	0+4*2, 1+4*2, 2+4*2, 0+4*2, 2+4*2, 3+4*2,
	0+4*3, 1+4*3, 2+4*3, 0+4*3, 2+4*3, 3+4*3,
	0+4*4, 1+4*4, 2+4*4, 0+4*4, 2+4*4, 3+4*4,
	0+4*5, 1+4*5, 2+4*5, 0+4*5, 2+4*5, 3+4*5,
}

create_mesh::proc(cpu_mesh:Mesh_CPU) ->(mesh_hd:Mesh_Handle){
	mesh:Mesh
	vertices_byte_size:=len(cpu_mesh.vertex_buf)
	indices_byte_size:=len(cpu_mesh.index_buf) * size_of(cpu_mesh.index_buf[0])
	mesh.cpu = cpu_mesh

	mesh.gpu.vertex_buf = sdl.CreateGPUBuffer(s.gpu_device,{
		usage={.GRAPHICS_STORAGE_READ},
		size = cast(u32)vertices_byte_size,
	})
	mesh.gpu.index_buf = sdl.CreateGPUBuffer(s.gpu_device,{
		usage={.GRAPHICS_STORAGE_READ},
		size = cast(u32)indices_byte_size,
	})
	mesh.gpu.transfer_buf = sdl.CreateGPUTransferBuffer(s.gpu_device,{
		usage = .UPLOAD,
		size = cast(u32)(vertices_byte_size + indices_byte_size),
	})
	mesh_hd=hm.add(&s.meshes, mesh)
	return
}
delete_mesh::proc(mesh_hd:Mesh_Handle){
	mesh:=get_mesh(mesh_hd)
	delete(mesh.cpu.index_buf)
	delete(mesh.cpu.vertex_buf)
	sdl.ReleaseGPUBuffer(s.gpu_device, mesh.gpu.index_buf)
	sdl.ReleaseGPUBuffer(s.gpu_device, mesh.gpu.vertex_buf)
	hm.remove(&s.meshes,mesh_hd)
	
}
update_mesh::proc(mesh:Mesh_Handle){
	mesh:=get_mesh(mesh)
	vertices_byte_size:=len(mesh.cpu.vertex_buf)
	indices_byte_size:=len(mesh.cpu.index_buf) * size_of(mesh.cpu.index_buf[0])
	transfer_mem := transmute([^]byte)sdl.MapGPUTransferBuffer(s.gpu_device, mesh.gpu.transfer_buf, false)
	mem.copy(transfer_mem, raw_data(mesh.cpu.vertex_buf), vertices_byte_size)
	mem.copy(transfer_mem[vertices_byte_size:], raw_data(mesh.cpu.index_buf), indices_byte_size)	
	copy_pass: = sdl.BeginGPUCopyPass(s.copy_cmd_buf)
	sdl.UploadToGPUBuffer(
		copy_pass = copy_pass,
		source = {
			transfer_buffer = mesh.gpu.transfer_buf,
			offset = 0,
		},
		destination = {
			buffer = mesh.gpu.vertex_buf, 
			size = cast(u32)vertices_byte_size,
		},
		cycle = false,
	)
	sdl.UploadToGPUBuffer(
		copy_pass = copy_pass,
		source = {
			transfer_buffer = mesh.gpu.transfer_buf,
			offset = cast(u32)vertices_byte_size,
		},
		destination = {
			buffer = mesh.gpu.index_buf,
			size = cast(u32)indices_byte_size,
		},
		cycle = false,
	)
	
	mesh.gpu.index_count = mesh.cpu.index_buf_used
	sdl.EndGPUCopyPass(copy_pass)
	ok := sdl.SubmitGPUCommandBuffer(s.copy_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")
	sdl.ReleaseGPUTransferBuffer(s.gpu_device, mesh.gpu.transfer_buf)
}
get_mesh::proc(mesh_hd:Mesh_Handle, )->(mesh:^Mesh){
	mesh = hm.get(s.meshes, mesh_hd)
	return
}

append_to_mesh::proc(mesh:^Mesh_CPU,indices:[]u32,vertices:$T/[]$E, shift_indices:bool=true){
	// attribute_info:=type_info_of(mesh.attribute_type,)
	mesh_attribute_info:=type_info_of(mesh.attribute_type)
	attribute_info:=type_info_of(E,)
	
	assert(mesh_attribute_info.size == attribute_info.size, "mesh vertex data size must == incoming vertices size")
	indices:=indices
	if shift_indices{
		for &ind in &indices{
			// ind += mesh.index_buf_used
			ind += mesh.vertex_count
		}
	}
	vertices_byte_size:= len(vertices) * attribute_info.size
	indices_byte_size:= len(indices) * size_of(indices[0])
	
	resize_dynamic_array(&mesh.vertex_buf, vertices_byte_size + cast(int)mesh.vertex_buf_used)
	// resize_dynamic_array(&mesh.index_buf,  len(indices) + cast(int)mesh.index_buf_used)
	
	mem.copy(raw_data(mesh.vertex_buf[mesh.vertex_buf_used:]), raw_data(vertices), vertices_byte_size)
	// mem.copy(raw_data(mesh.index_buf[mesh.index_buf_used:]), raw_data(indices), indices_byte_size)
	append(&mesh.index_buf, ..indices)
	
	mesh.vertex_count += cast(u32)len(vertices)
	mesh.vertex_buf_used += cast(u32)vertices_byte_size
	mesh.index_buf_used += cast(u32)len(indices)
}

append_mesh_to_mesh::proc(mesh_form:^Mesh_CPU,mesh_to:^Mesh_CPU){
	append_to_mesh(mesh_to,mesh_form.index_buf[:],mesh_form.vertex_buf[:])
}

Mesh_vert::union{
	Mesh,
	Mesh_CPU,
}
draw_triangle_vx :: proc(mesh: ^Mesh_CPU, pos:Vec3, verts:$T/[3]$E , origin: Vec3 = {}, rot: f32 = 0,tex:Texture_GPU_Handle = {}) {

	// v0, v1, v2: Vec2
	new_v:[3]E = verts

	when intrinsics.type_has_field(E, "pos"){
	// Rotation adapted from Raylib's "DrawTexturePro"
		if rot == 0 {
			x := pos.x - origin.x
			y := pos.y - origin.y
			z := pos.z - origin.z
			new_v[0].pos = { x + verts[0].pos.x, y + verts[0].pos.y, z + verts[0].pos.z}
			new_v[1].pos = { x + verts[1].pos.x, y + verts[1].pos.y, z + verts[1].pos.z}
			new_v[2].pos = { x + verts[2].pos.x, y + verts[2].pos.y, z + verts[2].pos.z}
		} else {
			sin_rot := math.sin(rot * math.PI)
			cos_rot := math.cos(rot * math.PI)
			x := pos.x
			y := pos.y
			z := pos.z
			dx := -origin.x
			dy := -origin.y
			dz := -origin.z
	
			new_v[0].pos = {
				x + (dx + verts[0].pos.x) * cos_rot - (dy + verts[0].pos.y) * sin_rot,
				y + (dx + verts[0].pos.x) * sin_rot + (dy + verts[0].pos.y) * cos_rot,
				z + dz,
			}
			
			new_v[1].pos = {
				x + (dx + verts[1].pos.x) * cos_rot - (dy + verts[1].pos.y) * sin_rot,
				y + (dx + verts[1].pos.x) * sin_rot + (dy + verts[1].pos.y) * cos_rot,
				z + dz,
			}
	
			new_v[2].pos = {
				x + (dx + verts[2].pos.x) * cos_rot - (dy + verts[2].pos.y) * sin_rot,
				y + (dx + verts[2].pos.x) * sin_rot + (dy + verts[2].pos.y) * cos_rot,
				z + dz,
			}
		}
	}
	draw_verts_by_tri(mesh, 1, new_v[:])
	// append_to_mesh(mesh, {0, 1, 2}, new_v[:])
}

draw_triangle_mat :: proc(mesh: ^Mesh_CPU, verts:$T/[3]$E , mat:matrix[4, 4]f32 = Mat4(1)) {
	// v0, v1, v2: Vec2
	new_v:[3]E = verts

	when intrinsics.type_has_field(E, "pos"){
		new_v[0].pos = (mat * Vec4{new_v[0].pos.x, new_v[0].pos.y, new_v[0].pos.z, 1.0}).xyz
		new_v[1].pos = (mat * Vec4{new_v[1].pos.x, new_v[1].pos.y, new_v[1].pos.z, 1.0}).xyz
		new_v[2].pos = (mat * Vec4{new_v[2].pos.x, new_v[2].pos.y, new_v[2].pos.z, 1.0}).xyz
	}
	draw_verts_by_tri(mesh, 1, new_v[:])
	// append_to_mesh(mesh, {0, 1, 2}, new_v[:])
}


draw_quad_vx :: proc(mesh: ^Mesh_CPU, pos:Vec3, verts:$T/[4]$E , origin: Vec3 = {}, rot: f32 = 0,tex:Texture_GPU_Handle = {}) {

	// v0, v1, v2: Vec2
	new_v:[4]E = verts
	when intrinsics.type_has_field(E, "pos"){
	// Rotation adapted from Raylib's "DrawTexturePro"
		if rot == 0 {
			x := pos.x - origin.x
			y := pos.y - origin.y
			z := pos.z - origin.z
			new_v[0].pos = { x + verts[0].pos.x, y + verts[0].pos.y, z + verts[0].pos.z}
			new_v[1].pos = { x + verts[1].pos.x, y + verts[1].pos.y, z + verts[1].pos.z}
			new_v[2].pos = { x + verts[2].pos.x, y + verts[2].pos.y, z + verts[2].pos.z}
			new_v[3].pos = { x + verts[3].pos.x, y + verts[3].pos.y, z + verts[3].pos.z}
		} else {
			sin_rot := math.sin(rot * math.PI)
			cos_rot := math.cos(rot * math.PI)
			x := pos.x
			y := pos.y
			z := pos.z
			dx := -origin.x
			dy := -origin.y
			dz := -origin.z
	
			new_v[0].pos = {
				x + (dx + verts[0].pos.x) * cos_rot - (dy + verts[0].pos.y) * sin_rot,
				y + (dx + verts[0].pos.x) * sin_rot + (dy + verts[0].pos.y) * cos_rot,
				z + dz,
			}
			
			new_v[1].pos = {
				x + (dx + verts[1].pos.x) * cos_rot - (dy + verts[1].pos.y) * sin_rot,
				y + (dx + verts[1].pos.x) * sin_rot + (dy + verts[1].pos.y) * cos_rot,
				z + dz,
			}
	
			new_v[2].pos = {
				x + (dx + verts[2].pos.x) * cos_rot - (dy + verts[2].pos.y) * sin_rot,
				y + (dx + verts[2].pos.x) * sin_rot + (dy + verts[2].pos.y) * cos_rot,
				z + dz,
			}
			
			new_v[3].pos = {
				x + (dx + verts[3].pos.x) * cos_rot - (dy + verts[3].pos.y) * sin_rot,
				y + (dx + verts[3].pos.x) * sin_rot + (dy + verts[3].pos.y) * cos_rot,
				z + dz,
			}
		}
	}
	append_to_mesh(mesh, {0, 1, 2, 0, 2, 3,}, new_v[:])
}


draw_cube_vx :: proc(mesh: ^Mesh_CPU, verts:$T/[24]$E , mat:matrix[4, 4]f32 = Mat4(1)) {
	new_v:[24]E = verts
	when intrinsics.type_has_field(E, "pos"){
		transform_verts(new_v[:],mat)
	}
	append_to_mesh(mesh, CUBE_INDEXES,new_v[:])
}
draw_verts_by_tri_mat :: proc(mesh: ^Mesh_CPU, $tri_count:u32, verts:$T/[]$E , mat:matrix[4, 4]f32 = Mat4(1)){
	when intrinsics.type_has_field(E, "pos"){
		transform_verts(verts[:],mat)
	}
	draw_verts_by_tri(mesh,tri_count,verts[:])
}
draw_verts_by_tri :: proc(mesh: ^Mesh_CPU, $tri_count:u32, verts:$T/[]$E){
	indexes:[tri_count*3]u32
	for i in 0..<tri_count {
		indexes[i*3+0] = TRIANGLE_INDEXES[0]+i*3
		indexes[i*3+1] = TRIANGLE_INDEXES[1]+i*3
		indexes[i*3+2] = TRIANGLE_INDEXES[2]+i*3
	}
	append_to_mesh(mesh, indexes[:],verts[:])
}
draw_verts_by_quad_mat :: proc(mesh: ^Mesh_CPU, $quad_count:u32, verts:$T/[]$E , mat:matrix[4, 4]f32 = Mat4(1)){
	when intrinsics.type_has_field(E, "pos"){
		transform_verts(verts[:],mat)
	}
	draw_verts_by_quad(mesh,quad_count,verts[:])
}
draw_verts_by_quad :: proc(mesh: ^Mesh_CPU, $quad_count:u32, verts:$T/[]$E){
	indexes:[quad_count*6]u32
	for i in 0..<quad_count {
	
		indexes[i*6+0] = QUAD_INDEXES[0]+i*4
		indexes[i*6+1] = QUAD_INDEXES[1]+i*4
		indexes[i*6+2] = QUAD_INDEXES[2]+i*4
		indexes[i*6+3] = QUAD_INDEXES[3]+i*4
		indexes[i*6+4] = QUAD_INDEXES[4]+i*4
		indexes[i*6+5] = QUAD_INDEXES[5]+i*4
	}
	append_to_mesh(mesh, indexes[:],verts[:])
}
Cube::struct{
	pos:[3]f32,
	w_h_l:[3]f32,
}
draw_cube::proc(mesh: ^Mesh_CPU,tex_id:Texture_ID_Types, $vert_t:typeid, col:[4]f32={1,1,1,1}, cube:Cube, origin: Vec3 = {}, rot:[3]f32 = {}, mat:matrix[4, 4]f32 = Mat4(1)){
	tex:=get_texture(tex_id)
	verts:[24]vert_t
	// mat:Mat4=mat
	translate_m4: Mat4 = lin.matrix4_translate_f32(cube.pos)
	origin_m4:    Mat4 = lin.matrix4_translate_f32(origin)
	scale_m4:     Mat4 = lin.matrix4_scale_f32(cube.w_h_l)
	rotate_q:          = lin.quaternion_from_pitch_yaw_roll_f32(rot.x,rot.y,rot.z)
	rotate_m4:    Mat4 = lin.matrix4_from_quaternion_f32(rotate_q)
	mat :=translate_m4 * rotate_m4 * origin_m4 * scale_m4 * mat
	when intrinsics.type_has_field(vert_t, "pos"){
		//front
		verts[0].pos =  { 0,  0,  0}
		verts[1].pos =  { 0, -1,  0}
		verts[2].pos =  { 1, -1,  0}
		verts[3].pos =  { 1,  0,  0}
		
		//top
		verts[4].pos =  { 0,  0, -1}
		verts[5].pos =  { 0,  0,  0}
		verts[6].pos =  { 1,  0,  0}
		verts[7].pos =  { 1,  0, -1}
		
		//back
		verts[8].pos =  { 1,  0, -1}
		verts[9].pos =  { 1, -1, -1}
		verts[10].pos = { 0, -1, -1}
		verts[11].pos = { 0,  0, -1}
		
		//bot
		verts[12].pos = { 1, -1, -1}
		verts[13].pos = { 1, -1,  0}
		verts[14].pos = { 0, -1,  0}
		verts[15].pos = { 0, -1, -1}
		
		//right
		verts[16].pos = { 1,  0,  0}
		verts[17].pos = { 1, -1,  0}
		verts[18].pos = { 1, -1, -1}
		verts[19].pos = { 1,  0, -1}
		
		//left
		verts[20].pos = { 0,  0, -1}
		verts[21].pos = { 0, -1, -1}
		verts[22].pos = { 0, -1,  0}
		verts[23].pos = { 0,  0,  0}
	}
	when intrinsics.type_has_field(vert_t, "col"){
		verts[0].col = col
		verts[1].col = col
		verts[2].col = col
		verts[3].col = col
		verts[4].col = col
		verts[5].col = col
		verts[6].col = col
		verts[7].col = col
		verts[8].col = col
		verts[9].col = col
		verts[10].col = col
		verts[11].col = col
		verts[12].col = col
		verts[13].col = col
		verts[14].col = col
		verts[15].col = col
		verts[16].col = col
		verts[17].col = col
		verts[18].col = col
		verts[19].col = col
		verts[20].col = col
		verts[21].col = col
		verts[22].col = col
		verts[23].col = col
	}
	when intrinsics.type_has_field(vert_t, "uv"){
		verts[0].uv =  {0,0}
		verts[1].uv =  {0,1}
		verts[2].uv =  {1,1}
		verts[3].uv =  {1,0}
		
		verts[4].uv =  {0,0}
		verts[5].uv =  {0,1}
		verts[6].uv =  {1,1}
		verts[7].uv =  {1,0}
		
		verts[8].uv =  {0,0}
		verts[9].uv =  {0,1}
		verts[10].uv = {1,1}
		verts[11].uv = {1,0}
		
		verts[12].uv = {0,0}
		verts[13].uv = {0,1}
		verts[14].uv = {1,1}
		verts[15].uv = {1,0}
		
		verts[16].uv = {0,0}
		verts[17].uv = {0,1}
		verts[18].uv = {1,1}
		verts[19].uv = {1,0}
		
		verts[20].uv = {0,0}
		verts[21].uv = {0,1}
		verts[22].uv = {1,1}
		verts[23].uv = {1,0}
	}
	when intrinsics.type_has_field(vert_t, "img_index"){
		for &vert in &verts{
			vert.img_index = cast(u32)tex.groop_index
		}
	}
	when intrinsics.type_has_field(vert_t, "layer"){
		for &vert in &verts{
			vert.layer = tex.layer
		}
	}
	draw_verts_by_quad_mat(mesh, 6, verts[:], mat)
}

transform_verts::proc(verts:$T/[]$E , mat:matrix[4, 4]f32 = Mat4(1)){
	vec4:Vec4
	for &v , i in verts{
		vec4 = {v.pos.x,  v.pos.y,  v.pos.z,  1.0}
		v.pos =  (mat * vec4 ).xyz
	}
}
