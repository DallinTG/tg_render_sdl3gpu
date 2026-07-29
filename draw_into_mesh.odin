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
// import hm "handle_map_static_virtual"
import hm "core:container/handle_map"
import "core:os"
import "base:intrinsics"

import sc"shader_cross"

import "core:image"
import "core:image/jpeg"
import "core:image/bmp"
import "core:image/png"
import "core:image/tga"


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

// this is for drawing into a mesh at a offset mostly for a mesh that you know exsactly how it will be layed out
draw_over_verts_by_quad_mat :: proc(mesh: ^Mesh_CPU, $quad_count:u32, verts:$T/[]$E , verts_offset:int, indexes_offset:int, mat:matrix[4, 4]f32 = Mat4(1)){
	when intrinsics.type_has_field(E, "pos"){
		transform_verts(verts[:],mat)
	}

	draw_over_verts_by_quad(mesh,quad_count,verts[:],verts_offset,indexes_offset)
}

// this is for drawing into a mesh at a offset mostly for a mesh that you know exsactly how it will be layed out
draw_over_verts_by_quad :: proc(mesh: ^Mesh_CPU, $quad_count:u32, verts:$T/[]$E, verts_offset:int, indexes_offset:int){
	indexes:[quad_count*6]u32
	for i in 0..<quad_count {
		indexes[i*6+0] = QUAD_INDEXES[0]+i*4
		indexes[i*6+1] = QUAD_INDEXES[1]+i*4
		indexes[i*6+2] = QUAD_INDEXES[2]+i*4
		indexes[i*6+3] = QUAD_INDEXES[3]+i*4
		indexes[i*6+4] = QUAD_INDEXES[4]+i*4
		indexes[i*6+5] = QUAD_INDEXES[5]+i*4
	}

	set_verts_in_mesh(mesh, indexes[:],indexes_offset,verts[:],verts_offset)
}

