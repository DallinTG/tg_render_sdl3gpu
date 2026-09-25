// struct Input{
// 	float4 position : SV_Position;
// 	float4 color : TEXCOORD0;
// 	float2 uv : TEXCOORD1;
// 	uint   img_index : TEXCOORD2;
// 	uint   layer: TEXCOORD3;
// 	float4 color2 : TEXCOORD4;
// 	float4 normal : TEXCOORD5;
// };
// // Texture2D<float4> tex : register(t0, space2);
// SamplerState smp[10] : register(s0, space2);
// Texture2DArray<float4> g_Textures[10] : register(t0, space2);

// float4 main(Input input) : SV_Target0 {
// 	Texture2DArray tex = g_Textures[input.img_index];
// 	float4 color = tex.Sample(smp[input.img_index], float3(input.uv, input.layer));
// 	return color * input.color + input.color2 + float4(0,0,0,0);
// }


struct Input{
    float4 position : SV_Position;
    float4 color : TEXCOORD0;
    float2 uv : TEXCOORD1;
    uint   img_index : TEXCOORD2;
    uint   layer: TEXCOORD3;
    float4 color2 : TEXCOORD4;
    float4 normal : TEXCOORD5;
    uint   draw_index : TEXCOORD6;
    float   shading: TEXCOORD7;
};


SamplerState smp[10] : register(s0, space2);
Texture2DArray<float4> g_Textures[10] : register(t0, space2);

float4 main(Input input) : SV_Target0 {
    Texture2DArray tex = g_Textures[input.img_index];
	 float4 color = tex.Sample(
	    smp[input.img_index],
	    float3(input.uv, input.layer)
	);


    if (all(color ==float4(0, 0, 0, 0))){
    	discard;
    }

    
    return color * input.color   *  float4(input.shading,input.shading,input.shading,1);

    // uint w, h, layers, levels;
	// tex.GetDimensions(5, w, h, layers, levels);
	
	// return float4(
	//     w == 1 ? 1 : 0,
	//     h == 1 ? 1 : 0,
	//     levels == 6 ? 1 : 0,
	//     1
	// );
	// return float4(1, 0, 0, 1);
}


// float4 main(Input input) : SV_Target0 {
// 	return float4(1, 0, 0, 1);
// }
