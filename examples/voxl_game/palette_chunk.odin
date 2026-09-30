package voxl_game

import "base:runtime"

import "core:time"
import tg"../../../tg_render_sdl3gpu"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:math"
import "core:math/rand"
import "core:hash"
import "core:c"
import "core:fmt"
import "core:thread"
// import hm "../../handle_map_static_virtual"
import hm "core:container/handle_map"
import "core:container/xar"
import an"../../ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"
import st"core:strings"
import steam "../../steamworks"
import reg "../../registry"
import atom "core:sync"
import nos "core:math/noise"

Palette_Sizes::enum u8{
	u0,
	u1,
	u2,
	u4,
	u8,
	u16,
}
Palette_Info::struct{
	bits_per_vox:int,
	bits_per_chunk:int,
	bytes_per_chunk:int,
	max_pal_size:int,
	u32_per_chunk:int,
	index_shift:u8,
	shift:u8,
	mask:u32,
	field_mask:u16,
	fill_mask:u32,

}
@(rodata)PAL_INFO:=PALETTES_INFO

PALETTES_INFO:[Palette_Sizes]Palette_Info:{
	.u0 = {
		bits_per_vox = 0,
		bits_per_chunk = 0,
		bytes_per_chunk = 0,
		u32_per_chunk = 0,
		max_pal_size = 1,
		index_shift=0,
		shift=0,
		field_mask=0,
		mask=0,
		fill_mask = 0
	},
	.u1 = {
		bits_per_vox = 1,
		bits_per_chunk = 1 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE,
		bytes_per_chunk = 1 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8,
		u32_per_chunk = 1 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/32,
		max_pal_size = 2,
		index_shift=5,
		shift=0,
		field_mask=31,
		mask=1,
		fill_mask=0xFFFFFFFF,
	},
	.u2 = {
		bits_per_vox = 2,
		bits_per_chunk = 2 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE,
		bytes_per_chunk = 2 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8,
		u32_per_chunk = 2 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/32,
		max_pal_size = 4,
		index_shift=4,
		shift=1,
		field_mask=15,
		mask=3,
		fill_mask=0x55555555,
	},
	.u4 = {
		bits_per_vox = 4,
		bits_per_chunk = 4 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE,
		bytes_per_chunk = 4 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8,
		u32_per_chunk = 4 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/32,
		max_pal_size = 16,
		index_shift=3,
		shift=2,
		field_mask=7,
		mask=15,
		fill_mask=0x11111111,
	},
	.u8 = {
		bits_per_vox = 8,
		bits_per_chunk = 8 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE,
		bytes_per_chunk = 8 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8,
		u32_per_chunk = 8 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/32,
		max_pal_size = 256,
		index_shift=2,
		shift=3,
		field_mask=3,
		mask=255,
		fill_mask=0x01010101,
	},
	.u16 = {
		bits_per_vox = 16,
		bits_per_chunk = 16 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE,
		bytes_per_chunk = 16 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8,
		u32_per_chunk = 16 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/32,
		max_pal_size = CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE,
		index_shift=1,
		shift=4,
		field_mask=1,
		mask=65535,
		fill_mask=0x00010001,
	},
}

//this is a groop of maps that can store vox data in difrent sizing formats
Backing_Vox_World_Data::struct{
	u0_chunk_data:	U0_Backing_Chunk_Data_HM,
	u1_chunk_data:	U1_Backing_Chunk_Data_HM,
	u2_chunk_data:	U2_Backing_Chunk_Data_HM,
	u4_chunk_data:	U4_Backing_Chunk_Data_HM,
	u8_chunk_data:	U8_Backing_Chunk_Data_HM,
	u16_chunk_data:	U16_Backing_Chunk_Data_HM,
}

Palette_Data::struct{
	item:Item_HD,
	count:u16,
	is_solid:bool,
	is_opaque:bool,
	is_occupied:bool,
}

Backing_Vox_Chunk_Data_HD::distinct hm.Handle64

U0_Chunk_Data::	struct{handle:Backing_Vox_Chunk_Data_HD,pal:[PALETTES_INFO[.u0].max_pal_size]	Palette_Data, pal_count:u16,}
U1_Chunk_Data::	struct{handle:Backing_Vox_Chunk_Data_HD,pal:[PALETTES_INFO[.u1].max_pal_size]	Palette_Data, pal_count:u16,data:[PALETTES_INFO[.u1].u32_per_chunk]u32,}
U2_Chunk_Data::	struct{handle:Backing_Vox_Chunk_Data_HD,pal:[PALETTES_INFO[.u2].max_pal_size]	Palette_Data, pal_count:u16,data:[PALETTES_INFO[.u2].u32_per_chunk]u32,}
U4_Chunk_Data::	struct{handle:Backing_Vox_Chunk_Data_HD,pal:[PALETTES_INFO[.u4].max_pal_size]	Palette_Data, pal_count:u16,data:[PALETTES_INFO[.u4].u32_per_chunk]u32,}
U8_Chunk_Data::	struct{handle:Backing_Vox_Chunk_Data_HD,pal:[PALETTES_INFO[.u8].max_pal_size]	Palette_Data, pal_count:u16,data:[PALETTES_INFO[.u8].u32_per_chunk]u32,}
U16_Chunk_Data::struct{handle:Backing_Vox_Chunk_Data_HD,pal:[PALETTES_INFO[.u16].max_pal_size]	Palette_Data, pal_count:u16,data:[PALETTES_INFO[.u16].u32_per_chunk]u32,}

