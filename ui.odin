package tg_render

import "vendor:stb/truetype"

import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import hm "handle_map_static_virtual"
import "core:time"
import lin"core:math/linalg"
import cl"clay-odin"
import "core:encoding/json"
import "core:os"
import "core:strconv"

UI_Style::struct{
	col:struct{
		// fg:			[4]f32,
		// fg_alt:		[4]f32,
		// bg:			[4]f32,
		// bg_alt:		[4]f32,
		// txt_main: 	[4]f32,
		// txt_bright: [4]f32,
		// txt_muted: 	[4]f32,
		// focus: 		[4]f32,
		// // border: 	[4]f32,
		// button:		[4]f32,
		// button_hov:	[4]f32,

		accents: [7]Vec4,

        border: Vec4,
        border_variant: Vec4,
        border_focused: Vec4,
        border_selected: Vec4,
        border_transparent: Vec4,
        border_disabled: Vec4,
        elevated_surface_background: Vec4,
        surface_background: Vec4,
        background: Vec4,
        element_background: Vec4,
        element_hover: Vec4,
        element_active:Vec4,
        element_selected:Vec4,
        element_disabled: Vec4,
        drop_target_background: Vec4,
        text: Vec4,
        text_muted: Vec4,
        text_placeholder: Vec4,
        text_disabled: Vec4,
        text_accent: Vec4,
        icon: Vec4,
        icon_muted: Vec4,
        icon_disabled: Vec4,
        icon_placeholder: Vec4,
        icon_accent: Vec4,
        status_bar_background: Vec4,
        title_bar_background: Vec4,
        title_bar_inactive_background: Vec4,
        toolbar_background: Vec4,
        tab_bar_background: Vec4,
        tab_inactive_background: Vec4,
        tab_active_background: Vec4,
        search_match_background: Vec4,

        panel_background: Vec4,
        panel_focused_border: Vec4,
        panel_indent_guide: Vec4,
        panel_indent_guide_active: Vec4,
        panel_indent_guide_hover: Vec4,
        panel_overlay_background: Vec4,
        pane_focused_border: Vec4,
        pane_group_border: Vec4,

        scrollbar_thumb_background: Vec4,
        scrollbar_thumb_hover_background: Vec4,
        scrollbar_thumb_border: Vec4,
        scrollbar_track_background: Vec4,
        scrollbar_track_border: Vec4,

        editor_foreground: Vec4,
        editor_background: Vec4,
        editor_gutter_background: Vec4,
        editor_subheader_background: Vec4,
        editor_active_line_background: Vec4,
        editor_highlighted_line_background: Vec4,
        editor_line_number: Vec4,
        editor_active_line_number: Vec4,
        editor_invisible: Vec4,
        editor_wrap_guide: Vec4,
        editor_active_wrap_guide: Vec4,
        editor_document_highlight_read_background: Vec4,
        editor_document_highlight_write_background: Vec4,
        editor_document_highlight_bracket_background: Vec4,
        editor_indent_guide: Vec4,
        editor_indent_guide_active: Vec4,
        terminal_background: Vec4,
        terminal_foreground: Vec4,
        terminal_ansi_background: Vec4,
        terminal_bright_foreground: Vec4,
        terminal_dim_foreground: Vec4,

        ansi_black: Vec4,
        ansi_bright_black: Vec4,
        ansi_dim_black: Vec4,
        ansi_red: Vec4,
        ansi_bright_red: Vec4,
        ansi_dim_red:Vec4,
        ansi_green:Vec4 ,
        ansi_bright_green:Vec4 ,
        ansi_dim_green: Vec4,
        ansi_yellow: Vec4,
        ansi_bright_yellow: Vec4,
        ansi_dim_yellow:Vec4,
        ansi_blue:Vec4,
        ansi_bright_blue:Vec4,
        ansi_dim_blue: Vec4,
        ansi_magenta: Vec4,
        ansi_bright_magenta: Vec4,
        ansi_dim_magenta:Vec4 ,
        ansi_cyan: Vec4,
        ansi_bright_cyan: Vec4,
        ansi_dim_cyan: Vec4,
        ansi_white:Vec4,
        ansi_bright_white:Vec4 ,
        ansi_dim_white:Vec4,
        link_text_hover:Vec4,

		success: Vec4,
		success_background: Vec4,
		success_border: Vec4,
		
		error: Vec4,
		error_background: Vec4,
		error_border: Vec4,
		
		info: Vec4,
		info_background: Vec4,
		info_border: Vec4,
		
		hint: Vec4,
		hint_background: Vec4,
		hint_border: Vec4,
		
		warning: Vec4,
		warning_background: Vec4,
		warning_border: Vec4,
	},
	siz:struct{
		txt:f32,
		txt_h1:f32,
		txt_h2:f32,
		txt_h3:f32,
		txt_h4:f32,
		
		// border:f32,
		text_multiplyer:f32,
		text_tiny:f32,
		text_small:f32,
		text:f32,
		text_big:f32,
		text_large:f32,
		text_huge:f32,

		border_multiplyer:f32,
		border_tiny:f32,
		border_small:f32,
		border:f32,
		border_big:f32,
		border_large:f32,
		border_huge:f32,

		pading_multiplyer:f32,
		pading_tiny:f32,
		pading_small:f32,
		pading:f32,
		pading_big:f32,
		pading_large:f32,
		pading_huge:f32,
	
		child_gap_multiplyer:f32,
		child_gap_tiny:f32,
		child_gap_small:f32,
		child_gap:f32,
		child_gap_big:f32,
		child_gap_large:f32,
		child_gap_huge:f32,
		
		roundnes_multiplyer:f32,
		sharp:f32,
		smooth:f32,
		round:f32,
		bubble:f32,
	},
	pading:struct{
		button:[4]f32,
	},
}

