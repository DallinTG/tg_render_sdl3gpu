struct Input{
	// float4 position : SV_Position;
	float4 color : TEXCOORD0;
	float2 uv : TEXCOORD1;
	uint   img_index : TEXCOORD2;
	uint   layer: TEXCOORD3;
	float4 color2 : TEXCOORD4;
};
// Texture2D<float4> tex : register(t0, space2);
Texture2D<float4> g_Textures[4] : register(t0, space2);
SamplerState smp[4] : register(s0, space2);


float4 main(Input input) : SV_Target0 {
	// uint texIndex = g_InstanceData[input.img_index].texture_index;
	Texture2D tex = g_Textures[input.img_index];
	
    return tex.Sample(smp[input.img_index], input.uv) * input.color + input.color2;
}
