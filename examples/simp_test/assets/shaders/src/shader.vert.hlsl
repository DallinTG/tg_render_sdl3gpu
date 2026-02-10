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
    float2 pad_2 ;
    float4 color2;
};

StructuredBuffer<Vertex> Vertices : register(t0);
StructuredBuffer<uint> Indices : register(t1);

struct Output{
	float4 position : SV_Position;
	float4 color : TEXCOORD0;
	float2 uv : TEXCOORD1;
	float4 color2 : TEXCOORD2;
};

Output main(uint vid : SV_VertexID) {
// Output main(Input input, uint vid : SV_VertexID) {
	// Output output;
	// output.color2 = input.color2;
 //    output.position = mul(mvp , float4(input.pos, 1));
 //    output.color = input.color;
 //    output.uv = input.uv;
 //    return output;
    
    uint index = Indices[vid];
    Vertex v = Vertices[index]; // vertex pulling
    Output output;
	output.color2 = v.color2;
    output.position = mul(mvp , float4(v.pos, 1));
    output.color = v.color;
    output.uv = v.uv;
    return output;
}