U0_Backing_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U0_Chunk_Data,	Backing_Vox_Chunk_Data_HD)
U1_Backing_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U1_Chunk_Data,	Backing_Vox_Chunk_Data_HD)
U2_Backing_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U2_Chunk_Data,	Backing_Vox_Chunk_Data_HD)
U4_Backing_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U4_Chunk_Data,	Backing_Vox_Chunk_Data_HD)
U8_Backing_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U8_Chunk_Data,	Backing_Vox_Chunk_Data_HD)
U16_Backing_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U16_Chunk_Data,	Backing_Vox_Chunk_Data_HD)

Backing_Chunk_Data_Abstract::struct{
	pal:[]Palette_Data,
	pal_count:^u16,
	data:[]u32,
	palette_size:Palette_Sizes,
}
Vox_Chunk_Data_HD::distinct hm.Handle64
Vox_Chunk_Data_HM::hm.Dynamic_Handle_Map(Vox_Chunk_Data,Vox_Chunk_Data_HD)
Vox_Chunk_Data::struct{
	handle:Vox_Chunk_Data_HD,
	backing_world_data:^Backing_Vox_World_Data,
	backing_chunk_data_hd:Backing_Vox_Chunk_Data_HD,
	backing_chunk_data_abstract:Backing_Chunk_Data_Abstract,

	backing_mask_data:^Vox_Mask_HM,
	vox_mask_hd:Vox_Mask_HD,
}

Vox_Mask_HD::distinct hm.Handle64
Vox_Mask_HM::hm.Dynamic_Handle_Map(Vox_Mask_Data,Vox_Mask_HD)
Vox_Mask_Data::struct{
	handle:Vox_Mask_HD,
	is_occupied_mask:[CHUNK_SIZE * CHUNK_SIZE]u32,//[x][z]
	is_solid_mask:   [CHUNK_SIZE * CHUNK_SIZE]u32,//[x][z]
	is_opaque_mask:  [CHUNK_SIZE * CHUNK_SIZE]u32,//[x][z]
}

make_new_vox_chunk_data::proc(w_map:^Map,size:Palette_Sizes=.u0)->(vox_chunk_hd:Vox_Chunk_Data_HD){
	// log.log(.Debug,"make_new_vox_chunk_data")
	backing_chunk_data_hd,backing_chunk_vox_data_hd_ok:=new_backing_chunk_vox_data(&w_map.backing_world_vox_data,size)
	assert(backing_chunk_vox_data_hd_ok,"new_backing_chunk_vox_data !ok")

	backing_chunk_data,backing_chunk_data_ok:=get_backing_chunk_vox_data(&w_map.backing_world_vox_data,backing_chunk_data_hd,size)
	assert(backing_chunk_vox_data_hd_ok,"new_backing_chunk_vox_data !ok")

	vox_chunk:=Vox_Chunk_Data{
		backing_world_data=&w_map.backing_world_vox_data,
		backing_chunk_data_hd = backing_chunk_data_hd,
		backing_chunk_data_abstract=backing_chunk_data,
		backing_mask_data = &w_map.vox_mask_hm,
	}
	assert(vox_chunk.backing_chunk_data_abstract.pal_count != nil)
	err:runtime.Allocator_Error
	vox_chunk_hd,err=hm.add(&w_map.vox_chunk_hm,vox_chunk)

	return
}
delete_vox_chunk_data::proc(w_map:^Map,vox_chunk_hd:Vox_Chunk_Data_HD)->(ok:bool){
	// log.log(.Debug,"delete_vox_chunk_data")
	vox_chunk_data,vox_chunk_data_ok:=get_vox_chunk_data(w_map,vox_chunk_hd)
	assert(vox_chunk_data_ok,"get_vox_chunk_data not ok")
	remove_chunk_data_ok:=remove_backing_vox_chunk_data(&w_map.backing_world_vox_data,vox_chunk_data.backing_chunk_data_hd,vox_chunk_data.backing_chunk_data_abstract.palette_size)
	assert(remove_chunk_data_ok,"new_backing_chunk_vox_data !ok")
	err:runtime.Allocator_Error
	ok,err=hm.remove(&w_map.vox_chunk_hm,vox_chunk_hd)
	assert(err ==.None)
	return
}
get_vox_chunk_data::proc(w_map:^Map, vox_chunk_hd:Vox_Chunk_Data_HD )->(vox_chunk_data:^Vox_Chunk_Data,ok:bool){
	// log.log(.Debug,"get_vox_chunk_data")
	vox_chunk_data,ok=hm.get(&w_map.vox_chunk_hm,vox_chunk_hd)
	return
}

