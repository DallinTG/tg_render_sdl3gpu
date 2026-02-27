
package tg_render

import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import str"core:strings"
import "core:fmt"
import "core:math"
import "core:path/filepath"
import "core:encoding/json"
import lin"core:math/linalg"
import "base:runtime"
import hm "handle_map_static_virtual"
import "core:os"

import sc"shader_cross"

import "core:image"
import "core:image/jpeg"
import "core:image/bmp"
import "core:image/png"
import "core:image/tga"



DEFALT_DEPTH_TEXTURE_CREATEINFO:sdl.GPUTextureCreateInfo:{
	// format= s.depth_texture_format,// gests set during the create proc
	usage = {.DEPTH_STENCIL_TARGET},
	// width = ,// gests set during the create proc
	// height = ,// gests set during the create proc
	layer_count_or_depth = 1,
	num_levels = 1,

}
DEFALT_OPAQUET_DEPTH_STENCIL_STATE :sdl.GPUDepthStencilState:{
	enable_depth_test = true,
	enable_depth_write = true,
	compare_op = .LESS,
}
DEFALT_MASKED_DEPTH_STENCIL_STATE :sdl.GPUDepthStencilState:{
	enable_depth_test = true,
	enable_depth_write = true,
	compare_op = .LESS,
}
DEFALT_TRANSPARENT_DEPTH_STENCIL_STATE :sdl.GPUDepthStencilState:{
	enable_depth_test = true,
	enable_depth_write = false,
	compare_op = .LESS,
}
DEFALT_RASTERRIZER_STATE : sdl.GPURasterizerState:{
	cull_mode = .BACK,
}
DEFALT_TRANSPARENT_BLEND_STATE :sdl.GPUColorTargetBlendState:{
	src_color_blendfactor   = sdl.GPUBlendFactor.SRC_ALPHA,            /**< The value to be multiplied by the source RGB value. */
	dst_color_blendfactor   = sdl.GPUBlendFactor.ONE_MINUS_SRC_ALPHA,  /**< The value to be multiplied by the destination RGB value. */
	color_blend_op          = sdl.GPUBlendOp.ADD,                      /**< The blend operation for the RGB components. */
	src_alpha_blendfactor   = sdl.GPUBlendFactor.ONE,  /**< The value to be multiplied by the source alpha. */
	dst_alpha_blendfactor   = sdl.GPUBlendFactor.ONE_MINUS_SRC_ALPHA,                    /**< The value to be multiplied by the destination alpha. */
	alpha_blend_op          = sdl.GPUBlendOp.ADD,                      /**< The blend operation for the alpha component. */
	color_write_mask        = sdl.GPUColorComponentFlags{.R,.G,.B,.A},            /**< A bitmask specifying which of the RGBA components are enabled for writing. Writes to all channels if enable_color_write_mask is false. */
	enable_blend            = true,                                  /**< Whether blending is enabled for the color target. */
	enable_color_write_mask = true,                                  /**< Whether the color write mask is enabled. */
}
DEFALT_MASKED_BLEND_STATE :sdl.GPUColorTargetBlendState:{
	src_color_blendfactor   = sdl.GPUBlendFactor.SRC_ALPHA,            /**< The value to be multiplied by the source RGB value. */
	dst_color_blendfactor   = sdl.GPUBlendFactor.ONE_MINUS_SRC_ALPHA,  /**< The value to be multiplied by the destination RGB value. */
	color_blend_op          = sdl.GPUBlendOp.ADD,                      /**< The blend operation for the RGB components. */
	src_alpha_blendfactor   = sdl.GPUBlendFactor.ONE,  /**< The value to be multiplied by the source alpha. */
	dst_alpha_blendfactor   = sdl.GPUBlendFactor.ONE_MINUS_SRC_ALPHA,                    /**< The value to be multiplied by the destination alpha. */
	alpha_blend_op          = sdl.GPUBlendOp.ADD,                      /**< The blend operation for the alpha component. */
	color_write_mask        = sdl.GPUColorComponentFlags{.R,.G,.B,.A},            /**< A bitmask specifying which of the RGBA components are enabled for writing. Writes to all channels if enable_color_write_mask is false. */
	enable_blend            = true,                                  /**< Whether blending is enabled for the color target. */
	enable_color_write_mask = true,                                  /**< Whether the color write mask is enabled. */
}
DEFALT_OPAQUET_BLEND_STATE :sdl.GPUColorTargetBlendState:{
	src_color_blendfactor   = sdl.GPUBlendFactor.SRC_ALPHA,            /**< The value to be multiplied by the source RGB value. */
	dst_color_blendfactor   = sdl.GPUBlendFactor.ONE_MINUS_SRC_ALPHA,  /**< The value to be multiplied by the destination RGB value. */
	color_blend_op          = sdl.GPUBlendOp.ADD,                      /**< The blend operation for the RGB components. */
	src_alpha_blendfactor   = sdl.GPUBlendFactor.ONE,  /**< The value to be multiplied by the source alpha. */
	dst_alpha_blendfactor   = sdl.GPUBlendFactor.ONE_MINUS_SRC_ALPHA,                    /**< The value to be multiplied by the destination alpha. */
	alpha_blend_op          = sdl.GPUBlendOp.ADD,                      /**< The blend operation for the alpha component. */
	color_write_mask        = sdl.GPUColorComponentFlags{.R,.G,.B,.A},            /**< A bitmask specifying which of the RGBA components are enabled for writing. Writes to all channels if enable_color_write_mask is false. */
	enable_blend            = true,                                  /**< Whether blending is enabled for the color target. */
	enable_color_write_mask = true,                                  /**< Whether the color write mask is enabled. */
}
DEFALT_R_PASS_INFO:Render_Pass_Info:{
	load_op = .CLEAR, 
	clear_color = {.3, .3, .3, 1},
	has_depth_stencil_target = true,
	depth_texture_createinfo = DEFALT_DEPTH_TEXTURE_CREATEINFO,
	depth_stencil_state =      DEFALT_OPAQUET_DEPTH_STENCIL_STATE,
	rasterizer_state =         DEFALT_RASTERRIZER_STATE,
	blend_state =              DEFALT_OPAQUET_BLEND_STATE,
	vertex_input_state = sdl.GPUVertexInputState{},
}

