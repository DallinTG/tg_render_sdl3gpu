// This file is generated. Re-generate it by running:
//	odin run generate_image_info
package voxl_game

import tg"../../../tg_render_sdl3gpu"

Image :: struct {
	width: int,
	height: int,
	id:[2]u32,
	hd:tg.Texture_HD,//this will be set at runtime
	data: []u8,
}


Src :: enum {
	 Ui_Shader_vert ,
	 Vox_frag ,
	 Sand_Sim_Shader_frag ,
	 Shader_vert ,
	 Ui_Shader_frag ,
	 Vox_vert ,
	 Sand_Sim_Shader_vert ,
	 Shader_frag ,
}

Textures :: enum {
	 Stone_Slate ,
	 Grass_Side_Overlay ,
	 Dirt ,
	 Grass_Overlay ,
}

Textures_Dir  := #load_directory("assets/textures")
Textures_Dat := [Textures]Image {
	.Stone_Slate = {  width = 16, height = 16, id = { 2062199185,410206797},  },
	.Grass_Side_Overlay = {  width = 16, height = 16, id = { 2062199185,303175764},  },
	.Dirt = {  width = 16, height = 16, id = { 2062199185,609455824},  },
	.Grass_Overlay = {  width = 16, height = 16, id = { 2062199185,1424846840},  },
}

