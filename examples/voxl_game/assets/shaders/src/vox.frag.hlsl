

struct Input{
	float4 position : SV_Position;
	float4 color : TEXCOORD0;
	float2 uv : TEXCOORD1;
	uint size : TEXCOORD2;

	// uint   img_index : TEXCOORD3;
	// uint   layer: TEXCOORD4;
	// float4 img_1_tint : TEXCOORD5;

	// uint   img_index_2 : TEXCOORD6;
	// uint   layer_2: TEXCOORD7;
	// float4 img_2_tint : TEXCOORD8;


	float3 normal : TEXCOORD3;
	uint   draw_index : TEXCOORD4;
	float   shading: TEXCOORD5;

	float2 face_uv : TEXCOORD6;
	uint texture_face_index : TEXCOORD7;
	// float4 clip_box : TEXCOORD11;
};

struct Face {
	uint packed_block_pos__geometry_face_index;
	uint texture_face_index;
};
struct Chunk_Data{
	int   pos_x;
	int   pos_y;
	int   pos_z;
	int   size;
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

SamplerState smp[10] : register(s0, space2);
Texture2DArray<float4> g_Textures[10] : register(t0, space2);

// StructuredBuffer<Face_Texure> face_texure : register(t1, space0);

// StructuredBuffer<Face> Faces : register(t10, space0);
StructuredBuffer<Face_Texure> face_texure : register(t10, space2);
// StructuredBuffer<Face_Geometry> face_geometry : register(t11, space2);
// StructuredBuffer<Chunk_Data> chunk_data : register(t12, space2);

float4 main(Input input) : SV_Target0 {

	Face_Texure tex = face_texure[input.texture_face_index];
	
	uint img_index = tex.img_index;
	uint layer = tex.layer;
	float4 img_1_tint = tex.tint;

	uint img_index_2 = tex.img_index_2;
	uint layer_2 = tex.layer_2;
	float4 img_2_tint = tex.tint_2;


	const float CLIP_EPSILON = 0.5;

	float2 uv_dx = abs(ddx(input.face_uv));
	float2 uv_dy = abs(ddy(input.face_uv));
	
	float clip_epsilon_x = max(uv_dx.x, uv_dy.x);
	float clip_epsilon_y = max(uv_dx.y, uv_dy.y);
	
	if (
		input.face_uv.x > 1.0 + clip_epsilon_x ||
		input.face_uv.y > 1.0 + clip_epsilon_y
	) {
		discard;
	}

	float2 lod_uv = input.uv / float(input.size);

	Texture2DArray tex1 = g_Textures[img_index];
	// float4 color1 = tex1.Sample(smp[input.img_index], float3(input.uv, input.layer));
	// float4 color1 = tex1.Sample(smp[input.img_index],float3(0.5,0.5, input.layer));

	float4 color1 = tex1.Sample(smp[img_index], float3(lod_uv, layer));


	color1 *= img_1_tint;

	// if (color1.a <= 0.0) discard;

	float4 color = color1;

	if (img_2_tint.a > 0.0) {
		Texture2DArray tex2 = g_Textures[img_index_2];
		// float4 color2 = tex2.Sample(smp[input.img_index_2], float3(input.uv, input.layer_2));
		float4 color2 = tex2.Sample(smp[img_index_2], float3(lod_uv, layer_2));
		color2 *= img_2_tint;

		color.rgb = lerp(color1.rgb, color2.rgb, color2.a);
		color.a = color1.a;
	}

	return color * input.color * float4(input.shading,input.shading,input.shading,1);
}