get_backing_chunk_vox_data::proc(data:^Backing_Vox_World_Data,hd:Backing_Vox_Chunk_Data_HD,size:Palette_Sizes)->(ab_chunk:Backing_Chunk_Data_Abstract,ok:bool){
	// log.log(.Debug,"get_backing_chunk_vox_data")
	palettes_info:=PALETTES_INFO
	switch size{
	case.u0:
		chunk,ok:=hm.dynamic_get(&data.u0_chunk_data,hd)
		if !ok{
			log.log(.Error,"bad chunk data",hd,)
			ok = false
			return
		}
		// ab_chunk.data = chunk.data[:]
		ab_chunk.pal  = chunk.pal[:]
		ab_chunk.pal_count = &chunk.pal_count
		assert(ab_chunk.pal_count!=nil)
		ab_chunk.palette_size = size
		

	case.u1:
		chunk,ok:=hm.dynamic_get(&data.u1_chunk_data,hd)
		if !ok{
			log.log(.Error,"bad chunk data",hd,)
			ok = false
			return
		}
		ab_chunk.data = chunk.data[:]
		ab_chunk.pal  = chunk.pal[:]
		ab_chunk.pal_count = &chunk.pal_count
		ab_chunk.palette_size = size

	case.u2:
		chunk,ok:=hm.dynamic_get(&data.u2_chunk_data,hd)
		if !ok{
			log.log(.Error,"bad chunk data",hd,)
			ok = false
			return
		}
		ab_chunk.data = chunk.data[:]
		ab_chunk.pal  = chunk.pal[:]
		ab_chunk.pal_count = &chunk.pal_count
		ab_chunk.palette_size = size

	case.u4:
		chunk,ok:=hm.dynamic_get(&data.u4_chunk_data,hd)
		if !ok{
			log.log(.Error,"bad chunk data",hd,)
			ok = false
			return
		}
		ab_chunk.data = chunk.data[:]
		ab_chunk.pal  = chunk.pal[:]
		ab_chunk.pal_count = &chunk.pal_count
		ab_chunk.palette_size = size

	case.u8:
		chunk,ok:=hm.dynamic_get(&data.u8_chunk_data,hd)
		if !ok{
			log.log(.Error,"bad chunk data",hd,)
			ok = false
			return
		}
		ab_chunk.data = chunk.data[:]
		ab_chunk.pal  = chunk.pal[:]
		ab_chunk.pal_count = &chunk.pal_count
		ab_chunk.palette_size = size

	case.u16:
		chunk,ok:=hm.dynamic_get(&data.u16_chunk_data,hd)
		if !ok{
			log.log(.Error,"bad chunk data",hd,)
			ok = false
			return
		}
		ab_chunk.data = chunk.data[:]
		ab_chunk.pal  = chunk.pal[:]
		ab_chunk.pal_count = &chunk.pal_count
		ab_chunk.palette_size = size

	}
	ok = true
	return
}
new_backing_chunk_vox_data::proc(data:^Backing_Vox_World_Data, size:Palette_Sizes)->(hd:Backing_Vox_Chunk_Data_HD,ok:bool){
	// log.log(.Debug,"new_backing_chunk_vox_data")
	// Remove the old chunk from its old handle map.
	err:runtime.Allocator_Error
	switch size {
	case .u0:
		hd, err = hm.dynamic_add(&data.u0_chunk_data,U0_Chunk_Data{pal=Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		if err != nil {
			log.log(.Error, "failed adding u0 chunk during err = ", err)
			return
		}
	case .u1:
		hd, err = hm.dynamic_add(&data.u1_chunk_data,U1_Chunk_Data{pal=Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		if err != nil {
			log.log(.Error, "failed adding u1 chunk during err = ", err)
			return
		}
	case .u2:
		hd, err = hm.dynamic_add(&data.u2_chunk_data,U2_Chunk_Data{pal=Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		if err != nil {
			log.log(.Error, "failed adding u2 chunk during err = ", err)
			return
		}
	case .u4:
		hd, err = hm.dynamic_add(&data.u4_chunk_data,U4_Chunk_Data{pal=Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		if err != nil {
			log.log(.Error, "failed adding u4 chunk during err = ", err)
			return
		}
	case .u8:
		hd, err = hm.dynamic_add(&data.u8_chunk_data,U8_Chunk_Data{pal=Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		if err != nil {
			log.log(.Error, "failed adding u8 chunk during err = ", err)
			return
		}
	case .u16:
		hd, err = hm.dynamic_add(&data.u16_chunk_data,U16_Chunk_Data{pal=Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		if err != nil {
			log.log(.Error, "failed adding u16 chunk during err = ", err)
			return
		}
	}
	ok = true
	return
}
remove_backing_vox_chunk_data::proc(data:^Backing_Vox_World_Data,hd:Backing_Vox_Chunk_Data_HD,size:Palette_Sizes)->(ok:bool){
	// Remove the old chunk from its old handle map.
	// log.log(.Debug,"remove_backing_vox_chunk_data")
	switch size {
	case .u0:
		ok, err := hm.dynamic_remove(&data.u0_chunk_data, hd)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,hd)
			return false
		}
		if err != nil {
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err)
			return false
		}
	case .u1:
		ok, err := hm.dynamic_remove(&data.u1_chunk_data, hd)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,hd)
			return false
		}
		if err != nil {
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err)
			return false
		}

	case .u2:
		ok, err := hm.dynamic_remove(&data.u2_chunk_data, hd)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,hd)
			return false
		}
		if err != nil {
			log.log(.Error, "failed removing old u2 chunk during promotion, err = ", err)
			return false
		}

	case .u4:
		ok, err := hm.dynamic_remove(&data.u4_chunk_data, hd)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,hd)
			return false
		}
		if err != nil {
			log.log(.Error, "failed removing old u4 chunk during promotion, err = ", err)
			return false
		}
	case .u8:
		ok, err := hm.dynamic_remove(&data.u8_chunk_data, hd)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,hd)
			return false
		}
		if err != nil {
			log.log(.Error, "failed removing old u8 chunk during promotion, err = ", err)
			return false
		}
	case .u16:
		ok, err := hm.dynamic_remove(&data.u16_chunk_data, hd)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,hd)
			return false
		}
		if err != nil {
			log.log(.Error, "failed removing old u16 chunk during promotion, err = ", err)
			return false
		}
	}
	ok = true
	return
}

