

// cbuffer UBO : register(b0, space1){ 
// 	float4x4 mvp;
// };

// static const uint CORNER_MAP[6] = { 0, 1, 2, 2, 3, 0 };
// struct Face {
// 	uint packed_block_pos__geometry_face_index;
// 	uint texture_face_index;
// };

// struct Face_Texure {
// 	float2 uv0;  float2 uv1;  float2 uv2;  float2 uv3;  

//     uint   img_index;
//     uint   layer;
//    	uint _padding_1;
// 	uint _padding_2;
//     float4 tint;

//     uint   img_index_2;
//     uint   layer_2;
//    	uint _padding_1_2;
// 	uint _padding_2_2;
//     float4 tint_2;
// };

// struct Face_Geometry {
// 	float4 pos0;
// 	float4 pos1;
// 	float4 pos2;
// 	float4 pos3;

// 	float4 normal;
// 	float sarting_shade;
// 	float _padding_1;
// 	float _padding_2;
// 	float _padding_3;
// };
// struct Chunk_Data{
// 	int   pos_x;
// 	int   pos_y;
// 	int   pos_z;
// 	int   size;
// };


// StructuredBuffer<Face> Faces : register(t0, space0);
// StructuredBuffer<Face_Texure> face_texure : register(t1, space0);
// StructuredBuffer<Face_Geometry> face_geometry : register(t2, space0);
// StructuredBuffer<Chunk_Data> chunk_data : register(t3, space0);

// struct Output{
// 	float4 position : SV_Position;
// 	float4 color : TEXCOORD0;
// 	float2 uv : TEXCOORD1;

// 	uint   img_index : TEXCOORD2;
// 	uint   layer: TEXCOORD3;
// 	float4 img_1_tint : TEXCOORD4;

// 	uint   img_index_2 : TEXCOORD5;
// 	uint   layer_2: TEXCOORD6;
// 	float4 img_2_tint : TEXCOORD7;


// 	float3 normal : TEXCOORD8;
// 	uint   draw_index : TEXCOORD9;
// 	float   shading: TEXCOORD10;
// };

// Output main(

// 	uint vid : SV_VertexID,

// 	[[vk::builtin("DrawIndex")]] uint draw_index : TEXCOORD6

// ) {

// // Output main(uint vid : SV_VertexID) {

// 	uint face_index = vid / 6;

// 	uint corner_id = CORNER_MAP[vid % 6];

// 	Face face = Faces[face_index];

// 	// Unpack block position and geometry index.
// 	uint packed_pos = face.packed_block_pos__geometry_face_index & 0xFFFF;
// 	uint geometry_face_index = face.packed_block_pos__geometry_face_index >> 16;

// 	// Unpack texture index.
// 	uint texture_face_index = face.texture_face_index & 0xFFFF;

// 	Face_Geometry geometry = face_geometry[geometry_face_index];
// 	Face_Texure tex = face_texure[texture_face_index];

// 	Output output;

// 	// Unpack block position.
// 	uint block_x =  packed_pos        & 0x1F;
// 	uint block_y = (packed_pos >> 5)  & 0x1F;
// 	uint block_z = (packed_pos >> 10) & 0x1F;

// 	float3 block_pos = float3(
// 		block_x,
// 		block_y,
// 		block_z
// 	);

// 	float4 final_pos = float4(0, 0, 0, 1);
// 	float2 final_uv = float2(0, 0);

// 	if (corner_id == 0) {
// 		final_pos = geometry.pos0;
// 		final_uv = tex.uv0;
// 	}
// 	else if (corner_id == 1) {
// 		final_pos = geometry.pos1;
// 		final_uv = tex.uv1;
// 	}
// 	else if (corner_id == 2) {
// 		final_pos = geometry.pos2;
// 		final_uv = tex.uv2;
// 	}
// 	else if (corner_id == 3) {
// 		final_pos = geometry.pos3;
// 		final_uv = tex.uv3;
// 	}

// 	final_pos.xyz += block_pos;

// 	final_pos.xyz += float3(
// 	    mul(chunk_data[draw_index].pos_x , 32),
// 	    mul(chunk_data[draw_index].pos_y , 32),
// 	    mul(chunk_data[draw_index].pos_z , 32)
// 	);	


// 	output.position = mul(mvp, final_pos);
// 	output.uv = final_uv;


// 	output.img_index = tex.img_index;
// 	output.layer = tex.layer;
// 	output.img_1_tint = tex.tint;

// 	output.img_index_2 = tex.img_index_2;
// 	output.layer_2 = tex.layer_2;
// 	output.img_2_tint = tex.tint_2;

// 	output.color = float4(1, 1, 1, 1);

