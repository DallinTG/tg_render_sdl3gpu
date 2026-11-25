// Renders one direction-based procedural sky into the selected cubemap face.
// Keep this uniform layout in sync with Procedural_Sky_Generate_Params in
// skybox.odin. All members are float4 to keep the CPU/GPU layout unambiguous.

cbuffer Sky_Generate_Params : register(b0, space3)
{
    float4 face_forward;
    float4 face_right;
    float4 face_up;
    float4 sun_direction_time;
    float4 cloud_params;
    float4 day_horizon;
    float4 day_zenith;
    float4 night_horizon;
    float4 night_zenith;
    float4 sunset_color;
    float4 sun_color;
    float4 atmosphere_params;
};

struct PS_Input
{
    float4 position : SV_Position;
};

float hash31(float3 p)
{
    // Fast arithmetic hash; avoids a sin() per lattice corner.
    p = frac(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return frac((p.x + p.y) * p.z);
}

float noise3(float3 p)
{
    float3 i = floor(p);
    float3 f = frac(p);
    f = f * f * (3.0 - 2.0 * f);

    float n000 = hash31(i + float3(0, 0, 0));
    float n100 = hash31(i + float3(1, 0, 0));
    float n010 = hash31(i + float3(0, 1, 0));
    float n110 = hash31(i + float3(1, 1, 0));
    float n001 = hash31(i + float3(0, 0, 1));
    float n101 = hash31(i + float3(1, 0, 1));
    float n011 = hash31(i + float3(0, 1, 1));
    float n111 = hash31(i + float3(1, 1, 1));

    float n00 = lerp(n000, n100, f.x);
    float n10 = lerp(n010, n110, f.x);
    float n01 = lerp(n001, n101, f.x);
    float n11 = lerp(n011, n111, f.x);
    return lerp(lerp(n00, n10, f.y), lerp(n01, n11, f.y), f.z);
}

float fbm3(float3 p)
{
    float value = 0.0;
    float amplitude = 0.5;

    value += noise3(p) * amplitude;
    p = p * 2.03 + float3(17.1, 9.2, 13.7);
    amplitude *= 0.5;
    value += noise3(p) * amplitude;
    p = p * 2.01 + float3(5.7, 21.4, 3.1);
    amplitude *= 0.5;
    value += noise3(p) * amplitude;

    return value;
}

float4 main(PS_Input input) : SV_Target0
{
    float resolution = max(atmosphere_params.w, 1.0);
    float2 uv = input.position.xy / resolution;
    float2 ndc = float2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);

    // 90-degree cube-face projection. Direction-space noise makes the cloud
    // field continuous across the six face boundaries.
    float3 ray = normalize(
        face_forward.xyz + face_right.xyz * ndc.x + face_up.xyz * ndc.y
    );

    float3 sun_dir = normalize(sun_direction_time.xyz);
    float daylight = smoothstep(-0.10, 0.12, sun_dir.y);
    float twilight = (1.0 - smoothstep(0.015, 0.42, abs(sun_dir.y)))
        * smoothstep(-0.25, 0.02, sun_dir.y);

    float sky_height = smoothstep(-0.10, 0.72, ray.y);
    float3 day_sky = lerp(day_horizon.rgb, day_zenith.rgb, sky_height);
    float3 night_sky = lerp(night_horizon.rgb, night_zenith.rgb, sky_height);
    float3 color = lerp(night_sky, day_sky, daylight);

    // Broad low-angle warm scattering around sunrise and sunset.
    float horizon_scatter = exp(-abs(ray.y) * 8.0);
    float toward_sun = saturate(dot(ray, sun_dir) * 0.5 + 0.5);
    color = lerp(color, sunset_color.rgb, twilight * horizon_scatter * toward_sun * 0.58);
    color += float3(0.10, 0.14, 0.22) * horizon_scatter
        * atmosphere_params.y * (1.0 - daylight) * 0.24;

    // Sun disc and a soft multi-scale halo.
    float sun_dot = saturate(dot(ray, sun_dir));
    float sun_visibility = smoothstep(-0.10, 0.035, sun_dir.y);
    float sun_disc = smoothstep(0.99955, 0.99988, sun_dot);
    float sun_halo = pow(sun_dot, 48.0) * 0.18 + pow(sun_dot, 9.0) * 0.055;
    float3 warm_sun = lerp(sun_color.rgb, sunset_color.rgb, twilight * 0.72);
    color += warm_sun * (sun_disc * 1.35 + sun_halo) * sun_visibility;

    // Seamless spherical cloud field. Sampling noise in 3D direction space
    // avoids the longitude seam produced by ordinary equirectangular UVs.
    float time = sun_direction_time.w;
    float cloud_scale = max(cloud_params.y, 0.01);
    float3 cloud_p = ray * (cloud_scale * 9.0)
        + float3(time * cloud_params.z, time * cloud_params.z * 0.19, -time * cloud_params.z * 0.11);
    float cloud_noise = fbm3(cloud_p);
    float cloud_threshold = 0.69 - saturate(cloud_params.w) * 0.24;
    float cloud_shape = smoothstep(cloud_threshold, cloud_threshold + 0.16, cloud_noise);
    float cloud_band = smoothstep(-0.12, 0.04, ray.y)
        * (1.0 - smoothstep(0.52, 0.78, ray.y));
    float clouds = cloud_shape * cloud_band * saturate(cloud_params.x);

    float cloud_light = saturate(dot(ray, sun_dir) * 0.35 + 0.65);
    float3 day_cloud = lerp(float3(0.46, 0.53, 0.62), float3(1.0, 0.97, 0.91), cloud_light);
    float3 night_cloud = float3(0.045, 0.060, 0.105) * (0.65 + cloud_light * 0.45);
    float3 cloud_color = lerp(night_cloud, day_cloud, daylight);
    cloud_color = lerp(cloud_color, sunset_color.rgb * 0.78, twilight * horizon_scatter * 0.65);
    color = lerp(color, cloud_color, clouds * 0.88);

    // Moon is opposite the sun direction. It is intentionally simple; its
    // phase and position can be made independent later if desired.
    float3 moon_dir = -sun_dir;
    float moon_dot = saturate(dot(ray, moon_dir));
    float moon_visibility = (1.0 - daylight) * smoothstep(-0.10, 0.06, moon_dir.y);
    float moon_disc = smoothstep(0.99970, 0.99991, moon_dot);
    color += float3(0.56, 0.70, 0.92) * moon_disc * moon_visibility * atmosphere_params.z;
    color += float3(0.08, 0.12, 0.20) * pow(moon_dot, 20.0) * moon_visibility * atmosphere_params.z * 0.15;

    // Sparse direction-space stars. They are generated with no star texture.
    float3 star_cell = floor(ray * 260.0);
    float3 star_local = frac(ray * 260.0) - 0.5;
    float star_random = hash31(star_cell);
    float star_shape = 1.0 - smoothstep(0.10, 0.34, length(star_local));
    float stars = step(1.0 - 0.0035 * saturate(atmosphere_params.x), star_random)
        * star_shape
        * smoothstep(-0.04, 0.24, ray.y)
        * (1.0 - daylight);
    color += stars * float3(0.72, 0.82, 1.0);

    return float4(color, 1.0);
}
