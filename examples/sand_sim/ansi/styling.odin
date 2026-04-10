package simp_ansi

import "core:fmt"
import str"core:strings"

ESC :: "\033["
RESET :: ESC + "0m"

BLACK :: ESC + "30m"
RED :: ESC + "31m"
GREEN :: ESC + "32m"
YELLOW :: ESC + "33m"
BLUE :: ESC + "34m"
MAGENTA :: ESC + "35m"
CYAN :: ESC + "36m"
WHITE :: ESC + "37m"

BR_BLACK :: ESC + "90m"
BR_RED :: ESC + "91m"
BR_GREEN :: ESC + "92m"
BR_YELLOW :: ESC + "93m"
BR_BLUE :: ESC + "94m"
BR_MAGENTA :: ESC + "95m"
BR_CYAN :: ESC + "96m"
BR_WHITE :: ESC + "97m"

ANSI_Color::enum{
	no_color,
	black ,
	red ,
	green ,
	yellow ,
	blue ,
	magenta ,
	cyan ,
	white ,
	
	br_black ,
	br_red ,
	br_green ,
	br_yellow ,
	br_blue ,
	br_magenta ,
	br_cyan ,
	br_white ,
}
color::proc(code:ANSI_Color)->(color:string){
	switch code {
	case .no_color:
	case .black: color = BLACK
	case .red: color = RED
	case .green: color = GREEN
	case .yellow: color = YELLOW
	case .blue: color = BLUE
	case .magenta: color = MAGENTA
	case .cyan: color = CYAN
	case .white: color = WHITE
	
	case .br_black: color = BR_BLACK
	case .br_red: color = BR_RED
	case .br_green: color = BR_GREEN
	case .br_yellow: color = BR_YELLOW
	case .br_blue: color = BR_BLUE
	case .br_magenta: color = BR_MAGENTA
	case .br_cyan: color = BR_CYAN
	case .br_white: color = BR_WHITE
	}
	return
}

//_____________________________________________________

BG_BLACK :: ESC + "40m"
BG_RED :: ESC + "41m"
BG_GREEN :: ESC + "42m"
BG_YELLOW :: ESC + "43m"
BG_BLUE :: ESC + "44m"
BG_MAGENTA :: ESC + "45m"
BG_CYAN :: ESC + "46m"
BG_WHITE :: ESC + "47m"

BG_BR_BLACK :: ESC + "100m"
BG_BR_RED :: ESC + "101m"
BG_BR_GREEN :: ESC + "102m"
BG_BR_YELLOW :: ESC + "103m"
BG_BR_BLUE :: ESC + "104m"
BG_BR_MAGENTA :: ESC + "105m"
BG_BR_CYAN :: ESC + "106m"
BG_BR_WHITE :: ESC + "107m"

ANSI_Background_Color::enum{
	no_bg_color,
	black ,
	red ,
	green ,
	yellow ,
	blue ,
	magenta ,
	cyan ,
	white ,
	
	// br == bright vertions of the color
	black_br ,
	red_br ,
	green_br ,
	yellow_br ,
	blue_br ,
	magenta_br ,
	cyan_br ,
	white_br ,
}
background_color::proc(code:ANSI_Background_Color)->(color:string){
	switch code {
	case .no_bg_color:
	case .black: color = BG_BLACK
	case .red: color = BG_RED
	case .green: color = BG_GREEN
	case .yellow: color = BG_YELLOW
	case .blue: color = BG_BLUE
	case .magenta: color = BG_MAGENTA
	case .cyan: color = BG_CYAN
	case .white: color = BG_WHITE
	
	case .black_br: color = BG_BR_BLACK
	case .red_br: color = BG_BR_RED
	case .green_br: color = BG_BR_GREEN
	case .yellow_br: color = BG_BR_YELLOW
	case .blue_br: color = BG_BR_BLUE
	case .magenta_br: color = BG_BR_MAGENTA
	case .cyan_br: color = BG_BR_CYAN
	case .white_br: color = BG_BR_WHITE
	}
	return
}

BOLD :: ESC + "1m"
DIM :: ESC + "2m"
ITALIC :: ESC + "3m"
UNDERLINE :: ESC + "4m"
BLINKING :: ESC + "5m"
INVERSE :: ESC + "7m"
HIDDEN :: ESC + "8m"
STRIKETHROUGH :: ESC + "9m"

ANSI_Styles::enum{
	no_styles,
	bold ,
	dim ,
	italic ,
	underline ,
	blinking ,
	inverse ,
	hidden ,
	strikethrough ,
}

styles::proc(code:ANSI_Styles)->(styles:string){
	switch code {
	case .no_styles:
	case .bold: styles = BOLD
	case .dim: styles = DIM
	case .italic: styles = ITALIC
	case .underline: styles = UNDERLINE
	case .blinking: styles = BLINKING
	case .inverse: styles = INVERSE
	case .hidden: styles = HIDDEN
	case .strikethrough: styles = STRIKETHROUGH
	}
	return
}

// Style resets

BOLD_RESET :: ESC + "22m"
DIM_RESET :: ESC + "22m"
ITALIC_RESET :: ESC + "23m"
UNDERLINE_RESET :: ESC + "24m"
BLINKING_RESET :: ESC + "25m"
INVERSE_RESET :: ESC + "27m"
HIDDEN_RESET :: ESC + "28m"
STRIKETHROUGH_RESET :: ESC + "29m"

ANSI_Resets::enum{
	reset,
	no_reset,
	bold,
	dim,
	italic,
	underline,
	blinking,
	inverse,
	hidden,
	strikethrough,
}

reset::proc(code:ANSI_Resets)->(styles:string){
	switch code {
	case .reset: styles = RESET
	case .no_reset:
	case .bold: styles = BOLD_RESET
	case .dim: styles = DIM_RESET
	case .italic: styles = ITALIC_RESET
	case .underline: styles = UNDERLINE_RESET
	case .blinking: styles = BLINKING_RESET
	case .inverse: styles = INVERSE_RESET
	case .hidden: styles = HIDDEN_RESET
	case .strikethrough: styles = STRIKETHROUGH_RESET
	}
	return
}


ansy::proc(
	input:string,
	col:ANSI_Color = .no_color,
	bg_col:ANSI_Background_Color = .no_bg_color,
	sty:bit_set[ANSI_Styles] = {.no_styles},
	res:bit_set[ANSI_Resets] = {.reset},
	allocator := context.allocator
) ->(out:string){

	all_styles:string
	all_reset:string
	defer delete(all_reset)
	defer delete(all_styles)
	if res == nil{
		all_reset = str.clone(RESET)
	}
	for s in sty{
		all_styles = str.concatenate({all_styles,styles(s)})
	}
	for r in res{
		all_reset = str.concatenate({all_reset,reset(r)})
	}
	out= str.concatenate({color(col), background_color(bg_col), all_styles, input, all_reset,}, allocator)
	return
}

//uses the tep alocator
ansy_t::proc(
	input:string,
	col:ANSI_Color = .no_color,
	bg_col:ANSI_Background_Color = .no_bg_color,
	sty:bit_set[ANSI_Styles] = {.no_styles},
	res:bit_set[ANSI_Resets] = {.reset},
) ->(out:string){
	return ansy(input, col , bg_col, sty, res,context.temp_allocator)
}
