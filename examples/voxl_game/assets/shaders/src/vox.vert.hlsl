cbuffer UBO : register(b0, space1){ 
	float4x4 mvp;
};

// struct Vertex {
//     float4 pos;
//     // float pad_1;
//     float4 color;
//     float4 uv_img_layer; // pack everything
//     float4 color2;
// };
static const uint CORNER_MAP[6] = { 0, 1, 2, 2, 3, 0 };
struct Face {
    // Matches Odin's pos: [4][4]f32 (64 bytes total)
    float4 pos0; float4 pos1; float4 pos2; float4 pos3; 
    
    // Matches Odin's uv: [4][2]f32 (32 bytes total)
    float2 uv0;  float2 uv1;  float2 uv2;  float2 uv3;  
    uint   modl_index;
    uint   img_index;
    uint   layer;
};

StructuredBuffer<Face> Faces : register(t0, space0);
// StructuredBuffer<uint> Indices : register(t1, space0);

struct Output{
	float4 position : SV_Position;
	float4 color : TEXCOORD0;
	float2 uv : TEXCOORD1;
	uint   img_index : TEXCOORD2;
	uint   layer: TEXCOORD3;
	float4 color2 : TEXCOORD4;
};

Output main(uint vid : SV_VertexID) {
 //    uint index = Indices[vid];
 //    Vertex v = Vertices[index]; // vertex pulling
 //    Output output;

 //    output.img_index = asuint(v.uv_img_layer.z);
 //    output.layer = asuint(v.uv_img_layer.w);
 //    output.uv = v.uv_img_layer.xy;

	// output.color2 = v.color2;
 //    output.position = mul(mvp , v.pos);
 //    output.color = v.color;

 //    return output;\
 	
    // Determine which face structure we are reading, and which corner index (0 to 3)
    uint face_index = vid / 6;
    uint corner_id  = CORNER_MAP[vid % 6];

    Face face = Faces[face_index];
    Output output;

    // Remap corner_id cleanly to your unrolled struct elements
    float4 final_pos = float4(0,0,0,1);
    float2 final_uv  = float2(0,0);

    if (corner_id == 0)      { final_pos = face.pos0; final_uv = face.uv0; }
    else if (corner_id == 1) { final_pos = face.pos1; final_uv = face.uv1; }
    else if (corner_id == 2) { final_pos = face.pos2; final_uv = face.uv2; }
	else if (corner_id == 3) { final_pos = face.pos3; final_uv = face.uv3; }

	// Output transformation and properties
	output.position  = mul(mvp, final_pos); 
	output.uv        = final_uv;
	output.img_index = face.img_index;
	output.layer     = face.layer;
	output.color     = float4(1.0, 1.0, 1.0, 1.0); // solid fallback tint
	output.color2    = float4(0.0, 0.0, 0.0, 0.0); 

    return output;
}