DEFALT_UI_STYLE:UI_Style:{
	// col = {
	// 	fg			= {0.086, 0.122, 0.153, 1},
	// 	fg_alt		= {0.102, 0.141, 0.184, 1},
	// 	bg			= {0.086, 0.122, 0.153, 1},
	// 	bg_alt		= {0.102, 0.141, 0.184, 1},
	// 	txt_main 	= {0.859, 0.859, 0.859, 1},
	// 	txt_bright	= {0.859, 0.859, 0.859, 1},
	// 	txt_muted 	= {0.663, 0.694, 0.729, 1},
	// 	focus 		= {0, 0.588, 0.749, 1},
	// 	border 		= {0.322, 0.412, 0.502, 1},
	// 	button		= {0.047, 0.082, 0.11, 1},
	// 	button_hov	= {0.016, 0.039, 0.059, 1},
	// },
	siz = {
		// txt 	= 25,
		// txt_h1	= 100,
		// txt_h2	= 75,
		// txt_h3	= 50,
		// txt_h4	= 30,
		
		// border	= 4,
		
		text_multiplyer = 1,
		text_tiny = 5,
		text_small = 10,
		text = 25,
		text_big = 30,
		text_large = 50,
		text_huge = 75,

		border_multiplyer = 1,
		border_tiny = 1,
		border_small = 2,
		border = 4,
		border_big = 6,
		border_large = 8,
		border_huge = 12,

		pading_multiplyer = 1,
		pading_tiny = 2,
		pading_small = 4,
		pading = 8,
		pading_big = 12,
		pading_large = 24,
		pading_huge = 48,
	
		child_gap_multiplyer = 1,
		child_gap_tiny = 2,
		child_gap_small = 4,
		child_gap = 8,
		child_gap_big = 12,
		child_gap_large  = 24,
		child_gap_huge = 48,
		
		roundnes_multiplyer = 1,
		sharp = 0,
		smooth = 2,
		round = 4,
		bubble = 8,
	}
}

UI_Size::enum{
	normal,
	tiny,
	small,
	big,
	large,
	huge,
}
get_ui_text_size::proc(size:union{UI_Size,f32}) -> (new_size:u16){
	switch siz in size{
	case UI_Size:
		switch siz{
		case.normal:
		new_size = cast(u16)(s.ui_style.siz.text * s.ui_style.siz.text_multiplyer )
		case.tiny:
		new_size = cast(u16)(s.ui_style.siz.text_tiny * s.ui_style.siz.text_multiplyer )
		case.small:
		new_size = cast(u16)(s.ui_style.siz.text_small * s.ui_style.siz.text_multiplyer) 
		case.big:
		new_size = cast(u16)(s.ui_style.siz.text_big * s.ui_style.siz.text_multiplyer )
		case.large:
		new_size = cast(u16)(s.ui_style.siz.text_large * s.ui_style.siz.text_multiplyer )
		case.huge:
		new_size = cast(u16)(s.ui_style.siz.text_huge * s.ui_style.siz.text_multiplyer )
		}
	case f32:
		new_size = cast(u16)siz
	}
	return
}

get_ui_border::proc(size:union{UI_Size,f32}) -> (new_size:u16){
	switch siz in size{
	case UI_Size:
		switch siz{
		case.normal:
		new_size = cast(u16)(s.ui_style.siz.border * s.ui_style.siz.border_multiplyer )
		case.tiny:
		new_size = cast(u16)(s.ui_style.siz.border_tiny * s.ui_style.siz.border_multiplyer )
		case.small:
		new_size = cast(u16)(s.ui_style.siz.border_small * s.ui_style.siz.border_multiplyer) 
		case.big:
		new_size = cast(u16)(s.ui_style.siz.border_big * s.ui_style.siz.border_multiplyer )
		case.large:
		new_size = cast(u16)(s.ui_style.siz.border_large * s.ui_style.siz.border_multiplyer )
		case.huge:
		new_size = cast(u16)(s.ui_style.siz.border_huge * s.ui_style.siz.border_multiplyer )
		}
	case f32:
		new_size = cast(u16)siz
	}
	return
}

get_ui_pading::proc(size:union{UI_Size,f32}) -> (new_size:u16){
	switch siz in size{
	case UI_Size:
		switch siz{
		case.normal:
		new_size = cast(u16)(s.ui_style.siz.pading * s.ui_style.siz.pading_multiplyer )
		case.tiny:
		new_size = cast(u16)(s.ui_style.siz.pading_tiny * s.ui_style.siz.pading_multiplyer )
		case.small:
		new_size = cast(u16)(s.ui_style.siz.pading_small * s.ui_style.siz.pading_multiplyer )
		case.big:
		new_size = cast(u16)(s.ui_style.siz.pading_big * s.ui_style.siz.pading_multiplyer )
		case.large:
		new_size = cast(u16)(s.ui_style.siz.pading_large * s.ui_style.siz.pading_multiplyer )
		case.huge:
		new_size = cast(u16)(s.ui_style.siz.pading_huge * s.ui_style.siz.pading_multiplyer )
		}
	case f32:
		new_size = cast(u16)siz
	}
	return
}



get_ui_child_gap::proc(size:union{UI_Size,f32}) -> (new_size:u16){
	switch siz in size{
	case UI_Size:
		switch siz{
		case.normal:
		new_size = cast(u16)(s.ui_style.siz.child_gap * s.ui_style.siz.child_gap_multiplyer )
		case.tiny:
		new_size = cast(u16)(s.ui_style.siz.child_gap_tiny * s.ui_style.siz.child_gap_multiplyer )
		case.small:
		new_size = cast(u16)(s.ui_style.siz.child_gap_small * s.ui_style.siz.child_gap_multiplyer )
		case.big:
		new_size = cast(u16)(s.ui_style.siz.child_gap_big * s.ui_style.siz.child_gap_multiplyer )
		case.large:
		new_size = cast(u16)(s.ui_style.siz.child_gap_large * s.ui_style.siz.child_gap_multiplyer )
		case.huge:
		new_size = cast(u16)(s.ui_style.siz.child_gap_huge * s.ui_style.siz.child_gap_multiplyer )
		}
	case f32:
		new_size = cast(u16)siz
	}
	return
}

