

cbuffer UBO : register(b0, space1){ 
	float4x4 mvp;
};

// cbuffer Chuck_Data : register(b1, space1){ 
//     float4x4 chuck_mat;
// };

static const uint CORNER_MAP[6] = { 0, 1, 2, 2, 3, 0 };
struct Face {
	uint packed_block_pos__geometry_face_index;
	uint texture_face_index;
};

struct Face_Texure {
    uint   img_index;
    uint   layer;
   	uint _padding_1;
	uint _padding_2;
    float4 tint;
	float2 uv0;  float2 uv1;  float2 uv2;  float2 uv3;  
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
	uint   img_index : TEXCOORD2;
	uint   layer: TEXCOORD3;
	float4 color2 : TEXCOORD4;
	float3 normal : TEXCOORD5;
	uint   draw_index : TEXCOORD6;
	float   shading: TEXCOORD7;
};

Output main(

	uint vid : SV_VertexID,

	[[vk::builtin("DrawIndex")]] uint draw_index : TEXCOORD6

) {

// Output main(uint vid : SV_VertexID) {

	uint face_index = vid / 6;

	uint corner_id = CORNER_MAP[vid % 6];

	Face face = Faces[face_index];

	// Unpack block position and geometry index.
	uint packed_pos = face.packed_block_pos__geometry_face_index & 0xFFFF;
	uint geometry_face_index = face.packed_block_pos__geometry_face_index >> 16;

	// Unpack texture index.
	uint texture_face_index = face.texture_face_index & 0xFFFF;

	Face_Geometry geometry = face_geometry[geometry_face_index];
	Face_Texure tex = face_texure[texture_face_index];

	Output output;

	// Unpack block position.
	uint block_x =  packed_pos        & 0x1F;
	uint block_y = (packed_pos >> 5)  & 0x1F;
	uint block_z = (packed_pos >> 10) & 0x1F;

	float3 block_pos = float3(
		block_x,
		block_y,
		block_z
	);

	float4 final_pos = float4(0, 0, 0, 1);
	float2 final_uv = float2(0, 0);

	if (corner_id == 0) {
		final_pos = geometry.pos0;
		final_uv = tex.uv0;
	}
	else if (corner_id == 1) {
		final_pos = geometry.pos1;
		final_uv = tex.uv1;
	}
	else if (corner_id == 2) {
		final_pos = geometry.pos2;
		final_uv = tex.uv2;
	}
	else if (corner_id == 3) {
		final_pos = geometry.pos3;
		final_uv = tex.uv3;
	}

	final_pos.xyz += block_pos;

	final_pos.xyz += float3(
	    mul(chunk_data[draw_index].pos_x , 32),
	    mul(chunk_data[draw_index].pos_y , 32),
	    mul(chunk_data[draw_index].pos_z , 32)
	);	


	output.position = mul(mvp, final_pos);
	output.uv = final_uv;


	output.img_index = tex.img_index;
	output.layer = tex.layer;

	output.color = tex.tint;
	// output.color = float4(1, 1, 1, 1);

	output.color2 = float4(0.0, 0.0, 0.0, 0.0);

	output.normal = geometry.normal.xyz;

	output.draw_index = draw_index;
	output.shading = geometry.sarting_shade;
	return output;
}
