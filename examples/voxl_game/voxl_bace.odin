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



sand_hd:Item_HD

reg_items::proc(){
	sand_info:Item_Info={
		texture = tg.get_texture_by_id(.Software_Hourglass_Sand_Time_Wait)
	}
	sand_hd=reg.add(&g.item_reg,sand_info,{1,1})
}

Voxel_Modle::union{
	Voxel_Non,
	Voxel_Cube,
}
Voxel_Non::struct{

}
Voxel_Cube::struct{
	texture:^tg.Texture,
}

CHUNCK_SIZE::32

Voxel::struct{
	item_hd:Item_HD,
}
Map::struct{
	chunks:map[[3]int]Chunck,
}
Chunck_Data::[CHUNCK_SIZE][CHUNCK_SIZE][CHUNCK_SIZE]Voxel
Chunck::struct{
	data:Chunck_Data,
	mesh_hd:tg.Mesh_Handle,
}


mesh_map::proc(w_map:^Map){

}
CHUNCK_VERTEX_TYPE::tg.Vert_Face

init_chunck_mesh::proc(chunck:^Chunck,debug_name := "chunk"){
	mesh_cpu:tg.Mesh_CPU={attribute_type = CHUNCK_VERTEX_TYPE}
	mesh_attribute_info:=type_info_of(mesh_cpu.attribute_type)
	// resize(&mesh_cpu.vertex_buf,size_of(CHUNCK_VERTEX_TYPE) * CHUNCK_SIZE * CHUNCK_SIZE * 4) 
	tg.init_buffer(&mesh_cpu.vertex_buf,0,size_of(CHUNCK_VERTEX_TYPE)*CHUNCK_SIZE * CHUNCK_SIZE * CHUNCK_SIZE * 6 *6)
	// resize(&mesh_cpu.index_buf,size_of(CHUNCK_VERTEX_TYPE)*CHUNCK_SIZE * CHUNCK_SIZE * CHUNCK_SIZE * 6 *6) 
	chunck.mesh_hd = tg.create_mesh(mesh_cpu,CHUNCK_SIZE * CHUNCK_SIZE * CHUNCK_SIZE * 6 * 6*6, CHUNCK_SIZE * CHUNCK_SIZE * CHUNCK_SIZE * 6 * 6*6,debug_name = debug_name)

	for &plane, x in &chunck.data{
		for &col, y in &plane{
			for &vox, z in &col{
				vox.item_hd = sand_hd
			}
		}
	}
}

mesh_chunck::proc(chunck:^Chunck){
	mesh:=tg.get_mesh(chunck.mesh_hd)
	text:=tg.get_texture_by_id(.Bad)
	// tg.draw_rect(&mesh.cpu,text,tg.Vertex_Data,{1,0,0,1},tg.Rect{{cast(f32)0,cast(f32)0,cast(f32)0},{100,100}})
	// tg.draw_cube(&mesh.cpu,text,tg.Vertex_Data,{0,1,0,1},tg.Cube{{cast(f32)0,cast(f32)0,cast(f32)0},{100,100,100}},{0,0,0})
	// tg.draw_cube_by_face(&mesh.cpu,text,tg.Vert_Face,{1,1,1,1},tg.Cube{{cast(f32)1,cast(f32)1,cast(f32)1},{1,1,1}},{0,0,0})
	for plane, x in chunck.data{
		for col, y in plane{
			for vox, z in col{
				item:=reg.get(&g.item_reg,vox.item_hd)
				if item != nil{
					tg.draw_cube_by_face(&mesh.cpu,item.texture,tg.Vert_Face,{1,1,1,1},tg.Cube{{cast(f32)x,cast(f32)y,cast(f32)z},{1,1,1}},{0,0,0})
				}
				// tg.draw_rect(&mesh.cpu,text,tg.Vertex_Data,{1,1,1,1},tg.Rect{{cast(f32)x,cast(f32)y,cast(f32)z},{1,1}})
			}
		}
	}

	// w_map_overlay_mesh:=tg.get_mesh(w_map.overlay_mesh)

	tg.update_mesh(chunck.mesh_hd)
}
hds:[1]tg.Mesh_Handle
render_chunck::proc(chunck:^Chunck){
	if chunck.mesh_hd == {0,0}{
		log.log(.Warning,"\ncant do render_chunck() chunck mesh hd == {0,0} \n")
		return
	}
	hds[0]=chunck.mesh_hd
	tg.do_render_pass(&g.vox_pass, &g.cam, hds[:],type = .face)
}

render_map::proc(w_map:^Map){

	// tg.do_render_pass(&g.sand_sim_pass, &g.cam, meshes[:],)
}

render_map_debug_overlay::proc(w_map:^Map){
	// tg.do_render_pass(&g.pass, &g.cam, {w_map.overlay_mesh},)
}
