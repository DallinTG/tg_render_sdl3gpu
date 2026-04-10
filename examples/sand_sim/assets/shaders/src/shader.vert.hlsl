cbuffer UBO : register(b0, space1){ 
	float4x4 mvp;
};
// struct Input{
// 	float3 pos : TEXCOORD0;
// 	float4 color : TEXCOORD1;
// 	float2 uv : TEXCOORD2;
// 	float4 color2 : TEXCOORD3;
// };
struct Vertex {
    float3 pos;
    float pad_1;
    float4 color;
    float2 uv;
	uint img_index;
	uint layer;
    float4 color2;
};

StructuredBuffer<Vertex> Vertices : register(t0, space0);
StructuredBuffer<uint> Indices : register(t1, space0);

struct Output{
	float4 position : SV_Position;
	float4 color : TEXCOORD0;
	float2 uv : TEXCOORD1;
	uint   img_index : TEXCOORD2;
	uint   layer: TEXCOORD3;
	float4 color2 : TEXCOORD4;
};

Output main(uint vid : SV_VertexID) {
    uint index = Indices[vid];
    Vertex v = Vertices[index]; // vertex pulling
    Output output;
    output.img_index = v.img_index;
    output.layer = v.layer;
	output.color2 = v.color2;
    output.position = mul(mvp , float4(v.pos, 1));
    output.color = v.color;
    output.uv = v.uv;
    return output;
}