pos_to_vox_index::proc(pos:[3]u8,)->(vox_index:u16){
	// log.log(.Debug,"pos_to_vox_index")
	vox_index = cast(u16)pos.y + cast(u16)pos.x*CHUNK_SIZE + cast(u16)pos.z*CHUNK_SIZE*CHUNK_SIZE
	return
}


get_vox_in_chunk :: proc(vox_chunk_data:^Vox_Chunk_Data,pos:[3]u8)->(item_hd:Item_HD){
	// log.log(.Debug,"get_vox_in_chunk")
	ab_chunk:=vox_chunk_data.backing_chunk_data_abstract
	// palettes_info:=&ab_chunk.palette_info
	// bits:=ab_chunk.palette_info.bits_per_vox

	vox_index := pos_to_vox_index(pos)
	pal_index:=get_palette_index(vox_chunk_data,vox_index)

	return ab_chunk.pal[pal_index].item
}
get_vox_in_chunk_index :: proc(vox_chunk_data:^Vox_Chunk_Data,vox_index:u16)->(item_hd:Item_HD){
	// log.log(.Debug,"get_vox_in_chunk")
	ab_chunk:=vox_chunk_data.backing_chunk_data_abstract
	// palettes_info:=&ab_chunk.palette_info
	// bits:=ab_chunk.palette_info.bits_per_vox


	pal_index:=get_palette_index(vox_chunk_data,vox_index)

	return ab_chunk.pal[pal_index].item
}

get_palette_index_by_pos::proc(chunk:^Vox_Chunk_Data,pos:[3]u8)->(palette_index:u16){
	// log.log(.Debug,"get_palette_index_by_pos")
	vox_index := pos_to_vox_index(pos)
	palette_index=get_palette_index(chunk,vox_index)
	return
}

get_palette_index::proc(chunk:^Vox_Chunk_Data,vox_index:u16)->u16{

	ab:=&chunk.backing_chunk_data_abstract
	size:=chunk.backing_chunk_data_abstract.palette_size
	pinfo:=&PAL_INFO[size]

	if size == .u0 {
		return 0
	}
	word_index:=vox_index>>pinfo.index_shift
	bit_offset:=(vox_index&pinfo.field_mask)<<pinfo.shift

	return u16((ab.data[word_index]>>u32(bit_offset))&pinfo.mask)

}


set_palette_index::proc(chunk:^Vox_Chunk_Data,vox_index:u16,pal_index:u16,){
	ab:=&chunk.backing_chunk_data_abstract
	size:=chunk.backing_chunk_data_abstract.palette_size
	pinfo:=&PAL_INFO[size]

	old_pal_index:=get_palette_index(chunk,vox_index)
	if size == .u0{
		return
	}

	ab.pal[old_pal_index].count -= 1
	ab.pal[pal_index].count += 1


	word_index:=vox_index>>pinfo.index_shift
	bit_offset:=(vox_index&pinfo.field_mask)<<pinfo.shift

	mask:=pinfo.mask<<u32(bit_offset)
	value:=u32(pal_index&u16(pinfo.mask))<<u32(bit_offset)

	ab.data[word_index]=(ab.data[word_index]&~mask)|value

	mask_data,ok:=hm.get(chunk.backing_mask_data,chunk.vox_mask_hd)
	if !ok{
		// no maskes so no need to update them
		return
	}

	pal:=&ab.pal[pal_index]
	mask_index:=vox_index>>5
	bit:=u32(1)<<(vox_index&31)

	if pal.is_occupied{
		mask_data.is_occupied_mask[mask_index]|=bit
	}else{
		mask_data.is_occupied_mask[mask_index]&=~bit
	}

	if pal.is_solid{
		mask_data.is_solid_mask[mask_index]|=bit
	}else{
		mask_data.is_solid_mask[mask_index]&=~bit
	}

	if pal.is_opaque{
		mask_data.is_opaque_mask[mask_index]|=bit
	}else{
		mask_data.is_opaque_mask[mask_index]&=~bit
	}
}

