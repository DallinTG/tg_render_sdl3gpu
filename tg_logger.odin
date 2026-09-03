package tg_render

import "vendor:stb/truetype"

import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import "core:strings"
// import hm "handle_map_static_virtual"
import hm "core:container/handle_map"
import "core:time"
import lin"core:math/linalg"
import cl"clay-odin"
import "core:encoding/json"
import "core:os"
import "core:strconv"
import steam "steamworks"
import sdl3i"vendor:sdl3/image"
import "core:sort"
import "core:slice"
import "base:runtime"

@(private) global_subtract_stdout_options: log.Options
@(private) global_subtract_stderr_options: log.Options

@(private)
thread_name:map[int]string

name_thread::proc(name:string){
	thread_name[os.get_current_thread_id()] = name
}

create_tg_console_logger :: proc(lowest := log.Level.Debug, opt := log.Default_Console_Logger_Opts, ident := "", allocator := context.allocator) -> log.Logger {
	data := new(log.File_Console_Logger_Data, allocator)
	data.file_handle = nil
	data.ident = ident
	return log.Logger{tg_console_logger_proc, data, lowest, opt}
}

tg_console_logger_proc :: proc(logger_data: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) {
	options := options
	data := cast(^log.File_Console_Logger_Data)logger_data
	h: ^os.File = nil
	if level < log.Level.Error {
		h = os.stdout
		options -= global_subtract_stdout_options
	} else {
		h = os.stderr
		options -= global_subtract_stderr_options
	}
	_file_tg_console_logger_proc(h, data.ident, level, text, options, location)
}

_file_tg_console_logger_proc :: proc(h: ^os.File, ident: string, level: log.Level, text: string, options: log.Options, location: runtime.Source_Code_Location) {
	backing: [1024]byte //NOTE(Hoej): 1024 might be too much for a header backing, unless somebody has really long paths.
	buf := strings.builder_from_bytes(backing[:])

	log.do_level_header(options, &buf, level)

	when time.IS_SUPPORTED {
		log.do_time_header(options, &buf, time.now())
	}

	log.do_location_header(options, &buf, location)

	if .Thread_Id in options {
		th_id:=os.get_current_thread_id()
		name, ok := thread_name[th_id]
		if ok{
			fmt.sbprintf(&buf, "[{}] ", name)
		}else{
			fmt.sbprintf(&buf, "[{}] ", th_id)
		}
	}

	if ident != "" {
		fmt.sbprintf(&buf, "[%s] ", ident)
	}
	//TODO(Hoej): When we have better atomics and such, make this thread-safe
	fmt.fprintf(h, "%s%s\n", strings.to_string(buf), text)
}
