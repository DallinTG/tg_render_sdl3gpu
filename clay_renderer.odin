package tg_render

import sdl "vendor:sdl3"
import "core:fmt"
import "core:unicode/utf8"
import "base:runtime"
import cl "clay-odin"
import "core:c"
import "core:math"
import "core:strings"
import hm "handle_map_static_virtual"
// import rl "vendor:raylib"

// Raylib_Font :: struct {
//     fontId: u16,
//     // font:   rl.Font,
// }

// clay_color_to_rl_color :: proc(color: cl.Color) -> rl.Color {
//     return {u8(color.r), u8(color.g), u8(color.b), u8(color.a)}
// }

// raylib_fonts := [dynamic]Raylib_Font{}

// Alias for compatibility, default to ascii support


// measure_text_unicode :: proc "c" (text: cl.StringSlice, config: ^cl.TextElementConfig, userData: rawptr) -> cl.Dimensions {
//     // Needed for grapheme_count
//     context = runtime.default_context()
    
// 	line_width: f32 = 0
    
// 	// font := raylib_fonts[config.fontId].font
// 	text_str := string(text.chars[:text.length])

//     // This function seems somewhat expensive, if you notice performance issues, you could assume
//     // - 1 codepoint per visual character (no grapheme clusters), where you can get the length from the loop
//     // - 1 byte per visual character (ascii), where you can get the length with `text.length`
//     // see `measure_text_ascii`
//     grapheme_count, _, _ := utf8.grapheme_count(text_str)

// 	for letter, byte_idx in text_str {
// 		glyph_index := rl.GetGlyphIndex(font, letter)

//         glyph := font.glyphs[glyph_index]

// 		if glyph.advanceX != 0 {
// 			line_width += f32(glyph.advanceX)
// 		} else {
// 			line_width += font.recs[glyph_index].width + f32(font.glyphs[glyph_index].offsetX)
// 		}
// 	}

// 	scaleFactor := f32(config.fontSize) / f32(font.baseSize)

//     // Note: 
//     //   I'd expect this to be `grapheme_count - 1`, 
//     //   but that seems to be one letterSpacing too small
//     //   maybe that's a raylib bug, maybe that's Clay?
// 	total_spacing := f32(grapheme_count) * f32(config.letterSpacing)

// 	return {width = line_width * scaleFactor + total_spacing, height = f32(config.fontSize)}
// }

// measure_text_ascii :: proc "c" (text: cl.StringSlice, config: ^cl.TextElementConfig, userData: rawptr) -> cl.Dimensions {    
// 	line_width: f32 = 0
    
// 	font := raylib_fonts[config.fontId].font
// 	text_str := string(text.chars[:text.length])

// 	for i in 0..<len(text_str) {
// 		glyph_index := text_str[i] - 32

//         glyph := font.glyphs[glyph_index]

// 		if glyph.advanceX != 0 {
// 			line_width += f32(glyph.advanceX)
// 		} else {
// 			line_width += font.recs[glyph_index].width + f32(font.glyphs[glyph_index].offsetX)
// 		}
// 	}

// 	scaleFactor := f32(config.fontSize) / f32(font.baseSize)

//     // Note: 
//     //   I'd expect this to be `len(text_str) - 1`, 
//     //   but that seems to be one letterSpacing too small
//     //   maybe that's a raylib bug, maybe that's Clay?
// 	total_spacing := f32(len(text_str)) * f32(config.letterSpacing)

// 	return {width = line_width * scaleFactor + total_spacing, height = f32(config.fontSize)}
// }