DEFALT_OPAQUE_PASS:Render_Pass_Info:{
	load_op = .CLEAR, 
	clear_color = {.3, .3, .3, 1},
	has_depth_stencil_target = true,
	depth_texture_createinfo = DEFALT_DEPTH_TEXTURE_CREATEINFO,
	depth_stencil_state =      DEFALT_OPAQUET_DEPTH_STENCIL_STATE,
	rasterizer_state =         DEFALT_RASTERRIZER_STATE,
	blend_state =              DEFALT_OPAQUET_BLEND_STATE,
	vertex_input_state = sdl.GPUVertexInputState{},
}
DEFALT_MASKED_PASS:Render_Pass_Info:{
	load_op = .CLEAR, 
	clear_color = {.3, .3, .3, 1},
	has_depth_stencil_target = true,
	depth_texture_createinfo = DEFALT_DEPTH_TEXTURE_CREATEINFO,
	depth_stencil_state =      DEFALT_MASKED_DEPTH_STENCIL_STATE,
	rasterizer_state =         DEFALT_RASTERRIZER_STATE,
	blend_state =              DEFALT_TRANSPARENT_BLEND_STATE,
	vertex_input_state = sdl.GPUVertexInputState{},
}
DEFALT_TRANSPARENT_PASS:Render_Pass_Info:{
	load_op = .CLEAR, 
	clear_color = {.3, .3, .3, 1},
	has_depth_stencil_target = true,
	depth_texture_createinfo = DEFALT_DEPTH_TEXTURE_CREATEINFO,
	depth_stencil_state =      DEFALT_TRANSPARENT_DEPTH_STENCIL_STATE,
	rasterizer_state =         DEFALT_RASTERRIZER_STATE,
	blend_state =              DEFALT_TRANSPARENT_BLEND_STATE,
	vertex_input_state = sdl.GPUVertexInputState{},
}