Cube::struct{
	pos:[3]f32,
	w_h_l:[3]f32,
}
draw_cube::proc(mesh: ^Mesh_CPU, tex:^Texture, $vert_t:typeid, col:[4]f32={1,1,1,1}, cube:Cube, origin: Vec3 = {}, rot:[3]f32 = {}, mat:matrix[4, 4]f32 = Mat4(1)){
	// tex:=get_texture(tex_id)
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
		verts[0].pos =  { 0,  0,  0, 1}
		verts[1].pos =  { 0, -1,  0, 1}
		verts[2].pos =  { 1, -1,  0, 1}
		verts[3].pos =  { 1,  0,  0, 1}
		
		//top
		verts[4].pos =  { 0,  0, -1, 1}
		verts[5].pos =  { 0,  0,  0, 1}
		verts[6].pos =  { 1,  0,  0, 1}
		verts[7].pos =  { 1,  0, -1, 1}
		
		//back
		verts[8].pos =  { 1,  0, -1, 1}
		verts[9].pos =  { 1, -1, -1, 1}
		verts[10].pos = { 0, -1, -1, 1}
		verts[11].pos = { 0,  0, -1, 1}
		
		//bot
		verts[12].pos = { 1, -1, -1, 1}
		verts[13].pos = { 1, -1,  0, 1}
		verts[14].pos = { 0, -1,  0, 1}
		verts[15].pos = { 0, -1, -1, 1}
		
		//right
		verts[16].pos = { 1,  0,  0, 1}
		verts[17].pos = { 1, -1,  0, 1}
		verts[18].pos = { 1, -1, -1, 1}
		verts[19].pos = { 1,  0, -1, 1}
		
		//left
		verts[20].pos = { 0,  0, -1, 1}
		verts[21].pos = { 0, -1, -1, 1}
		verts[22].pos = { 0, -1,  0, 1}
		verts[23].pos = { 0,  0,  0, 1}
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
Rect::struct{
	pos:[3]f32,
	w_h:[2]f32,
}

DEFALT_QUAD_UV:[4]f32={
	0,0,
	// {0,1},
	1,1,
	// {1,0},
}
draw_rect::proc(
	mesh: ^Mesh_CPU,
	tex:^Texture, 
	$vert_t:typeid, 
	col:[4]f32={1,1,1,1}, 
	rect:Rect, 
	origin: Vec3 = {}, 
	rot:[3]f32 = {},
	uv:[4]f32=DEFALT_QUAD_UV, 
	scissor_rect:Vec4 = {},
	mat:matrix[4, 4]f32 = Mat4(1),
){
	// tex:=get_texture(tex_hd)
	verts:[4]vert_t
	// mat:Mat4=mat
	translate_m4: Mat4 = lin.matrix4_translate_f32(rect.pos)
	origin_m4:    Mat4 = lin.matrix4_translate_f32(origin)
	scale_m4:     Mat4 = lin.matrix4_scale_f32({rect.w_h.x,rect.w_h.y,1,})
	rotate_q:          = lin.quaternion_from_pitch_yaw_roll_f32(rot.x,rot.y,rot.z)
	rotate_m4:    Mat4 = lin.matrix4_from_quaternion_f32(rotate_q)
	mat :=translate_m4 * rotate_m4 * origin_m4 * scale_m4 * mat

	when intrinsics.type_has_field(vert_t, "pos"){
		//front
		verts[0].pos =  { 0,  0,  0, 1}
		verts[1].pos =  { 0, -1,  0, 1}
		verts[2].pos =  { 1, -1,  0, 1}
		verts[3].pos =  { 1,  0,  0, 1}
	}
	when intrinsics.type_has_field(vert_t, "col"){
		verts[0].col = col
		verts[1].col = col
		verts[2].col = col
		verts[3].col = col
	}
	when intrinsics.type_has_field(vert_t, "uv"){


		uvs:=[4][2]f32{
			{uv.x,uv.y},
			{uv.x,uv.w},
			{uv.z,uv.w},
			{uv.z,uv.y},
		}

		verts[0].uv =  uvs.x
		verts[1].uv =  uvs.y
		verts[2].uv =  uvs.z
		verts[3].uv =  uvs.w

		ofset:[2]f32={cast(f32)tex.offset.x,cast(f32)tex.offset.y}
		if ofset != {}{
			f32_wh:=[2]f32{cast(f32)tex.w_h.x,cast(f32)tex.w_h.y} 
			new_uv:=f32_wh/(ofset+f32_wh) 

			verts[0].uv *=  new_uv
			verts[1].uv *=  new_uv
			verts[2].uv *=  new_uv
			verts[3].uv *=  new_uv
		}
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

	when intrinsics.type_has_field(vert_t, "scissor_rect"){
		for &vert in &verts {
			vert.scissor_rect = scissor_rect
		}
	}

	draw_verts_by_quad_mat(mesh, 1, verts[:], mat)

}

draw_ring::proc(
	mesh: ^Mesh_CPU,
	tex:^Texture, 
	$vert_t:typeid, 
	center:Vec3,
	$segments:i32,
	innerRadius:f32,
	outerRadius:f32,
	startAngle:f32 = 0, 
	endAngle:f32 = 360,
	uv:[4]f32=DEFALT_QUAD_UV, 
	scissor_rect:Vec4 = {},
	col:[4]f32 = {1,1,1,1},
){
    if (startAngle == endAngle) {return}
    outerRadius:=outerRadius
    innerRadius:=innerRadius
    startAngle:= startAngle
    endAngle:= endAngle
    // tex:=get_texture(tex_hd)

    // Function expects (outerRadius > innerRadius)
    if (outerRadius < innerRadius){
        tmp:f32 = outerRadius
        outerRadius = innerRadius
        innerRadius = tmp

        if (outerRadius <= 0) {outerRadius = 0.1}
    }

    // Function expects (endAngle > startAngle)
    if (endAngle < startAngle){
        // Swap values
        tmp:f32 = startAngle
        startAngle = endAngle
        endAngle = tmp
    }

    minSegments:i32 = cast(i32)math.ceil((endAngle - startAngle)/90)

    // if (segments < minSegments){
        // Calculate the maximum angle between segments based on the error rate (usually 0.5f)
        // th:f32 = acosf(2*powf(1 - SMOOTH_CIRCLE_ERROR_RATE/outerRadius, 2) - 1)
        // segments = cast(i32)math.ceil((endAngle - startAngle)*(2*math.PI/th)/360.0)

        // if (segments <= 0) {segments = minSegments}
    // }

    // Not a ring
    // if (innerRadius <= 0.0){
    	// TODO need to impliment DrawCircleSector
        // DrawCircleSector(center, outerRadius, startAngle, endAngle, segments, color);
        // return
    // }
    stepLength:f32 = (endAngle - startAngle)/cast(f32)segments
    angle:f32 = startAngle

	verts:[4*segments]vert_t
	i:i32 = 0
    for  ( i < segments){	
		when intrinsics.type_has_field(vert_t, "pos"){
			//front
			verts[3+(i*4)].pos =  {center.x + math.cos(math.to_radians(angle))*outerRadius, (center.y + math.sin(math.to_radians(angle))*outerRadius),  center.z, 1}
			verts[2+(i*4)].pos =  {center.x + math.cos(math.to_radians(angle))*innerRadius, (center.y + math.sin(math.to_radians(angle))*innerRadius), center.z , 1}
			verts[1+(i*4)].pos =  {center.x + math.cos(math.to_radians(angle + stepLength))*innerRadius, (center.y + math.sin(math.to_radians(angle + stepLength))*innerRadius),  center.z, 1}
			verts[0+(i*4)].pos =  {center.x + math.cos(math.to_radians(angle + stepLength))*outerRadius, (center.y + math.sin(math.to_radians(angle + stepLength))*outerRadius),  center.z, 1}
		}
		when intrinsics.type_has_field(vert_t, "uv"){
			uvs:=[4][2]f32{
				{uv.x,uv.y},
				{uv.x,uv.w},
				{uv.z,uv.w},
				{uv.z,uv.y},
			}
			verts[0+(i*4)].uv =  uvs.x
			verts[1+(i*4)].uv =  uvs.y
			verts[2+(i*4)].uv =  uvs.z
			verts[3+(i*4)].uv =  uvs.w
			ofset:[2]f32={cast(f32)tex.offset.x,cast(f32)tex.offset.y}
			if ofset != {}{
				f32_wh:=[2]f32{cast(f32)tex.w_h.x,cast(f32)tex.w_h.y} 
				new_uv:=f32_wh/(ofset+f32_wh) 

				verts[0+(i*4)].uv *=  new_uv
				verts[1+(i*4)].uv *=  new_uv
				verts[2+(i*4)].uv *=  new_uv
				verts[3+(i*4)].uv *=  new_uv
			}
		}
		angle += stepLength
	i+=1
	}
	when intrinsics.type_has_field(vert_t, "col"){
		for &vert in &verts{
			vert.col = col
		}
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

	when intrinsics.type_has_field(vert_t, "scissor_rect"){
		for &vert in &verts {
			vert.scissor_rect = scissor_rect
		}
	}
	draw_verts_by_quad(mesh,cast(u32)segments,verts[:])
	// draw_verts_by_quad_mat(mesh, segments, verts[:], mat)

}



Plane_Cell::struct{
	col:[4]f32,
}

draw_plane::proc(
	mesh: ^Mesh_CPU,
	tex:^Texture, 
	$vert_t:typeid, 
	pos:[3]f32,
	plane:[$w][$h]Plane_Cell,
	scale:[2]f32 = {1,1},
	origin: Vec3 = {}, 
	rot:[3]f32 = {},
	uv:[4]f32=DEFALT_QUAD_UV, 
	mat:matrix[4, 4]f32 = Mat4(1),
){
	// tex:=get_texture(tex_id)
	verts:[4]vert_t
	// mat:Mat4=mat
	translate_m4: Mat4 = lin.matrix4_translate_f32(pos)
	origin_m4:    Mat4 = lin.matrix4_translate_f32(origin)
	scale_m4:     Mat4 = lin.matrix4_scale_f32({scale.x,scale.y,1,})
	rotate_q:          = lin.quaternion_from_pitch_yaw_roll_f32(rot.x,rot.y,rot.z)
	rotate_m4:    Mat4 = lin.matrix4_from_quaternion_f32(rotate_q)
	mat :=translate_m4 * rotate_m4 * origin_m4 * scale_m4 * mat

	for y in 0..<h{
		for x in 0..<w{
			when intrinsics.type_has_field(vert_t, "pos"){
				//front
				verts[0].pos =  { 0+cast(f32)x,   0 +(cast(f32)y*-1),  0}
				verts[1].pos =  { 0+cast(f32)x,  -1 +(cast(f32)y*-1),  0}
				verts[2].pos =  { 1+cast(f32)x,  -1 +(cast(f32)y*-1),  0}
				verts[3].pos =  { 1+cast(f32)x,   0 +(cast(f32)y*-1),  0}
			}
			when intrinsics.type_has_field(vert_t, "col"){
				verts[0].col = plane[x][y].col
				verts[1].col = plane[x][y].col
				verts[2].col = plane[x][y].col
				verts[3].col = plane[x][y].col

				// verts[0].col = {1,1,1,1}
				// verts[1].col = {1,1,1,1}
				// verts[2].col = {1,1,1,1}
				// verts[3].col = {1,1,1,1}
			}
			
			when intrinsics.type_has_field(vert_t, "uv"){
				uvs:=[4][2]f32{
					{uv.x,uv.y},
					{uv.x,uv.w},
					{uv.z,uv.w},
					{uv.z,uv.y},
				}
				verts[0].uv =  uvs.x
				verts[1].uv =  uvs.y
				verts[2].uv =  uvs.z
				verts[3].uv =  uvs.w
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
			when intrinsics.type_has_field(vert_t, "scissor_rect"){
				for &vert in &verts {
					vert.scissor_rect = scissor_rect
				}
			}
			draw_verts_by_quad_mat(mesh, cast(u32)(1), verts[:], mat)
		}
	}



}

draw_rect_rounded::proc(
	mesh: ^Mesh_CPU,
	tex:^Texture,
	$vert_t:typeid,
	rec: Rect,
	roundness: f32 = .25,
	col:[4]f32={1,1,1,1},
	origin: Vec3 = {},
	rot: [3]f32 = 0,
	segments: int = 3,
	uv:[4]f32=DEFALT_QUAD_UV,
	scissor_rect:Vec4 = {},
	mat:matrix[4, 4]f32 = Mat4(1),
){
	roundness := roundness
	segments := segments * 2
	verts:[4]vert_t
	
	translate_m4: Mat4 = lin.matrix4_translate_f32(rec.pos)
	origin_m4:    Mat4 = lin.matrix4_translate_f32(origin)
	scale_m4:     Mat4 = lin.matrix4_scale_f32({rec.w_h.x,rec.w_h.y,1,})
	rotate_q:          = lin.quaternion_from_pitch_yaw_roll_f32(rot.x,rot.y,rot.z)
	rotate_m4:    Mat4 = lin.matrix4_from_quaternion_f32(rotate_q)
	// mat :=translate_m4 * rotate_m4 * origin_m4 *  mat
	// mat :=translate_m4 * rotate_m4 * origin_m4 * scale_m4 * mat
	mat :=translate_m4 * rotate_m4 * origin_m4 * mat
	// 
	uvs:=[4][2]f32{
		{uv.x,uv.y},
		{uv.x,uv.w},
		{uv.z,uv.w},
		{uv.z,uv.y},
	}
	
	when intrinsics.type_has_field(vert_t, "col"){
		verts[0].col = col
		verts[1].col = col
		verts[2].col = col
		verts[3].col = col
	}
	
	when intrinsics.type_has_field(vert_t, "uv"){
		verts[0].uv =  uvs.x
		verts[1].uv =  uvs.y
		verts[2].uv =  uvs.z
		verts[3].uv =  uvs.w
	}
	
	// tex:=get_texture(tex_hd)
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
	
	
	if roundness <= 0 { // if not a rounded rectangle will just draw a regular rect
		draw_rect(mesh=mesh,tex=tex, rect=rec, vert_t=vert_t, origin=origin, rot= rot, col=col)
		return
	}
	if roundness >= 1 {roundness = 1 }// clamps the roundness value to 1

	radius:f32 = (rec.w_h.x > rec.w_h.y)? (rec.w_h.y*roundness)/2 : (rec.w_h.x*roundness)/2
	stepLength:f32 = 90 / cast(f32)segments

	// Diagram points and part of the math was adapted from Raylib's "DrawRectangleRounded"
	/*
	Quick sketch to make sense of all of this,
	there are 9 parts to draw, also mark the 12 points we'll use
	      P0____________________P1
	      /|                    |\
	     /1|          2         |3\
	 P7 /__|____________________|__\ P2
	   |   |P8                P9|   |
	   | 8 |          9         | 4 |
	   | __|____________________|__ |
	 P6 \  |P11              P10|  / P3
	     \7|          6         |5/
	      \|____________________|/
	      P5                    P4
	*/
	// Coordinates of the 12 points that define the rounded rect
	// These cords are in locale space {0,0}
	point:[12]Vec3

	point = {
		{ radius,				-rec.w_h.y, 			0},	// P0
		{(rec.w_h.x) - radius,	-rec.w_h.y, 			0},	// P1
		{ rec.w_h.x,						-(rec.w_h.y)+radius, 0},	// P2
		{ rec.w_h.x,						- radius, 			0},	// P3
		{(rec.w_h.x) - radius,	0, 						0},	// P4
		{ radius,				0, 						0},	// P5
		{ 0,								- radius, 			0},	// P6
		{ 0,								-(rec.w_h.y)+radius, 0},	// P7
		{ radius,				-(rec.w_h.y)+radius, 0},	// P8
		{(rec.w_h.x) - radius,	-(rec.w_h.y)+radius, 0},	// P9
		{(rec.w_h.x) - radius,	- radius, 			0},	// P10
		{ radius,				- radius, 			0},	// P11
	}
	
	//INFO this code is fore if you are using a matrix to scale :: ps if you want to use this you need to stop using radius and switch to roundness everywhere
	// point = {
	// 	{ roundness,		-1, 						0},	// P0
	// 	{(1) - roundness,	-1, 						0},	// P1
	// 	{ 1,				-(1)+roundness, 				0},	// P2
	// 	{ 1,				- roundness, 	0},	// P3
	// 	{(1) - roundness,	0, 				0},	// P4
	// 	{ roundness,		0, 				0},	// P5
	// 	{ 0,				- roundness, 	0},	// P6
	// 	{ 0,				-(1)+roundness, 				0},	// P7
	// 	{ roundness,		-(1)+roundness, 				0},	// P8
	// 	{(1) - roundness,	-(1)+roundness, 				0},	// P9
	// 	{(1) - roundness,	- roundness, 	0},	// P10
	// 	{ roundness,		- roundness, 	0},	// P11
	// }


	
	centers:[4]Vec3= { point[8], point[9], point[10], point[11] }// The center of the 4 rounded corners
	angles:[4]f32 = { 180, 270, 0, 90 }
	tl, tr, bl, br :Vec3
	
	// Draw all the 4 corners: 
	// [1] Upper Left Corner, 
	// [3] Upper Right Corner, 
	// [5] Lower Right Corner, 
	// [7] Lower Left Corner
	for k :int= 0; k < 4; k+=1 {
		angle :f32= angles[k]
		center :Vec3= centers[k]
		// NOTE: Every QUAD actually represents two segments
		for i := 0; i < segments/2; i+=1 {
			x := center.x// + rec.pos.x - origin.x
			y := center.y// + rec.pos.y - origin.y
			tl = { x, y, 0, }
			tr = { 
				x + math.cos_f32((math.PI/180)*(angle + stepLength*2))*radius,
				y + math.sin_f32((math.PI/180)*(angle + stepLength*2))*radius,
				0,
			}
			bl = {
				x + math.cos_f32((math.PI/180)*(angle + stepLength))*radius,
				y + math.sin_f32((math.PI/180)*(angle + stepLength))*radius,
				0,
			}
			br = {
				x + math.cos_f32((math.PI/180)*angle)*radius,
				y + math.sin_f32((math.PI/180)*angle)*radius,
				0,
			}
			// when intrinsics.type_has_field(vert_t, "col"){
			// 	verts[0].col = {1,0,0,.5}
			// 	verts[1].col = {1,0,0,.5}
			// 	verts[2].col = {1,0,0,.5}
			// 	verts[3].col = {1,0,0,.5}
			// }
			verts[0].pos.xyz = tl
			verts[1].pos.xyz = br
			verts[2].pos.xyz = bl
			draw_verts_by_tri_mat(mesh, 1, verts[:3],mat)

			verts[0].pos.xyz = tl
			verts[1].pos.xyz = bl
			verts[2].pos.xyz = tr
			draw_verts_by_tri_mat(mesh, 1, verts[:3],mat)

			angle += (stepLength*2)
		}
	}
	// [2] Upper Rectangle
	tl = point[0]
	tr = point[8]
	bl = point[1]
	br = point[9]

// 	when intrinsics.type_has_field(vert_t, "col"){
// 		verts[0].col = {0,0,1,.1}
// 		verts[1].col = {0,1,1,.1}
// 		verts[2].col = {1,1,1,.1}
// 		verts[3].col = {0,0,1,.1}
// }

	verts[0].pos.xyz = tl
	verts[1].pos.xyz = bl
	verts[2].pos.xyz = br
	verts[3].pos.xyz = tr
	draw_verts_by_quad_mat(mesh, 1, verts[:], mat)

	// [4] Right Rectangle
	tl = point[2]
	tr = point[9]
	bl = point[3]
	br = point[10]
	

	verts[0].pos.xyz = tl
	verts[1].pos.xyz = bl
	verts[2].pos.xyz = br
	verts[3].pos.xyz = tr
	draw_verts_by_quad_mat(mesh, 1, verts[:], mat)

	// [6] Bottom Rectangle	
	tl = point[4]
	tr = point[10]
	bl = point[5]
	br = point[11]

	verts[0].pos.xyz = tl
	verts[1].pos.xyz = bl
	verts[2].pos.xyz = br
	verts[3].pos.xyz = tr

	draw_verts_by_quad_mat(mesh, 1, verts[:], mat)

	// [8] Left Rectangle 
	
	tl = point[6]
	tr = point[11]
	bl = point[7]
	br = point[8]

	verts[0].pos.xyz = tl
	verts[1].pos.xyz = bl
	verts[2].pos.xyz = br
	verts[3].pos.xyz = tr

	draw_verts_by_quad_mat(mesh, 1, verts[:], mat)

	// [9] Middle Rectangle

	
	tl = point[9]
	tr = point[8]
	bl = point[10]
	br = point[11]

	verts[0].pos.xyz = tl
	verts[1].pos.xyz = bl
	verts[2].pos.xyz = br
	verts[3].pos.xyz = tr

	draw_verts_by_quad_mat(mesh, 1, verts[:], mat)
}