UI_Vertex_Data :: struct #align(16){
	pos:Vec4,
	// _1:f32,
	col:Vec4,
	uv: [2]f32,
	// _2:[2]f32,
	img_index:u32,
	layer:u32,
	col_over:[4]f32,
}
DEFALT_UI_VERTEX_DATA::UI_Vertex_Data 
clay_render :: proc(clay_instance:Clay_I_Handle, render_commands: ^cl.ClayArray(cl.RenderCommand),mesh:^Mesh_CPU, allocator := context.temp_allocator) {
	inst:=get_clay_instance(clay_instance)
	inst.z_offset = 0
	clear_mesh_cpu(mesh)
	draw_rect_clay(inst, mesh,0, 0, 0, 0, {0,0,0,0})// this is just a blank rect to force it to update
    for i in 0 ..< render_commands.length {
        render_command := cl.RenderCommandArray_Get(render_commands, i)
        bounds := render_command.boundingBox

        switch render_command.commandType {
        case .None: // None
        case .Text:
            config := render_command.renderData.text

            text := string(config.stringContents.chars[:config.stringContents.length])

            // // Raylib uses C strings instead of Odin strings, so we need to clone
            // // Assume this will be freed elsewhere since we default to the temp allocator
            cstr_text := strings.clone_to_cstring(text, allocator)

            // font := raylib_fonts[config.fontId].font
            
            draw_text(mesh = mesh,vert_t = DEFALT_UI_VERTEX_DATA, pos = {bounds.x, bounds.y*-1, 0}, text = text,col = config.textColor ,scale = cast(f32)config.fontSize * inst.gbl_font_size)
            // rl.DrawTextEx(font, cstr_text, {bounds.x, bounds.y}, f32(config.fontSize), f32(config.letterSpacing), clay_color_to_rl_color(config.textColor))
        case .Image:
            // config := render_command.renderData.image
            // tint := config.backgroundColor
            // if tint == 0 {
            //     tint = {255, 255, 255, 255}
            // }

            // imageTexture := (^rl.Texture2D)(config.imageData)
            // rl.DrawTextureEx(imageTexture^, {bounds.x, bounds.y}, 0, bounds.width / f32(imageTexture.width), clay_color_to_rl_color(tint))
            // draw_rect()
        case .ScissorStart:
            // rl.BeginScissorMode(i32(math.round(bounds.x)), i32(math.round(bounds.y)), i32(math.round(bounds.width)), i32(math.round(bounds.height)))
        case .ScissorEnd:
            // rl.EndScissorMode()
        case .Rectangle:
            config := render_command.renderData.rectangle
            if config.cornerRadius.topLeft > 0 {
                radius: f32 = (config.cornerRadius.topLeft * 2) / min(bounds.width, bounds.height)
                draw_rect_rounded_clay(bounds.x, bounds.y, bounds.width, bounds.height, radius, config.backgroundColor)
            } else {
                draw_rect_clay(inst, mesh,bounds.x, bounds.y, bounds.width, bounds.height, config.backgroundColor)
            }
        case .Border:
            config := render_command.renderData.border
            // Left border
            if config.width.left > 0 {
                draw_rect_clay(
                	inst,
                	mesh,
                    bounds.x,
                    bounds.y + config.cornerRadius.topLeft,
                    f32(config.width.left),
                    bounds.height - config.cornerRadius.topLeft - config.cornerRadius.bottomLeft,
                    config.color,
                )
            }
            // Right border
            if config.width.right > 0 {
                draw_rect_clay(
                	inst,
                	mesh,
                    bounds.x + bounds.width - f32(config.width.right),
                    bounds.y + config.cornerRadius.topRight,
                    f32(config.width.right),
                    bounds.height - config.cornerRadius.topRight - config.cornerRadius.bottomRight,
                    config.color,
                )
            }
            // Top border
            if config.width.top > 0 {
                draw_rect_clay(
                	inst,
                	mesh,
                    bounds.x + config.cornerRadius.topLeft,
                    bounds.y,
                    bounds.width - config.cornerRadius.topLeft - config.cornerRadius.topRight,
                    f32(config.width.top),
                    config.color,
                )
            }
            // Bottom border
            if config.width.bottom > 0 {
                draw_rect_clay(
                	inst,
                	mesh,
                    bounds.x + config.cornerRadius.bottomLeft,
                    bounds.y + bounds.height - f32(config.width.bottom),
                    bounds.width - config.cornerRadius.bottomLeft - config.cornerRadius.bottomRight,
                    f32(config.width.bottom),
                    config.color,
                )
            }

            // Rounded Borders
            if config.cornerRadius.topLeft > 0 {
                draw_arc(
                    bounds.x + config.cornerRadius.topLeft, 
                    bounds.y + config.cornerRadius.topLeft,
                    config.cornerRadius.topLeft - f32(config.width.top),
                    config.cornerRadius.topLeft,
                    180,
                    270,
                    config.color,
                )
            }
            if config.cornerRadius.topRight > 0 {
                draw_arc(
                    bounds.x + bounds.width - config.cornerRadius.topRight,
                    bounds.y + config.cornerRadius.topRight,
                    config.cornerRadius.topRight - f32(config.width.top),
                    config.cornerRadius.topRight,
                    270,
                    360,
                    config.color,
                )
            }
            if config.cornerRadius.bottomLeft > 0 {
                draw_arc(
                    bounds.x + config.cornerRadius.bottomLeft,
                    bounds.y + bounds.height - config.cornerRadius.bottomLeft,
                    config.cornerRadius.bottomLeft - f32(config.width.top),
                    config.cornerRadius.bottomLeft,
                    90,
                    180,
                    config.color,
                )
            }
            if config.cornerRadius.bottomRight > 0 {
                draw_arc(
                    bounds.x + bounds.width - config.cornerRadius.bottomRight, 
                    bounds.y + bounds.height - config.cornerRadius.bottomRight,
                    config.cornerRadius.bottomRight - f32(config.width.bottom),
                    config.cornerRadius.bottomRight,
                    0.1,
                    90,
                    config.color,
                )
            }
        case cl.RenderCommandType.Custom:
            // Implement custom element rendering here
        }
    }
}