UI_Roundnes::enum{
	sharp,
	smooth,
	round,
	bubble,
}

get_ui_roundnes::proc(size:union{UI_Roundnes,f32}) -> (new_size:f32){
	switch siz in size{
	case UI_Roundnes:
		switch siz{
		case.sharp:
		new_size = s.ui_style.siz.sharp * s.ui_style.siz.roundnes_multiplyer
		case.smooth:
		new_size = s.ui_style.siz.smooth * s.ui_style.siz.roundnes_multiplyer
		case.round:
		new_size = s.ui_style.siz.round * s.ui_style.siz.roundnes_multiplyer
		case.bubble:
		new_size = s.ui_style.siz.bubble * s.ui_style.siz.roundnes_multiplyer
		}
	case f32:
		new_size = siz
	}
	return
}

Ansi_Color::enum{
    ansi_black,
    ansi_bright_black,
    ansi_dim_black,
    ansi_red,
    ansi_bright_red,
    ansi_dim_red,
    ansi_green,
    ansi_bright_green,
    ansi_dim_green,
    ansi_yellow,
    ansi_bright_yellow,
    ansi_dim_yellow,
    ansi_blue,
    ansi_bright_blue,
    ansi_dim_blue,
    ansi_magenta,
    ansi_bright_magenta,
    ansi_dim_magenta,
    ansi_cyan,
    ansi_bright_cyan,
    ansi_dim_cyan,
    ansi_white,
    ansi_bright_white,
    ansi_dim_white,
}
UI_Border_Color::enum{
	border,
    border_variant,
    border_focused,
    border_selected,
    border_transparent,
    border_disabled,
}
UI_Color::enum{
	icon,
    icon_muted,
    icon_disabled,
    icon_placeholder,
    icon_accent,

    elevated_surface_background,
    surface_background,
    background,
    element_background,
    element_hover,
    element_active,
    element_selected,
    element_disabled,
    drop_target_background,
    status_bar_background,

    title_bar_background,
    title_bar_inactive_background,
    toolbar_background,
    tab_bar_background,
    tab_inactive_background,
    tab_active_background,
    search_match_background,

    panel_background,
    panel_focused_border,
    panel_indent_guide,
    panel_indent_guide_active,
    panel_indent_guide_hover,
    panel_overlay_background,
    pane_focused_border,
    pane_group_border,

    scrollbar_thumb_background,
    scrollbar_thumb_hover_background,
    scrollbar_thumb_border,
    scrollbar_track_background,
    scrollbar_track_border,

    editor_foreground,
    editor_background,
    editor_gutter_background,
    editor_subheader_background,
    editor_active_line_background,
    editor_highlighted_line_background,
    editor_line_number,
    editor_active_line_number,
    editor_invisible,
    editor_wrap_guide,
    editor_active_wrap_guide,
    editor_document_highlight_read_background,
    editor_document_highlight_write_background,
    editor_document_highlight_bracket_background,
    editor_indent_guide,
    editor_indent_guide_active,
    terminal_background,
    terminal_foreground,
    terminal_ansi_background,
    terminal_bright_foreground,
    terminal_dim_foreground,

    success,
	success_background,
	success_border,
	
	error,
	error_background,
	error_border,
	
	info,
	info_background,
	info_border,
	
	hint,
	hint_background,
	hint_border,
	
	warning,
	warning_background,
	warning_border,
}
UI_Text_Color::enum{
    text,
    text_muted,
    text_placeholder,
    text_disabled,
    text_accent,
    link_text_hover,
}
UI_Accents_Color::enum{
	ac1,
	ac2,
	ac3,
	ac4,
	ac5,
	ac6,
	ac7,
}
Color_Types::union{
	Ansi_Color,
	Vec4,
	UI_Border_Color,
	UI_Text_Color,
	UI_Accents_Color,
	UI_Color,
}
get_color::proc(col:Color_Types)->(new_col:Vec4){
	switch c in col{
	case Ansi_Color:
		switch c{
			case.ansi_black:
			new_col = s.ui_style.col.ansi_black
			case.ansi_bright_black:
			new_col = s.ui_style.col.ansi_bright_black
			case.ansi_dim_black:
			new_col = s.ui_style.col.ansi_dim_black
			case.ansi_red:
			new_col = s.ui_style.col.ansi_red
			case.ansi_bright_red:
			new_col = s.ui_style.col.ansi_bright_red
			case.ansi_dim_red:
			new_col = s.ui_style.col.ansi_dim_red
			case.ansi_green:
			new_col = s.ui_style.col.ansi_green
			case.ansi_bright_green:
			new_col = s.ui_style.col.ansi_bright_green
			case.ansi_dim_green:
			new_col = s.ui_style.col.ansi_dim_green
			case.ansi_yellow:
			new_col = s.ui_style.col.ansi_yellow
			case.ansi_bright_yellow:
			new_col = s.ui_style.col.ansi_bright_yellow
			case.ansi_dim_yellow:
			new_col = s.ui_style.col.ansi_dim_yellow
			case.ansi_blue:
			new_col = s.ui_style.col.ansi_blue
			case.ansi_bright_blue:
			new_col = s.ui_style.col.ansi_bright_blue
			case.ansi_dim_blue:
			new_col = s.ui_style.col.ansi_dim_blue
			case.ansi_magenta:
			new_col = s.ui_style.col.ansi_magenta
			case.ansi_bright_magenta:
			new_col = s.ui_style.col.ansi_bright_magenta
			case.ansi_dim_magenta:
			new_col = s.ui_style.col.ansi_dim_magenta
			case.ansi_cyan:
			new_col = s.ui_style.col.ansi_cyan
			case.ansi_bright_cyan:
			new_col = s.ui_style.col.ansi_bright_cyan
			case.ansi_dim_cyan:
			new_col = s.ui_style.col.ansi_dim_cyan
			case.ansi_white:
			new_col = s.ui_style.col.ansi_white
			case.ansi_bright_white:
			new_col = s.ui_style.col.ansi_bright_white
			case.ansi_dim_white:
			new_col = s.ui_style.col.ansi_dim_white
		}
	case UI_Border_Color:
		switch c{
			case.border:
			new_col = s.ui_style.col.border
			case.border_variant:
			new_col = s.ui_style.col.border_variant
			case.border_focused:
			new_col = s.ui_style.col.border_focused
			case.border_selected:
			new_col = s.ui_style.col.border_selected
			case.border_transparent:
			new_col = s.ui_style.col.border_transparent
			case.border_disabled:
			new_col = s.ui_style.col.border_disabled
		}
	case UI_Text_Color:
		switch c{
			case.text:
			new_col = s.ui_style.col.text
			case.text_muted:
			new_col = s.ui_style.col.text_muted
			case.text_placeholder:
			new_col = s.ui_style.col.text_placeholder
			case.text_disabled:
			new_col = s.ui_style.col.text_disabled
			case.text_accent:
			new_col = s.ui_style.col.text_accent
			case.link_text_hover:
			new_col = s.ui_style.col.link_text_hover
		}
	case UI_Color:
		switch c{
			case.icon:
			new_col = s.ui_style.col.icon
			case.icon_muted:
			new_col = s.ui_style.col.icon_muted
			case.icon_disabled:
			new_col = s.ui_style.col.icon_disabled
			case.icon_placeholder:
			new_col = s.ui_style.col.icon_placeholder
			case.icon_accent:
			new_col = s.ui_style.col.icon_accent
			case.elevated_surface_background:
			new_col = s.ui_style.col.elevated_surface_background
			case.surface_background:
			new_col = s.ui_style.col.surface_background
			case.background:
			new_col = s.ui_style.col.background
			case.element_background:
			new_col = s.ui_style.col.element_background
			case.element_hover:
			new_col = s.ui_style.col.element_hover
			case.element_active:
			new_col = s.ui_style.col.element_active
			case.element_selected:
			new_col = s.ui_style.col.element_selected
			case.element_disabled:
			new_col = s.ui_style.col.element_disabled
			case.drop_target_background:
			new_col = s.ui_style.col.drop_target_background
			case.status_bar_background:
			new_col = s.ui_style.col.status_bar_background
			case.title_bar_background:
			new_col = s.ui_style.col.title_bar_background
			case.title_bar_inactive_background:
			new_col = s.ui_style.col.title_bar_inactive_background
			case.toolbar_background:
			new_col = s.ui_style.col.toolbar_background
			case.tab_bar_background:
			new_col = s.ui_style.col.tab_bar_background
			case.tab_inactive_background:
			new_col = s.ui_style.col.tab_inactive_background
			case.tab_active_background:
			new_col = s.ui_style.col.tab_active_background
			case.search_match_background:
			new_col = s.ui_style.col.search_match_background
			case.panel_background:
			new_col = s.ui_style.col.panel_background
			case.panel_focused_border:
			new_col = s.ui_style.col.panel_focused_border
			case.panel_indent_guide:
			new_col = s.ui_style.col.panel_indent_guide
			case.panel_indent_guide_active:
			new_col = s.ui_style.col.panel_indent_guide_active
			case.panel_indent_guide_hover:
			new_col = s.ui_style.col.panel_indent_guide_hover
			case.panel_overlay_background:
			new_col = s.ui_style.col.panel_overlay_background
			case.pane_focused_border:
			new_col = s.ui_style.col.pane_focused_border
			case.pane_group_border:
			new_col = s.ui_style.col.pane_group_border
			case.scrollbar_thumb_background:
			new_col = s.ui_style.col.scrollbar_thumb_background
			case.scrollbar_thumb_hover_background:
			new_col = s.ui_style.col.scrollbar_thumb_hover_background
			case.scrollbar_thumb_border:
			new_col = s.ui_style.col.scrollbar_thumb_border
			case.scrollbar_track_background:
			new_col = s.ui_style.col.scrollbar_track_background
			case.scrollbar_track_border:
			new_col = s.ui_style.col.scrollbar_track_border
			case.editor_foreground:
			new_col = s.ui_style.col.editor_foreground
			case.editor_background:
			new_col = s.ui_style.col.editor_background
			case.editor_gutter_background:
			new_col = s.ui_style.col.editor_gutter_background
			case.editor_subheader_background:
			new_col = s.ui_style.col.editor_subheader_background
			case.editor_active_line_background:
			new_col = s.ui_style.col.editor_active_line_background
			case.editor_highlighted_line_background:
			new_col = s.ui_style.col.editor_highlighted_line_background
			case.editor_line_number:
			new_col = s.ui_style.col.editor_line_number
			case.editor_active_line_number:
			new_col = s.ui_style.col.editor_active_line_number
			case.editor_invisible:
			new_col = s.ui_style.col.editor_invisible
			case.editor_wrap_guide:
			new_col = s.ui_style.col.editor_wrap_guide
			case.editor_active_wrap_guide:
			new_col = s.ui_style.col.editor_active_wrap_guide
			case.editor_document_highlight_read_background:
			new_col = s.ui_style.col.editor_document_highlight_read_background
			case.editor_document_highlight_write_background:
			new_col = s.ui_style.col.editor_document_highlight_write_background
			case.editor_document_highlight_bracket_background:
			new_col = s.ui_style.col.editor_document_highlight_bracket_background
			case.editor_indent_guide:
			new_col = s.ui_style.col.editor_indent_guide
			case.editor_indent_guide_active:
			new_col = s.ui_style.col.editor_indent_guide
			case.terminal_background:
			new_col = s.ui_style.col.terminal_background
			case.terminal_foreground:
			new_col = s.ui_style.col.terminal_foreground
			case.terminal_ansi_background:
			new_col = s.ui_style.col.terminal_ansi_background
			case.terminal_bright_foreground:
			new_col = s.ui_style.col.terminal_bright_foreground
			case.terminal_dim_foreground:
			new_col = s.ui_style.col.terminal_dim_foreground
			case.success:
			new_col = s.ui_style.col.success
			case.success_background:
			new_col = s.ui_style.col.success_background
			case.success_border:
			new_col = s.ui_style.col.success_border
			case.error:
			new_col = s.ui_style.col.error
			case.error_background:
			new_col = s.ui_style.col.error_background
			case.error_border:
			new_col = s.ui_style.col.error_border
			case.info:
			new_col = s.ui_style.col.info
			case.info_background:
			new_col = s.ui_style.col.info_background
			case.info_border:
			new_col = s.ui_style.col.info_border
			case.hint:
			new_col = s.ui_style.col.hint
			case.hint_background:
			new_col = s.ui_style.col.hint_background
			case.hint_border:
			new_col = s.ui_style.col.hint_border
			case.warning:
			new_col = s.ui_style.col.warning
			case.warning_background:
			new_col = s.ui_style.col.warning_background
			case.warning_border:
			new_col = s.ui_style.col.warning_border
		}
		case UI_Accents_Color:
		switch c{
			case.ac1:
			new_col = s.ui_style.col.accents[0]
			case.ac2:
			new_col = s.ui_style.col.accents[1]
			case.ac3:
			new_col = s.ui_style.col.accents[2]
			case.ac4:
			new_col = s.ui_style.col.accents[3]
			case.ac5:
			new_col = s.ui_style.col.accents[4]
			case.ac6:
			new_col = s.ui_style.col.accents[5]
			case.ac7:
			new_col = s.ui_style.col.accents[6]
		}
	case Vec4:
		new_col = c
	}
	return
}


