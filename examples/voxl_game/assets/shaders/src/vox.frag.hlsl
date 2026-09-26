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
	float4 img_1_tint : TEXCOORD4;

	uint   img_index_2 : TEXCOORD5;
	uint   layer_2: TEXCOORD6;
	float4 img_2_tint : TEXCOORD7;


	float3 normal : TEXCOORD8;
	uint   draw_index : TEXCOORD9;
	float   shading: TEXCOORD10;
};


SamplerState smp[10] : register(s0, space2);
Texture2DArray<float4> g_Textures[10] : register(t0, space2);

// float4 main(Input input) : SV_Target0 {
//     Texture2DArray tex = g_Textures[input.img_index];
// 	 float4 color = tex.Sample(
// 	    smp[input.img_index],
// 	    float3(input.uv, input.layer)
// 	);


//     if (all(color ==float4(0, 0, 0, 0))){
//     	discard;
//     }

//     color = color * input.img_1_tint;
//     return color * input.color   *  float4(input.shading,input.shading,input.shading,1);

// }

// float4 main(Input input) : SV_Target0 {
//     // Image 1
//     Texture2DArray tex1 = g_Textures[input.img_index];

//     float4 color1 = tex1.Sample(
//         smp[input.img_index],
//         float3(input.uv, input.layer)
//     );

//     color1 *= input.img_1_tint;


//     // Image 2
// 	if (input.img_2_tint.a > 0.0) {
// 	    Texture2DArray tex2 = g_Textures[input.img_index_2];
	
// 	    float4 color2 = tex2.Sample(
// 	        smp[input.img_index_2],
// 	        float3(input.uv, input.layer_2)
// 	    );
	
// 	    color2 *= input.img_2_tint;
	
	
// 	    // Image 2 over image 1
// 	    float4 color = lerp(color1, color2, color2.a);
// 	}

//     // Only discard if the final result is transparent
//     if (color.a <= 0.0) {
//         discard;
//     }


//     return color
//         * input.color
//         * float4(input.shading, input.shading, input.shading, 1);
// }
float4 main(Input input) : SV_Target0 {

    // Image 1
    Texture2DArray tex1 = g_Textures[input.img_index];

    float4 color1 = tex1.Sample(
        smp[input.img_index],
        float3(input.uv, input.layer)
    );

    color1 *= input.img_1_tint;


    // Start with image 1
    float4 color = color1;


    // Image 2 is optional
    if (input.img_2_tint.a > 0.0) {

        Texture2DArray tex2 = g_Textures[input.img_index_2];

        float4 color2 = tex2.Sample(
            smp[input.img_index_2],
            float3(input.uv, input.layer_2)
        );

        color2 *= input.img_2_tint;

        // Image 2 over image 1
        color = lerp(color1, color2, color2.a);
    }


    if (color.a <= 0.0) {
        discard;
    }

    return color
        * input.color
        * float4(input.shading, input.shading, input.shading, 1);
}
