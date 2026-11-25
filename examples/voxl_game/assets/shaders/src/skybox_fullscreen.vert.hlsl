struct VS_Output
{
    float4 position : SV_Position;
};

VS_Output main(uint vertex_id : SV_VertexID)
{
    VS_Output output;
    float2 p;

    if (vertex_id == 0)
        p = float2(-1.0, -1.0);
    else if (vertex_id == 1)
        p = float2(3.0, -1.0);
    else
        p = float2(-1.0, 3.0);

    output.position = float4(p, 0.0, 1.0);
    return output;
}