load_ui_theme_by_file::proc(file:string,s:^UI_Style,id:int=0){
	data, read_err := os.read_entire_file(file, context.allocator)
	if read_err != nil {
		fmt.eprintfln("Failed to load the file: %v", read_err,"path:",file)
		return
	}
	defer delete(data) // Free the memory at the end
	load_ui_theme_by_data(data,s,id)
}
mjv::map[string]json.Value
load_ui_theme_by_data::proc(data:[]u8,s:^UI_Style,id:int=0){
	json_data, err := json.parse(data)
	if err != .None {
		fmt.eprintln("Failed to parse the json file.")
		fmt.eprintln("Error:", err)
		return
	}
	defer json.destroy_value(json_data)

	// Access the Root Level Object
	root := json_data.(json.Object)
	if root["themes"].(json.Array)[id].(json.Object)["style"].(json.Object) == nil{return}
	style:=root["themes"].(json.Array)[id].(json.Object)["style"].(json.Object)

 
	if accents, ok := style["accents"].(json.Array); ok {
		for i in 0..<min(len(accents), len(s.col.accents)) {
			if c, ok := accents[i].(json.String); ok {
				s.col.accents[i] = string_hex_to_rgba(c)
			}
		}
	} 


	load_color(cast(mjv)style, "border", &s.col.border)
	load_color(cast(mjv)style, "border.variant", &s.col.border_variant)
	load_color(cast(mjv)style, "border.focused", &s.col.border_focused)
	load_color(cast(mjv)style, "border.selected", &s.col.border_selected)
	load_color(cast(mjv)style, "border.transparent", &s.col.border_transparent)
	load_color(cast(mjv)style, "border.disabled", &s.col.border_disabled)
	
	load_color(cast(mjv)style, "elevated_surface.background", &s.col.elevated_surface_background)
	load_color(cast(mjv)style, "surface.background", &s.col.surface_background)
	load_color(cast(mjv)style, "background", &s.col.background)
	
	load_color(cast(mjv)style, "element.background", &s.col.element_background)
	load_color(cast(mjv)style, "element.hover", &s.col.element_hover)
	load_color(cast(mjv)style, "element.active", &s.col.element_active)
	load_color(cast(mjv)style, "element.selected", &s.col.element_selected)
	load_color(cast(mjv)style, "element.disabled", &s.col.element_disabled)
	
	load_color(cast(mjv)style, "panel.background", &s.col.panel_background)
	load_color(cast(mjv)style, "panel.focused_border", &s.col.panel_focused_border)
	load_color(cast(mjv)style, "panel.indent_guide", &s.col.panel_indent_guide)
	load_color(cast(mjv)style, "panel.indent_guide_active", &s.col.panel_indent_guide_active)
	load_color(cast(mjv)style, "panel.indent_guide_hover", &s.col.panel_indent_guide_hover)
	load_color(cast(mjv)style, "panel.overlay_background", &s.col.panel_overlay_background)
	
	load_color(cast(mjv)style, "pane.focused_border", &s.col.pane_focused_border)
	load_color(cast(mjv)style, "pane_group.border", &s.col.pane_group_border)
	
	load_color(cast(mjv)style, "drop_target.background", &s.col.drop_target_background)
	
	load_color(cast(mjv)style, "text", &s.col.text)
	load_color(cast(mjv)style, "text.muted", &s.col.text_muted)
	load_color(cast(mjv)style, "text.placeholder", &s.col.text_placeholder)
	load_color(cast(mjv)style, "text.disabled", &s.col.text_disabled)
	load_color(cast(mjv)style, "text.accent", &s.col.text_accent)
	
	load_color(cast(mjv)style, "icon", &s.col.icon)
	load_color(cast(mjv)style, "icon.muted", &s.col.icon_muted)
	load_color(cast(mjv)style, "icon.disabled", &s.col.icon_disabled)
	load_color(cast(mjv)style, "icon.placeholder", &s.col.icon_placeholder)
	load_color(cast(mjv)style, "icon.accent", &s.col.icon_accent)
	
	load_color(cast(mjv)style, "status_bar.background", &s.col.status_bar_background)
	load_color(cast(mjv)style, "title_bar.background", &s.col.title_bar_background)
	load_color(cast(mjv)style, "title_bar.inactive_background", &s.col.title_bar_inactive_background)
	load_color(cast(mjv)style, "toolbar.background", &s.col.toolbar_background)
	load_color(cast(mjv)style, "tab_bar.background", &s.col.tab_bar_background)
	load_color(cast(mjv)style, "tab.inactive_background", &s.col.tab_inactive_background)
	load_color(cast(mjv)style, "tab.active_background", &s.col.tab_active_background)
	
	load_color(cast(mjv)style, "search.match_background", &s.col.search_match_background)
	
	load_color(cast(mjv)style, "scrollbar.thumb.background", &s.col.scrollbar_thumb_background)
	load_color(cast(mjv)style, "scrollbar.thumb.hover_background", &s.col.scrollbar_thumb_hover_background)
	load_color(cast(mjv)style, "scrollbar.thumb.border", &s.col.scrollbar_thumb_border)
	load_color(cast(mjv)style, "scrollbar.track.background", &s.col.scrollbar_track_background)
	load_color(cast(mjv)style, "scrollbar.track.border", &s.col.scrollbar_track_border)


	load_color(cast(mjv)style, "editor.foreground", &s.col.editor_foreground)
	load_color(cast(mjv)style, "editor.background", &s.col.editor_background)
	load_color(cast(mjv)style, "editor.gutter.background", &s.col.editor_gutter_background)
	load_color(cast(mjv)style, "editor.subheader.background", &s.col.editor_subheader_background)
	load_color(cast(mjv)style, "editor.active_line.background", &s.col.editor_active_line_background)
	load_color(cast(mjv)style, "editor.highlighted_line.background", &s.col.editor_highlighted_line_background)
	load_color(cast(mjv)style, "editor.line_number", &s.col.editor_line_number)
	load_color(cast(mjv)style, "editor.active_line_number", &s.col.editor_active_line_number)
	load_color(cast(mjv)style, "editor.invisible", &s.col.editor_invisible)
	load_color(cast(mjv)style, "editor.wrap_guide", &s.col.editor_wrap_guide)
	load_color(cast(mjv)style, "editor.active_wrap_guide", &s.col.editor_active_wrap_guide)
	load_color(cast(mjv)style, "editor.document_highlight.read_background", &s.col.editor_document_highlight_read_background)
	load_color(cast(mjv)style, "editor.document_highlight.write_background", &s.col.editor_document_highlight_write_background)
	load_color(cast(mjv)style, "editor.document_highlight.bracket_background", &s.col.editor_document_highlight_bracket_background)
	load_color(cast(mjv)style, "editor.indent_guide", &s.col.editor_indent_guide)
	load_color(cast(mjv)style, "editor.indent_guide_active", &s.col.editor_indent_guide_active)
	
	load_color(cast(mjv)style, "terminal.background", &s.col.terminal_background)
	load_color(cast(mjv)style, "terminal.foreground", &s.col.terminal_foreground)
	
	load_color(cast(mjv)style, "terminal.ansi.background", &s.col.terminal_ansi_background)
	
	load_color(cast(mjv)style, "terminal.bright_foreground", &s.col.terminal_bright_foreground)
	load_color(cast(mjv)style, "terminal.dim_foreground", &s.col.terminal_dim_foreground)
	
	load_color(cast(mjv)style, "terminal.ansi.black", &s.col.ansi_black)
	load_color(cast(mjv)style, "terminal.ansi.bright_black", &s.col.ansi_bright_black)
	load_color(cast(mjv)style, "terminal.ansi.dim_black", &s.col.ansi_dim_black)
	
	load_color(cast(mjv)style, "terminal.ansi.red", &s.col.ansi_red)
	load_color(cast(mjv)style, "terminal.ansi.bright_red", &s.col.ansi_bright_red)
	load_color(cast(mjv)style, "terminal.ansi.dim_red", &s.col.ansi_dim_red)
	
	load_color(cast(mjv)style, "terminal.ansi.green", &s.col.ansi_green)
	load_color(cast(mjv)style, "terminal.ansi.bright_green", &s.col.ansi_bright_green)
	load_color(cast(mjv)style, "terminal.ansi.dim_green", &s.col.ansi_dim_green)
	
	load_color(cast(mjv)style, "terminal.ansi.yellow", &s.col.ansi_yellow)
	load_color(cast(mjv)style, "terminal.ansi.bright_yellow", &s.col.ansi_bright_yellow)
	load_color(cast(mjv)style, "terminal.ansi.dim_yellow", &s.col.ansi_dim_yellow)
	
	load_color(cast(mjv)style, "terminal.ansi.blue", &s.col.ansi_blue)
	load_color(cast(mjv)style, "terminal.ansi.bright_blue", &s.col.ansi_bright_blue)
	load_color(cast(mjv)style, "terminal.ansi.dim_blue", &s.col.ansi_dim_blue)
	
	load_color(cast(mjv)style, "terminal.ansi.magenta", &s.col.ansi_magenta)
	load_color(cast(mjv)style, "terminal.ansi.bright_magenta", &s.col.ansi_bright_magenta)
	load_color(cast(mjv)style, "terminal.ansi.dim_magenta", &s.col.ansi_dim_magenta)
	
	load_color(cast(mjv)style, "terminal.ansi.cyan", &s.col.ansi_cyan)
	load_color(cast(mjv)style, "terminal.ansi.bright_cyan", &s.col.ansi_bright_cyan)
	load_color(cast(mjv)style, "terminal.ansi.dim_cyan", &s.col.ansi_dim_cyan)
	
	load_color(cast(mjv)style, "terminal.ansi.white", &s.col.ansi_white)
	load_color(cast(mjv)style, "terminal.ansi.bright_white", &s.col.ansi_bright_white)
	load_color(cast(mjv)style, "terminal.ansi.dim_white", &s.col.ansi_dim_white)
	
	load_color(cast(mjv)style, "link_text.hover", &s.col.link_text_hover)

	load_color(cast(mjv)style, "success", &s.col.success)
	load_color(cast(mjv)style, "success.background", &s.col.success_background)
	load_color(cast(mjv)style, "success.border", &s.col.success_border)
	
	load_color(cast(mjv)style, "error", &s.col.error)
	load_color(cast(mjv)style, "error.background", &s.col.error_background)
	load_color(cast(mjv)style, "error.border", &s.col.error_border)
	
	load_color(cast(mjv)style, "info", &s.col.info)
	load_color(cast(mjv)style, "info.background", &s.col.info_background)
	load_color(cast(mjv)style, "info.border", &s.col.info_border)
	
	load_color(cast(mjv)style, "hint", &s.col.hint)
	load_color(cast(mjv)style, "hint.background", &s.col.hint_background)
	load_color(cast(mjv)style, "hint.border", &s.col.hint_border)
	
	load_color(cast(mjv)style, "warning", &s.col.warning)
	load_color(cast(mjv)style, "warning.background", &s.col.warning_background)
	load_color(cast(mjv)style, "warning.border", &s.col.warning_border)

	fmt.print(s.col.border,"\n\n")


}
load_color :: proc(style: map[string]json.Value, key: string, dst: ^Vec4) {
    if s, ok := style[key].(json.String); ok {
        dst^ = string_hex_to_rgba(s)
    }
}
string_hex_to_rgba::proc(s:string)->Vec4{
	num,ok:=strconv.parse_u64_of_base(s[1:],16)
	return u32_to_rgba(cast(u32)num)
}
hex_to_rgba :: u32_to_rgba;
u32_to_rgba :: proc(v: u32) -> Vec4 {
	temp_c:=Vec4{
		cast(f32)((v & 0xff000000)>>24)/255.0,
		cast(f32)((v & 0x00ff0000)>>16)/255.0,
		cast(f32)((v & 0x0000ff00)>>8) /255.0,
		cast(f32) (v & 0x000000ff)     /255.0,
	}
	new_c:=temp_c
	if temp_c.r == 0{
		new_c.r=temp_c.g
		new_c.g=temp_c.b
		new_c.b=temp_c.a
		new_c.a=1
	}
	return new_c
}


