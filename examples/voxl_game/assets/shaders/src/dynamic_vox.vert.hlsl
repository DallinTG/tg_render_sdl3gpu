
cbuffer UBO : register(b0, space1){ 
	float4x4 mvp;
};

static const uint CORNER_MAP[6] = { 0, 1, 2, 2, 3, 0 };
struct Face {
	float pos_x;
	float pos_y;
	float pos_z;
	float pos_w;

	uint light_0;
	uint light_1;
	uint light_2;
	uint light_3;

	float r;
	float g;
	float b;
	float a;

	uint packed_block_pos__geometry_face_index;
	uint texture_face_index;
};

struct Face_Texure {
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
	float2 uv0;
	float2 uv1;
	float2 uv2;
	float2 uv3;

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
// struct Chunk_Data{
// 	int   pos_x;
// 	int   pos_y;
// 	int   pos_z;
// 	int   size;
// };


StructuredBuffer<Face> Faces : register(t0, space0);
// StructuredBuffer<Face_Texure> face_texure : register(t1, space0);
StructuredBuffer<Face_Geometry> face_geometry : register(t1, space0);
// StructuredBuffer<Chunk_Data> chunk_data : register(t2, space0);

struct Output{
	float4 position : SV_Position;
	float4 color : TEXCOORD0;
	float2 uv : TEXCOORD1;
	uint size : TEXCOORD2;
	float3 normal : TEXCOORD3;
	uint   draw_index : TEXCOORD4;
	float   shading: TEXCOORD5;
	float2 face_uv : TEXCOORD6;
	uint texture_face_index : TEXCOORD7;
	float3 sun_light   : TEXCOORD8;
	float3 block_light : TEXCOORD9;
};



Output main(

	uint vid : SV_VertexID

	// [[vk::builtin("DrawIndex")]] uint draw_index : TEXCOORD6

) {
	Output output;

	// ------------------------------------------------------------
	// Face
	// ------------------------------------------------------------

	// uint face_index = vid / 3;
	// uint corner_id = vid % 3;

	// Face face = Faces[face_index];

	uint face_index = vid / 6;

	uint corner_id = CORNER_MAP[vid % 6];

	Face face = Faces[face_index];


	uint packed_pos = face.packed_block_pos__geometry_face_index & 0xFFFF;
	uint geometry_face_index = face.packed_block_pos__geometry_face_index >> 16;

	uint texture_face_index = face.texture_face_index & 0xFFFF;

	Face_Geometry geometry = face_geometry[geometry_face_index];
	// Face_Texure tex = face_texure[texture_face_index];
	// ------------------------------------------------------------
	// Chunk
	// ------------------------------------------------------------
	// Chunk_Data chunk = chunk_data[draw_index];

	// float lod_size = float(chunk.size);
	
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
	// if (corner_id == 0) {
	// 	final_pos.xyz = geometry.pos0.xyz;
	// 	final_uv = geometry.uv0;
	// 	face_uv = float2(0, 0);
	// }
	// else if (corner_id == 1) {
	// 	final_pos.xyz = geometry.pos0.xyz + edge1 * 2.0;
	// 	final_uv = geometry.uv0 +(geometry.uv1 - geometry.uv0) * 2.0;
	// 	face_uv = float2(2, 0);
	// }
	// else {
	// 	final_pos.xyz = geometry.pos0.xyz + edge3 * 2.0;
	// 	final_uv = geometry.uv0 +(geometry.uv3 - geometry.uv0) * 2.0;
	// 	face_uv = float2(0, 2);
	// }

	if (corner_id == 0) {
		final_pos = geometry.pos0;
		final_uv = geometry.uv0;
	}
	else if (corner_id == 1) {
		final_pos = geometry.pos1;
		final_uv = geometry.uv1;
	}
	else if (corner_id == 2) {
		final_pos = geometry.pos2;
		final_uv = geometry.uv2;
	}
	else if (corner_id == 3) {
		final_pos = geometry.pos3;
		final_uv = geometry.uv3;
	}

	// ------------------------------------------------------------
	// Local position
	// ------------------------------------------------------------
	final_pos.xyz += block_pos + float3(face.pos_x,face.pos_y,face.pos_z);
	// -----------------------------------------------------------
	// LOD scaling
	//
	// Everything inside the chunk gets larger:
	// blocks AND face geometry.
	// ------------------------------------------------------------
	// final_pos.xyz *= lod_size;
	// ------------------------------------------------------------
	// Chunk world position
	// ------------------------------------------------------------
	// final_pos.xyz += float3(
	// 	float(chunk.pos_x) * 32.0,
	// 	float(chunk.pos_y) * 32.0,
	// 	float(chunk.pos_z) * 32.0
	// );



	uint packed_light = face.light_0;
	
	if (corner_id == 1) {
	    packed_light = face.light_1;
	} else if (corner_id == 2) {
	    packed_light = face.light_2;
	} else if (corner_id == 3) {
	    packed_light = face.light_3;
	}
	
	float3 sun_light = float3(
	    float((packed_light >> 25) & 31u),
	    float((packed_light >> 20) & 31u),
	    float((packed_light >> 15) & 31u)
	) / 31.0;
	
	float3 block_light = float3(
	    float((packed_light >> 10) & 31u),
	    float((packed_light >>  5) & 31u),
	    float( packed_light        & 31u)
	) / 31.0;

	// ------------------------------------------------------------
	// Vertex output
	// ------------------------------------------------------------
	output.position = mul(mvp, final_pos);
	output.uv = final_uv;
	output.texture_face_index = texture_face_index;
	output.sun_light = sun_light;
	output.block_light = block_light;
	output.color = float4(face.r, face.g, face.b, face.a);
	output.normal = geometry.normal.xyz;
	output.face_uv = face_uv;
	output.size = 1;
	output.draw_index = 0;
	output.shading = geometry.sarting_shade;

	return output;
}
