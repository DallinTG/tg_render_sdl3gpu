package tg_render

import "vendor:stb/truetype"

import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import "core:reflect"
// import hm "handle_map_static_virtual"
import hm "core:container/handle_map"
import "core:time"
import lin"core:math/linalg"
import cl"clay-odin"
import "core:encoding/json"
import "core:os"
import "core:strconv"
import steam "steamworks"

UI_Info::struct{
	style:		UI_Style,
	themes:[dynamic;100][dynamic]UI_Style,
	notifications:	Notification_Buffer, 
	boxes:		hm.Dynamic_Handle_Map(UI_Box_Data, UI_Box_Handle),
	sorted_boxes:[dynamic;500]^UI_Box_Data,//this gets wiped every frame and resorted
}


UI_Style::struct{
	groop_name:		[100]u8,
	name:	[100]u8,
	author:		[100]u8,
	appearance:	[100]u8,
	col:struct{
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
	non,
}
get_ui_text_size::proc(size:union{UI_Size,f32},style:^UI_Style = nil) -> (new_size:u16){
	style:=style
	if style == nil{
		style = &s.ui.style
	}
	switch siz in size{
	case UI_Size:
		switch siz{
		case.normal:
		new_size = cast(u16)(style.siz.text * style.siz.text_multiplyer )
		case.tiny:
		new_size = cast(u16)(style.siz.text_tiny * style.siz.text_multiplyer )
		case.small:
		new_size = cast(u16)(style.siz.text_small * style.siz.text_multiplyer) 
		case.big:
		new_size = cast(u16)(style.siz.text_big * style.siz.text_multiplyer )
		case.large:
		new_size = cast(u16)(style.siz.text_large * style.siz.text_multiplyer )
		case.huge:
		new_size = cast(u16)(style.siz.text_huge * style.siz.text_multiplyer )
		case.non:
		new_size = 0 
		}
	case f32:
		new_size = cast(u16)siz
	}
	return
}

get_ui_border::proc(size:union{UI_Size,f32}, style:^UI_Style = nil) -> (new_size:u16){
	style:=style
	if style == nil{
		style = &s.ui.style
	}
	switch siz in size{
	case UI_Size:
		switch siz{
		case.normal:
		new_size = cast(u16)(style.siz.border * style.siz.border_multiplyer )
		case.tiny:
		new_size = cast(u16)(style.siz.border_tiny * style.siz.border_multiplyer )
		case.small:
		new_size = cast(u16)(style.siz.border_small * style.siz.border_multiplyer) 
		case.big:
		new_size = cast(u16)(style.siz.border_big * style.siz.border_multiplyer )
		case.large:
		new_size = cast(u16)(style.siz.border_large * style.siz.border_multiplyer )
		case.huge:
		new_size = cast(u16)(style.siz.border_huge * style.siz.border_multiplyer )
		case.non:
		new_size = 0 
		}
	case f32:
		new_size = cast(u16)siz
	}
	return
}

get_ui_pading::proc(size:union{UI_Size,f32}, style:^UI_Style = nil) -> (new_size:u16){
	style:=style
	if style == nil{
		style = &s.ui.style
	}
	switch siz in size{
	case UI_Size:
		switch siz{
		case.normal:
		new_size = cast(u16)(style.siz.pading * style.siz.pading_multiplyer )
		case.tiny:
		new_size = cast(u16)(style.siz.pading_tiny * style.siz.pading_multiplyer )
		case.small:
		new_size = cast(u16)(style.siz.pading_small * style.siz.pading_multiplyer )
		case.big:
		new_size = cast(u16)(style.siz.pading_big * style.siz.pading_multiplyer )
		case.large:
		new_size = cast(u16)(style.siz.pading_large * style.siz.pading_multiplyer )
		case.huge:
		new_size = cast(u16)(style.siz.pading_huge * style.siz.pading_multiplyer )
		case.non:
		new_size = 0 
		}
	case f32:
		new_size = cast(u16)siz
	}
	return
}



get_ui_child_gap::proc(size:union{UI_Size,f32}, style:^UI_Style = nil) -> (new_size:u16){
	style:=style
	if style == nil{
		style = &s.ui.style
	}
	switch siz in size{
	case UI_Size:
		switch siz{
		case.normal:
		new_size = cast(u16)(style.siz.child_gap * style.siz.child_gap_multiplyer )
		case.tiny:
		new_size = cast(u16)(style.siz.child_gap_tiny * style.siz.child_gap_multiplyer )
		case.small:
		new_size = cast(u16)(style.siz.child_gap_small * style.siz.child_gap_multiplyer )
		case.big:
		new_size = cast(u16)(style.siz.child_gap_big * style.siz.child_gap_multiplyer )
		case.large:
		new_size = cast(u16)(style.siz.child_gap_large * style.siz.child_gap_multiplyer )
		case.huge:
		new_size = cast(u16)(style.siz.child_gap_huge * style.siz.child_gap_multiplyer )
		case.non:
		new_size = 0 
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

get_ui_roundnes::proc(size:union{UI_Roundnes,f32}, style:^UI_Style = nil) -> (new_size:f32){
	style:=style
	if style == nil{
		style = &s.ui.style
	}
	switch siz in size{
	case UI_Roundnes:
		switch siz{
		case.sharp:
		new_size = style.siz.sharp * style.siz.roundnes_multiplyer
		case.smooth:
		new_size = style.siz.smooth * style.siz.roundnes_multiplyer
		case.round:
		new_size = style.siz.round * style.siz.roundnes_multiplyer
		case.bubble:
		new_size = style.siz.bubble * style.siz.roundnes_multiplyer
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
	steam.EPersonaState,
}
get_color::proc(col:Color_Types, style:^UI_Style = nil)->(new_col:Vec4){
	style:=style
	if style == nil{
		style = &s.ui.style
	}
	switch c in col{
	case Ansi_Color:
		switch c{
			case.ansi_black:
			new_col = style.col.ansi_black
			case.ansi_bright_black:
			new_col = style.col.ansi_bright_black
			case.ansi_dim_black:
			new_col = style.col.ansi_dim_black
			case.ansi_red:
			new_col = style.col.ansi_red
			case.ansi_bright_red:
			new_col = style.col.ansi_bright_red
			case.ansi_dim_red:
			new_col = style.col.ansi_dim_red
			case.ansi_green:
			new_col = style.col.ansi_green
			case.ansi_bright_green:
			new_col = style.col.ansi_bright_green
			case.ansi_dim_green:
			new_col = style.col.ansi_dim_green
			case.ansi_yellow:
			new_col = style.col.ansi_yellow
			case.ansi_bright_yellow:
			new_col = style.col.ansi_bright_yellow
			case.ansi_dim_yellow:
			new_col = style.col.ansi_dim_yellow
			case.ansi_blue:
			new_col = style.col.ansi_blue
			case.ansi_bright_blue:
			new_col = style.col.ansi_bright_blue
			case.ansi_dim_blue:
			new_col = style.col.ansi_dim_blue
			case.ansi_magenta:
			new_col = style.col.ansi_magenta
			case.ansi_bright_magenta:
			new_col = style.col.ansi_bright_magenta
			case.ansi_dim_magenta:
			new_col = style.col.ansi_dim_magenta
			case.ansi_cyan:
			new_col = style.col.ansi_cyan
			case.ansi_bright_cyan:
			new_col = style.col.ansi_bright_cyan
			case.ansi_dim_cyan:
			new_col = style.col.ansi_dim_cyan
			case.ansi_white:
			new_col = style.col.ansi_white
			case.ansi_bright_white:
			new_col = style.col.ansi_bright_white
			case.ansi_dim_white:
			new_col = style.col.ansi_dim_white
		}
	case UI_Border_Color:
		switch c{
			case.border:
			new_col = style.col.border
			case.border_variant:
			new_col = style.col.border_variant
			case.border_focused:
			new_col = style.col.border_focused
			case.border_selected:
			new_col = style.col.border_selected
			case.border_transparent:
			new_col = style.col.border_transparent
			case.border_disabled:
			new_col = style.col.border_disabled
		}
	case UI_Text_Color:
		switch c{
			case.text:
			new_col = style.col.text
			case.text_muted:
			new_col = style.col.text_muted
			case.text_placeholder:
			new_col = style.col.text_placeholder
			case.text_disabled:
			new_col = style.col.text_disabled
			case.text_accent:
			new_col = style.col.text_accent
			case.link_text_hover:
			new_col = style.col.link_text_hover
		}
	case UI_Color:
		switch c{
			case.icon:
			new_col = style.col.icon
			case.icon_muted:
			new_col = style.col.icon_muted
			case.icon_disabled:
			new_col = style.col.icon_disabled
			case.icon_placeholder:
			new_col = style.col.icon_placeholder
			case.icon_accent:
			new_col = style.col.icon_accent
			case.elevated_surface_background:
			new_col = style.col.elevated_surface_background
			case.surface_background:
			new_col = style.col.surface_background
			case.background:
			new_col = style.col.background
			case.element_background:
			new_col = style.col.element_background
			case.element_hover:
			new_col = style.col.element_hover
			case.element_active:
			new_col = style.col.element_active
			case.element_selected:
			new_col = style.col.element_selected
			case.element_disabled:
			new_col = style.col.element_disabled
			case.drop_target_background:
			new_col = style.col.drop_target_background
			case.status_bar_background:
			new_col = style.col.status_bar_background
			case.title_bar_background:
			new_col = style.col.title_bar_background
			case.title_bar_inactive_background:
			new_col = style.col.title_bar_inactive_background
			case.toolbar_background:
			new_col = style.col.toolbar_background
			case.tab_bar_background:
			new_col = style.col.tab_bar_background
			case.tab_inactive_background:
			new_col = style.col.tab_inactive_background
			case.tab_active_background:
			new_col = style.col.tab_active_background
			case.search_match_background:
			new_col = style.col.search_match_background
			case.panel_background:
			new_col = style.col.panel_background
			case.panel_focused_border:
			new_col = style.col.panel_focused_border
			case.panel_indent_guide:
			new_col = style.col.panel_indent_guide
			case.panel_indent_guide_active:
			new_col = style.col.panel_indent_guide_active
			case.panel_indent_guide_hover:
			new_col = style.col.panel_indent_guide_hover
			case.panel_overlay_background:
			new_col = style.col.panel_overlay_background
			case.pane_focused_border:
			new_col = style.col.pane_focused_border
			case.pane_group_border:
			new_col = style.col.pane_group_border
			case.scrollbar_thumb_background:
			new_col = style.col.scrollbar_thumb_background
			case.scrollbar_thumb_hover_background:
			new_col = style.col.scrollbar_thumb_hover_background
			case.scrollbar_thumb_border:
			new_col = style.col.scrollbar_thumb_border
			case.scrollbar_track_background:
			new_col = style.col.scrollbar_track_background
			case.scrollbar_track_border:
			new_col = style.col.scrollbar_track_border
			case.editor_foreground:
			new_col = style.col.editor_foreground
			case.editor_background:
			new_col = style.col.editor_background
			case.editor_gutter_background:
			new_col = style.col.editor_gutter_background
			case.editor_subheader_background:
			new_col = style.col.editor_subheader_background
			case.editor_active_line_background:
			new_col = style.col.editor_active_line_background
			case.editor_highlighted_line_background:
			new_col = style.col.editor_highlighted_line_background
			case.editor_line_number:
			new_col = style.col.editor_line_number
			case.editor_active_line_number:
			new_col = style.col.editor_active_line_number
			case.editor_invisible:
			new_col = style.col.editor_invisible
			case.editor_wrap_guide:
			new_col = style.col.editor_wrap_guide
			case.editor_active_wrap_guide:
			new_col = style.col.editor_active_wrap_guide
			case.editor_document_highlight_read_background:
			new_col = style.col.editor_document_highlight_read_background
			case.editor_document_highlight_write_background:
			new_col = style.col.editor_document_highlight_write_background
			case.editor_document_highlight_bracket_background:
			new_col = style.col.editor_document_highlight_bracket_background
			case.editor_indent_guide:
			new_col = style.col.editor_indent_guide
			case.editor_indent_guide_active:
			new_col = style.col.editor_indent_guide
			case.terminal_background:
			new_col = style.col.terminal_background
			case.terminal_foreground:
			new_col = style.col.terminal_foreground
			case.terminal_ansi_background:
			new_col = style.col.terminal_ansi_background
			case.terminal_bright_foreground:
			new_col = style.col.terminal_bright_foreground
			case.terminal_dim_foreground:
			new_col = style.col.terminal_dim_foreground
			case.success:
			new_col = style.col.success
			case.success_background:
			new_col = style.col.success_background
			case.success_border:
			new_col = style.col.success_border
			case.error:
			new_col = style.col.error
			case.error_background:
			new_col = style.col.error_background
			case.error_border:
			new_col = style.col.error_border
			case.info:
			new_col = style.col.info
			case.info_background:
			new_col = style.col.info_background
			case.info_border:
			new_col = style.col.info_border
			case.hint:
			new_col = style.col.hint
			case.hint_background:
			new_col = style.col.hint_background
			case.hint_border:
			new_col = style.col.hint_border
			case.warning:
			new_col = style.col.warning
			case.warning_background:
			new_col = style.col.warning_background
			case.warning_border:
			new_col = style.col.warning_border
		}
		case UI_Accents_Color:
		switch c{
			case.ac1:
			new_col = style.col.accents[0]
			case.ac2:
			new_col = style.col.accents[1]
			case.ac3:
			new_col = style.col.accents[2]
			case.ac4:
			new_col = style.col.accents[3]
			case.ac5:
			new_col = style.col.accents[4]
			case.ac6:
			new_col = style.col.accents[5]
			case.ac7:
			new_col = style.col.accents[6]
		}
		case steam.EPersonaState:
		switch c{
		case.Offline:
		new_col = style.col.ansi_bright_red
		case.Online:
		new_col = style.col.ansi_bright_green
		case.Busy:
		new_col = style.col.ansi_bright_red
		case.Away:
		new_col = style.col.ansi_bright_yellow
		case.Snooze:
		new_col = style.col.text
		case.LookingToTrade:
		new_col = style.col.ansi_bright_green
		case.LookingToPlay:
		new_col = style.col.ansi_bright_green
		case.Invisible:
		new_col = style.col.text
		case.Max:
		new_col = style.col.text
		}
	case Vec4:
		new_col = c
	}
	return
}

init_all_themes::proc(){
	init_themes_from_dir("themes")
	set_ui_style(s.ui.themes[0][0])

}
init_themes_from_dir::proc(path:string){
	files,err:=os.read_directory_by_path(path,100,context.temp_allocator)
	if err !=nil{
		log.log(.Error,fmt.tprint("bad path at init_themes_from_dir()",path))
		return
	}
	for fil in &files{
		if len(s.ui.themes) >= 100{
			log.log(.Error,"you have reached the max number of themes 100")
			return
		}
		load_ui_theme_by_file(fil.fullpath)
	}
}


load_ui_theme_by_file::proc(file:string){
	data, read_err := os.read_entire_file(file, context.allocator)
	if read_err != nil {
		fmt.eprintfln("Failed to load the file: %v", read_err,"path:",file)
		return
	}
	defer delete(data) // Free the memory at the end
	load_ui_theme_by_data(data)
}
mjv::map[string]json.Value
load_ui_theme_by_data::proc(data:[]u8){
	json_data, err := json.parse(data)
	if err != .None {
		fmt.eprintln("Failed to parse the json file.")
		fmt.eprintln("Error:", err)
		return
	}
	defer json.destroy_value(json_data)
	// fmt.print(size_of(json_data)," size of json_data\n")

	// Access the Root Level Object
	root := json_data.(json.Object)
	append(&s.ui.themes,[dynamic]UI_Style{})
	
	for id := 0;true; id += 1 {
		// st:=sty[id]

		if root["themes"].(json.Array) == nil {return}
		if id >= len(root["themes"].(json.Array)) {return}

		if root["themes"].(json.Array)[id].(json.Object) == nil{continue}
		theme:=root["themes"].(json.Array)[id].(json.Object)
	
		if root["themes"].(json.Array)[id].(json.Object)["style"].(json.Object) == nil{continue}
		style:=root["themes"].(json.Array)[id].(json.Object)["style"].(json.Object)

		append(&s.ui.themes[len(s.ui.themes)-1],UI_Style{})
		st:=&s.ui.themes[len(s.ui.themes)-1][id]
	
	 
		if accents, ok := style["accents"].(json.Array); ok {
			for i in 0..<min(len(accents), len(st.col.accents)) {
				if c, ok := accents[i].(json.String); ok {
					st.col.accents[i] = string_hex_to_rgba(c)
				}
			}
		} 
		
		st.siz = DEFALT_UI_STYLE.siz
		load_string(cast(mjv)root,  "name", st.groop_name[:])
		load_string(cast(mjv)root,  "author", st.author[:])
		load_string(cast(mjv)theme, "name", st.name[:])
		load_string(cast(mjv)theme, "appearance", st.appearance[:])
	
		load_color(cast(mjv)style, "border", &st.col.border)
		load_color(cast(mjv)style, "border.variant", &st.col.border_variant)
		load_color(cast(mjv)style, "border.focused", &st.col.border_focused)
		load_color(cast(mjv)style, "border.selected", &st.col.border_selected)
		load_color(cast(mjv)style, "border.transparent", &st.col.border_transparent)
		load_color(cast(mjv)style, "border.disabled", &st.col.border_disabled)
		
		load_color(cast(mjv)style, "elevated_surface.background", &st.col.elevated_surface_background)
		load_color(cast(mjv)style, "surface.background", &st.col.surface_background)
		load_color(cast(mjv)style, "background", &st.col.background)
		
		load_color(cast(mjv)style, "element.background", &st.col.element_background)
		load_color(cast(mjv)style, "element.hover", &st.col.element_hover)
		load_color(cast(mjv)style, "element.active", &st.col.element_active)
		load_color(cast(mjv)style, "element.selected", &st.col.element_selected)
		load_color(cast(mjv)style, "element.disabled", &st.col.element_disabled)
		
		load_color(cast(mjv)style, "panel.background", &st.col.panel_background)
		load_color(cast(mjv)style, "panel.focused_border", &st.col.panel_focused_border)
		load_color(cast(mjv)style, "panel.indent_guide", &st.col.panel_indent_guide)
		load_color(cast(mjv)style, "panel.indent_guide_active", &st.col.panel_indent_guide_active)
		load_color(cast(mjv)style, "panel.indent_guide_hover", &st.col.panel_indent_guide_hover)
		load_color(cast(mjv)style, "panel.overlay_background", &st.col.panel_overlay_background)
		
		load_color(cast(mjv)style, "pane.focused_border", &st.col.pane_focused_border)
		load_color(cast(mjv)style, "pane_group.border", &st.col.pane_group_border)
		
		load_color(cast(mjv)style, "drop_target.background", &st.col.drop_target_background)
		
		load_color(cast(mjv)style, "text", &st.col.text)
		load_color(cast(mjv)style, "text.muted", &st.col.text_muted)
		load_color(cast(mjv)style, "text.placeholder", &st.col.text_placeholder)
		load_color(cast(mjv)style, "text.disabled", &st.col.text_disabled)
		load_color(cast(mjv)style, "text.accent", &st.col.text_accent)
		
		load_color(cast(mjv)style, "icon", &st.col.icon)
		load_color(cast(mjv)style, "icon.muted", &st.col.icon_muted)
		load_color(cast(mjv)style, "icon.disabled", &st.col.icon_disabled)
		load_color(cast(mjv)style, "icon.placeholder", &st.col.icon_placeholder)
		load_color(cast(mjv)style, "icon.accent", &st.col.icon_accent)
		
		load_color(cast(mjv)style, "status_bar.background", &st.col.status_bar_background)
		load_color(cast(mjv)style, "title_bar.background", &st.col.title_bar_background)
		load_color(cast(mjv)style, "title_bar.inactive_background", &st.col.title_bar_inactive_background)
		load_color(cast(mjv)style, "toolbar.background", &st.col.toolbar_background)
		load_color(cast(mjv)style, "tab_bar.background", &st.col.tab_bar_background)
		load_color(cast(mjv)style, "tab.inactive_background", &st.col.tab_inactive_background)
		load_color(cast(mjv)style, "tab.active_background", &st.col.tab_active_background)
		
		load_color(cast(mjv)style, "search.match_background", &st.col.search_match_background)
		
		load_color(cast(mjv)style, "scrollbar.thumb.background", &st.col.scrollbar_thumb_background)
		load_color(cast(mjv)style, "scrollbar.thumb.hover_background", &st.col.scrollbar_thumb_hover_background)
		load_color(cast(mjv)style, "scrollbar.thumb.border", &st.col.scrollbar_thumb_border)
		load_color(cast(mjv)style, "scrollbar.track.background", &st.col.scrollbar_track_background)
		load_color(cast(mjv)style, "scrollbar.track.border", &st.col.scrollbar_track_border)
	
	
		load_color(cast(mjv)style, "editor.foreground", &st.col.editor_foreground)
		load_color(cast(mjv)style, "editor.background", &st.col.editor_background)
		load_color(cast(mjv)style, "editor.gutter.background", &st.col.editor_gutter_background)
		load_color(cast(mjv)style, "editor.subheader.background", &st.col.editor_subheader_background)
		load_color(cast(mjv)style, "editor.active_line.background", &st.col.editor_active_line_background)
		load_color(cast(mjv)style, "editor.highlighted_line.background", &st.col.editor_highlighted_line_background)
		load_color(cast(mjv)style, "editor.line_number", &st.col.editor_line_number)
		load_color(cast(mjv)style, "editor.active_line_number", &st.col.editor_active_line_number)
		load_color(cast(mjv)style, "editor.invisible", &st.col.editor_invisible)
		load_color(cast(mjv)style, "editor.wrap_guide", &st.col.editor_wrap_guide)
		load_color(cast(mjv)style, "editor.active_wrap_guide", &st.col.editor_active_wrap_guide)
		load_color(cast(mjv)style, "editor.document_highlight.read_background", &st.col.editor_document_highlight_read_background)
		load_color(cast(mjv)style, "editor.document_highlight.write_background", &st.col.editor_document_highlight_write_background)
		load_color(cast(mjv)style, "editor.document_highlight.bracket_background", &st.col.editor_document_highlight_bracket_background)
		load_color(cast(mjv)style, "editor.indent_guide", &st.col.editor_indent_guide)
		load_color(cast(mjv)style, "editor.indent_guide_active", &st.col.editor_indent_guide_active)
		
		load_color(cast(mjv)style, "terminal.background", &st.col.terminal_background)
		load_color(cast(mjv)style, "terminal.foreground", &st.col.terminal_foreground)
		
		load_color(cast(mjv)style, "terminal.ansi.background", &st.col.terminal_ansi_background)
		
		load_color(cast(mjv)style, "terminal.bright_foreground", &st.col.terminal_bright_foreground)
		load_color(cast(mjv)style, "terminal.dim_foreground", &st.col.terminal_dim_foreground)
		
		load_color(cast(mjv)style, "terminal.ansi.black", &st.col.ansi_black)
		load_color(cast(mjv)style, "terminal.ansi.bright_black", &st.col.ansi_bright_black)
		load_color(cast(mjv)style, "terminal.ansi.dim_black", &st.col.ansi_dim_black)
		
		load_color(cast(mjv)style, "terminal.ansi.red", &st.col.ansi_red)
		load_color(cast(mjv)style, "terminal.ansi.bright_red", &st.col.ansi_bright_red)
		load_color(cast(mjv)style, "terminal.ansi.dim_red", &st.col.ansi_dim_red)
		
		load_color(cast(mjv)style, "terminal.ansi.green", &st.col.ansi_green)
		load_color(cast(mjv)style, "terminal.ansi.bright_green", &st.col.ansi_bright_green)
		load_color(cast(mjv)style, "terminal.ansi.dim_green", &st.col.ansi_dim_green)
		
		load_color(cast(mjv)style, "terminal.ansi.yellow", &st.col.ansi_yellow)
		load_color(cast(mjv)style, "terminal.ansi.bright_yellow", &st.col.ansi_bright_yellow)
		load_color(cast(mjv)style, "terminal.ansi.dim_yellow", &st.col.ansi_dim_yellow)
		
		load_color(cast(mjv)style, "terminal.ansi.blue", &st.col.ansi_blue)
		load_color(cast(mjv)style, "terminal.ansi.bright_blue", &st.col.ansi_bright_blue)
		load_color(cast(mjv)style, "terminal.ansi.dim_blue", &st.col.ansi_dim_blue)
		
		load_color(cast(mjv)style, "terminal.ansi.magenta", &st.col.ansi_magenta)
		load_color(cast(mjv)style, "terminal.ansi.bright_magenta", &st.col.ansi_bright_magenta)
		load_color(cast(mjv)style, "terminal.ansi.dim_magenta", &st.col.ansi_dim_magenta)
		
		load_color(cast(mjv)style, "terminal.ansi.cyan", &st.col.ansi_cyan)
		load_color(cast(mjv)style, "terminal.ansi.bright_cyan", &st.col.ansi_bright_cyan)
		load_color(cast(mjv)style, "terminal.ansi.dim_cyan", &st.col.ansi_dim_cyan)
		
		load_color(cast(mjv)style, "terminal.ansi.white", &st.col.ansi_white)
		load_color(cast(mjv)style, "terminal.ansi.bright_white", &st.col.ansi_bright_white)
		load_color(cast(mjv)style, "terminal.ansi.dim_white", &st.col.ansi_dim_white)
		
		load_color(cast(mjv)style, "link_text.hover", &st.col.link_text_hover)
	
		load_color(cast(mjv)style, "success", &st.col.success)
		load_color(cast(mjv)style, "success.background", &st.col.success_background)
		load_color(cast(mjv)style, "success.border", &st.col.success_border)
		
		load_color(cast(mjv)style, "error", &st.col.error)
		load_color(cast(mjv)style, "error.background", &st.col.error_background)
		load_color(cast(mjv)style, "error.border", &st.col.error_border)
		
		load_color(cast(mjv)style, "info", &st.col.info)
		load_color(cast(mjv)style, "info.background", &st.col.info_background)
		load_color(cast(mjv)style, "info.border", &st.col.info_border)
		
		load_color(cast(mjv)style, "hint", &st.col.hint)
		load_color(cast(mjv)style, "hint.background", &st.col.hint_background)
		load_color(cast(mjv)style, "hint.border", &st.col.hint_border)
		
		load_color(cast(mjv)style, "warning", &st.col.warning)
		load_color(cast(mjv)style, "warning.background", &st.col.warning_background)
		load_color(cast(mjv)style, "warning.border", &st.col.warning_border)

	
	}
}
load_color :: proc(style: map[string]json.Value, key: string, dst: ^Vec4) {
    if s, ok := style[key].(json.String); ok {
        dst^ = string_hex_to_rgba(s)
    }
}
load_string :: proc(style: map[string]json.Value, key: string, dst: []u8) {
    if str, ok := style[key].(json.String); ok {
        copy_slice(dst,transmute([]u8)str)
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
	s.ui.style = sty
}





defalt_box_dec::proc(
	border_col_id:Color_Types = .border,
	background_col_id:Color_Types = .element_background,
	// background_huv_col_id:Color_Types = .element_hover,
	
	
	border_size_id: UI_Size  = .normal,
	padding_size_id:UI_Size = .normal,
	child_gap_id:UI_Size = .small,
	roundnes_id:UI_Roundnes = .sharp,
	

	layout_direction :cl.LayoutDirection= .TopToBottom,
	child_alignment: = cl.ChildAlignment{x=.Center,y=.Center},
	
	clip:cl.ClipElementConfig={
		horizontal=false, // clip overflowing elements on the "X" axis
		vertical=false, // clip overflowing elements on the "Y" axis
		childOffset={}, // offsets the [X,Y] positions of all child elements, primarily for scrolling containers
	},
	style_overide:^UI_Style = nil,

)->(button:cl.ElementDeclaration){

	border_col:=get_color(border_col_id,style_overide)
	background_col:=get_color(background_col_id,style_overide)
	
	// background_huv_col:=get_color(background_huv_col_id)

	border_size:= get_ui_border(border_size_id,style_overide)
	child_gap:= get_ui_child_gap(child_gap_id)
	padding_size:= get_ui_pading(padding_size_id,style_overide)
	roundnes_id:= get_ui_roundnes(roundnes_id,style_overide)

	new_clip:=clip
	if clip.horizontal{ new_clip.childOffset = cl.GetScrollOffset()}
	if clip.vertical{new_clip.childOffset = cl.GetScrollOffset()}

	
	button_hov:=cl.Hovered()
	button = cl.ElementDeclaration{
		layout = {
			layoutDirection = layout_direction,
			sizing = { cl.SizingGrow(), cl.SizingFit() },
			childAlignment = child_alignment,
			padding = {padding_size,padding_size,padding_size,padding_size},
			childGap = child_gap,
		},
		// cornerRadius =cl.CornerRadius{5,5,5,5,},
		backgroundColor = background_col,
		border = cl.BorderElementConfig{
			color = border_col,
			width = cl.BorderWidth {border_size,border_size,border_size,border_size,0}
		},
		clip = new_clip,
	}
	return button
}

defalt_seperator_dec::proc(
	padding_size_id:UI_Size = .non,
	child_gap:UI_Size = .non,
	layout_direction :cl.LayoutDirection= .TopToBottom,
	child_alignment: = cl.ChildAlignment{x=.Center,y=.Center},
)->(button:cl.ElementDeclaration){

	// border_col:=get_color(border_col_id)
	// background_col:=get_color(background_col_id)
	// background_huv_col:=get_color(background_huv_col_id)

	// border_size:= get_ui_border(border_size_id)
	padding_size:= get_ui_pading(padding_size_id)
	child_gap_size:= get_ui_pading(child_gap)
	// roundnes_id:= get_ui_roundnes(roundnes_id)
	
	
	button_hov:=cl.Hovered()
	button = cl.ElementDeclaration{
		layout = {
				layoutDirection = layout_direction,
				sizing = { cl.SizingGrow(), cl.SizingFit() },
				childAlignment = child_alignment,
				padding = {padding_size,padding_size,padding_size,padding_size},
				childGap = child_gap_size,
			},
		// backgroundColor = background_col,
		// border = cl.BorderElementConfig{
		// 	color = border_col,
		// 	width = cl.BorderWidth{border_size,border_size,border_size,border_size,0}
		// },
	}
	return button
}

defalt_img_box_dec::proc(
	img:rawptr,
	border_col_id:Color_Types = .border_variant,
	background_col_id:Color_Types = .element_background,
	// background_huv_col_id:Color_Types = .element_hover,
	img_color:Color_Types = Vec4{1,1,1,1},
	border_size_id:UI_Size = .small,
	padding_size_id:UI_Size = .normal,
	roundnes_id:UI_Roundnes = .sharp,
	size:UI_Size = .normal,

	style_overide:^UI_Style = nil,
)->(button:cl.ElementDeclaration){

	border_col:=get_color(border_col_id,style_overide)
	background_col:=get_color(background_col_id,style_overide)
	img_col:=get_color(img_color,style_overide)
	// background_huv_col:=get_color(background_huv_col_id)

	border_size:= get_ui_border(border_size_id,style_overide)
	padding_size:= get_ui_pading(padding_size_id,style_overide)
	roundnes_id:= get_ui_roundnes(roundnes_id,style_overide)

	img_size:=get_ui_text_size(size,style_overide)

	
	button_hov:=cl.Hovered()
	button = cl.ElementDeclaration{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = { cl.SizingFixed(cast(f32)img_size), cl.SizingFixed(cast(f32)img_size) },
			childAlignment = cl.ChildAlignment{x=.Center,y=.Center},
			padding = {padding_size,padding_size,padding_size,padding_size},
			childGap = {},
		},
		image={img},
		// backgroundColor = img_col,
		overlayColor = img_col,
		border = cl.BorderElementConfig{
			color = border_col,
			width = cl.BorderWidth{border_size,border_size,border_size,border_size,0}
		},
	}
	return button
}


button_dec::proc(
	border_col_id:Color_Types = .border,
	background_col_id:Color_Types = .element_background,
	background_huv_col_id:Color_Types = .element_hover,
	
	border_size_id:UI_Size = .normal,
	padding_size_id:UI_Size = .normal,
	roundnes_id:UI_Roundnes = .sharp,
	child_gap_id:UI_Size = .small,
	layout_direction:cl.LayoutDirection = .LeftToRight,
	style_overide:^UI_Style = nil,

)->(button:cl.ElementDeclaration){

	border_col:=get_color(border_col_id,style_overide)
	background_col:=get_color(background_col_id,style_overide)
	background_huv_col:=get_color(background_huv_col_id,style_overide)

	border_size:= get_ui_border(border_size_id,style_overide)
	padding_size:= get_ui_pading(padding_size_id,style_overide)
	roundnes_id:= get_ui_roundnes(roundnes_id,style_overide)
	child_gap:= get_ui_child_gap(child_gap_id,style_overide)

	
	button_hov:=cl.Hovered()
	button = cl.ElementDeclaration{
		layout = {
				layoutDirection = layout_direction,
				sizing = { cl.SizingGrow(), cl.SizingFit() },
				childAlignment = cl.ChildAlignment{x=.Center,y=.Center},
				padding = {padding_size,padding_size,padding_size,padding_size},
				childGap = child_gap,
			},
		// cornerRadius = {20,20,20,20},
		backgroundColor = background_col if !button_hov else background_huv_col,
		border = cl.BorderElementConfig{
			color = border_col,
			width = cl.BorderWidth{border_size,border_size,border_size,border_size,0}
		},
	}
	return button
}

toggle_button_dec::proc(
	tf:^bool,
	border_col_id:Color_Types = .border,
	background_col_off_id:Color_Types = .element_background,
	background_col_on_id:Color_Types = .element_active,
	background_huv_col_id:Color_Types = .element_hover,
	
	border_size_id:UI_Size = .normal,
	padding_size_id:UI_Size = .normal,
	child_gap_id:UI_Size = .small,
	roundnes_id:UI_Roundnes = .sharp,
	
	style_overide:^UI_Style = nil,

)->(button:cl.ElementDeclaration){

	border_col:=get_color(border_col_id,style_overide)
	background_col_on:=get_color(background_col_on_id,style_overide)
	background_col_off:=get_color(background_col_off_id,style_overide)
	background_huv_col:=get_color(background_huv_col_id,style_overide)

	border_size:= get_ui_border(border_size_id,style_overide)
	padding_size:= get_ui_pading(padding_size_id,style_overide)
	roundnes_id:= get_ui_roundnes(roundnes_id,style_overide)
	child_gap:= get_ui_child_gap(child_gap_id,style_overide)

	button_hov:=cl.Hovered()

	background_col:=background_col_on
	if tf^{
		background_col = background_col_on
	}else{
		background_col = background_col_off
	}	
	if button_hov{
		background_col = background_huv_col
	}
	button = cl.ElementDeclaration{
		layout = {
				layoutDirection = .TopToBottom,
				sizing = { cl.SizingGrow(), cl.SizingFit() },
				childAlignment = cl.ChildAlignment{x=.Center,y=.Center},
				padding = {padding_size,padding_size,padding_size,padding_size},
				childGap = {},
			},
		// cornerRadius = {20,20,20,20},
		backgroundColor = background_col,
		border = cl.BorderElementConfig{
			color = border_col,
			width = cl.BorderWidth{border_size,border_size,border_size,border_size,0}
		},
	}
	return button
}

text_dec::proc(
	text_col_id:Color_Types = .text,
	text_size_id:UI_Size = .normal,
	style_overide:^UI_Style = nil,
)->(dec:cl.TextElementConfig){
	text_col:=get_color(text_col_id,style_overide)
	text_size:=get_ui_text_size(text_size_id,style_overide)

	dec = cl.TextElementConfig{
		textColor = text_col,
		fontSize = text_size
	}
	return
}


button_txt::proc(
	$text:string,
	text_col_id:Color_Types = .text,
	text_size_id:UI_Size = .normal,
	style_overide:^UI_Style = nil,
 ){
	text_col:=get_color(text_col_id,style_overide)
	text_size:=get_ui_text_size(text_size_id,style_overide)
	cl.Text(
		text,
		cl.TextElementConfig{
			textColor = text_col,
			fontSize = text_size
		},
	)
}
button_txt_dynamic::proc(
	text:string,
	text_col_id:Color_Types = .text,
	text_size_id:UI_Size = .normal,
	style_overide:^UI_Style = nil,
){
	text_col:=get_color(text_col_id,style_overide)
	text_size:=get_ui_text_size(text_size_id,style_overide)
	cl.TextDynamic(
		text,
		cl.TextElementConfig{
			textColor = text_col,
			fontSize = text_size
		},
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
	style_overide:^UI_Style = nil,
)->(button:cl.ElementDeclaration){
	
	
	border_col:=get_color(border_col_id,style_overide)
	background_col:=get_color(background_col_id,style_overide)
	background_huv_col:=get_color(background_huv_col_id,style_overide)

	border_size:= get_ui_border(border_size_id,style_overide)
	padding_size:= get_ui_pading(padding_size_id,style_overide)
	child_gap_id:= get_ui_child_gap(child_gap_id,style_overide)
	roundnes_id:= get_ui_roundnes(roundnes_id,style_overide)

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
		transition = cl.TransitionElementConfig{

			handler = cl.EaseOut,
			duration = .2,
			properties = cl.TransitionPropertyFlags{.X,.Y},
			interactionHandling = .AllowInteractionsWhileTransitioningPosition,
			enter = {
				setInitialState = state_slide_in_right,
				trigger = cl.TransitionEnterTriggerType.TriggerOnFirstParentFrame,
			},
			exit = {
				setFinalState = state_slide_in_right,
				// trigger=         .TriggerOnFirstParentFrame,
				// siblingOrdering: TriggerOnFirstParentFrame,
			},

		},
		backgroundColor = background_col if !button_hov else background_huv_col,
		border = cl.BorderElementConfig{
			color = border_col,
			width = cl.BorderWidth{border_size,border_size,border_size,border_size,0}
		},
	}
	return button
}

state_drop_in:: proc "c" (initialState: cl.TransitionData, properties: cl.TransitionPropertyFlags) -> (new_t:cl.TransitionData){
	new_t=initialState
	new_t.boundingBox.y = -100 
	return
}
state_slide_in_left:: proc "c" (initialState: cl.TransitionData, properties: cl.TransitionPropertyFlags) -> (new_t:cl.TransitionData){
	new_t=initialState
	new_t.boundingBox.x = -10 -new_t.boundingBox.x
	return
}
state_slide_in_right:: proc "c" (initialState: cl.TransitionData, properties: cl.TransitionPropertyFlags) -> (new_t:cl.TransitionData){
	new_t=initialState

	new_t.boundingBox.x += new_t.boundingBox.width*1.5
	return
}


notification_progress_bar::proc(
	persent:f32,
	col_id:Color_Types = .ac1,
	style_overide:^UI_Style = nil,
){
	col:=get_color(col_id,style_overide)
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
	style_overide:^UI_Style = nil,
){
	padding_size:= get_ui_pading(padding_size_id,style_overide)
	x_border_size:=get_ui_border(border_size_id,style_overide)
	x_border_col:=get_color(border_col_id,style_overide)
	x_color:=get_color(x_color_id,style_overide)
	x_color_huv:=get_color(x_color_huv_id,style_overide)
	if cl.UI(cl.ID("Notification_x_button", notification.id))({
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
	style_overide:^UI_Style = nil,
 ){
	text_col:=get_color(text_col_id,style_overide)
	text_size:=get_ui_text_size(text_size_id,style_overide)
	cl.Text(
		text,
		cl.TextElementConfig{
			textColor = text_col,
			fontSize = text_size
		},
	)
}
notification_txt_dynamic::proc(
	text:string,
	text_col_id:Color_Types = .text_accent,
	text_size_id:UI_Size = .small,
	style_overide:^UI_Style = nil,
){
	text_col:=get_color(text_col_id,style_overide)
	text_size:=get_ui_text_size(text_size_id,style_overide)
	cl.TextDynamic(
		text,
		cl.TextElementConfig{
			textColor = text_col,
			fontSize = text_size
		},
	)
}

defalt_txt::proc(
	$text:string,
	text_col_id:Color_Types = .text,
	text_size_id:UI_Size = .small,
	style_overide:^UI_Style = nil,
 ){
	text_col:=get_color(text_col_id,style_overide)
	text_size:=get_ui_text_size(text_size_id,style_overide)
	cl.Text(
		text,
		cl.TextElementConfig{
			textColor = text_col,
			fontSize = text_size
		},
	)
}
defalt_txt_dynamic::proc(
	text:string,
	text_col_id:Color_Types = .text,
	text_size_id:UI_Size = .small,
	style_overide:^UI_Style = nil,
){
	text_col:=get_color(text_col_id,style_overide)
	text_size:=get_ui_text_size(text_size_id,style_overide)
	cl.TextDynamic(
		text,
		cl.TextElementConfig{
			textColor = text_col,
			fontSize = text_size
		},
	)
}


MAX_NUMBER_OF_NOTIFICATION::100
Notification_Buffer::struct{
	notifications:[dynamic;MAX_NUMBER_OF_NOTIFICATION]Notification,
	last_id_created:u32,
}
Notification::struct{
	id:u32,
	max_time:f64,
	time_left:f64,
	mesg_1:string,
	mesg_1_col:Color_Types,
	lobby_id_to_join:u64,
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
draw_notification_buffer::proc(buff:^Notification_Buffer, location:cl.LayoutAlignmentX = .Right){
	child_gap:=get_ui_child_gap(.normal)
	if cl.UI(cl.ID("Notification_List"))({
		layout =cl.LayoutConfig { 
			layoutDirection = .TopToBottom,
			sizing = { cl.SizingGrow(), cl.SizingGrow() },
			childGap = child_gap,
			childAlignment= {x = location,y= .Top},
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
			if cl.UI(cl.ID("Notification", notif.id))(notification_dec(&notif)) {
				notification_x_button(&notif)
				notification_txt_dynamic(notif.mesg_1,text_col_id = notif.mesg_1_col,)
				if notif.lobby_id_to_join != 0 {
					button_join_lobby_by_id(notif.lobby_id_to_join,2789346289)
				}
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
		buff.last_id_created+=1
		temp_mesg:=mesg
		temp_mesg.id = buff.last_id_created
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

send_accept_invite_to_game_notification::proc(
	buff:^Notification_Buffer,
	mesg:string,
	time:f64=5,
	lobby_id:u64 = 0,
){
	if lobby_id != 0{
		send_notification(buff,{max_time= time,time_left = time,mesg_1=mesg,lobby_id_to_join = lobby_id})
	}
}

send_simp_error_notification::proc(
	buff:^Notification_Buffer,
	mesg:string,
	time:f64=5,
){
	send_notification(buff,{max_time= DEFALT_NOTIFICATION_TIME,time_left = DEFALT_NOTIFICATION_TIME,mesg_1=mesg,mesg_1_col = Ansi_Color.ansi_bright_red})
}

draw_steam_friends::proc(location:cl.LayoutAlignmentX = .Right){
	if s.steam.is_using_steam != true {return}

	child_gap:=get_ui_child_gap(.normal)
	
	List_box_data:=cl.GetElementData(cl.ID("steam_friends_List_iner_box"))
	custom_offset:[2]f32={List_box_data.boundingBox.width,0}
	if cl.PointerOver(cl.ID("Player_friends_icon_box"))||cl.PointerOver(cl.ID("steam_friends_List_iner_box")){
		custom_offset={0,0}
	}
	if cl.UI(cl.ID("steam_friends_List_outer_box"))({
		layout = { 
			layoutDirection = .LeftToRight,
			sizing = { cl.SizingFit(), cl.SizingGrow() },
			// childGap = child_gap,
			childAlignment= {x = location,y= .Top},

		},
		floating =cl.FloatingElementConfig{
			// attachment = {.Root},
			offset = custom_offset,
			attachTo = .Root,
			pointerCaptureMode =cl.PointerCaptureMode.Passthrough,
			attachment= cl.FloatingAttachPoints{
				element = cl.FloatingAttachPointType.RightTop,
				parent =   cl.FloatingAttachPointType.RightTop,
			}
		},
		
		transition = cl.TransitionElementConfig{

			handler = cl.EaseOut,
			duration = .2,
			properties = cl.TransitionPropertyFlags{.X,.Y},
			interactionHandling = .AllowInteractionsWhileTransitioningPosition,
			enter = {
				setInitialState = state_slide_in_right,
				trigger = cl.TransitionEnterTriggerType.TriggerOnFirstParentFrame,
			},
			exit = {
				setFinalState = state_slide_in_right,
				// trigger=         .TriggerOnFirstParentFrame,
				// siblingOrdering: TriggerOnFirstParentFrame,
			},

		},
		// clip ={
		// 	horizontal=false,
		// 	vertical=true,
		// 	childOffset=cl.GetScrollOffset(),
		// },
		backgroundColor = {0,0,0,0},
		
	}) {
		icon_box_dec:=defalt_box_dec(border_size_id=.normal,layout_direction = .LeftToRight,child_alignment = {.Left,.Top},padding_size_id=.small)
		icon_box_dec.layout.padding.right = 0
		icon_box_dec.border.width.right = 0
	
		if cl.UI(cl.ID("Player_friends_icon_box"))(icon_box_dec) {
			img:=get_texture_by_id(.Travel_Person_People_Three)
			//TODO this needs to use a textur handle insted
			// img:=get_texture(.Travel_Person_People_Three)
			if cl.UI(cl.ID("Player_friends_icon",))(defalt_img_box_dec(cast(rawptr)&img.handle,border_size_id=.non,padding_size_id=.non,size = .big,img_color = .info)) {
			}
		}
		temp_list_iner_box_proc:=cl.UI(cl.ID("steam_friends_List_iner_box", ))
		list_box_dec:=defalt_box_dec(clip = {vertical = true},padding_size_id = .non)
		list_box_dec.border.width.betweenChildren = list_box_dec.border.width.bottom
		if temp_list_iner_box_proc(list_box_dec,) {

			draw_steam_player_groop(&s.steam.friends)
		}

	}
}

draw_steam_lobby_ui::proc(location:cl.LayoutAlignmentX = .Right){
	if s.steam.is_using_steam != true {return}

	child_gap:=get_ui_child_gap(.normal)
	
	List_box_data:=cl.GetElementData(cl.ID("steam_lobby_List_iner_box"))
	custom_offset:[2]f32={List_box_data.boundingBox.width*-1,0}
	if cl.PointerOver(cl.ID("Player_lobby_icon_box"))||cl.PointerOver(cl.ID("steam_lobby_List_iner_box")){
		custom_offset={0,0}
	}
	if cl.UI(cl.ID("steam_lobby_List_outer_box"))({
		layout = { 
			layoutDirection = .LeftToRight,
			sizing = { cl.SizingFit(), cl.SizingGrow() },
			// childGap = child_gap,
			childAlignment= {x = location,y= .Top},

		},
		floating =cl.FloatingElementConfig{
			// attachment = {.Root},
			offset = custom_offset,
			attachTo = .Root,
			pointerCaptureMode =cl.PointerCaptureMode.Passthrough,
			attachment= cl.FloatingAttachPoints{
				element = cl.FloatingAttachPointType.LeftTop,
				parent =   cl.FloatingAttachPointType.LeftTop,
			}
		},
		
		transition = cl.TransitionElementConfig{

			handler = cl.EaseOut,
			duration = .2,
			properties = cl.TransitionPropertyFlags{.X,.Y},
			interactionHandling = .AllowInteractionsWhileTransitioningPosition,
			enter = {
				setInitialState = state_slide_in_right,
				trigger = cl.TransitionEnterTriggerType.TriggerOnFirstParentFrame,
			},
			exit = {
				setFinalState = state_slide_in_right,
				// trigger=         .TriggerOnFirstParentFrame,
				// siblingOrdering: TriggerOnFirstParentFrame,
			},

		},
		// clip ={
		// 	horizontal=false,
		// 	vertical=true,
		// 	childOffset=cl.GetScrollOffset(),
		// },
		backgroundColor = {0,0,0,0},
		
	}) {

	
		{
		temp_list_iner_box_proc:=cl.UI(cl.ID("steam_lobby_List_iner_box", ))
		list_box_dec:=defalt_box_dec(clip = {vertical = true},padding_size_id = .non)
		list_box_dec.border.width.betweenChildren = list_box_dec.border.width.bottom
		if temp_list_iner_box_proc(list_box_dec,) {
			draw_steam_player_groop(&s.steam.steam_lobby.groop, 534121265)
		}
		}
		icon_box_dec:=defalt_box_dec(border_size_id=.normal,layout_direction = .LeftToRight,child_alignment = {.Left,.Top},padding_size_id=.small)
		icon_box_dec.layout.padding.right = 0
		icon_box_dec.border.width.right = 0
		if cl.UI(cl.ID("Player_lobby_icon_box"))(icon_box_dec) {
			img:=get_texture_by_id(.Travel_Person_People_Three)
			//TODO this part needs to be fixed
			// img:=get_texture(.Travel_Person_People_Three)
			if cl.UI(cl.ID("Player_lobby_icon",))(defalt_img_box_dec(cast(rawptr)&img.handle,border_size_id=.non,padding_size_id=.non,size = .big,img_color = .info)) {
			}
		}
	}
}

draw_steam_player_groop::proc(groop:^Steam_Player_Groop,index:u32=0){
	if s.steam.is_using_steam != true {return}
	if groop == nil {return}
	for &player in &groop.player{

		draw_steam_player(&player,index)
	}
}


draw_steam_player::proc(
	player:^Steam_Player,
	index:u32=0,
	text_size:UI_Size = .small,
	player_icon_size:UI_Size = .large,
	border_size:UI_Size = .small,
){
	if s.steam.is_using_steam != true {return}
	if player == nil {return}
	if cl.UI(cl.ID("Player_Card", cast(u32)player.l_player_icon_id+index))(defalt_box_dec(border_size_id=border_size,layout_direction = .LeftToRight,child_alignment = {.Left,.Top})) {
		if cl.UI(cl.ID("Player_larg_icon", cast(u32)player.l_player_icon_id+index))(defalt_img_box_dec(cast(rawptr)&player.l_player_icon_gpu_hd,size = player_icon_size)) {
		}
		if cl.UI(cl.ID("Player_Card_info", cast(u32)player.l_player_icon_id+index))(defalt_seperator_dec(layout_direction = .TopToBottom,child_alignment = {.Left,.Top},padding_size_id = .normal,child_gap=.small)) {
			defalt_txt_dynamic(player.name)
			defalt_txt_dynamic(player.status_string,text_col_id=player.status,text_size_id = text_size)
			defalt_txt_dynamic(fmt.tprint(" Lobby_ID: ",player.game.steamIDLobby),)	
			button_invite_to_lobby(player,index)
			button_join_game(player,index)
			
		}
	}
}
button_invite_to_lobby::proc(player:^Steam_Player,index:u32=0){
	if cl.UI(cl.ID("button_invite_to_lobby",cast(u32)player.cs_id+index))(button_dec()) {
		button_txt("Invite")
		if cl.Hovered() && s.is_ui_l_click(){
			steam_invite_player_to_lobby(player.cs_id)
		}
	}
}

button_join_game::proc(player:^Steam_Player,index:u32=0){
	if player.game.steamIDLobby != 0{
		button_join_lobby_by_id(player.game.steamIDLobby,index)
	}
}
button_join_lobby_by_id::proc(lobby_id:u64,index:u32=0){
	if cl.UI(cl.ID("button_join_game_by_id",cast(u32)lobby_id+index))(button_dec()) {
		button_txt("Join")
		if cl.Hovered() && s.is_ui_l_click(){
			fmt.print("join lobby button cliciked",lobby_id,"\n")
			steam_join_lobby(lobby_id)
		}
	}
}


all_steame_friends_dec::proc(
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
		transition = cl.TransitionElementConfig{

			handler = cl.EaseOut,
			duration = .2,
			properties = cl.TransitionPropertyFlags{.X,.Y},
			interactionHandling = .AllowInteractionsWhileTransitioningPosition,
			enter = {
				setInitialState = state_slide_in_right,
				trigger = cl.TransitionEnterTriggerType.TriggerOnFirstParentFrame,
			},
			exit = {
				setFinalState = state_slide_in_right,
				// trigger=         .TriggerOnFirstParentFrame,
				// siblingOrdering: TriggerOnFirstParentFrame,
			},

		},
		backgroundColor = background_col if !button_hov else background_huv_col,
		border = cl.BorderElementConfig{
			color = border_col,
			width = cl.BorderWidth{border_size,border_size,border_size,border_size,0}
		},
	}
	return button
}

draw_debug_info::proc(){
	child_gap:=get_ui_child_gap(.normal)

	if cl.UI(cl.ID("Debug_List_outer_box"))({
		layout = { 
			layoutDirection = .TopToBottom,
			sizing = { cl.SizingFit(), cl.SizingGrow() },
			// childGap = child_gap,
			childAlignment= {x = .Left,y= .Top},

		},
		floating =cl.FloatingElementConfig{
			// attachment = {.Root},
			offset = {0,0,},
			attachTo = .Root,
			pointerCaptureMode =cl.PointerCaptureMode.Passthrough,
			attachment= cl.FloatingAttachPoints{
				element = cl.FloatingAttachPointType.CenterTop,
				parent =   cl.FloatingAttachPointType.CenterTop,
			}
		},
		
		// transition = cl.TransitionElementConfig{

		// 	handler = cl.EaseOut,
		// 	duration = .2,
		// 	properties = cl.TransitionPropertyFlags{.X,.Y},
		// 	interactionHandling = .AllowInteractionsWhileTransitioningPosition,
		// 	enter = {
		// 		setInitialState = state_slide_in_right,
		// 		trigger = cl.TransitionEnterTriggerType.TriggerOnFirstParentFrame,
		// 	},
		// 	exit = {
		// 		setFinalState = state_slide_in_right,
		// 		// trigger=         .TriggerOnFirstParentFrame,
		// 		// siblingOrdering: TriggerOnFirstParentFrame,
		// 	},

		// },
		// clip ={
		// 	horizontal=false,
		// 	vertical=true,
		// 	childOffset=cl.GetScrollOffset(),
		// },
		backgroundColor = {0,0,0,0},
		
	}) {
		if s.steam.is_using_steam == true {
			defalt_txt_dynamic("Steam Info __________")
			// defalt_txt_dynamic(fmt.tprint(" Steam_ID: ",s.steam.))
			defalt_txt_dynamic(fmt.tprint(" Lobby_ID: ",s.steam.steam_lobby.lobby_id))	
			defalt_txt_dynamic(fmt.tprint(" Lobby_Size: ",s.steam.steam_lobby.groop.count))	
			defalt_txt_dynamic(fmt.tprint(" Lobby_Owner_id: ",s.steam.steam_lobby.loby_owner_id))	
			defalt_txt_dynamic(fmt.tprint(" Lobby_Owner_Name: ",s.steam.steam_lobby.loby_owner_name))	
		}
	}
}

true_false_button::proc(
	tf:^bool,
	id:u32,

	border_col_id:Color_Types = .border,
	background_col_on_id:Color_Types = .element_active,
	background_col_off_id:Color_Types = .element_background,
	background_huv_col_id:Color_Types = .element_hover,
	
	border_size_id:UI_Size = .normal,
	padding_size_id:UI_Size = .normal,
	child_gap_id:UI_Size = .small,
	roundnes_id:UI_Roundnes = .sharp,

	text_size_id:UI_Size = .small,
	text_col_id:Color_Types = .text,

	style_overide:^UI_Style = nil,
	){
	

	if cl.UI(cl.ID("true_false_button",id))(
		toggle_button_dec(
			tf=tf,
			
			border_col_id=border_col_id,
			background_col_on_id  = background_col_on_id,
			background_col_off_id = background_col_off_id,
			border_size_id = border_size_id,
			padding_size_id = padding_size_id,
			child_gap_id = child_gap_id,
			roundnes_id = roundnes_id,
			
			style_overide = style_overide,
		)
	) {
		is_huvered:=cl.Hovered()
		if is_huvered{
			if is_input_event(.ui_l_c,always_consume_d = true){
				tf^ = !tf^
			}
		}
		if tf^{
			cl.Text("True",text_dec(text_size_id = text_size_id,text_col_id = text_col_id,style_overide=style_overide))
		}else{
			cl.Text("False",text_dec(text_size_id = text_size_id,text_col_id = text_col_id,style_overide=style_overide))
		}
		
	}
}

enum_drop_down_menu::proc(
	enum_any:any,
	// enum_v:rawptr,
	// enum_t:typeid,
	
	id:u32,

	border_col_id:Color_Types = .border,
	background_col_id:Color_Types = .element_background,
	background_huv_col_id:Color_Types = .element_hover,
	
	border_size_id:UI_Size = .normal,
	padding_size_id:UI_Size = .normal,
	child_gap_id:UI_Size = .small,
	roundnes_id:UI_Roundnes = .sharp,

	text_size_id:UI_Size = .small,
	text_col_id:Color_Types = .text,

	style_overide:^UI_Style = nil,
	){
	text_size:=get_ui_text_size(text_size_id)
	huv:bool
	// fmt.print(cl.GetPointerOverIds(),"\n\n\n")
	el_id_enum_drop_down_menu:=cl.ID("enum_drop_down_menu",id)
	el_id_enum_drop_down_menu_options_container:=cl.ID("enum_drop_down_menu_options_container",id)
	if cl.UI(el_id_enum_drop_down_menu)(
		button_dec(
			
			
			border_col_id=border_col_id,
			background_col_id  = background_col_id,
			border_size_id = border_size_id,
			padding_size_id = .small,
			child_gap_id = child_gap_id,
			roundnes_id = roundnes_id,

			layout_direction = .LeftToRight,
			style_overide = style_overide,

		)
	) {

		hovering:=cl.Hovered()
		if hovering {huv = hovering}
		if cl.PointerOver(el_id_enum_drop_down_menu_options_container) {
			huv = true
		}
		type_info:=type_info_of(enum_any.id)
		if reflect.is_enum(type_info){
// reflect.enum_field_names()
			enum_index,ok:=reflect.as_i64(enum_any)
			if ok{
				cl.Text(reflect.enum_field_names(enum_any.id)[enum_index],text_dec(text_size_id = text_size_id,text_col_id = text_col_id,style_overide=style_overide))
				texture:=get_texture_by_id(.Arrows_Pointer_Down_South)
				if huv{texture=get_texture_by_id(.Arrows_Media_Controls_Stop)}
				if cl.UI(cl.ID("enum_drop_down_menu_options_box",id))(defalt_img_box_dec(texture,border_size_id = .non,img_color = .element_selected,padding_size_id = .non,size = .big)){}
			}
		}
		if huv{
			// el_id_drop_contaner:=cl.ID("enum_drop_down_menu_options_container",id)
			data:=cl.GetElementData(el_id_enum_drop_down_menu)
			fmt.print(data.boundingBox.width,"\n")
			if cl.UI(el_id_enum_drop_down_menu_options_container)({
				layout={
					sizing ={
						cl.SizingFit({0,cast(f32)(data.boundingBox.width*3)}),
						cl.SizingFit({0,cast(f32)(data.boundingBox.height*10)}),
					},
					layoutDirection= .TopToBottom
				},
				floating ={
					attachTo = .Parent,
					attachment={.RightTop,.RightBottom}
				}
			}){
				if cl.UI(cl.ID("enum_drop_down_menu_options_box",id))(defalt_box_dec(
					border_col_id=border_col_id,
					background_col_id  = background_col_id,
					border_size_id = border_size_id,
					padding_size_id = padding_size_id,
					child_gap_id = child_gap_id,
					roundnes_id = roundnes_id,
					
					style_overide = style_overide,
					clip = {
						vertical = true,
						childOffset = cl.GetScrollOffset(),
					},
				)){

				
					enum_fields:=reflect.enum_fields_zipped(enum_any.id)
					for field, field_index in enum_fields{
	
						if cl.UI(cl.ID("enum_drop_down_menu_row",cast(u32)field_index))(
							button_dec(
								
								
								border_col_id=border_col_id,
								background_col_id  = background_col_id,
								border_size_id = border_size_id,
								padding_size_id = padding_size_id,
								child_gap_id = child_gap_id,
								roundnes_id = roundnes_id,
								
								style_overide = style_overide,
							)
						) {
							cl.Text(field.name,text_dec(text_size_id = text_size_id,text_col_id = text_col_id,style_overide=style_overide))
							if cl.Hovered(){
								if is_input_event(.ui_l_c,always_consume_d = true){
									enum_v:=enum_fields[field_index].value
									raw_ptr,e_id:=reflect.any_data(enum_any)
									mem.copy(raw_ptr,cast(rawptr)(&enum_v),type_info.size)
								}
							}
						}
					}
				}
			}
		}
		
	}
}