set_ui_style::proc(sty:=DEFALT_UI_STYLE){
	s.ui_style = sty
}


button_dec::proc(
	border_col_id:Color_Types = .border,
	background_col_id:Color_Types = .element_background,
	background_huv_col_id:Color_Types = .element_hover,
	
	border_size_id:UI_Size = .normal,
	padding_size_id:UI_Size = .normal,
	roundnes_id:UI_Roundnes = .sharp,

)->(button:cl.ElementDeclaration){

	border_col:=get_color(border_col_id)
	background_col:=get_color(background_col_id)
	background_huv_col:=get_color(background_huv_col_id)

	border_size:= get_ui_border(border_size_id)
	padding_size:= get_ui_pading(padding_size_id)
	roundnes_id:= get_ui_roundnes(roundnes_id)

	
	button_hov:=cl.Hovered()
	button = cl.ElementDeclaration{
		layout = {
				layoutDirection = .TopToBottom,
				sizing = { cl.SizingGrow(), cl.SizingFit() },
				childAlignment = cl.ChildAlignment{x=.Center,y=.Center},
				padding = {padding_size,padding_size,padding_size,padding_size},
				childGap = {},
			},
		backgroundColor = background_col if !button_hov else background_huv_col,
		border = cl.BorderElementConfig{
			color = border_col,
			width = cl.BorderWidth{border_size,border_size,border_size,border_size,0}
		},
	}
	return button
}

