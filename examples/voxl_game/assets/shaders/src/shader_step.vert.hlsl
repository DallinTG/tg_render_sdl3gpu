cbuffer UBO : register(b0, space1) {
    float4x4 mvp;
    int4 camera_step;
    float4 camera_pos;
    float step_size;
    float3 _padding;
    float2 viewport_size;
    float2 _padding_2;
};

struct Vertex {
    float4 pos;
    int4 step;
    float4 color;
    float4 uv_img_layer;
    float4 color2;
};

StructuredBuffer<Vertex> Vertices : register(t0, space0);
StructuredBuffer<uint> Indices : register(t1, space0);

struct Output {
    float4 position : SV_Position;
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    uint img_index : TEXCOORD2;
    uint layer : TEXCOORD3;
    float4 color2 : TEXCOORD4;
};

Output main(uint vid : SV_VertexID) {
    Output output;

    uint index = Indices[vid];
    Vertex v = Vertices[index];

    output.img_index = asuint(v.uv_img_layer.z);
    output.layer = asuint(v.uv_img_layer.w);
    output.uv = v.uv_img_layer.xy;

    output.color2 = v.color2;
    output.color = v.color;

    // Camera-relative vertex position.
    int3 step_delta = v.step.xyz - camera_step.xyz;

    float3 relative_pos =
        float3(step_delta) * step_size +
        v.pos.xyz -
        camera_pos.xyz;

    output.position = mul(mvp, float4(relative_pos, v.pos.w));

    return output;
}
