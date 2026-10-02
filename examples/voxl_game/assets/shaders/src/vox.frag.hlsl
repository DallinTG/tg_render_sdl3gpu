
// struct Input{
// 	float4 position : SV_Position;
// 	float4 color : TEXCOORD0;
// 	float2 uv : TEXCOORD1;

// 	uint   img_index : TEXCOORD2;
// 	uint   layer: TEXCOORD3;
// 	float4 img_1_tint : TEXCOORD4;

// 	uint   img_index_2 : TEXCOORD5;
// 	uint   layer_2: TEXCOORD6;
// 	float4 img_2_tint : TEXCOORD7;


// 	float3 normal : TEXCOORD8;
// 	uint   draw_index : TEXCOORD9;
// 	float   shading: TEXCOORD10;
// };


// SamplerState smp[10] : register(s0, space2);
// Texture2DArray<float4> g_Textures[10] : register(t0, space2);

// float4 main(Input input) : SV_Target0 {

//     // Image 1
//     Texture2DArray tex1 = g_Textures[input.img_index];

//     float4 color1 = tex1.Sample(
//         smp[input.img_index],
//         float3(input.uv, input.layer)
//     );

//     color1 *= input.img_1_tint;

//     if (color1.a <= 0.0) {
//         discard;
//     }

//     // Start with image 1
//     float4 color = color1;


//     // Image 2 is optional
//     if (input.img_2_tint.a > 0.0) {

//         Texture2DArray tex2 = g_Textures[input.img_index_2];

//         float4 color2 = tex2.Sample(
//             smp[input.img_index_2],
//             float3(input.uv, input.layer_2)
//         );

//         color2 *= input.img_2_tint;

//         // Image 2 over image 1
// 		color.rgb = lerp(color1.rgb, color2.rgb, color2.a);
// 		color.a = color1.a;
//     }



//     return color
//         * input.color
//         * float4(input.shading, input.shading, input.shading, 1);
// }







//_________________________________________________________________________________
// 



struct Input{
	float4 position : SV_Position;
	float4 color : TEXCOORD0;
	float2 uv : TEXCOORD1;
	uint size : TEXCOORD2;

	uint   img_index : TEXCOORD3;
	uint   layer: TEXCOORD4;
	float4 img_1_tint : TEXCOORD5;

	uint   img_index_2 : TEXCOORD6;
	uint   layer_2: TEXCOORD7;
	float4 img_2_tint : TEXCOORD8;


	float3 normal : TEXCOORD9;
	uint   draw_index : TEXCOORD10;
	float   shading: TEXCOORD11;

	float2 face_uv : TEXCOORD12;

	// float4 clip_box : TEXCOORD11;
};


SamplerState smp[10] : register(s0, space2);
Texture2DArray<float4> g_Textures[10] : register(t0, space2);


float4 main(Input input) : SV_Target0 {

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

	Texture2DArray tex1 = g_Textures[input.img_index];
	// float4 color1 = tex1.Sample(smp[input.img_index], float3(input.uv, input.layer));
	// float4 color1 = tex1.Sample(smp[input.img_index],float3(0.5,0.5, input.layer));

	float4 color1 = tex1.Sample(smp[input.img_index], float3(lod_uv, input.layer));


	color1 *= input.img_1_tint;

	// if (color1.a <= 0.0) discard;

	float4 color = color1;

	if (input.img_2_tint.a > 0.0) {
		Texture2DArray tex2 = g_Textures[input.img_index_2];
		// float4 color2 = tex2.Sample(smp[input.img_index_2], float3(input.uv, input.layer_2));
		float4 color2 = tex2.Sample(smp[input.img_index_2], float3(lod_uv, input.layer_2));
		color2 *= input.img_2_tint;

		color.rgb = lerp(color1.rgb, color2.rgb, color2.a);
		color.a = color1.a;
	}

	return color * input.color * float4(input.shading,input.shading,input.shading,1);
}
