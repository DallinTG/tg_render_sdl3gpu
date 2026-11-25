package tg_render

import sdl "vendor:sdl3"
import "core:log"
import "core:math"
import lin "core:math/linalg"

// This file is a companion to the existing tg_render package.
// It uses the package's existing State `s`, Camera, Render_Pass_Info,
// Frame_Data, Shader_Handle, get_shader, Vec3, Vec4, Sample_Count,
// and Sample_Count_To_SDL_Sample_Count declarations.
//
// The generated environment lives in a real SDL GPU cubemap. No CPU image
// data, image files, transfer buffers, or face uploads are involved.

Procedural_Sky_Environment :: struct {
    sun_direction: Vec3,
    time_seconds: f32,

    day_horizon: Vec4,
    day_zenith: Vec4,
    night_horizon: Vec4,
    night_zenith: Vec4,
    sunset_color: Vec4,
    sun_color: Vec4,

    cloud_density: f32,
    cloud_scale: f32,
    cloud_speed: f32,
    cloud_coverage: f32,

    star_density: f32,
    atmosphere_strength: f32,
    moon_intensity: f32,
}

DF_PROCEDURAL_SKY_ENVIRONMENT :: Procedural_Sky_Environment{
    sun_direction = {0.32, 0.58, -0.75},
    time_seconds = 0,

    day_horizon = {0.58, 0.76, 0.91, 1},
    day_zenith = {0.10, 0.31, 0.68, 1},
    night_horizon = {0.018, 0.026, 0.075, 1},
    night_zenith = {0.0015, 0.003, 0.018, 1},
    sunset_color = {1.0, 0.31, 0.105, 1},
    sun_color = {1.0, 0.86, 0.67, 1},

    cloud_density = 0.62,
    cloud_scale = 1.0,
    cloud_speed = 0.012,
    cloud_coverage = 0.48,

    star_density = 1.0,
    atmosphere_strength = 1.0,
    moon_intensity = 0.75,
}

Procedural_Skybox :: struct {
    cubemap: ^sdl.GPUTexture,
    sampler: ^sdl.GPUSampler,
    cubemap_format: sdl.GPUTextureFormat,

    generate_pipeline: ^sdl.GPUGraphicsPipeline,
    display_pipeline: [Sample_Count]^sdl.GPUGraphicsPipeline,

    resolution: u32,
    environment: Procedural_Sky_Environment,

    dirty: bool,
    refresh_interval: f32,
    refresh_elapsed: f32,
}

Procedural_Sky_Generate_Params :: struct #align(16) {
    face_forward: Vec4,
    face_right: Vec4,
    face_up: Vec4,
    sun_direction_time: Vec4,
    cloud_params: Vec4,
    day_horizon: Vec4,
    day_zenith: Vec4,
    night_horizon: Vec4,
    night_zenith: Vec4,
    sunset_color: Vec4,
    sun_color: Vec4,
    atmosphere_params: Vec4,
}

Procedural_Sky_Display_Params :: struct #align(16) {
    camera_forward: Vec4,
    camera_right: Vec4,
    camera_up: Vec4,
    viewport_fov: Vec4,
}

// This basis is the Vulkan/D3D-compatible cube sampler face orientation:
// +X, -X, +Y, -Y, +Z, -Z. Fragment Y is converted from top-down pixel
// coordinates to an upward-positive face coordinate in the shader.
PROCEDURAL_SKY_CUBE_FACE_BASIS: [6]struct {
    forward: Vec3,
    right: Vec3,
    up: Vec3,
} = {
    {forward = { 1, 0, 0}, right = { 0, 0,-1}, up = { 0, 1, 0}},
    {forward = {-1, 0, 0}, right = { 0, 0, 1}, up = { 0, 1, 0}},
    {forward = { 0, 1, 0}, right = { 1, 0, 0}, up = { 0, 0,-1}},
    {forward = { 0,-1, 0}, right = { 1, 0, 0}, up = { 0, 0, 1}},
    {forward = { 0, 0, 1}, right = { 1, 0, 0}, up = { 0, 1, 0}},
    {forward = { 0, 0,-1}, right = {-1, 0, 0}, up = { 0, 1, 0}},
}

