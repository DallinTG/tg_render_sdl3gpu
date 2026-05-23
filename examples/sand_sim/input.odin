package sand_sim

import tg"../../../tg_render_sdl3gpu"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import hm "../../handle_map_static_virtual"
import an"../../ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"


event_data::struct{
	// q:[dynamic]input_data,
	list:[input_e_id]input_event_data,

	key:#sparse[sdl.Scancode]input_data,
	key_p:#sparse[sdl.Scancode]bool,
	key_d:#sparse[sdl.Scancode]bool,
	key_r:#sparse[sdl.Scancode]bool,

	mouse:[sdl.MouseButtonFlag]input_data,
	mouse_p:[sdl.MouseButtonFlag]bool,
	mouse_d:[sdl.MouseButtonFlag]bool,
	mouse_r:[sdl.MouseButtonFlag]bool,

	mouse_pos:[2]f32,
	mouse_move:[2]f32,
	mouse_wheel:[2]i32,

}
input_id::union{
	sdl.Scancode,
	sdl.MouseButtonFlag,
}

input_data::struct{
    id:input_id,
    pressed:bool,
    down:bool,
    released:bool,
   

}
input_e_id::enum{
    ui_debug,
    ui_l_c,
    ui_l_c_d,
    ui_r_c,
    ui_m_c,
    ui_shift,
    ui_drag_l_c,
    ui_esc,
    ui_tab,
    ui_del,
    ui_back_space,
    ui_a_up,
    ui_a_down,
    ui_a_left,
    ui_a_right,
    ui_enter,
    ui_coppy,
    ui_cut,
    ui_past,
    ui_t_select_left,
    ui_t_select_right,
    ui_t_select_up,
    ui_t_select_down,
    ui_t_select_all,
    ui_move_lin_up,
    enter,
    pan_cam,
    jump,
    move_l,
    move_r,
    move_d,
    move_u,
    alt_fire,
    fire,
    alt_fire_p,
    fire_p,
    test,
    
}
input_event_data::struct{
    input:[max_key_combo]struct{
        data:input_data,
        // is_consumed:bool,
        consum_press:bool,
        consum_down:bool,
    }
}
max_key_combo::4
reg_input_events::proc(){
	reg_event(.move_l,{{{data=             {id= sdl.Scancode.A,               pressed= false,down= true, released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
	reg_event(.move_r,{{{data=             {id= sdl.Scancode.D,               pressed= false,down= true, released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.jump,{{{data=               {id= sdl.Scancode.SPACE,           pressed= true ,down= false, released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_debug,{{{data=           {id= sdl.Scancode.F10,             pressed= true ,down= false, released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_l_c,{{{data=             {id= sdl.MouseButtonFlag.LEFT,     pressed= true ,down= false, released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_l_c_d,{{{data=           {id= sdl.MouseButtonFlag.LEFT,     pressed= false,down= true, released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.fire,{{{data=               {id= sdl.MouseButtonFlag.LEFT,     pressed= false,down= true, released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.alt_fire,{{{data=           {id= sdl.MouseButtonFlag.RIGHT,    pressed= false,down= true, released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.fire_p,{{{data=             {id= sdl.MouseButtonFlag.LEFT,     pressed= true ,down= false, released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.alt_fire_p,{{{data=         {id= sdl.MouseButtonFlag.RIGHT,    pressed= true ,down= false, released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_r_c,{{{data=             {id= sdl.MouseButtonFlag.RIGHT,    pressed= true ,down= false, released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_m_c,{{{data=             {id= sdl.MouseButtonFlag.MIDDLE,   pressed= true ,down= false, released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.test,{{{data=               {id= sdl.Scancode.LSHIFT,          pressed= false,down= true , released= false}, consum_press= true , consum_down= true ,},{data=        {id= sdl.Scancode.SPACE, pressed= true,down= false, released= false}, consum_press= true, consum_down= true,},{},{}}})
    reg_event(.pan_cam,{{{data=            {id= sdl.MouseButtonFlag.RIGHT,    pressed= false,down= true , released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_drag_l_c,{{{data=        {id= sdl.MouseButtonFlag.LEFT,     pressed= false,down= true , released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_shift,{{{data=           {id= sdl.Scancode.LSHIFT,          pressed= false,down= true , released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_tab,{{{data=             {id= sdl.Scancode.TAB,             pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_esc,{{{data=             {id= sdl.Scancode.ESCAPE,          pressed= true ,down= false, released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_back_space,{{{data=      {id= sdl.Scancode.BACKSPACE,       pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_del,{{{data=             {id= sdl.Scancode.DELETE,          pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_a_down,{{{data=          {id= sdl.Scancode.DOWN,            pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_a_up,{{{data=            {id= sdl.Scancode.UP,              pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_a_left,{{{data=          {id= sdl.Scancode.LEFT,            pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_a_right,{{{data=         {id= sdl.Scancode.RIGHT,           pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_enter,{{{data=           {id= sdl.Scancode.RETURN,          pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
    reg_event(.ui_coppy,{{{data=           {id= sdl.Scancode.LCTRL,           pressed= false,down= true , released= false}, consum_press= true , consum_down= true ,},{data=       {id= sdl.Scancode.C,    pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{}}})
    reg_event(.ui_past,{{{data=            {id= sdl.Scancode.LCTRL,           pressed= false,down= true , released= false}, consum_press= true , consum_down= true ,},{data=       {id= sdl.Scancode.V,    pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{}}})
    reg_event(.ui_cut,{{{data=             {id= sdl.Scancode.LCTRL,           pressed= false,down= true , released= false}, consum_press= true , consum_down= true ,},{data=       {id= sdl.Scancode.X,    pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{}}})
    reg_event(.ui_t_select_left,{{{data=   {id= sdl.Scancode.LSHIFT,          pressed= false,down= true , released= false}, consum_press= true , consum_down= true ,},{data=       {id= sdl.Scancode.LEFT, pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{}}})
    reg_event(.ui_t_select_right,{{{data=  {id= sdl.Scancode.LSHIFT,          pressed= false,down= true , released= false}, consum_press= true , consum_down= true ,},{data=       {id= sdl.Scancode.RIGHT,pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{}}})
    reg_event(.ui_t_select_up,{{{data=     {id= sdl.Scancode.LSHIFT,          pressed= false,down= true , released= false}, consum_press= true , consum_down= true ,},{data=       {id= sdl.Scancode.UP,   pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{}}})
    reg_event(.ui_t_select_down,{{{data=   {id= sdl.Scancode.LSHIFT,          pressed= false,down= true , released= false}, consum_press= true , consum_down= true ,},{data=       {id= sdl.Scancode.DOWN, pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{}}})
    reg_event(.ui_t_select_all,{{{data=    {id= sdl.Scancode.LCTRL,           pressed= false,down= true , released= false}, consum_press= true , consum_down= true ,},{data=       {id= sdl.Scancode.A,    pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{}}})
    reg_event(.ui_move_lin_up,{{{data=     {id= sdl.Scancode.LCTRL,           pressed= false,down= true , released= false}, consum_press= true , consum_down= true ,},{data=       {id= sdl.Scancode.UP,   pressed= true ,down= true , released= false}, consum_press= true , consum_down= true ,},{},{}}})
    reg_event(.enter,{{{data=              {id= sdl.Scancode.RETURN,          pressed= true ,down= false, released= false}, consum_press= true , consum_down= true ,},{},{},{}}})
}
reg_event::proc(i_event:input_e_id,i_e_data:input_event_data){
    g.input_events.list[i_event] = i_e_data
}

is_input_event::proc(
    input_id        :input_e_id,
    always_consume_p:bool=false,
    always_consume_d:bool=false,
    never_consume_p :bool=false,
    never_consume_d :bool=false,
    require_p       :bool=false,
    require_d       :bool=false,
    require_r       :bool=false,
    ignore_p        :bool=false,
    ignore_d        :bool=false,
    ignore_r        :bool=false,
)->(ev:bool,){
    i_e_data:=&g.input_events.list[input_id].input
    is_good:[max_key_combo]bool
    ref:[4]^input_data
    // for &event in &g.input_events.q {
        for i in 0..<max_key_combo{
            if i_e_data[i].data.id == nil &&i!=0{
                // ref[i]= &event
                is_good[i]=true
            // }else if i_e_data[i].data.id == event.id{
            }else{

                // ref[i]= &event
                ref[i]= get_input_event_data(i_e_data[i].data.id)
                is_good[i]=true
                if !ignore_p {if i_e_data[i].data.pressed  || require_p { if !ref[i].pressed   {is_good[i] = false}}}
                if !ignore_d {if i_e_data[i].data.down     || require_d { if !ref[i].down      {is_good[i] = false}}}
                if !ignore_r {if i_e_data[i].data.released || require_r { if !ref[i].released  {is_good[i] = false}}}

            } 
        }
    // }
	if is_good=={true,true,true,true}{
		for i in 0..<max_key_combo{
			if ref[i] != nil{
				if !never_consume_p{ if i_e_data[i].consum_press || always_consume_p{ref[i].pressed = false}}   
				if !never_consume_d{ if i_e_data[i].consum_down  || always_consume_d{ref[i].down    = false}}   
			}
		}
		ev= true
	}
	return
}

get_input_event_data::proc(id:input_id)->(data:^input_data){
	switch t_id in id {
	case sdl.Scancode:
		data = &g.input_events.key[t_id]
	case sdl.MouseButtonFlag:
		data = &g.input_events.mouse[t_id]
	}
	return
}

gather_input_info::proc(){//triger this as fast as the game will run
	add_input_to_event_q()
	update_input_q()
	
	add_input_to_event_q::proc(){
		t_input_data:input_data
		for &e in &s.events {
			t_input_data = {}
			#partial switch e.type{
			
				case .KEY_DOWN:
					g.input_events.key_p[e.key.scancode] = true
					g.input_events.key_d[e.key.scancode] = true
					fmt.println("KEY:", e.key.scancode, e.key.key)
				case .KEY_UP:
					g.input_events.key_r[e.key.scancode] = true
				case .MOUSE_BUTTON_DOWN:
		
					g.input_events.mouse_p[cast(sdl.MouseButtonFlag)(e.button.button - 1)] = true
					g.input_events.mouse_d[cast(sdl.MouseButtonFlag)(e.button.button - 1)] = true
					
				case .MOUSE_BUTTON_UP:

					g.input_events.mouse_r[cast(sdl.MouseButtonFlag)(e.button.button - 1)] = true
	
				case .MOUSE_WHEEL:
					g.input_events.mouse_wheel += {e.wheel.integer_x,e.wheel.integer_y}
	
				case .MOUSE_MOTION:
					g.input_events.mouse_pos = {e.motion.x,e.motion.y}
					g.input_events.mouse_move += {e.motion.xrel,e.motion.yrel}
			}
			if t_input_data.id != nil{
				// append(&g.input_events.q,t_input_data) 
			}
		}  
	}

	update_input_q::proc(){
		for &key ,e in &g.input_events.key{
			key.pressed = g.input_events.key_p[e]
			key.down = g.input_events.key_d[e]
			key.released = g.input_events.key_r[e]
		}
		for &mouse ,e in &g.input_events.mouse{
			mouse.pressed = g.input_events.mouse_p[e]
			mouse.down = g.input_events.mouse_d[e]
			mouse.released = g.input_events.mouse_r[e]
		}
	}
}

maintain_input_info::proc(){// only triger this on tickes that use input if trigered faser then the inputs are used you may be mising inputs
	maintain_input_q()
	maintain_input_q::proc(){
		for key_r , e in g.input_events.key_r{
			if key_r == true{g.input_events.key_d[e] = false}
		}
		g.input_events.key_p = {}
		g.input_events.key_r = {}

		for mouse_r , e in g.input_events.mouse_r{
			if mouse_r == true{g.input_events.mouse_d[e] = false}
		}
		g.input_events.mouse_p = {}
		g.input_events.mouse_r = {}

		g.input_events.mouse_move = {}
		g.input_events.mouse_wheel = {}
	}

}
