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








init_map::proc(w_map:^Map){
	for x in-5..=5{
		for y in-5..=5{
			for z in-1..=1{
				w_map.chunks[{x,y,z}] = {}
				chunck, ok := &w_map.chunks[{x,y,z}]
				if ok {
					init_chunck_mesh(chunck,"chunck")
				}
			} 
		} 
	} 
}
mesh_map::proc(w_map:^Map){
	loop:for key,&chunck in w_map.chunks{
		if chunck.mesh_hd == {0,0}{
			log.log(.Warning,"\ncant do mesh_map() chunck mesh hd == {0,0} | key =",key,"\n")
			continue loop
		}
		mesh_chunck(&chunck,pos = key)
	}
}
CHUNCK_VERTEX_TYPE::tg.Vert_Face

init_chunck_mesh::proc(chunck:^Chunck,debug_name := "chunk"){ 
	chunck.mesh_hd = tg.create_mesh(CHUNCK_VERTEX_TYPE, CHUNCK_SIZE * CHUNCK_SIZE * CHUNCK_SIZE * 6,0,debug_name = debug_name)

	for &plane, x in &chunck.data{
		for &col, y in &plane{
			for &vox, z in &col{
				vox.item_hd = sand_hd
			}
		}
	}
}

mesh_chunck::proc(chunck:^Chunck, pos:[3]int){
	mesh:=tg.get_mesh(chunck.mesh_hd)
	text:=tg.get_texture_by_id(.Bad)
	// tg.draw_rect(&mesh.cpu,text,tg.Vertex_Data,{1,0,0,1},tg.Rect{{cast(f32)0,cast(f32)0,cast(f32)0},{100,100}})
	// tg.draw_cube(&mesh.cpu,text,tg.Vertex_Data,{0,1,0,1},tg.Cube{{cast(f32)0,cast(f32)0,cast(f32)0},{100,100,100}},{0,0,0})
	// tg.draw_cube_by_face(&mesh.cpu,text,tg.Vert_Face,{1,1,1,1},tg.Cube{{cast(f32)1,cast(f32)1,cast(f32)1},{1,1,1}},{0,0,0})

	mesh.mesh_mat = lin.matrix4_translate_f32({cast(f32)pos.x,cast(f32)pos.y,cast(f32)pos.z}*CHUNCK_SIZE)
	
	for plane, x in chunck.data{
		// y:int
		// col:=plane[0]
		// z:int
		for col, y in plane{
			// vox:=col[0]
			for vox, z in col{
				item:=reg.get(&g.item_reg,vox.item_hd)
				if item != nil{
					// tg.draw_cube_by_face(&mesh.cpu,nil,item.texture_face_index,tg.Vert_Face,{1,1,1,1},tg.Cube{{cast(f32)x,cast(f32)y,cast(f32)z},{1,1,1}},{0,0,0})
					draw_cube_by_face_item(&mesh.cpu,{cast(u16)x,cast(u16)y,cast(u16)z},vox.item_hd)
				}
				// tg.draw_rect(&mesh.cpu,text,tg.Vertex_Data,{1,1,1,1},tg.Rect{{cast(f32)x,cast(f32)y,cast(f32)z},{1,1}})
			}
		}
	}

	// w_map_overlay_mesh:=tg.get_mesh(w_map.overlay_mesh)

	tg.update_mesh(chunck.mesh_hd)
}


render_chunck::proc(chunck:^Chunck){
	hds:[1]tg.Mesh_Handle
	if chunck.mesh_hd == {0,0}{
		log.log(.Warning,"\ncant do render_chunck() chunck mesh hd == {0,0} \n")
		return
	}
	hds[0]=chunck.mesh_hd
	tg.do_render_pass(&g.vox_pass, &g.cam, hds[:],{&g.texture_facees,&g.geometry_facees},type = .face)
}

render_map::proc(w_map:^Map){
	hds:[dynamic;1000]tg.Mesh_Handle
	loop:for key,&chunck in w_map.chunks{

		if chunck.mesh_hd == {0,0}{
			log.log(.Warning,"\ncant do render_chunck() chunck mesh hd == {0,0} \n")
			continue loop
		}
		append(&hds, chunck.mesh_hd)
	}
	tg.do_render_pass(&g.vox_pass, &g.cam, hds[:],{&g.texture_facees,&g.geometry_facees},type = .face)
}



render_map_debug_overlay::proc(w_map:^Map){
	// tg.do_render_pass(&g.pass, &g.cam, {w_map.overlay_mesh},)
}

draw_cube_by_face_item::proc(
	mesh: ^tg.Mesh_CPU,
	pos:[3]u16,
	item_hd:Item_HD,
){
	faces:[6]tg.Vert_Face
	item:=reg.get(&g.item_reg,item_hd)

	packed_pos := pack_block_pos(pos)

	for &face in &faces{
		face.block_pos = packed_pos
		face.texture_face_index = cast(u32)item.texture_face_index
	}
	for &face,i in &faces{
		face.geometry_face_index = cast(u16)item.model_data.cube_indices[cast(Model_Indices)i]
	}
	
	tg.draw_feces(mesh,faces[:])
}
pack_block_pos :: proc(pos: [3]u16) -> u16 {
    assert(pos.x < 32)
    assert(pos.y < 32)
    assert(pos.z < 32)

	return pos.x | (pos.y << 5) | (pos.z << 10)
}