// set_palette_index::proc(chunk:^Vox_Chunk_Data,vox_index:u16,pal_index:u16){
// 	ab_chunk:=&chunk.backing_chunk_data_abstract
// 	bits:=ab_chunk.palette_info.bits_per_vox

// 	if bits == 0{
// 		return
// 	}
	
// 	if bits == 1{
// 		u64_index:=vox_index>>6
// 		bit_offset:=vox_index&31
// 		mask:=u32(1)<<u32(bit_offset)

// 		if pal_index == 0{
// 			ab_chunk.data[u64_index]&=~mask
// 		}else{
// 			ab_chunk.data[u64_index]|=mask
// 		}
// 		return
// 	}

// 	if bits == 2{
// 		u64_index:=vox_index>>5
// 		bit_offset:=(vox_index&15)<<1
// 		mask:=u32(3)<<u32(bit_offset)
// 		value:=u32(pal_index&3)<<u32(bit_offset)

// 		ab_chunk.data[u64_index]=(ab_chunk.data[u64_index]&~mask)|value
// 		return
// 	}

// 	if bits == 4{
// 		u64_index:=vox_index>>4
// 		bit_offset:=(vox_index&7)<<2
// 		mask:=u32(15)<<u32(bit_offset)
// 		value:=u32(pal_index&15)<<u32(bit_offset)

// 		ab_chunk.data[u64_index]=(ab_chunk.data[u64_index]&~mask)|value
// 		return
// 	}

// 	if bits == 8{
// 		u64_index:=vox_index>>3
// 		bit_offset:=(vox_index&3)<<3
// 		mask:=u32(255)<<u32(bit_offset)
// 		value:=u32(pal_index&255)<<u32(bit_offset)

// 		ab_chunk.data[u64_index]=(ab_chunk.data[u64_index]&~mask)|value
// 		return
// 	}

// 	u64_index:=vox_index>>2
// 	bit_offset:=(vox_index&1)<<4
// 	mask:=u32(65535)<<u32(bit_offset)
// 	value:=u32(pal_index&65535)<<u32(bit_offset)

// 	ab_chunk.data[u64_index]=(ab_chunk.data[u64_index]&~mask)|value
// }


// promote_palette_chunk::proc(chunk:^Vox_Chunk_Data,preserve_data:bool=true){
// 	ab_chunk:=&chunk.backing_chunk_data_abstract
// 	old_size:=ab_chunk.palette_size	
// 	old_pinfo:=&PAL_INFO[old_size]
// 	new_size:=get_next_palett_size(old_size)
// 	new_pinfo:=&PAL_INFO[new_size]


// 	old_chunk:=&chunk.backing_chunk_data_abstract
// 	old_hd:=chunk.backing_chunk_data_hd

// 	new_hd,new_hd_ok:=new_backing_chunk_vox_data(chunk.backing_world_data,new_size)
// 	assert(new_hd_ok)

// 	new_chunk,new_chunk_ok:=get_backing_chunk_vox_data(chunk.backing_world_data,new_hd,new_size)
// 	assert(new_chunk_ok)


// 	new_chunk.pal_count^=old_chunk.pal_count^

// 	for i in 0..<old_chunk.pal_count^{
// 		new_chunk.pal[i]=old_chunk.pal[i]
// 	}

// 	old_bits:=old_pinfo.bits_per_vox
// 	new_bits:=new_pinfo.bits_per_vox

// 	if preserve_data{
// 		if old_bits > 0{
// 			fields_per_u64:=32/old_bits
	
// 			for i in 0..<len(old_chunk.data){
// 				old_data:=old_chunk.data[i]
	
// 				new_data_0:u32=0
// 				new_data_1:u32=0
	
// 				for field in 0..<fields_per_u64{
// 					old_shift:=field*old_bits
// 					new_shift:=field*new_bits
	
// 					value:=(old_data>>u32(old_shift))&((u32(1)<<u32(old_bits))-1)
	
// 					if new_shift < 32{
// 						new_data_0|=value<<u32(new_shift)
// 					}else{
// 						new_data_1|=value<<u32(new_shift-32)
// 					}
// 				}
	
// 				new_chunk.data[i*2]=new_data_0
// 				new_chunk.data[i*2+1]=new_data_1
// 			}
// 		}
// 	}
// 	chunk.backing_chunk_data_hd = new_hd
// 	chunk.backing_chunk_data_abstract = new_chunk
// 	remove_backing_vox_chunk_data(chunk.backing_world_data,old_hd,old_size)
// }

