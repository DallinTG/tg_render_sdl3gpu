package tg_render

import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import str"core:strings"
import "core:fmt"
import "core:time"
import "core:math"
import "core:path/filepath"
import "core:encoding/json"
import lin"core:math/linalg"
import "base:runtime"
// import hm "handle_map_static_virtual"
import hm "core:container/handle_map"
import "core:os"

import sc"shader_cross"

import "core:image"
import "core:image/jpeg"
import "core:image/bmp"
import "core:image/png"
import "core:image/tga"

// some of the shape stuff was stolen from Karle2D https://github.com/karl-zylinski/karl2d/blob/master/karl2d.odin

Rect_Shape :: struct {
	x, y, z: f32,
	w, h: f32,
}



// Returns true if rectangles `a` and `b` are overlapping.
rect_overlapping :: proc(a: Rect_Shape, b: Rect_Shape) -> bool {
	return \
		a.x < b.x + b.w &&
		a.x + a.w > b.x &&
		a.y < b.y + b.h &&
		a.y + a.h > b.y
}

// Returns the overlap of rectangle `a` and `b`. The second return value is `false` if no overlap
// was found, `true` otherwise.
rect_overlap :: proc(a: Rect_Shape, b: Rect_Shape) -> (Rect_Shape, bool) {
	overlap_x := max(0, min(a.x + a.w, b.x + b.w) - max(a.x, b.x))
	overlap_y := max(0, min(a.y + a.h, b.y + b.h) - max(a.y, b.y))

	if overlap_x == 0 || overlap_y == 0 {
		return {}, false
	}

	return {
		x = max(a.x, b.x),
		y = max(a.y, b.y),
		w = overlap_x,
		h = overlap_y,
	}, true
}

// Return true if `point` is inside `rect`.
point_in_rect :: proc(point: Vec2, rect: Rect_Shape) -> bool {
	return \
		point.x >= rect.x &&
		point.x < rect.x + rect.w &&
		point.y >= rect.y &&
		point.y < rect.y + rect.h
}

// Returns the mid-point of a rectangle.
//
// Useful when for passing as `origin` to drawing procedures, especially when you want the
// drawn thing to rotate around its center.
rect_middle :: proc(r: Rect_Shape) -> Vec2 {
	return { r.x + r.w/2, r.y + r.h/2 }
}

rect_center :: rect_middle
rect_centre :: rect_middle

// Combine a position and a size into a rectangle.
rect_from_pos_size :: proc(pos: Vec2, size: Vec2) -> Rect_Shape {
	return {
		x = pos.x,
		y = pos.y,
		w = size.x,
		h = size.y,
	}
}

// Get the top left corner of a rectangle.
rect_top_left :: proc(r: Rect_Shape) -> Vec2 {
	return {r.x, r.y}
}

// Get the top middle point of a rectangle. That is, the mid-point between the top left and top
// right corners.
rect_top_middle :: proc(r: Rect_Shape) -> Vec2 {
	return {r.x + r.w / 2, r.y}
}

// Get the top right corner of a rectangle.
rect_top_right :: proc(r: Rect_Shape) -> Vec2 {
	return {r.x + r.w, r.y}
}

// Get the bottom left corner of a rectangle.
rect_bottom_left :: proc(r: Rect_Shape) -> Vec2 {
	return {r.x, r.y + r.h}
}

// Get the bottom middle point of a rectangle. That is, the mid-point between the bottom left and
// bottom right corners.
rect_bottom_middle :: proc(r: Rect_Shape) -> Vec2 {
	return {r.x + r.w / 2, r.y + r.h}
}

// Get the bottom right corner of a rectangle.
rect_bottom_right :: proc(r: Rect_Shape) -> Vec2 {
	return {r.x + r.w, r.y + r.h}
}

// Make a rectangle smaller by `x` pixels in the horizontal direction and `y` pixels in the vertical
rect_shrink :: proc(r: Rect_Shape, x: f32, y: f32) -> Rect_Shape {
	return {
		r.x + x,
		r.y + y,
		r.z ,
		r.w - x * 2,
		r.h - y * 2,
	}
}

// Make a rectangle bigger by `x` pixels in the horizontal direction and `y` pixels in the vertical.
rect_expand :: proc(r: Rect_Shape, x: f32, y: f32) -> Rect_Shape {
	return {
		r.x - x,
		r.y - y,
		r.z ,
		r.w + x * 2,
		r.h + y * 2,
	}
}

// Cut off `h` pixels from the top of `r`. `r` is modified. The cut off part is returned.
// `m` is the margin added above the cut part.
rect_cut_top :: proc(r: ^Rect_Shape, h: f32, m: f32) -> Rect_Shape {
	res := r^
	res.y += m
	res.h = h
	r.y += h + m
	r.h -= h + m
	return res
}

// Cut off `h` pixels from the bottom of `r`. `r` is modified. The cut off part is returned.
// `m` is the margin added below the cut part.
rect_cut_bottom :: proc(r: ^Rect_Shape, h: f32, m: f32) -> Rect_Shape {
	res := r^
	res.h = h
	res.y = r.y + r.h - h - m
	r.h -= h + m
	return res
}

