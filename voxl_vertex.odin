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


Vert_Face::struct  #align(16){
	// block_pos:[3]u8,
	pos:[4][4]f32,
	uv:[4][2]f32,
	modl_index:u32,
	img_index:u32,
	layer:u32,
	pad_ :u32,
}

Vert_Modl::struct{
	pos:[4][4]f32,
	uv:[4][2]f32,
}


draw_cube_by_face::proc(
	mesh: ^Mesh_CPU, 
	tex:^Texture, 
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
		// verts[6].col = col
		// verts[7].col = col
		// verts[8].col = col
		// verts[9].col = col
		// verts[10].col = col
		// verts[11].col = col
		// verts[12].col = col
		// verts[13].col = col
		// verts[14].col = col
		// verts[15].col = col
		// verts[16].col = col
		// verts[17].col = col
		// verts[18].col = col
		// verts[19].col = col
		// verts[20].col = col
		// verts[21].col = col
		// verts[22].col = col
		// verts[23].col = col
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
	draw_faces_mat(mesh, faces[:], mat)
}
