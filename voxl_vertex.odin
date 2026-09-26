package tg_render


import "vendor:stb/truetype"
import "base:intrinsics"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
// import hm "handle_map_static_virtual"
import hm "core:container/handle_map"
import "core:time"
import lin"core:math/linalg"
import cl"clay-odin"
import "core:encoding/json"
import "core:os"
import "core:strconv"
import steam "steamworks"
import sdl3i"vendor:sdl3/image"
import "core:sort"
import "core:slice"


Vert_Face::struct{
	block_pos:u16,
	geometry_face_index:u16,
	texture_face_index:u32,
}
Vert_Face_Texure::struct{
	uv:[4][2]f32,
	img_index:u32,
	layer:u32,
	pad_1:u32,
	pad_2:u32,
	tint:[4]f32,

	img_index_2:u32,
	layer_2:u32,
	pad_1_2:u32,
	pad_2_2:u32,
	tint_2:[4]f32,
}
Vert_Face_Geometry::struct{
	pos:[4][4]f32,
	normal: [4]f32,
	starting_shade:f32,
	_pading:[3]f32,
}


Indexed_GPU_Data::struct{
	mesh_hd:Mesh_Handle,
	count:int,
}

init_indexed_gpu_data::proc(vert_type:typeid,debug_name:="Face_Texure_Mesh")->(indexed_gpu_data:Indexed_GPU_Data){
	indexed_gpu_data.mesh_hd = create_mesh(vert_type,debug_name = debug_name)
	return
}
add_indexed_gpu_data::proc(indexed_gpu_data:^Indexed_GPU_Data,data:$T)->(index:int){
	index = indexed_gpu_data.count
	new_data:[1]T
	new_data[0] = data
	mesh:=get_mesh(indexed_gpu_data.mesh_hd)
	append_to_mesh(&mesh.cpu, {}, new_data[:], )
	indexed_gpu_data.count += 1
	return
}
update_indexed_gpu_data::proc(indexed_gpu_data:^Indexed_GPU_Data){
	update_mesh(indexed_gpu_data.mesh_hd)
}
delete_indexed_gpu_data::proc(indexed_gpu_data:^Indexed_GPU_Data){
	delete_mesh(indexed_gpu_data.mesh_hd)
}

draw_cube_by_face::proc(
	mesh: ^Mesh_CPU, 
	tex:^Texture,
	texture_face_index:u16 = 0,
	$vert_t:typeid, 
	col:[4]f32={1,1,1,1}, 
	cube:Cube, 
	origin: Vec3 = {}, 
	rot:[3]f32 = {}, 
	mat:matrix[4, 4]f32 = Mat4(1)
){
	// tex:=get_texture(tex_id)
	faces:[6]vert_t
	// mat:Mat4=mat
	translate_m4: Mat4 = lin.matrix4_translate_f32(cube.pos)
	origin_m4:    Mat4 = lin.matrix4_translate_f32(origin)
	scale_m4:     Mat4 = lin.matrix4_scale_f32(cube.w_h_l)
	rotate_q:          = lin.quaternion_from_pitch_yaw_roll_f32(rot.x,rot.y,rot.z)
	rotate_m4:    Mat4 = lin.matrix4_from_quaternion_f32(rotate_q)
	mat :=translate_m4 * rotate_m4 * origin_m4 * scale_m4 * mat
	when intrinsics.type_has_field(vert_t, "pos"){
		//front
		faces[0].pos[0] =  { 0,  0,  0, 1}
		faces[0].pos[1] =  { 0, -1,  0, 1}
		faces[0].pos[2] =  { 1, -1,  0, 1}
		faces[0].pos[3] =  { 1,  0,  0, 1}
		
		//top
		faces[1].pos[0] =  { 0,  0, -1, 1}
		faces[1].pos[1] =  { 0,  0,  0, 1}
		faces[1].pos[2] =  { 1,  0,  0, 1}
		faces[1].pos[3] =  { 1,  0, -1, 1}
		
		//back
		faces[2].pos[0] =  { 1,  0, -1, 1}
		faces[2].pos[1] =  { 1, -1, -1, 1}
		faces[2].pos[2] = { 0, -1, -1, 1}
		faces[2].pos[3] = { 0,  0, -1, 1}
		
		//bot
		faces[3].pos[0] = { 1, -1, -1, 1}
		faces[3].pos[1] = { 1, -1,  0, 1}
		faces[3].pos[2] = { 0, -1,  0, 1}
		faces[3].pos[3] = { 0, -1, -1, 1}
		
		//right
		faces[4].pos[0] = { 1,  0,  0, 1}
		faces[4].pos[1] = { 1, -1,  0, 1}
		faces[4].pos[2] = { 1, -1, -1, 1}
		faces[4].pos[3] = { 1,  0, -1, 1}
		
		//left
		faces[5].pos[0] = { 0,  0, -1, 1}
		faces[5].pos[1] = { 0, -1, -1, 1}
		faces[5].pos[2] = { 0, -1,  0, 1}
		faces[5].pos[3] = { 0,  0,  0, 1}
	}
	when intrinsics.type_has_field(vert_t, "col"){
		faces[0].col = col
		faces[1].col = col
		faces[2].col = col
		faces[3].col = col
		faces[4].col = col
		faces[5].col = col

	}
	when intrinsics.type_has_field(vert_t, "uv"){
		faces[0].uv[0] =  {0,0}
		faces[0].uv[1] =  {0,1}
		faces[0].uv[2] =  {1,1}
		faces[0].uv[3] =  {1,0}
		
		faces[1].uv[0] =  {0,0}
		faces[1].uv[1] =  {0,1}
		faces[1].uv[2] =  {1,1}
		faces[1].uv[3] =  {1,0}
		
		faces[2].uv[0] =  {0,0}
		faces[2].uv[1] =  {0,1}
		faces[2].uv[2] = {1,1}
		faces[2].uv[3] = {1,0}
		
		faces[3].uv[0] = {0,0}
		faces[3].uv[1] = {0,1}
		faces[3].uv[2] = {1,1}
		faces[3].uv[3] = {1,0}
		
		faces[4].uv[0] = {0,0}
		faces[4].uv[1] = {0,1}
		faces[4].uv[2] = {1,1}
		faces[4].uv[3] = {1,0}
		
		faces[5].uv[0] = {0,0}
		faces[5].uv[1] = {0,1}
		faces[5].uv[2] = {1,1}
		faces[5].uv[3] = {1,0}
	}
	when intrinsics.type_has_field(vert_t, "img_index"){
		for &face in &faces{
			face.img_index = cast(u32)tex.groop_index
		}
	}
	when intrinsics.type_has_field(vert_t, "layer"){
		for &face in &faces{
			face.layer = tex.layer
		}
	}
	when intrinsics.type_has_field(vert_t, "texture_face_index"){
		for &face in &faces{
			face.texture_face_index = cast(u32)texture_face_index
		}
	}
	draw_faces_mat(mesh, faces[:], mat)
}
