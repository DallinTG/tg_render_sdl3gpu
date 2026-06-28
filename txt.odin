package tg_render


import "core:prof/spall"
import "core:mem"
import "core:log"
import "core:os"
import "core:fmt"

import "core:image"


import "core:math"
import "core:math/linalg"

import tt "vendor:stb/truetype"
import stbrp "vendor:stb/rect_pack"

import hm "handle_map_static_virtual"

font_bitmap_w :: 64*8
font_bitmap_h :: 64*8
char_count :: 96
DEFALT_FONT::#load("assets/fonts/alagard.ttf")
// DEFALT_FONT::#load("defalt_assets/fonts/roboto.ttf")
Font_Handle :: distinct Handle
Font :: struct {
	handle:Font_Handle,
	char_data: [char_count]tt.bakedchar,
	sg_image: Texture_ID_Types,
	info:tt.fontinfo,
	height:f32,
	
	ascent:f32,
	descent:f32,
	lineGap:f32,
}
// font: Font
load_font_from_data :: proc(font_id:string ,height:f32, ttf_data:[]u8 = DEFALT_FONT,)->(font_hd:Font_Handle){
	font:Font
	font.height = height
	bitmap:=new([font_bitmap_w * font_bitmap_h][1]u8)
	new_bitmap:=new([font_bitmap_w * font_bitmap_h][4]u8)
	defer free(new_bitmap)
	defer free(bitmap)
	tt.InitFont(&font.info, raw_data(ttf_data), 0)
	scal:=tt.ScaleForMappingEmToPixels(&font.info,height)
	// scal:=tt.ScaleForPixelHeight(&font.info,height)
	ascent:i32
	descent:i32
	lineGap:i32
	tt.GetFontVMetrics(&font.info,&ascent, &descent, &lineGap)
	font.ascent  = cast(f32)ascent*scal
	font.descent = cast(f32)descent*scal
	font.lineGap = cast(f32)lineGap*scal
	
	ret := tt.BakeFontBitmap(raw_data(ttf_data), 0, cast(f32)(ascent-descent) * scal, transmute([^]byte)raw_data(bitmap), font_bitmap_w, font_bitmap_h, 32, char_count, &font.char_data[0])
	assert(ret > 0, "not enough space in bitmap")
	for bit, i in bitmap{
		new_bitmap[i].r = bit.x
		new_bitmap[i].g = bit.x
		new_bitmap[i].b = bit.x
		new_bitmap[i].a = bit.x
	}
	img ,ok:= image.pixels_to_image(pixels = new_bitmap[:],width = font_bitmap_w, height = font_bitmap_h,)
	id :=[2]string{"font_id","font"}
	reg_texture_from_bits(&img,id, format = .R8G8B8A8_UNORM)
	font.sg_image = id
	font_hd = hm.add(&s.fonts, font)

	return
}
get_font::proc(font_hd:Font_Handle)->(font:^Font){
	font = hm.get(s.fonts, font_hd)
	return
}

Txt_Origin::enum{
	top,
	top_bace,
	bot_bace,
	bot,
}

draw_text :: proc(
	mesh: ^Mesh_CPU, 
	$vert_t:typeid, 
	pos: [3]f32, 
	text: string,
	origin: Vec3 = {}, 
	rot:[3]f32 = {}, 
	col:[4]f32={1,1,1,1}, 
	scale:f32= 1,
	fixed_spacing:f32 = 0,
	txt_origin:Txt_Origin=.top,
	scissor_rect:Vec4={},
	
	
){
	font:=get_font(s.defalt_font)
	// scale:=tt.ScaleForMappingEmToPixels(&font.info,scale)
	debug_text := false
	// draw glyphs one by one
	y_origin_offset:f32
	switch txt_origin {
	case .top:  y_origin_offset = (font.ascent - font.descent)
	case .top_bace:  y_origin_offset = (font.ascent)
	case .bot_bace: y_origin_offset = 0
	case .bot:  y_origin_offset = (font.descent)
	}
	x: f32
	y: f32
	for char in text {
		
		advance_x: f32
		advance_y: f32

		q: tt.aligned_quad
		tt.GetBakedQuad(&font.char_data[0], font_bitmap_w, font_bitmap_h, cast(i32)char - 32, &advance_x, &advance_y, &q, false)
		if  fixed_spacing != 0{
			advance_x = fixed_spacing
		}
		size := Vec2{ abs(q.x0 - q.x1), abs(q.y0 - q.y1) }
		uv:=[4]f32{
			q.s0,q.t0,
			q.s1,q.t1,
		}
		w_h:=size
		rect:Rect={
			pos = pos,
			w_h = size*scale,
		}
		origin := origin
		origin.x += x*scale
		origin.y += (y+w_h.y-y_origin_offset)*scale
		
		if debug_text {
			// draw_rect(mesh = mesh, tex_id = [2]u32{0,0}, rect = {pos,{.01,.01}}, origin = origin, rot = rot,uv = uv, vert_t = vert_t,)
			draw_rect(mesh = mesh, tex_id = [2]u32{0,0}, rect = {pos,{1,1}}, origin = {}, rot = rot,uv = uv, vert_t = vert_t,scissor_rect= scissor_rect)
			// draw_rect(mesh = mesh, tex_id = [2]u32{0,0}, rect = rect, origin = origin, rot = rot,uv = uv, vert_t = vert_t,)
		}
		draw_rect(mesh = mesh, tex_id = font.sg_image, rect = rect, origin = origin, rot = rot,uv = uv, col = col, vert_t = vert_t, scissor_rect= scissor_rect)
		x += advance_x
		y += -advance_y	
	}
}

