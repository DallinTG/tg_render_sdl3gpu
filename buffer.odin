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
// import hm "handle_map_static_virtual"
import hm "core:container/handle_map"
import "core:os"
import "base:intrinsics"

import sc"shader_cross"

import "core:image"
import "core:image/jpeg"
import "core:image/bmp"
import "core:image/png"
import "core:image/tga"
import byt"core:bytes"
import "core:io"


Generic_Buffer::struct{
	buffer:byt.Buffer,
	type:Buffer_Types,
}

Buffer_Types::enum{
	dynamic_buff,
	static_buff,
	indirect_cmd_buff,
	no_tranfer_buff,
}

init_buffer::proc(buff:^Generic_Buffer,len:int,size:int,type:Buffer_Types = .dynamic_buff){
	buff.type = type
	byt.buffer_init_allocator(&buff.buffer,len,size)
}

clear_buffer::proc(buff:^Generic_Buffer){
	byt.buffer_reset(&buff.buffer)
}

delete_buffer::proc(buff:^Generic_Buffer){
	byt.buffer_destroy(&buff.buffer)
}

buffer_write_slice::proc(buff:^Generic_Buffer, slice: $S/[]$T, loc := #caller_location)->(n: int, err: io.Error){
	old_cap := cap(buff.buffer.buf)
	n, err = byt.buffer_write_slice(&buff.buffer, slice ,loc)
	if buff.type == .static_buff{
		cap := cap(buff.buffer.buf)
		assert(cap != old_cap, fmt.tprint("atemt to grow static_buff",loc))
	}
	return n, err
}


free_list_alloc :: proc(
	f: ^Free_List,
	count: u32,
) -> (new_range: Free_List_Range, ok: bool) {

	assert(f.size > 0,"free_list is not initialised")
	
	if count == 0 {
		return Free_List_Range{0,0}, false
	}

	for i := 0; i < len(f.ranges); i += 1 {
		range := &f.ranges[i]

		if range.count < count {
			continue
		}

		new_range.start = range.start
		new_range.count = count

		if range.count == count {
			// Entire range was consumed.
			ordered_remove(&f.ranges, i)
		} else {
			// Take from the beginning of the range.
			range.start += count
			range.count -= count
		}


		return new_range, true
	}

	return Free_List_Range{0,0}, false
}

free_list_free :: proc(
    f: ^Free_List,
    range_to_free: Free_List_Range,
    loc:= #caller_location,
) {
    assert(f.size > 0, "free_list is not initialised")
    assert(
        range_to_free.start <= f.size &&
        range_to_free.count <= f.size - range_to_free.start,
        "Free_List: range outside of list",
    )

    if range_to_free.count == 0 {
        return
    }

    new_start := range_to_free.start
    new_end := range_to_free.start + range_to_free.count

    i := 0

    // Find first range that is at or after the range being freed.
    for i < len(f.ranges) && f.ranges[i].start < new_start {
        i += 1
    }

    merged_previous := false

    // Merge with the range before us.
    if i > 0 {
        prev := f.ranges[i-1]

        if prev.start + prev.count > new_start {
            panic("Free_List: double free or overlapping allocation")
        }

        if prev.start + prev.count == new_start {
            new_start = prev.start
            i -= 1
            merged_previous = true
        }
    }

    // If we merged the previous range, start looking after it.
    scan_i := i
    if merged_previous {
        scan_i += 1
    }

    // Merge every adjacent range after us.
    for scan_i < len(f.ranges) {
        next := f.ranges[scan_i]

        if next.start > new_end {
            break
        }

        if next.start < new_end {
            panic("Free_List: double free or overlapping allocation")
        }

        new_end = next.start + next.count
        ordered_remove(&f.ranges, scan_i)
    }

    // If we merged the previous range, replace it.
    if merged_previous {
        f.ranges[i].count = new_end - new_start
    } else {
        inject_at(&f.ranges, i, Free_List_Range{
            start = new_start,
            count = new_end - new_start,
        })
    }
}




Free_List_Range :: struct {
    start: u32,
    count: u32,
}

Free_List :: struct {
    ranges:         [dynamic]Free_List_Range,
    size:           u32,
    last_alloc_end: u32, // Tracks where the last allocation ended
}

free_list_init :: proc(f: ^Free_List, size: u32, allocator := context.allocator) {
    f.size = size
    f.last_alloc_end = 0
    f.ranges = make([dynamic]Free_List_Range, 0, 1, allocator)
    append(&f.ranges, Free_List_Range{
        start = 0,
        count = size,
    })
}

clear_free_list :: proc(f: ^Free_List) {
    f.size = 0
    f.last_alloc_end = 0
    clear(&f.ranges)
}

delete_free_list :: proc(f: ^Free_List) {
    f.size = 0
    f.last_alloc_end = 0
    delete(f.ranges)
}

free_list_space_lef :: proc(f: ^Free_List) -> (space_lef: int) {
    for r in f.ranges {
        space_lef += cast(int)r.count
    }
    return
}