// 	output.normal = geometry.normal.xyz;

// 	output.draw_index = draw_index;
// 	output.shading = geometry.sarting_shade;
// 	return output;
// }






//-----------------------------------------------------------------------------------------------------------------




cbuffer UBO : register(b0, space1){ 
	float4x4 mvp;
};

static const uint CORNER_MAP[6] = { 0, 1, 2, 2, 3, 0 };
struct Face {
	uint packed_block_pos__geometry_face_index;
	uint texture_face_index;
};

struct Face_Texure {
	float2 uv0;  float2 uv1;  float2 uv2;  float2 uv3;  

    uint   img_index;
    uint   layer;
   	uint _padding_1;
	uint _padding_2;
    float4 tint;

    uint   img_index_2;
    uint   layer_2;
   	uint _padding_1_2;
	uint _padding_2_2;
    float4 tint_2;
    
};

struct Face_Geometry {
	float4 pos0;
	float4 pos1;
	float4 pos2;
	float4 pos3;

	float4 normal;
	float sarting_shade;
	float _padding_1;
	float _padding_2;
	float _padding_3;
};
struct Chunk_Data{
	int   pos_x;
	int   pos_y;
	int   pos_z;
	int   size;
};


StructuredBuffer<Face> Faces : register(t0, space0);
StructuredBuffer<Face_Texure> face_texure : register(t1, space0);
StructuredBuffer<Face_Geometry> face_geometry : register(t2, space0);
StructuredBuffer<Chunk_Data> chunk_data : register(t3, space0);

struct Output{
	float4 position : SV_Position;
	float4 color : TEXCOORD0;
	float2 uv : TEXCOORD1;
	uint size : TEXCOORD2;

	uint   img_index : TEXCOORD3;
	uint   layer: TEXCOORD4;
	float4 img_1_tint : TEXCOORD5;

	uint   img_index_2 : TEXCOORD6;
	uint   layer_2: TEXCOORD7;
	float4 img_2_tint : TEXCOORD8;


	float3 normal : TEXCOORD9;
	uint   draw_index : TEXCOORD10;
	float   shading: TEXCOORD11;

	float2 face_uv : TEXCOORD12;

	// float clip_u : SV_ClipDistance0;
	// float clip_v : SV_ClipDistance1;
	// float4 clip_box : TEXCOORD11;

};

// Output main(

// 	uint vid : SV_VertexID,

// 	[[vk::builtin("DrawIndex")]] uint draw_index : TEXCOORD6

// ) {
// 	Output output;

// 	uint face_index = vid / 3;
// 	uint corner_id = vid % 3;
// 	Face face = Faces[face_index];

// 	// Unpack block position and geometry index.
// 	uint packed_pos = face.packed_block_pos__geometry_face_index & 0xFFFF;
// 	uint geometry_face_index = face.packed_block_pos__geometry_face_index >> 16;

// 	// Unpack texture index.
// 	uint texture_face_index = face.texture_face_index & 0xFFFF;

// 	Face_Geometry geometry = face_geometry[geometry_face_index];
// 	Face_Texure tex = face_texure[texture_face_index];

// 	Chunk_Data chunk = chunk_data[draw_index];
// 	float lod_size = float(chunk.size);

// 	// Unpack block position.
// 	uint block_x =  packed_pos        & 0x1F;
// 	uint block_y = (packed_pos >> 5)  & 0x1F;
// 	uint block_z = (packed_pos >> 10) & 0x1F;

// 	float3 block_pos = float3(
// 		block_x,
// 		block_y,
// 		block_z
// 	);

// 	float3 edge1 = geometry.pos1.xyz - geometry.pos0.xyz;
// 	float3 edge3 = geometry.pos3.xyz - geometry.pos0.xyz;

// 	float4 final_pos = float4(0, 0, 0, 1);
// 	float2 final_uv = float2(0, 0);
// 	float2 face_uv = float2(0, 0);

// 	// float clip_u = 0;
// 	// float clip_v = 0;

// 	if (corner_id == 0) {
// 		final_pos.xyz = geometry.pos0.xyz;
// 		final_uv = tex.uv0;
// 		face_uv = float2(0, 0);
// 	}
// 	else if (corner_id == 1) {
// 		final_pos.xyz = geometry.pos0.xyz + edge1 * 2.0;
// 		final_uv = tex.uv0 + (tex.uv1 - tex.uv0) * 2.0;
// 		face_uv = float2(2, 0);
// 	}
// 	else {
// 		final_pos.xyz = geometry.pos0.xyz + edge3 * 2.0;
// 		final_uv = tex.uv0 + (tex.uv3 - tex.uv0) * 2.0;
// 		face_uv = float2(0, 2);
// 	}

