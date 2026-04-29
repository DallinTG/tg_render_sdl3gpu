package tg_render

import "vendor:stb/truetype"

import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import hm "handle_map_static_virtual"

import lin"core:math/linalg"
import cl"clay-odin"

UI_Style::struct{
	col:struct{
		fg:			[4]f32,
		fg_alt:		[4]f32,
		bg:			[4]f32,
		bg_alt:		[4]f32,
		txt_main: 	[4]f32,
		txt_bright: [4]f32,
		txt_muted: 	[4]f32,
		focus: 		[4]f32,
		border: 	[4]f32,
		button:		[4]f32,
		button_hov:	[4]f32,
	},
	siz:struct{
		txt:f32,
		txt_h1:f32,
		txt_h2:f32,
		txt_h3:f32,
		txt_h4:f32,
		
		border:f32,
	},
	pading:struct{
		button:[4]f32,
	},
}
DEFALT_UI_STYLE:UI_Style:{
	col = {
		fg			= {0.086, 0.122, 0.153, 1},
		fg_alt		= {0.102, 0.141, 0.184, 1},
		bg			= {0.086, 0.122, 0.153, 1},
		bg_alt		= {0.102, 0.141, 0.184, 1},
		txt_main 	= {0.859, 0.859, 0.859, 1},
		txt_bright	= {0.859, 0.859, 0.859, 1},
		txt_muted 	= {0.663, 0.694, 0.729, 1},
		focus 		= {0, 0.588, 0.749, 1},
		border 		= {0.322, 0.412, 0.502, 1},
		button		= {0.047, 0.082, 0.11, 1},
		button_hov	= {0.016, 0.039, 0.059, 1},
	},
	siz = {
		txt 	= 25,
		txt_h1	= 100,
		txt_h2	= 75,
		txt_h3	= 50,
		txt_h4	= 30,
		
		border	= 4,
	}
}

UI_Settings::struct{

}
set_ui_style::proc(sty:=DEFALT_UI_STYLE){
	s.ui_style = sty
}


button_dec::proc()->(button:cl.ElementDeclaration){
	button_hov:=cl.Hovered()
	button = cl.ElementDeclaration{
		layout = {
				layoutDirection = .TopToBottom,
				sizing = { cl.SizingGrow(), cl.SizingFit() },
				childAlignment = cl.ChildAlignment{x=.Center,y=.Center},
			},
		backgroundColor = s.ui_style.col.button if !button_hov else s.ui_style.col.button_hov,
		border = cl.BorderElementConfig{color = s.ui_style.col.border, width = cl.BorderWidth{3,3,3,3,6}},
	}
	return button
}

button_txt::proc($text:string, ){
	cl.Text(
		text,
		cl.TextConfig(cl.TextElementConfig{
			textColor = s.ui_style.col.txt_main,
			fontSize = cast(u16)s.ui_style.siz.txt_h2
		}),
	)
}

ui_l_click::proc()->(click:bool){
	click = s.input.mouse_button_down[.LEFT]
	return
}