button_txt::proc(
	$text:string,
	text_col_id:Color_Types = .text,
	text_size_id:UI_Size = .normal,
 ){
	text_col:=get_color(text_col_id)
	text_size:=get_ui_text_size(text_size_id)
	cl.Text(
		text,
		cl.TextConfig(cl.TextElementConfig{
			textColor = text_col,
			fontSize = text_size
		}),
	)
}
button_txt_dynamic::proc(
	text:string,
	text_col_id:Color_Types = .text,
	text_size_id:UI_Size = .normal,
){
	text_col:=get_color(text_col_id)
	text_size:=get_ui_text_size(text_size_id)
	cl.TextDynamic(
		text,
		cl.TextConfig(cl.TextElementConfig{
			textColor = text_col,
			fontSize = text_size
		}),
	)
}

notification_dec::proc(
	notification:^Notification,
	border_col_id:Color_Types = .border,
	background_col_id:Color_Types = .element_background,
	background_huv_col_id:Color_Types = .element_hover,
	
	border_size_id:UI_Size = .normal,
	padding_size_id:UI_Size = .normal,
	child_gap_id:UI_Size = .small,
	roundnes_id:UI_Roundnes = .sharp,
)->(button:cl.ElementDeclaration){
	
	
	border_col:=get_color(border_col_id)
	background_col:=get_color(background_col_id)
	background_huv_col:=get_color(background_huv_col_id)

	border_size:= get_ui_border(border_size_id)
	padding_size:= get_ui_pading(padding_size_id)
	child_gap_id:= get_ui_child_gap(child_gap_id)
	roundnes_id:= get_ui_roundnes(roundnes_id)

	button_hov:=cl.Hovered()
	button = cl.ElementDeclaration{
		layout = {
				layoutDirection = .TopToBottom,
				sizing = { cl.SizingPercent(.20), cl.SizingFit() },
				childAlignment = cl.ChildAlignment{x=.Center,y=.Center},
				padding = {padding_size,padding_size,padding_size,padding_size},
				childGap = child_gap_id,
			},
		floating ={
			// attachment = {.Root},
			expand = {1000,1000},
			// offset = {100,10},
			// attachTo = .Parent,
			// pointerCaptureMode = .Capture,
			// attachment= cl.FloatingAttachPoints{
			// 	element = cl.FloatingAttachPointType.RightTop,
			// 	parent =   cl.FloatingAttachPointType.RightTop,
			// }
		},
		backgroundColor = background_col if !button_hov else background_huv_col,
		border = cl.BorderElementConfig{
			color = border_col,
			width = cl.BorderWidth{border_size,border_size,border_size,border_size,0}
		},
	}
	return button
}
notification_progress_bar::proc(
	persent:f32,
	col_id:Color_Types = .ac1,
){
	col:=get_color(col_id)
	if cl.UI()({
		layout = { layoutDirection = .TopToBottom, 
		sizing = { cl.SizingPercent(persent), cl.SizingFixed(5) } },
		border={width = {0,0,0,0,0}},
		backgroundColor = col,
	}) {

	}
}