procedural_sky_create_pipeline :: proc(
    vertex_shader: ^sdl.GPUShader,
    fragment_shader: ^sdl.GPUShader,
    color_format: sdl.GPUTextureFormat,
    has_depth_target: bool,
    depth_format: sdl.GPUTextureFormat,
    sample_count: sdl.GPUSampleCount,
) -> (pipeline: ^sdl.GPUGraphicsPipeline) {
    color_desc := sdl.GPUColorTargetDescription{
        format = color_format,
        blend_state = {},
    }

    target_info := sdl.GPUGraphicsPipelineTargetInfo{
        num_color_targets = 1,
        color_target_descriptions = &color_desc,
        has_depth_stencil_target = has_depth_target,
        depth_stencil_format = depth_format,
    }

    pipeline = sdl.CreateGPUGraphicsPipeline(s.gpu_device, sdl.GPUGraphicsPipelineCreateInfo{
        vertex_shader = vertex_shader,
        fragment_shader = fragment_shader,
        vertex_input_state = {},
        primitive_type = .TRIANGLELIST,
        rasterizer_state = {
            fill_mode = .FILL,
            cull_mode = .NONE,
            front_face = .COUNTER_CLOCKWISE,
            enable_depth_clip = true,
        },
        multisample_state = {
            sample_count = sample_count,
        },
        depth_stencil_state = {
            enable_depth_test = false,
            enable_depth_write = false,
            enable_stencil_test = false,
        },
        target_info = target_info,
    })

    return
}

procedural_sky_create_cubemap :: proc(size: u32) -> (
    texture: ^sdl.GPUTexture,
    format: sdl.GPUTextureFormat,
    ok: bool,
) {
    if size < 16 {
        log.error("Procedural sky cubemap resolution must be at least 16")
        return
    }

    usage: sdl.GPUTextureUsageFlags = {.COLOR_TARGET, .SAMPLER}

    format = .R16G16B16A16_FLOAT
    if !sdl.GPUTextureSupportsFormat(s.gpu_device, format, .CUBE, usage) {
        format = .R8G8B8A8_UNORM
    }

    if !sdl.GPUTextureSupportsFormat(s.gpu_device, format, .CUBE, usage) {
        log.error("GPU does not support a renderable and sampleable cubemap format")
        return
    }

    texture = sdl.CreateGPUTexture(s.gpu_device, sdl.GPUTextureCreateInfo{
        type = .CUBE,
        format = format,
        usage = usage,
        width = size,
        height = size,
        layer_count_or_depth = 6,
        num_levels = 1,
        sample_count = ._1,
    })

    if texture == nil {
        log.error("Failed to create procedural sky cubemap:", sdl.GetError())
        return
    }

    ok = true
    return
}

create_procedural_skybox :: proc(
    fullscreen_vertex_hd: Shader_Handle,
    generate_fragment_hd: Shader_Handle,
    display_fragment_hd: Shader_Handle,
    display_pass_info: Render_Pass_Info,
    resolution: u32 = 256,
) -> (sky: Procedural_Skybox, ok: bool) {
    vertex := get_shader(fullscreen_vertex_hd)
    generate_fragment := get_shader(generate_fragment_hd)
    display_fragment := get_shader(display_fragment_hd)

    if vertex.shader == nil || generate_fragment.shader == nil || display_fragment.shader == nil {
        log.error("Procedural skybox received an invalid shader handle")
        return
    }

    sky.resolution = resolution
    sky.environment = DF_PROCEDURAL_SKY_ENVIRONMENT
    sky.refresh_interval = 0.1 // 10 Hz cubemap regeneration; set to 0 for every-frame updates.
    sky.dirty = true

    cube, cube_format, cube_ok := procedural_sky_create_cubemap(resolution)
    if !cube_ok {return}
    sky.cubemap = cube
    sky.cubemap_format = cube_format

    sky.sampler = sdl.CreateGPUSampler(s.gpu_device, sdl.GPUSamplerCreateInfo{
        min_filter = .LINEAR,
        mag_filter = .LINEAR,
        mipmap_mode = .LINEAR,
        address_mode_u = .CLAMP_TO_EDGE,
        address_mode_v = .CLAMP_TO_EDGE,
        address_mode_w = .CLAMP_TO_EDGE,
        min_lod = 0,
        max_lod = 0,
    })

    if sky.sampler == nil {
        log.error("Failed to create procedural skybox sampler:", sdl.GetError())
        destroy_procedural_skybox(&sky)
        return
    }

    // The cube is single-sampled and has no depth attachment.
    sky.generate_pipeline = procedural_sky_create_pipeline(
        vertex.shader,
        generate_fragment.shader,
        sky.cubemap_format,
        false,
        s.g_render_settings.depth_texture_format,
        ._1,
    )

    if sky.generate_pipeline == nil {
        log.error("Failed to create procedural sky generation pipeline:", sdl.GetError())
        destroy_procedural_skybox(&sky)
        return
    }

    // Match the render pass this skybox will be drawn into, including MSAA
    // and the presence/absence of its depth-stencil attachment.
    for msa in Sample_Count {
        sky.display_pipeline[msa] = procedural_sky_create_pipeline(
            vertex.shader,
            display_fragment.shader,
            s.g_render_settings.swap_chain_texture_format,
            display_pass_info.has_depth_stencil_target,
            s.g_render_settings.depth_texture_format,
            Sample_Count_To_SDL_Sample_Count[msa],
        )

        if sky.display_pipeline[msa] == nil {
            log.error("Failed to create procedural sky display pipeline:", sdl.GetError())
            destroy_procedural_skybox(&sky)
            return
        }
    }

    ok = true
    return
}

