// Samples the runtime-generated cubemap to draw the visible background.
// Uniform layout must match Procedural_Sky_Display_Params in skybox.odin.

TextureCube<float4> sky_cubemap : register(t0, space2);
SamplerState sky_sampler : register(s0, space2);

cbuffer Sky_Display_Params : register(b0, space3)
{
    float4 camera_forward;
    float4 camera_right;
    float4 camera_up;
    float4 viewport_fov;
};

struct PS_Input
{
    float4 position : SV_Position;
};

float4 main(PS_Input input) : SV_Target0
{
    float2 uv = input.position.xy / viewport_fov.xy;
    float2 ndc = float2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);

    float3 ray = normalize(
        camera_forward.xyz
        + camera_right.xyz * ndc.x * viewport_fov.z * viewport_fov.w
        + camera_up.xyz * ndc.y * viewport_fov.z
    );

    return sky_cubemap.Sample(sky_sampler, ray);
}