// Cut off `w` pixels from the left of `r`. `r` is modified. The cut off part is returned.
// `m` is the margin added to the left of the cut part.
rect_cut_left :: proc(r: ^Rect_Shape, w: f32, m: f32) -> Rect_Shape {
	res := r^
	res.x += m
	res.w = w
	r.x += w + m
	r.w -= w + m
	return res
}

// Cut off `w` pixels from the right of `r`. `r` is modified. The cut off part is returned.
// `m` is the margin added to the right of the cut part.
rect_cut_right :: proc(r: ^Rect_Shape, w: f32, m: f32) -> Rect_Shape {
	res := r^
	res.w = w
	res.x = r.x + r.w - w - m
	r.w -= w + m
	return res
}


// Rotate 2D vector `v` by `angle_radians` radians around the origin (0, 0).
//
// If you need to rotate around a point that is not the origin, then you can first subtract the
// point from `v`, then rotate and then add the point back to the result.
rotate :: proc(v: Vec2, angle_radians: f32) -> Vec2 {
	cos := math.cos(angle_radians)
	sin := math.sin(angle_radians)

	return {
		v.x * cos - v.y * sin,
		v.x * sin + v.y * cos,
	}
}

vec3_from_vec2 :: proc(v: Vec2) -> Vec3 {
	return {
		v.x, v.y, 0,
	}
}

frame_cstring :: proc(st: string, loc := #caller_location) -> cstring {
	return str.clone_to_cstring(st, s.frame_allocator, loc)
}

// An RGBA (Red, Green, Blue, Alpha) color. Each channel can have a value between 0 and 255.
Color :: [4]u8

// See the folder examples/palette for a demo that shows all colors
BLACK        :: Color { 0, 0, 0, 255 }
WHITE        :: Color { 255, 255, 255, 255 }
BLANK        :: Color { 0, 0, 0, 0 }
LIGHT_GRAY   :: Color { 183, 183, 183, 255 } 
GRAY         :: Color { 100, 100, 100, 255} 
DARK_GRAY    :: Color { 66, 66, 66, 255} 
BLUE         :: Color { 25, 198, 236, 255 }
DARK_BLUE    :: Color { 7, 47, 88, 255 }
LIGHT_BLUE   :: Color { 200, 230, 255, 255 }
GREEN        :: Color { 16, 130, 11, 255 }
DARK_GREEN   :: Color { 6, 53, 34, 255}
LIGHT_GREEN  :: Color { 175, 246, 184, 255 }
ORANGE       :: Color { 255, 114, 0, 255 }
RED          :: Color { 239, 53, 53, 255 }
DARK_RED     :: Color { 127, 10, 10, 255 }
LIGHT_RED    :: Color { 248, 183, 183, 255 }
BROWN        :: Color { 115, 78, 74, 255 }
DARK_BROWN   :: Color { 50, 36, 32, 255 }
LIGHT_BROWN  :: Color { 146, 119, 119, 255 }
PURPLE       :: Color { 155, 31, 232, 255 }
LIGHT_PURPLE :: Color { 217, 172, 248, 255 }
MAGENTA      :: Color { 209, 17, 209, 255 }
YELLOW       :: Color { 250, 250, 129, 255 }
LIGHT_YELLOW :: Color { 253, 250, 222, 255 }

// These are from Raylib. They are here so you can easily port a Raylib program to Karl2D.
RL_LIGHTGRAY  :: Color { 200, 200, 200, 255 }
RL_GRAY       :: Color { 130, 130, 130, 255 }
RL_DARKGRAY   :: Color { 80, 80, 80, 255 }
RL_YELLOW     :: Color { 253, 249, 0, 255 }
RL_GOLD       :: Color { 255, 203, 0, 255 }
RL_ORANGE     :: Color { 255, 161, 0, 255 }
RL_PINK       :: Color { 255, 109, 194, 255 }
RL_RED        :: Color { 230, 41, 55, 255 }
RL_MAROON     :: Color { 190, 33, 55, 255 }
RL_GREEN      :: Color { 0, 228, 48, 255 }
RL_LIME       :: Color { 0, 158, 47, 255 }
RL_DARKGREEN  :: Color { 0, 117, 44, 255 }
RL_SKYBLUE    :: Color { 102, 191, 255, 255 }
RL_BLUE       :: Color { 0, 121, 241, 255 }
RL_DARKBLUE   :: Color { 0, 82, 172, 255 }
RL_PURPLE     :: Color { 200, 122, 255, 255 }
RL_VIOLET     :: Color { 135, 60, 190, 255 }
RL_DARKPURPLE :: Color { 112, 31, 126, 255 }
RL_BEIGE      :: Color { 211, 176, 131, 255 }
RL_BROWN      :: Color { 127, 106, 79, 255 }
RL_DARKBROWN  :: Color { 76, 63, 47, 255 }
RL_WHITE      :: WHITE
RL_BLACK      :: BLACK
RL_BLANK      :: BLANK
RL_MAGENTA    :: Color { 255, 0, 255, 255 }
RL_RAYWHITE   :: Color { 245, 245, 245, 255 }


Color_F32 :: [4]f32
color_alpha :: proc(c: Color, a: u8) -> Color {
	return {c.r, c.g, c.b, a}
}

f32_color_from_color :: proc(color: Color) -> Color_F32 {
	return {
		f32(color.r) / 255,
		f32(color.g) / 255,
		f32(color.b) / 255,
		f32(color.a) / 255,
	}
}