draw_fps :: proc(
	mesh: ^Mesh_CPU, 
	$vert_t:typeid, 
	pos: [3]f32, 
	// text: string,
	origin: Vec3 = {}, 
	rot:[3]f32 = {}, 
	col:[4]f32={1,1,1,1}, 
	scale:f32= 1,
	fixed_spacing:f32 = 0,
	txt_origin:Txt_Origin=.top,
	scissor_rect:Vec4={},
	
){
	draw_text(mesh,vert_t,pos, fmt.tprint("FPS:",math.round(s.time.smooth_fps)),origin,rot,col,scale,fixed_spacing,txt_origin, scissor_rect=scissor_rect)
}

draw_tps :: proc(
	mesh: ^Mesh_CPU, 
	$vert_t:typeid, 
	pos: [3]f32, 
	// text: string,
	origin: Vec3 = {}, 
	rot:[3]f32 = {}, 
	col:[4]f32={1,1,1,1}, 
	scale:f32= 1,
	fixed_spacing:f32 = 0,
	txt_origin:Txt_Origin=.top,
	scissor_rect:Vec4={},
	
	
	
){
	// fmt.print(fmt.tprint("TPS:",s.time.tps),"\n")
	draw_text(mesh,vert_t,pos, fmt.tprint("TPS:",math.round(s.time.smooth_tps)),origin,rot,col,scale,fixed_spacing,txt_origin,scissor_rect=scissor_rect)
}

measure_text :: proc(
	// mesh: ^Mesh_CPU, 
	// $vert_t:typeid, 
	// pos: [3]f32, 
	text: string,
	// origin: Vec3 = {}, 
	// rot:[3]f32 = {}, 
	// col:[4]f32={1,1,1,1}, 
	scale:f32= 1, 
	fixed_spacing:f32 = 0,
	// txt_origin:Txt_Origin=.top
	
)->(box:[2]f32){
	font:=get_font(s.defalt_font)
	// scale:=tt.ScaleForMappingEmToPixels(&font.info,scale)
	debug_text := false
	// draw glyphs one by one
	y_origin_offset:f32
	// switch txt_origin {
	// case .top:  y_origin_offset = (font.ascent - font.descent)
	// case .top_bace:  y_origin_offset = (font.ascent)
	// case .bot_bace: y_origin_offset = 0
	// case .bot:  y_origin_offset = (font.descent)
	// }
	x: f32
	y: f32
	for char in text {
		
		advance_x: f32
		advance_y: f32
		q: tt.aligned_quad
		tt.GetBakedQuad(&font.char_data[0], font_bitmap_w, font_bitmap_h, cast(i32)char - 32, &advance_x, &advance_y, &q, false)
		if  fixed_spacing != 0{
			advance_x = fixed_spacing
		}
		// size := Vec2{ abs(q.x0 - q.x1), abs(q.y0 - q.y1) }
		// uv:=[4]f32{
		// 	q.s0,q.t0,
		// 	q.s1,q.t1,
		// }
		// w_h:=size
		// rect:Rect={
		// 	pos = pos,
		// 	w_h = size*scale,
		// }
		// origin := origin
		// origin.x += x*scale
		// origin.y += (y+w_h.y-y_origin_offset)*scale
		// if debug_text {
		// 	// draw_rect(mesh = mesh, tex_id = [2]u32{0,0}, rect = {pos,{.01,.01}}, origin = origin, rot = rot,uv = uv, vert_t = vert_t,)
		// 	draw_rect(mesh = mesh, tex_id = [2]u32{0,0}, rect = {pos,{1,1}}, origin = {}, rot = rot,uv = uv, vert_t = vert_t,)
		// 	// draw_rect(mesh = mesh, tex_id = [2]u32{0,0}, rect = rect, origin = origin, rot = rot,uv = uv, vert_t = vert_t,)
		// }
		// draw_rect(mesh = mesh, tex_id = font.sg_image, rect = rect, origin = origin, rot = rot,uv = uv, vert_t = vert_t,)
		x += advance_x
		y += -advance_y	
	}

	y +=font.height
	box = {x*scale,y*scale}
	return box
}
