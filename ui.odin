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
		
		border:f32,
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
		backgroundColor = s.ui_style.col.element_active if button_hov else s.ui_style.col.element_background,
		border = cl.BorderElementConfig{color = s.ui_style.col.border, width = cl.BorderWidth{3,3,3,3,6}},
	}
	return button
}

button_txt::proc($text:string, ){
	cl.Text(
		text,
		cl.TextConfig(cl.TextElementConfig{
			textColor = s.ui_style.col.text,
			fontSize = cast(u16)s.ui_style.siz.txt_h2
		}),
	)
}
button_txt_dynamic::proc(text:string, ){
	cl.TextDynamic(
		text,
		cl.TextConfig(cl.TextElementConfig{
			textColor = s.ui_style.col.text,
			fontSize = cast(u16)s.ui_style.siz.txt_h2
		}),
	)
}

notification_dec::proc()->(button:cl.ElementDeclaration){
	button_hov:=cl.Hovered()
	button = cl.ElementDeclaration{
		layout = {
				layoutDirection = .TopToBottom,
				sizing = { cl.SizingPercent(.20), cl.SizingFit() },
				childAlignment = cl.ChildAlignment{x=.Center,y=.Center},
				padding = {},
				// childGap = 30,
			},
		backgroundColor = s.ui_style.col.element_background if !button_hov else s.ui_style.col.element_hover,
		border = cl.BorderElementConfig{color = s.ui_style.col.border, width = cl.BorderWidth{3,3,3,3,0}},
	}
	return button
}
notification_progress_bar::proc(persent:f32){

	if cl.UI(cl.ID("notification_progress_bar"))({
		layout = { layoutDirection = .TopToBottom, 
		sizing = { cl.SizingPercent(persent), cl.SizingFixed(5) } },
		border={width = {0,0,0,0,0}},
		backgroundColor = s.ui_style.col.ansi_bright_cyan,
	}) {

	}
}

notification_txt::proc($text:string, ){
	cl.Text(
		text,
		cl.TextConfig(cl.TextElementConfig{
			textColor = s.ui_style.col.txt_main,
			fontSize = cast(u16)s.ui_style.siz.txt
		}),
	)
}
notification_txt_dynamic::proc(text:string, ){
	cl.TextDynamic(
		text,
		cl.TextConfig(cl.TextElementConfig{
			textColor = s.ui_style.col.text,
			fontSize = cast(u16)s.ui_style.siz.txt
		}),
	)
}

ui_l_click::proc()->(click:bool){
	click = s.input.mouse_button_down[.LEFT]
	return
}

MAX_NUMBER_OF_NOTIFICATION::100
Notification_Buffer::struct{
	notifications:[dynamic;MAX_NUMBER_OF_NOTIFICATION]Notification
}
Notification::struct{
	max_time:f64,
	time_left:f64,
	mesg_1:string,
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
draw_notification_buffer::proc(buff:^Notification_Buffer){
	if cl.UI(cl.ID("Notification_List"))({
		layout = { 
			layoutDirection = .TopToBottom,
			sizing = { cl.SizingGrow(), cl.SizingGrow() },
			childGap = 50,
		},
		backgroundColor = {0,0,0,0},
		
	}) {
		for &notif,i in &buff.notifications{
			if cl.UI(cl.ID("Notification_Box"))(notification_dec()) {
				notification_txt_dynamic(notif.mesg_1)
				notification_progress_bar(cast(f32)(notif.time_left/notif.max_time))
			}
		}
	}
}
send_notification::proc(buff:^Notification_Buffer,mesg:string,time:f64=5){
	if len(buff.notifications) <MAX_NUMBER_OF_NOTIFICATION{
		append(&buff.notifications,Notification{max_time=time,time_left = time,mesg_1=mesg})
	}
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
