// This file is generated. Re-generate it by running:
//	odin run generate_image_info
package sand_sim

Image :: struct {
	width: int,
	height: int,
	id:[2]u32,
	data: []u8,
}


Src_E :: enum {
	 Ui_Shader_vert ,
	 Sand_Sim_Shader_frag ,
	 Shader_vert ,
	 Ui_Shader_frag ,
	 Sand_Sim_Shader_vert ,
	 Shader_frag ,
}

Textures_E :: enum {
	 Bad ,
	 Mine ,
	 White ,
	 Ax_Man ,
	 O0 ,
	 Tile_Bace ,
	 O1 ,
	 Pawn ,
	 World_Tileset ,
	 Castle ,
}

Textures_Dir  := #load_directory("assets/textures")
Textures_Data := [Textures_E]Image {
	.Bad = {  width = 8, height = 8, id = { 2062199185,4244067989},  },
	.Mine = {  width = 32, height = 32, id = { 2062199185,913862576},  },
	.White = {  width = 8, height = 8, id = { 2062199185,1066745794},  },
	.Ax_Man = {  width = 32, height = 32, id = { 2062199185,21418266},  },
	.O0 = {  width = 16, height = 16, id = { 2062199185,423072926},  },
	.Tile_Bace = {  width = 32, height = 32, id = { 2062199185,2377268351},  },
	.O1 = {  width = 16, height = 16, id = { 2062199185,4198148233},  },
	.Pawn = {  width = 32, height = 32, id = { 2062199185,2147541368},  },
	.World_Tileset = {  width = 256, height = 256, id = { 2062199185,1287989370},  },
	.Castle = {  width = 32, height = 32, id = { 2062199185,2379043019},  },
}

