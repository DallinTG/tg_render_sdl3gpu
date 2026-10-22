package sstring

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
import "core:io"

// len::proc{
// 	ss_len,
// }
// cap::proc{
// 	ss_cap,
// }


SString_4::SString(4)//u32
SString_8::SString(8)//u64
SString_16::SString(16)//u128
SString_32::SString(32)//u256
SString::struct(Size:u8){
	// len:u8,
	buf:[dynamic;Size]byte,
}

get_builder::proc(sstring:^SString($Size))->(builder:str.Builder){
	return builder_from_bytes_keep_data(sstring.buf[:],sstring.len)
}


//this is just a cast to a string { cast(string)sstring.buf } yup that is it
ss_get::proc(sstring:^SString($size))->(s:string){
	return string(sstring.buf[:])
	
}

ss_set_by_string::proc(sstring:^SString($Size),s:string){
	min:=min(cap(sstring.buf),len(s))
	// sstring.len = cast(u8)min
	copy_from_string(sstring.buf[:],s[:min])
}
ss_cap::proc(sstring:SString($Size))->(int){
	return Size
}
ss_len::proc(sstring:SString($Size))->(int){
	return len(sstring.buf)
}
ss_pop::proc(sstring:^SString($Size)){
	pop(sstring.buf)
}
ss_clear::proc(sstring:^SString($Size)){
	clear(sstring.buf)
}
ss_append_byte::proc(sstring:^SString($Size),b:byte)->(ok:bool){
	if sstring.len > size{
		sstring.len += 1
		sstring[sstring.len] = b
		return true
	}
	return false
}

ss_write_bytes :: proc(sstring:^SString($Size), x: []byte) -> (n: int) {
	n0 := len(sstring.buf)
	append_fixed_capacity_elems(&sstring.buf, ..x,)
	n1 := len(sstring.buf)
	return n1-n0
}

ss_append_write_rune :: proc(sstring:^SString($Size), r: rune) -> (res: int, err: io.Error) {
	return io.write_rune(to_writer(sstring), r)
}

ss_append_string::proc(sstring:^SString($Size),s:string)->(res: int, err: io.Error){
	n0 := len(sstring.buf)
	append(&sstring.buf, s, loc)
	n1 := len(sstring.buf)
	return n1-n0
}


space::proc(sstring:SString($Size)) -> (space:int){
	return cap(sstring.buf) - len(sstring.buf)
}

clone_to_cstring::proc(sstring:^SString($Size), allocator := context.allocator, loc := #caller_location) -> (res: cstring, err: runtime.Allocator_Error) #optional_allocator_error {
	return str.clone_to_cstring(cast(string)sstring.buf,allocator,loc)
}

// END_ON_TEST::true
// run_sstring_test::proc(){
// 	temp:[dynamic;5]int
// 	temp_1:=temp[:]
// 	waf:SString_8
// 	log.log(.Warning,waf,len(waf.buf))
// 	fmt.print(waf,"\n")
// 	ss_set_by_string(&waf,"waffdddd8")
// 	log.log(.Warning,waf,space(waf))
// 	log.log(.Warning,ss_get(&waf),"\n\n")
// 	fmt.print(waf,ss_get(&waf),len(waf.buf),"\n")
// 	asdas:=to_stream(&waf)
// 	assert(!END_ON_TEST)
// }


builder_from_bytes_keep_data :: proc(backing: []byte,l:int) -> (res: str.Builder) {
	return str.Builder{
		buf = transmute([dynamic]byte)runtime.Raw_Dynamic_Array{
			data      = raw_data(backing),
			len       = l,
			cap       = len(backing),
			allocator = runtime.Allocator{
				procedure = runtime.nil_allocator_proc,
				data = nil,
			},
		},
	}
}


to_stream :: proc(sstring: ^SString($Size)) -> (res: io.Stream) {

	when Size == 4 {
		res = io.Stream{procedure = _sstring_stream_proc_4, data = rawptr(sstring)}
	} else when Size == 8 {
		res = io.Stream{procedure = _sstring_stream_proc_8, data = rawptr(sstring)}
	} else when Size == 16 {
		res = io.Stream{procedure = _sstring_stream_proc_16, data = rawptr(sstring)}
	} else when Size == 32 {
		res = io.Stream{procedure = _sstring_stream_proc_32, data = rawptr(sstring)}
	} else {
		assert(false, "Unsupported SString size")
	}
	return 
}
to_writer :: proc(sstring: ^SString($Size)) -> (res: io.Writer) {
	return io.to_writer(to_stream(b))
}

sstring_stream_data::struct{

}



_sstring_stream_proc_4 :: proc(stream_data: rawptr, mode: io.Stream_Mode, p: []byte, offset: i64, whence: io.Seek_From) -> (n: i64, err: io.Error) {
	b := (^SString(4))(stream_data)
	#partial switch mode {
	case .Write:
		n = i64(ss_write_bytes(b, p))
		if n < i64(len(p)) {
			err = .EOF
		}
		return
	case .Size:
		n = i64(len(b.buf))
		return
	case .Destroy:
		assert(true, "this should never hapen")

		return
	case .Query:
		return io.query_utility({.Write, .Size, .Destroy, .Query})
	}
	return 0, .Unsupported
}

_sstring_stream_proc_8 :: proc(stream_data: rawptr, mode: io.Stream_Mode, p: []byte, offset: i64, whence: io.Seek_From) -> (n: i64, err: io.Error) {
	b := (^SString(8))(stream_data)
	#partial switch mode {
	case .Write:
		n = i64(ss_write_bytes(b, p))
		if n < i64(len(p)) {
			err = .EOF
		}
		return
	case .Size:
		n = i64(len(b.buf))
		return
	case .Destroy:
		assert(true, "this should never hapen")

		return
	case .Query:
		return io.query_utility({.Write, .Size, .Destroy, .Query})
	}
	return 0, .Unsupported
}

_sstring_stream_proc_16 :: proc(stream_data: rawptr, mode: io.Stream_Mode, p: []byte, offset: i64, whence: io.Seek_From) -> (n: i64, err: io.Error) {
	b := (^SString(16))(stream_data)
	#partial switch mode {
	case .Write:
		n = i64(ss_write_bytes(b, p))
		if n < i64(len(p)) {
			err = .EOF
		}
		return
	case .Size:
		n = i64(len(b.buf))
		return
	case .Destroy:
		assert(true, "this should never hapen")

		return
	case .Query:
		return io.query_utility({.Write, .Size, .Destroy, .Query})
	}
	return 0, .Unsupported
}

_sstring_stream_proc_32 :: proc(stream_data: rawptr, mode: io.Stream_Mode, p: []byte, offset: i64, whence: io.Seek_From) -> (n: i64, err: io.Error) {
	b := (^SString(32))(stream_data)
	#partial switch mode {
	case .Write:
		n = i64(ss_write_bytes(b, p))
		if n < i64(len(p)) {
			err = .EOF
		}
		return
	case .Size:
		n = i64(len(b.buf))
		return
	case .Destroy:
		assert(true, "this should never hapen")

		return
	case .Query:
		return io.query_utility({.Write, .Size, .Destroy, .Query})
	}
	return 0, .Unsupported
}