destroy_procedural_skybox :: proc(sky: ^Procedural_Skybox) {
    if sky == nil {return}

    for msa in Sample_Count {
        if sky.display_pipeline[msa] != nil {
            sdl.ReleaseGPUGraphicsPipeline(s.gpu_device, sky.display_pipeline[msa])
        }
    }

    if sky.generate_pipeline != nil {
        sdl.ReleaseGPUGraphicsPipeline(s.gpu_device, sky.generate_pipeline)
    }
    if sky.sampler != nil {
        sdl.ReleaseGPUSampler(s.gpu_device, sky.sampler)
    }
    if sky.cubemap != nil {
        sdl.ReleaseGPUTexture(s.gpu_device, sky.cubemap)
    }

    sky^ = {}
}

procedural_skybox_mark_dirty :: proc(sky: ^Procedural_Skybox) {
    if sky == nil {return}
    sky.dirty = true
}

procedural_skybox_set_environment :: proc(
    sky: ^Procedural_Skybox,
    environment: Procedural_Sky_Environment,
) {
    if sky == nil {return}

    sky.environment = environment
    direction := sky.environment.sun_direction
    if direction.x == 0 && direction.y == 0 && direction.z == 0 {
        direction = {0, 1, 0}
    }
    sky.environment.sun_direction = lin.normalize0(direction)
    sky.dirty = true
}

procedural_skybox_tick :: proc(sky: ^Procedural_Skybox, dt: f32) {
    if sky == nil || dt <= 0 {return}

    sky.environment.time_seconds += dt

    if sky.refresh_interval <= 0 {
        sky.dirty = true
        return
    }

    sky.refresh_elapsed += dt
    if sky.refresh_elapsed >= sky.refresh_interval {
        sky.refresh_elapsed = 0
        sky.dirty = true
    }
}

