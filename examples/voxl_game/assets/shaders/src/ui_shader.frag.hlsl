struct Input{
	float4 position : SV_Position;
	float4 color : TEXCOORD0;
	float2 uv : TEXCOORD1;
	uint   img_index : TEXCOORD2;
	uint   layer: TEXCOORD3;
	float4 color2 : TEXCOORD4;
	float4 scissor_rect : TEXCOORD5;
};
// Texture2D<float4> tex : register(t0, space2);
Texture2DArray<float4> g_Textures[10] : register(t0, space2);
SamplerState smp[10] : register(s0, space2);


float4 main(Input input) : SV_Target0 {
	// uint texIndex = g_InstanceData[input.img_index].texture_index;
	Texture2DArray tex = g_Textures[input.img_index];
	float4 color = tex.Sample(smp[input.img_index], float3(input.uv, input.layer));

float2 p = input.position.xy;
	if (!all(input.scissor_rect == float4(0,0,0,0))){
		if (// this is for scisor rect
		    p.x < input.scissor_rect.x ||
		    p.y < input.scissor_rect.y ||
		    p.x > input.scissor_rect.z ||
		    p.y > input.scissor_rect.w
		)
		{
		    discard;
		}
	}
	// return float4(1, 0, 0, 1);
	return color * input.color + input.color2 + float4(0,0,0,0);

	// float v = tex.Sample(smp[input.img_index], float3(input.uv, input.layer)).r;
	// return float4(v, v, v, 1.0);
    // return tex.Sample(smp[input.img_index], float3(input.uv, input.layer)) * input.color + input.color2 + float4(0,0,0,.2);
}