// Helper procs, mainly for repeated conversions

@(private = "file")
draw_arc :: proc(x, y: f32, inner_rad, outer_rad: f32,start_angle, end_angle: f32, color: cl.Color){
    // rl.DrawRing(
    //     {math.round(x),math.round(y)},
    //     math.round(inner_rad),
    //     outer_rad,
    //     start_angle,
    //     end_angle,
    //     10,
    //     clay_color_to_rl_color(color),
    // )
}


@(private = "file")
draw_rect_clay :: proc(clay_instance:^Clay_Instance,mesh:^Mesh_CPU, x, y, w, h: f32, color: cl.Color) {
    rect:Rect={
    	pos = {x,y*-1,0+clay_instance.z_offset},
     	w_h = {w,h}
    }
    clay_instance.z_offset+=clay_instance.z_offseter
    draw_rect(mesh = mesh,tex_id= [2]u32{1,0},rect = rect, vert_t = DEFALT_UI_VERTEX_DATA,col = color,)
}

@(private = "file")
draw_rect_rounded_clay :: proc(x,y,w,h: f32, radius: f32, color: cl.Color){
    // rl.DrawRectangleRounded({x,y,w,h},radius,8,clay_color_to_rl_color(color))
}
errorHandler :: proc "c" (errorData: cl.ErrorData) {
    if (errorData.errorType == cl.ErrorType.DuplicateId) {
        // etc
    }
}
//______________________________________________________________________________
Clay_I_Handle :: distinct Handle

Clay_Instance::struct{
	handle:Clay_I_Handle,
	ctx:^cl.Context,
	pass:R_Pass,
	mesh:Mesh_Handle,
	arena:cl.Arena,
	z_offseter:    f32,
	z_offset:      f32,
	gbl_font_size: f32,
}
get_clay_instance::proc(hd:Clay_I_Handle)->(clay_instance:^Clay_Instance){
	clay_instance = hm.get(s.clay_instances,hd)
	return
}