procedural_skybox_generate :: proc(
    cmd: ^sdl.GPUCommandBuffer,
    sky: ^Procedural_Skybox,
) -> (ok: bool) {
    if cmd == nil || sky == nil || sky.cubemap == nil || sky.generate_pipeline == nil {
        return
    }

    sun := sky.environment.sun_direction
    if sun.x == 0 && sun.y == 0 && sun.z == 0 {
        sun = {0, 1, 0}
    }
    sun = lin.normalize0(sun)

    for face in 0..<6 {
        basis := PROCEDURAL_SKY_CUBE_FACE_BASIS[face]

        params := Procedural_Sky_Generate_Params{
            face_forward = {basis.forward.x, basis.forward.y, basis.forward.z, 0},
            face_right = {basis.right.x, basis.right.y, basis.right.z, 0},
            face_up = {basis.up.x, basis.up.y, basis.up.z, 0},
            sun_direction_time = {sun.x, sun.y, sun.z, sky.environment.time_seconds},
            cloud_params = {
                math.clamp(sky.environment.cloud_density, 0, 1),
                math.max(sky.environment.cloud_scale, 0.01),
                sky.environment.cloud_speed,
                math.clamp(sky.environment.cloud_coverage, 0, 1),
            },
            day_horizon = sky.environment.day_horizon,
            day_zenith = sky.environment.day_zenith,
            night_horizon = sky.environment.night_horizon,
            night_zenith = sky.environment.night_zenith,
            sunset_color = sky.environment.sunset_color,
            sun_color = sky.environment.sun_color,
            atmosphere_params = {
                math.clamp(sky.environment.star_density, 0, 1),
                math.max(sky.environment.atmosphere_strength, 0),
                math.max(sky.environment.moon_intensity, 0),
                cast(f32)sky.resolution,
            },
        }

        color_target := sdl.GPUColorTargetInfo{
            texture = sky.cubemap,
            mip_level = 0,
            layer_or_depth_plane = cast(u32)face,
            load_op = .DONT_CARE,
            store_op = .STORE,
        }

        render_pass := sdl.BeginGPURenderPass(cmd, &color_target, 1, nil)
        if render_pass == nil {
            log.error("Failed to begin procedural sky cubemap face pass:", face, sdl.GetError())
            return
        }

        sdl.BindGPUGraphicsPipeline(render_pass, sky.generate_pipeline)
        sdl.PushGPUFragmentUniformData(cmd, 0, &params, size_of(params))
        sdl.DrawGPUPrimitives(render_pass, 3, 1, 0, 0)
        sdl.EndGPURenderPass(render_pass)
    }

    ok = true
    return
}

procedural_skybox_generate_if_dirty :: proc(
    cmd: ^sdl.GPUCommandBuffer,
    sky: ^Procedural_Skybox,
) -> (generated: bool) {
    if sky == nil || !sky.dirty {return}
    generated = procedural_skybox_generate(cmd, sky)
    if generated {
        sky.dirty = false
    }
    return
}

procedural_skybox_draw :: proc(
    pass: ^R_Pass,
    cam: ^Camera,
    sky: ^Procedural_Skybox,
) {
    if pass == nil || cam == nil || sky == nil {return}
    if pass.render_pas == nil || pass.frame_data == nil || sky.cubemap == nil || sky.sampler == nil {return}
    if cam.type != .perspective || cam.texture_size.x <= 0 || cam.texture_size.y <= 0 {return}

    pipeline := sky.display_pipeline[s.g_render_settings.msaa_samp_count]
    if pipeline == nil {return}

    look_mat := lin.matrix3_from_yaw_pitch_roll_f32(
        lin.to_radians(cam.look.yaw),
        lin.to_radians(cam.look.pitch),
        0,
    )

    // Use the same camera orientation convention as camera_get_forward and
    // update_camera_3d in the existing renderer.
    forward := lin.normalize0(look_mat * Vec3{0, 0, -1})
    right := lin.normalize0(look_mat * Vec3{1, 0, 0})
    up := lin.normalize0(look_mat * Vec3{0, 1, 0})

    aspect := cast(f32)cam.texture_size.x / cast(f32)cam.texture_size.y
    tan_half_fov := math.tan(lin.to_radians(45 * cam.zoom))

    params := Procedural_Sky_Display_Params{
        camera_forward = {forward.x, forward.y, forward.z, 0},
        camera_right = {right.x, right.y, right.z, 0},
        camera_up = {up.x, up.y, up.z, 0},
        viewport_fov = {
            cast(f32)cam.texture_size.x,
            cast(f32)cam.texture_size.y,
            tan_half_fov,
            aspect,
        },
    }

    binding := sdl.GPUTextureSamplerBinding{
        texture = sky.cubemap,
        sampler = sky.sampler,
    }

    sdl.BindGPUGraphicsPipeline(pass.render_pas, pipeline)
    sdl.BindGPUFragmentSamplers(pass.render_pas, 0, &binding, 1)
    sdl.PushGPUFragmentUniformData(pass.frame_data.render_cmd_buf, 0, &params, size_of(params))
    sdl.DrawGPUPrimitives(pass.render_pas, 3, 1, 0, 0)
}