// 	final_pos.xyz += block_pos;

// 	final_pos.xyz *= lod_size;

// 	final_pos.xyz += float3(
// 	    mul(chunk_data[draw_index].pos_x , 32),
// 	    mul(chunk_data[draw_index].pos_y , 32),
// 	    mul(chunk_data[draw_index].pos_z , 32)
// 	);	


// 	output.position = mul(mvp, final_pos);
// 	output.uv = final_uv;


// 	output.img_index = tex.img_index;
// 	output.layer = tex.layer;
// 	output.img_1_tint = tex.tint;

// 	output.img_index_2 = tex.img_index_2;
// 	output.layer_2 = tex.layer_2;
// 	output.img_2_tint = tex.tint_2;

// 	output.color = float4(1, 1, 1, 1);

// 	output.normal = geometry.normal.xyz;
// 	output.face_uv = face_uv;
// 	output.draw_index = draw_index;
// 	output.shading = geometry.sarting_shade;

// 	// output.clip_u = clip_u;
// 	// output.clip_v = clip_v;
// 	return output;
// }






Output main(

	uint vid : SV_VertexID,

	[[vk::builtin("DrawIndex")]] uint draw_index : TEXCOORD6

) {
	Output output;

	// ------------------------------------------------------------
	// Face
	// ------------------------------------------------------------

	uint face_index = vid / 3;
	uint corner_id = vid % 3;

	Face face = Faces[face_index];

	uint packed_pos = face.packed_block_pos__geometry_face_index & 0xFFFF;
	uint geometry_face_index = face.packed_block_pos__geometry_face_index >> 16;

	uint texture_face_index = face.texture_face_index & 0xFFFF;

	Face_Geometry geometry = face_geometry[geometry_face_index];
	Face_Texure tex = face_texure[texture_face_index];
	// ------------------------------------------------------------
	// Chunk
	// ------------------------------------------------------------
	Chunk_Data chunk = chunk_data[draw_index];

	float lod_size = float(chunk.size);
	
	// ------------------------------------------------------------
	// Block position
	// ------------------------------------------------------------
	uint block_x =  packed_pos        & 0x1F;
	uint block_y = (packed_pos >> 5)  & 0x1F;
	uint block_z = (packed_pos >> 10) & 0x1F;

	float3 block_pos = float3(block_x,block_y,block_z);
	// ------------------------------------------------------------
	// Face geometry
	// ------------------------------------------------------------

	float3 edge1 = geometry.pos1.xyz - geometry.pos0.xyz;
	float3 edge3 = geometry.pos3.xyz - geometry.pos0.xyz;

	float4 final_pos = float4(0, 0, 0, 1);

	float2 final_uv = float2(0, 0);
	float2 face_uv = float2(0, 0);
	if (corner_id == 0) {
		final_pos.xyz = geometry.pos0.xyz;
		final_uv = tex.uv0;
		face_uv = float2(0, 0);
	}
	else if (corner_id == 1) {
		final_pos.xyz = geometry.pos0.xyz + edge1 * 2.0;
		final_uv = tex.uv0 +(tex.uv1 - tex.uv0) * 2.0;
		face_uv = float2(2, 0);
	}
	else {
		final_pos.xyz = geometry.pos0.xyz + edge3 * 2.0;
		final_uv = tex.uv0 +(tex.uv3 - tex.uv0) * 2.0;
		face_uv = float2(0, 2);
	}
	// ------------------------------------------------------------
	// Local position
	// ------------------------------------------------------------
	final_pos.xyz += block_pos;
	// -----------------------------------------------------------
	// LOD scaling
	//
	// Everything inside the chunk gets larger:
	// blocks AND face geometry.
	// ------------------------------------------------------------
	final_pos.xyz *= lod_size;
	// ------------------------------------------------------------
	// Chunk world position
	// ------------------------------------------------------------
	final_pos.xyz += float3(
		float(chunk.pos_x) * 32.0,
		float(chunk.pos_y) * 32.0,
		float(chunk.pos_z) * 32.0
	);
	// ------------------------------------------------------------
	// Vertex output
	// ------------------------------------------------------------
	output.position = mul(mvp, final_pos);
	output.uv = final_uv;
	output.size = lod_size;

	output.img_index = tex.img_index;
	output.layer = tex.layer;
	output.img_1_tint = tex.tint;

	output.img_index_2 = tex.img_index_2;
	output.layer_2 = tex.layer_2;
	output.img_2_tint = tex.tint_2;

	output.color = float4(1, 1, 1, 1);

	output.normal = geometry.normal.xyz;
	output.face_uv = face_uv;

	output.draw_index = draw_index;
	output.shading = geometry.sarting_shade;

	return output;
}
