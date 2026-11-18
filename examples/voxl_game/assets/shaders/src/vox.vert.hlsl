
cbuffer UBO : register(b0, space1) {
    float4x4 mvp;
    int4 camera_step;
    float4 camera_pos;
    float step_size;
    float3 _padding;
    float2 viewport_size;
    float2 _padding_2;
};

static const uint CORNER_MAP[6] = { 0, 1, 2, 2, 3, 0 };
struct Face {
	uint packed_block_pos__geometry_face_index;
	uint packed_texture_face_index__block_offset;
	uint light_0;
	uint light_1;
	uint light_2;
	uint light_3;
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
struct Chunk_Data{
	int   pos_x;
	int   pos_y;
	int   pos_z;
	int   size;
	uint  side;
};


StructuredBuffer<Face> Faces : register(t0, space0);
// StructuredBuffer<Face_Texure> face_texure : register(t1, space0);
StructuredBuffer<Face_Geometry> face_geometry : register(t1, space0);
StructuredBuffer<Chunk_Data> chunk_data : register(t2, space0);

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
	nointerpolation uint4 packed_light : TEXCOORD8;
};



float decode_offset_axis(uint packed, uint shift) {
	uint value = (packed >> shift) & 0x1F;
	float magnitude = float(value & 0x0F) * (1.0 / 16.0);

	return (value & 0x10) != 0 ? -magnitude : magnitude;
}

float3 decode_block_offset(uint packed) {
	return float3(
		decode_offset_axis(packed, 0),
		decode_offset_axis(packed, 5),
		decode_offset_axis(packed, 10)
	);
}

float3 decode_sun_light(uint packed) {
	return float3(
		float((packed >> 25) & 31u),
		float((packed >> 20) & 31u),
		float((packed >> 15) & 31u)
	) / 31.0;
}

float3 decode_block_light(uint packed) {
	return float3(
		float((packed >> 10) & 31u),
		float((packed >> 5) & 31u),
		float(packed & 31u)
	) / 31.0;
}

Output main(
	uint vid : SV_VertexID,
	[[vk::builtin("DrawIndex")]] uint draw_index : TEXCOORD6
) {
	Output output;

	uint face_index = vid / 6;
	uint corner_id = CORNER_MAP[vid % 6];
	Face face = Faces[face_index];

	uint packed_pos = face.packed_block_pos__geometry_face_index & 0xFFFF;
	uint geometry_face_index = face.packed_block_pos__geometry_face_index >> 16;

	uint packed_texture_offset = face.packed_texture_face_index__block_offset;

	uint texture_face_index = packed_texture_offset & 0xFFFF;
	uint block_offset_packed = packed_texture_offset >> 16;
	float3 block_offset = decode_block_offset(block_offset_packed);
	Face_Geometry geometry = face_geometry[geometry_face_index];
	// ------------------------------------------------------------
	// Chunk
	// ------------------------------------------------------------
	Chunk_Data chunk = chunk_data[draw_index];

	float lod_size = float(chunk.size);
	

	uint block_x =  packed_pos        & 0x1F;
	uint block_y = (packed_pos >> 5)  & 0x1F;
	uint block_z = (packed_pos >> 10) & 0x1F;

	float3 block_pos = float3(block_x,block_y,block_z);


	float3 edge1 = geometry.pos1.xyz - geometry.pos0.xyz;
	float3 edge3 = geometry.pos3.xyz - geometry.pos0.xyz;

	float4 final_pos = float4(0, 0, 0, 1);

	float2 final_uv = float2(0, 0);
	float2 face_uv = float2(0, 0);

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
	final_pos.xyz += block_pos + block_offset;

	float3 light_pos = final_pos.xyz - block_pos;
	float2 light_uv;
	
	switch (chunk.side) {
		case 0:
			light_uv = float2(1.0-light_pos.y,1.0-light_pos.z);
			break;
		case 1:
			light_uv = float2(1.0-light_pos.y,light_pos.z);
			break;
		case 2:
			light_uv = float2(light_pos.z,light_pos.x);
			break;
		case 3:
			light_uv = float2(light_pos.z,1.0-light_pos.x);
			break;
		case 4:
			light_uv = float2(1.0-light_pos.y,light_pos.x);
			break;
		case 5:
			light_uv = float2(1.0-light_pos.y,1.0-light_pos.x);
			break;
		default:
			light_uv = float2(0,0);
			break;
	}
	
	light_uv = saturate(light_uv);
	// ------------------------------------------------------------
	// Camera-relative position
	// ------------------------------------------------------------
	
	// Subtract integer coordinates BEFORE converting to float.
	int3 chunk_step = int3(
	    chunk.pos_x,
	    chunk.pos_y,
	    chunk.pos_z
	);
	
	int3 step_delta = chunk_step - camera_step.xyz;
	
	// Scale the step difference and add local vertex position.
	float3 relative_pos = float3(step_delta) * step_size + final_pos.xyz * lod_size - camera_pos.xyz;

	// ------------------------------------------------------------
	// Vertex output
	// ------------------------------------------------------------
	output.packed_light = uint4(face.light_0,face.light_1,face.light_2,face.light_3);
	output.position = mul(mvp, float4(relative_pos, 1.0));
	output.uv = final_uv;
	output.size = lod_size;
	output.texture_face_index = texture_face_index;
	output.color = float4(1, 1, 1, 1);
	output.normal = geometry.normal.xyz;
	output.face_uv = light_uv;
	output.draw_index = draw_index;
	output.shading = geometry.sarting_shade;

	return output;
}