notification_x_button::proc(
	notification:^Notification,
	border_col_id:Color_Types = .border,
	// background_col_id:Color_Types = .element_background,
	// background_huv_col_id:Color_Types = .ansy_red,

	x_color_id:Color_Types = .text,
	x_color_huv_id:Color_Types = .ansi_bright_red,
	
	border_size_id:UI_Size = .normal,
	padding_size_id:UI_Size = .normal,
	child_gap_id:UI_Size = .small,
	roundnes_id:UI_Roundnes = .sharp,
){
	padding_size:= get_ui_pading(padding_size_id)
	x_border_size:=get_ui_border(border_size_id)
	x_border_col:=get_color(border_col_id)
	x_color:=get_color(x_color_id)
	x_color_huv:=get_color(x_color_huv_id)
	if cl.UI()({
		layout = cl.LayoutConfig{ 
			padding = {padding_size,padding_size,padding_size,padding_size},
			layoutDirection = .TopToBottom, 
			sizing = { cl.SizingFit(), cl.SizingFit()},
			childAlignment = {.Left,.Top},
		},
		// border={width = {x_border_size,x_border_size,x_border_size,x_border_size,0},color = x_border_col },
		
		
		// backgroundColor = col,
		floating ={
			// attachment = {.Root},
			attachTo = .Parent,
			pointerCaptureMode = .Capture,
			attachment= cl.FloatingAttachPoints{
				element = cl.FloatingAttachPointType.RightTop,
				parent =   cl.FloatingAttachPointType.RightTop,
			}
		},
	}) {
		button_hov:=cl.Hovered()
		notification_txt("X", text_col_id =	x_color_id if !button_hov else x_color_huv_id ,text_size_id= .tiny,)
		if 	button_hov{
			if s.is_ui_l_click(){
				notification.time_left = 0
			}
		}
	}
}
notification_txt::proc(
	$text:string,
	text_col_id:Color_Types = .text_accent,
	text_size_id:UI_Size = .small,
 ){
	text_col:=get_color(text_col_id)
	text_size:=get_ui_text_size(text_size_id)
	cl.Text(
		text,
		cl.TextConfig(cl.TextElementConfig{
			textColor = text_col,
			fontSize = text_size
		}),
	)
}
notification_txt_dynamic::proc(
	text:string,
	text_col_id:Color_Types = .text_accent,
	text_size_id:UI_Size = .small,
){
	text_col:=get_color(text_col_id)
	text_size:=get_ui_text_size(text_size_id)
	cl.TextDynamic(
		text,
		cl.TextConfig(cl.TextElementConfig{
			textColor = text_col,
			fontSize = text_size
		}),
	)
}