promote_palette_chunk::proc(chunk:^Vox_Chunk_Data,preserve_data:bool=true){
	ab_chunk:=&chunk.backing_chunk_data_abstract
	old_size:=ab_chunk.palette_size
	old_pinfo:=&PAL_INFO[old_size]
	new_size:=get_next_palett_size(old_size)
	new_pinfo:=&PAL_INFO[new_size]

	old_hd:=chunk.backing_chunk_data_hd

	new_hd,new_hd_ok:=new_backing_chunk_vox_data(chunk.backing_world_data,new_size)
	assert(new_hd_ok)

	new_chunk,new_chunk_ok:=get_backing_chunk_vox_data(chunk.backing_world_data,new_hd,new_size)
	assert(new_chunk_ok)



	new_chunk.pal_count^=ab_chunk.pal_count^

	for i in 0..<ab_chunk.pal_count^{
		new_chunk.pal[i]=ab_chunk.pal[i]
	}

	if preserve_data && old_pinfo.bits_per_vox > 0{
		fields_per_old_word:=1<<old_pinfo.index_shift

		for i in 0..<len(ab_chunk.data){
			old_data:=ab_chunk.data[i]

			for field in 0..<fields_per_old_word{
				old_shift:=u32(field)<<u32(old_pinfo.shift)
				pal_index:=(old_data>>old_shift)&old_pinfo.mask

				vox_index:u16=cast(u16)(i*fields_per_old_word+field)
				new_word:=vox_index>>new_pinfo.index_shift
				new_field:=vox_index&new_pinfo.field_mask
				new_shift:=u32(new_field)<<u32(new_pinfo.shift)

				new_chunk.data[new_word]|=pal_index<<new_shift
			}
		}

		if !hm.is_valid(chunk.backing_mask_data,chunk.vox_mask_hd) && new_size!=.u0 && old_size == .u0{
			mask_data:Vox_Mask_Data
			item,item_ok:=reg.get(&g.item_reg,ab_chunk.pal[0].item)
			if item_ok{ // if !ok is air
				mask_data.is_occupied_mask = 1
				if item.is_opaque{
					mask_data.is_opaque_mask = 1
				}
				if item.is_solid{
					mask_data.is_solid_mask = 1
				}
			}
			chunk.vox_mask_hd = hm.dynamic_add(chunk.backing_mask_data, mask_data)
		}
	}else{
		if !hm.is_valid(chunk.backing_mask_data,chunk.vox_mask_hd) && new_size!=.u0 && old_size == .u0{
			chunk.vox_mask_hd = hm.dynamic_add(chunk.backing_mask_data, Vox_Mask_Data{})
		}
	}

	chunk.backing_chunk_data_hd=new_hd
	chunk.backing_chunk_data_abstract=new_chunk
	remove_backing_vox_chunk_data(chunk.backing_world_data,old_hd,old_size)
}


set_block_in_chunk::proc(
	chunk:^Vox_Chunk_Data,
	pos:[3]u8,
	item_hd:Item_HD,
){

	vox_index:=pos_to_vox_index(pos)
	pal_index:=get_or_add_palette_index(chunk,item_hd)
	set_palette_index(chunk,vox_index,pal_index)


}

// set_blocks_in_chunk_by_col_pal_index::proc(
// 	chunk:^Vox_Chunk_Data,
// 	pal_index:u16,
// 	xz:[2]u8,
// 	start_top:u8=0,
// 	end_bot:u8=31
// ){
// 	ab_chunk:=&chunk.backing_chunk_data_abstract
// 	size:=ab_chunk.palette_size	
// 	pinfo:=&PAL_INFO[size]
// 	bits:=pinfo.bits_per_vox

// 	if bits == 0{
// 		return
// 	}

// 	base_index:=cast(u16)xz.x*CHUNK_SIZE + cast(u16)xz.y*CHUNK_SIZE*CHUNK_SIZE

// 	if bits == 1{
// 		start:=cast(u32)start_top
// 		end:=cast(u32)end_bot

// 		word_index:=int((base_index+cast(u16)start_top)>>5)
// 		start_bit:=start&31
// 		end_bit:=end&31

// 		mask:u32
// 		if start_bit <= end_bit{
// 			mask=((u32(1)<<(end_bit-start_bit+1))-1)<<start_bit
// 		}else{
// 			mask=~u32(0)<<start_bit
// 		}

// 		value:=mask&u32(pal_index&1)<<start_bit
// 		ab_chunk.data[word_index]=(ab_chunk.data[word_index]&~mask)|value

// 		if start_bit > end_bit{
// 			word_index+=1
// 			end_mask:=(u32(1)<<(end_bit+1))-1
// 			end_value:=end_mask&u32(pal_index&1)
// 			ab_chunk.data[word_index]=(ab_chunk.data[word_index]&~end_mask)|end_value
// 		}
// 		return
// 	}

// 	if bits == 2{
// 		base_word:=int(base_index>>4)
// 		start_field:=int(start_top>>4)
// 		end_field:=int(end_bot>>4)
// 		value:=u32(pal_index&3)

// 		for word:=base_word+start_field; word<=base_word+end_field; word+=1{
// 			first:=0
// 			last:=15

// 			if word == base_word+start_field{
// 				first=int(start_top&15)
// 			}
// 			if word == base_word+end_field{
// 				last=int(end_bot&15)
// 			}

// 			mask:u32=0
// 			for field:=first; field<=last; field+=1{
// 				mask|=u32(3)<<u32(field*2)
// 			}

// 			new_value:u32=0
// 			for field:=first; field<=last; field+=1{
// 				new_value|=value<<u32(field*2)
// 			}

// 			ab_chunk.data[word]=(ab_chunk.data[word]&~mask)|new_value
// 		}
// 		return
// 	}