init_clay_instance::proc(
	// $vert_t:       typeid,
	dimentions:    [2]f32,
	// window_hd:     Window_Handle,
	vert_shader:   Shader_Handle,
	frag_shader:   Shader_Handle,
	gpu_buf_size:  int = 5000,
	z_offseter:    f32 = 0, 
	gbl_font_size: f32 = 1,
)->(instance_hd:Clay_I_Handle){
	inst_raw:Clay_Instance
    instance_hd = hm.add(&s.clay_instances,inst_raw)
    inst:=get_clay_instance(instance_hd)
    
    inst.gbl_font_size = gbl_font_size
	inst.pass = create_render_pass(vert_shader, frag_shader, info = DEFALT_TEXT_PASS)
	mesh_cpu:Mesh_CPU={attribute_type = DEFALT_UI_VERTEX_DATA}
	inst.mesh = create_mesh(mesh_cpu,gpu_buf_size)
	inst.z_offseter = z_offseter
	
	minMemorySize: c.size_t = cast(c.size_t)cl.MinMemorySize()
    memory := make([^]u8, minMemorySize)
    inst.arena = cl.CreateArenaWithCapacityAndMemory(minMemorySize, memory)
    inst.ctx=cl.Initialize(inst.arena, {dimentions.x,dimentions.y}, { handler = errorHandler })
    
    cl.SetCurrentContext(inst.ctx,)
    cl.SetMeasureTextFunction(measure_text_clay, inst)
    return
}
update_clay_instance::proc(clay_instance:Clay_I_Handle, renderCommands: ^cl.ClayArray(cl.RenderCommand), wh:[2]i32, mouse_pos:[2]f32 = {-1,-1}, mouse_down :bool=false){
	inst:=get_clay_instance(clay_instance)
	mesh:=get_mesh(inst.mesh)
	cl.SetLayoutDimensions({ cast(f32)wh.x, cast(f32)wh.y })
	cl.SetPointerState( mouse_pos, mouse_down)
	

	clay_render(clay_instance,renderCommands,&mesh.cpu)
	update_mesh(inst.mesh)


}
render_clay_instance::proc(
	clay_instance:Clay_I_Handle,
	camera:^Camera,
	render_target:Render_Targets,
	load_op:	sdl.GPULoadOp=.LOAD,
	d_load_op:	sdl.GPULoadOp=.LOAD,
	store_op:   sdl.GPUStoreOp = .STORE,
	d_store_op: sdl.GPUStoreOp = .STORE,
	clear_color:[4]f32={.3,.3,.3,1},
){
	inst:=get_clay_instance(clay_instance)
	do_render_pass(
		&inst.pass, 
		camera, 
		{inst.mesh}, 
		render_target, 
		load_op = load_op, 
		d_load_op = d_load_op, 
		clear_color = clear_color,
		store_op = store_op, 
		d_store_op = d_store_op
	)	
}
update_render_clay_instance::proc(
	clay_instance:Clay_I_Handle,
	renderCommands: ^cl.ClayArray(cl.RenderCommand),
	camera:^Camera,
	render_target:Render_Targets,
	load_op:	sdl.GPULoadOp=.LOAD,
	d_load_op:	sdl.GPULoadOp=.LOAD,
	clear_color:[4]f32={.3,.3,.3,1},
	 wh:[2]i32
){
	update_clay_instance(clay_instance, renderCommands, wh)
	render_clay_instance(clay_instance, camera, render_target, load_op = load_op, d_load_op = d_load_op, clear_color = clear_color)
}
delete_clay_instance::proc(clay_instance:Clay_I_Handle){
	inst:=get_clay_instance(clay_instance)
	delete_r_pass(&inst.pass)
	delete_mesh(inst.mesh)
	free(inst.arena.memory)
}

measure_text_clay:: proc "c" (text: cl.StringSlice, config: ^cl.TextElementConfig, userData: rawptr) -> cl.Dimensions {
	inst:= cast(^Clay_Instance)userData
	context = s.defalt_context
	text := string(text.chars[:text.length])
	box:=measure_text(text = text, scale = cast(f32)config.fontSize * inst.gbl_font_size)
	return {box.x,box.y}
}