MAX_NUMBER_OF_NOTIFICATION::100
Notification_Buffer::struct{
	notifications:[dynamic;MAX_NUMBER_OF_NOTIFICATION]Notification
}
Notification::struct{
	max_time:f64,
	time_left:f64,
	mesg_1:string,
	mesg_1_col:Color_Types,
}
init_notification_buffer::proc(buff:^Notification_Buffer){

}
update_notification_buffer::proc(buff:^Notification_Buffer,time_pased:f64){
	for &notif,i in &buff.notifications{
		notif.time_left -= time_pased
		if notif.time_left<=0{
			unordered_remove(&buff.notifications,i)
		}
	}
}
draw_notification_buffer::proc(buff:^Notification_Buffer, location:cl.LayoutAlignmentX = .Center){
	child_gap:=get_ui_child_gap(.normal)
	if cl.UI(cl.ID("Notification_List"))({
		layout = { 
			layoutDirection = .TopToBottom,
			sizing = { cl.SizingGrow(), cl.SizingGrow() },
			childGap = child_gap,
			childAlignment= {x = location,y= .Top}
		},
		floating ={
			// attachment = {.Root},
			attachTo = .Root,
			pointerCaptureMode = .Passthrough,
			attachment= cl.FloatingAttachPoints{
				element = cl.FloatingAttachPointType.LeftTop,
				parent =   cl.FloatingAttachPointType.LeftTop,
			}
		},
		backgroundColor = {0,0,0,0},
		
	}) {
		for &notif,i in &buff.notifications{
			if cl.UI()(notification_dec(&notif)) {
				notification_x_button(&notif)
				notification_txt_dynamic(notif.mesg_1,text_col_id = notif.mesg_1_col,)
				notification_progress_bar(cast(f32)(notif.time_left/notif.max_time))
			}
		}
	}
}
DEFALT_NOTIFICATION_TIME::7
send_notification::proc(
	buff:^Notification_Buffer,
	mesg:Notification={	
		mesg_1="defalt text",
	},
){
	if len(buff.notifications) <MAX_NUMBER_OF_NOTIFICATION{
		temp_mesg:=mesg
		if temp_mesg.mesg_1_col == nil{temp_mesg.mesg_1_col = .text_accent}
		if temp_mesg.max_time == 0{temp_mesg.max_time = DEFALT_NOTIFICATION_TIME}
		if temp_mesg.time_left == 0{temp_mesg.time_left = DEFALT_NOTIFICATION_TIME}
		append(&buff.notifications,temp_mesg)
	}
}
send_simp_notification::proc(
	buff:^Notification_Buffer,
	mesg:string,
	time:f64=5,
){
	send_notification(buff,{max_time= time,time_left = time,mesg_1=mesg})
}

send_simp_error_notification::proc(
	buff:^Notification_Buffer,
	mesg:string,
	time:f64=5,
){
	send_notification(buff,{max_time= DEFALT_NOTIFICATION_TIME,time_left = DEFALT_NOTIFICATION_TIME,mesg_1=mesg,mesg_1_col = Ansi_Color.ansi_bright_red})
}