// 	if bits == 4{
// 		base_word:=int(base_index>>3)
// 		start_field:=int(start_top>>3)
// 		end_field:=int(end_bot>>3)
// 		value:=u32(pal_index&15)

// 		for word:=base_word+start_field; word<=base_word+end_field; word+=1{
// 			first:=0
// 			last:=7

// 			if word == base_word+start_field{
// 				first=int(start_top&7)
// 			}
// 			if word == base_word+end_field{
// 				last=int(end_bot&7)
// 			}

// 			mask:u32=0
// 			new_value:u32=0
// 			for field:=first; field<=last; field+=1{
// 				shift:=u32(field*4)
// 				mask|=u32(15)<<shift
// 				new_value|=value<<shift
// 			}

// 			ab_chunk.data[word]=(ab_chunk.data[word]&~mask)|new_value
// 		}
// 		return
// 	}

// 	if bits == 8{
// 		base_word:=int(base_index>>2)
// 		start_field:=int(start_top>>2)
// 		end_field:=int(end_bot>>2)
// 		value:=u32(pal_index&255)

// 		for word:=base_word+start_field; word<=base_word+end_field; word+=1{
// 			first:=0
// 			last:=3

// 			if word == base_word+start_field{
// 				first=int(start_top&3)
// 			}
// 			if word == base_word+end_field{
// 				last=int(end_bot&3)
// 			}

// 			mask:u32=0
// 			new_value:u32=0
// 			for field:=first; field<=last; field+=1{
// 				shift:=u32(field*8)
// 				mask|=u32(255)<<shift
// 				new_value|=value<<shift
// 			}

// 			ab_chunk.data[word]=(ab_chunk.data[word]&~mask)|new_value
// 		}
// 		return
// 	}

// 	base_word:=int(base_index>>1)
// 	start_field:=int(start_top>>1)
// 	end_field:=int(end_bot>>1)
// 	value:=u32(pal_index)

// 	for word:=base_word+start_field; word<=base_word+end_field; word+=1{
// 		first:=0
// 		last:=1

// 		if word == base_word+start_field{
// 			first=int(start_top&1)
// 		}
// 		if word == base_word+end_field{
// 			last=int(end_bot&1)
// 		}

// 		mask:u32=0
// 		new_value:u32=0
// 		for field:=first; field<=last; field+=1{
// 			shift:=u32(field*16)
// 			mask|=u32(65535)<<shift
// 			new_value|=value<<shift
// 		}

// 		ab_chunk.data[word]=(ab_chunk.data[word]&~mask)|new_value
// 	}
// }


set_blocks_in_chunk_by_col_pal_index::proc(
	chunk:^Vox_Chunk_Data,
	pal_index:u16,
	xz:[2]u8,
	count:u8=32,
){
	ab:=&chunk.backing_chunk_data_abstract
	pinfo:=&PAL_INFO[ab.palette_size]

	if pinfo.index_shift == 0 || count == 0 {
		return
	}

	base_index:=cast(u32)xz[0]*CHUNK_SIZE + cast(u32)xz[1]*CHUNK_SIZE*CHUNK_SIZE
	word_index:=base_index>>u32(pinfo.index_shift)

	value:=u32(pal_index)&pinfo.mask
	full_value:=value*pinfo.fill_mask

	fields_per_word:=u32(1)<<u32(pinfo.index_shift)
	full_words:=cast(u32)count/fields_per_word
	remaining:=cast(u32)count%fields_per_word

	for i:=u32(0); i<full_words; i+=1 {
		ab.data[word_index+i]=full_value
	}

	if remaining != 0 {
		shift:=remaining<<u32(pinfo.shift)
		mask:=(u32(1)<<shift)-1
		ab.data[word_index+full_words]=(ab.data[word_index+full_words]&~mask)|(value*pinfo.fill_mask&mask)
	}

	mask_data,ok:=hm.get(chunk.backing_mask_data,chunk.vox_mask_hd)
	if !ok{
		// no maskes so no need to update them
		return
	}
	mask_index:=cast(u32)xz[0]+cast(u32)xz[1]*CHUNK_SIZE
	pal:=&ab.pal[pal_index]

	mask_bits:u32
	if count == 32 {
		mask_bits = ~u32(0)
	} else {
		mask_bits = (u32(1)<<u32(count))-1
	}

	if pal.is_occupied {
		mask_data.is_occupied_mask[mask_index]|=mask_bits
	} else {
		mask_data.is_occupied_mask[mask_index]&=~mask_bits
	}
	if pal.is_solid {
		mask_data.is_solid_mask[mask_index]|=mask_bits
	} else {
		mask_data.is_solid_mask[mask_index]&=~mask_bits
	}
	if pal.is_opaque {
		mask_data.is_opaque_mask[mask_index]|=mask_bits
	} else {
		mask_data.is_opaque_mask[mask_index]&=~mask_bits
	}
}
// set_block_in_chunk::proc(
// 	chunk:^Vox_Chunk_Data,
// 	pos:[3]u8,
// 	item_hd:Item_HD,
// )->bool{
// 	// if pos.x < 0 || pos.x >= CHUNK_SIZE || pos.y < 0 || pos.y >= CHUNK_SIZE || pos.z < 0 || pos.z >= CHUNK_SIZE {
// 	// 	log.log(.Warning,"position outside chunk = ",pos," p_hd = ",p_hd^,)
// 	// 	return false
// 	// }
// 	vox_index:=pos_to_vox_index(pos)


// 	for {
// 		ab_chunk:=&chunk.backing_chunk_data_abstract

// 		if ab_chunk.palette_size == .u0{
// 			if ab_chunk.pal[0].item == item_hd{
// 				return true
// 			}
// 			next_size:=get_next_palett_size(ab_chunk.palette_size)
// 			promoted:=promote_palette_chunk(chunk,true)
// 			assert(promoted)
// 			continue
// 		}

// 		old_pal_index:=get_palette_index(chunk,vox_index)

// 		// if old_pal_index < 0 || cast(u16)old_pal_index >= cast(u16)ab_chunk.pal_count^{
// 		// 	log.log(.Warning,"bad old palette index = ",old_pal_index," palette count = ",ab_chunk.pal_count^," pos = ",pos," p_hd = ",p_hd^,)
// 		// 	return false
// 		// }

// 		new_pal_index,new_ok:=get_or_add_palette_index(chunk,item_hd)

// 		if !new_ok{
// 			next_size,next_ok:=get_next_palett_size(ab_chunk.palette_size)
// 			if !next_ok{
// 				log.log(.Error,"palette is full and cannot be promoted, p_hd = ",p_hd^,)
// 				return false
// 			}

// 			// old_hd:=p_hd^
// 			promoted:=promote_palette_chunk(data,p_hd)
// 			if !promoted{
// 				log.log(.Error,"failed promoting palette, p_hd = ",p_hd,)
// 				return false
// 			}

// 			// p_hd^=new_hd
// 			continue
// 		}

// 		if new_pal_index == old_pal_index{
// 			return true
// 		}

// 		if ab_chunk.pal[old_pal_index].count == 0{
// 			log.log(.Warning,"old palette entry has zero references, old_pal_index = ",old_pal_index," pos = ",pos," p_hd = ",p_hd^,)
// 		}else{
// 			ab_chunk.pal[old_pal_index].count-=1
// 		}

// 		ab_chunk.pal[new_pal_index].count+=1
// 		set_palette_index(&ab_chunk,vox_index,new_pal_index)

// 		return true
// 	}
// }

//preserve_data tells it wherer or not to preserve_data when promoting the chunk to a new size this is expensiv so
//if the chunk is geting fully changed enyway set to falls but if the data matters leave it true
get_or_add_palette_index::proc(chunk:^Vox_Chunk_Data,item_hd:Item_HD,preserve_data:bool=true)->(pal_index:u16){
	ad_chunk:=&chunk.backing_chunk_data_abstract
	pal_count:=ad_chunk.pal_count^
	for i in 0..<pal_count{
		if ad_chunk.pal[i].item == item_hd{
			return cast(u16)i,
		}
	}

	if cast(int)pal_count >= len(ad_chunk.pal){
		promote_palette_chunk(chunk,preserve_data)
		ad_chunk=&chunk.backing_chunk_data_abstract
	}
	is_occupied:bool
	is_opaque:bool
	is_solid:bool
	item,item_ok:=reg.get(&g.item_reg,item_hd)
	if item_ok{
		is_occupied = item.is_occupied
		is_opaque = item.is_opaque
		is_solid = item.is_solid
	}else{
		is_occupied = false
		is_opaque = false
		is_solid = false
	}
	ad_chunk.pal[pal_count]=Palette_Data{
		item=item_hd,
		count=0,
		is_occupied=is_occupied,
		is_opaque=is_opaque,
		is_solid=is_solid,
	}
	ad_chunk.pal_count^+=1

	return pal_count
}


// add_palette_entry :: proc(
// 	chunk:^Vox_Chunk_Data,
// 	item_hd: Item_HD,
// ) -> (pal_index: int, ok: bool) {

// 	pal_count := int(chunk.pal_count^)

// 	// See if the item is already in the palette.
// 	for i in 0..<pal_count {
// 		if chunk.pal[i].item == item_hd {
// 			return i, true
// 		}
// 	}

// 	// Palette is full.
// 	if pal_count >= len(chunk.pal) {
// 		return -1, false
// 	}

// 	pal_index = pal_count

// 	chunk.pal[pal_index] = Palette_Data{
// 		item  = item_hd,
// 		count = 0,
// 	}

// 	chunk.pal_count^ += 1

// 	return pal_index, true
// }

//returns false if there is no next size
get_next_palett_size::proc(size:Palette_Sizes)->(next_size:Palette_Sizes){
	switch size{
	case .u0:return .u1
	case .u1:return .u2
	case .u2:return .u4
	case .u4:return .u8
	case .u8:return .u16
	case .u16:assert(false, "no next palett size")
	}
	return
}

get_prev_palett_size::proc(size:Palette_Sizes)->(prev_size:Palette_Sizes){
	switch size{
	case .u0:assert(false, "no next palett size")
	case .u1:return .u0
	case .u2:return .u1
	case .u4:return .u2
	case .u8:return .u4
	case .u16:return .u8
	}
	return
}
