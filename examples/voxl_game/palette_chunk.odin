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
	Mutex_u0:atom.Mutex,
	u0_chunk_data:	U0_Backing_Chunk_Data_HM,

	Mutex_u1:atom.Mutex,
	u1_chunk_data:	U1_Backing_Chunk_Data_HM,

	Mutex_u2:atom.Mutex,
	u2_chunk_data:	U2_Backing_Chunk_Data_HM,

	Mutex_u4:atom.Mutex,
	u4_chunk_data:	U4_Backing_Chunk_Data_HM,

	Mutex_u8:atom.Mutex,
	u8_chunk_data:	U8_Backing_Chunk_Data_HM,

	Mutex_u16:atom.Mutex,
	u16_chunk_data:	U16_Backing_Chunk_Data_HM,
}

Block_State::struct{
	state:u32,
	pad:u16,
	offset:u16,
}

Block_Palette_Data::struct{
	item:Item_HD,
	state:Block_State,
	count:u16, // Number of voxel chains containing this node.
	multy_block_index:u16, // 0 means this is the end of the chain; palette index 0 is reserved for empty cells.
}

Backing_Vox_Chunk_Data_HD::distinct hm.Handle64

U0_Chunk_Data::	struct{handle:Backing_Vox_Chunk_Data_HD,pal:[PALETTES_INFO[.u0].max_pal_size]Block_Palette_Data, pal_count:u16,}
U1_Chunk_Data::	struct{handle:Backing_Vox_Chunk_Data_HD,pal:[PALETTES_INFO[.u1].max_pal_size]Block_Palette_Data, pal_count:u16,data:[PALETTES_INFO[.u1].u32_per_chunk]u32,}
U2_Chunk_Data::	struct{handle:Backing_Vox_Chunk_Data_HD,pal:[PALETTES_INFO[.u2].max_pal_size]Block_Palette_Data, pal_count:u16,data:[PALETTES_INFO[.u2].u32_per_chunk]u32,}
U4_Chunk_Data::	struct{handle:Backing_Vox_Chunk_Data_HD,pal:[PALETTES_INFO[.u4].max_pal_size]Block_Palette_Data, pal_count:u16,data:[PALETTES_INFO[.u4].u32_per_chunk]u32,}
U8_Chunk_Data::	struct{handle:Backing_Vox_Chunk_Data_HD,pal:[PALETTES_INFO[.u8].max_pal_size]Block_Palette_Data, pal_count:u16,data:[PALETTES_INFO[.u8].u32_per_chunk]u32,}
U16_Chunk_Data::struct{handle:Backing_Vox_Chunk_Data_HD,pal:[PALETTES_INFO[.u16].max_pal_size]Block_Palette_Data, pal_count:u16,data:[PALETTES_INFO[.u16].u32_per_chunk]u32,}

U0_Backing_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U0_Chunk_Data,	Backing_Vox_Chunk_Data_HD)
U1_Backing_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U1_Chunk_Data,	Backing_Vox_Chunk_Data_HD)
U2_Backing_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U2_Chunk_Data,	Backing_Vox_Chunk_Data_HD)
U4_Backing_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U4_Chunk_Data,	Backing_Vox_Chunk_Data_HD)
U8_Backing_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U8_Chunk_Data,	Backing_Vox_Chunk_Data_HD)
U16_Backing_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U16_Chunk_Data,	Backing_Vox_Chunk_Data_HD)

Backing_Chunk_Data_Abstract::struct{
	pal:[]Block_Palette_Data,
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
	pos:[4]int,
	vox_gened:bool,
}

Vox_Mask_HD::distinct hm.Handle64
Vox_Mask_HM::struct{
	Mutex:atom.Mutex,
	hm:hm.Dynamic_Handle_Map(Vox_Mask_Data,Vox_Mask_HD),
}
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
		atom.mutex_lock(&data.Mutex_u0)
		hd, err = hm.dynamic_add(&data.u0_chunk_data,U0_Chunk_Data{pal=Block_Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		atom.mutex_unlock(&data.Mutex_u0)
		if err != nil {
			log.log(.Error, "failed adding u0 chunk during err = ", err)
			return
		}
		
	case .u1:
		atom.mutex_lock(&data.Mutex_u1)
		hd, err = hm.dynamic_add(&data.u1_chunk_data,U1_Chunk_Data{pal=Block_Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		atom.mutex_unlock(&data.Mutex_u1)
		if err != nil {
			log.log(.Error, "failed adding u1 chunk during err = ", err)
			return
		}
	case .u2:
		atom.mutex_lock(&data.Mutex_u2)
		hd, err = hm.dynamic_add(&data.u2_chunk_data,U2_Chunk_Data{pal=Block_Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		atom.mutex_unlock(&data.Mutex_u2)
		if err != nil {
			log.log(.Error, "failed adding u2 chunk during err = ", err)
			return
		}
	case .u4:
		atom.mutex_lock(&data.Mutex_u4)
		hd, err = hm.dynamic_add(&data.u4_chunk_data,U4_Chunk_Data{pal=Block_Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		atom.mutex_unlock(&data.Mutex_u4)
		if err != nil {
			log.log(.Error, "failed adding u4 chunk during err = ", err)
			return
		}
	case .u8:
		atom.mutex_lock(&data.Mutex_u8)
		hd, err = hm.dynamic_add(&data.u8_chunk_data,U8_Chunk_Data{pal=Block_Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		atom.mutex_unlock(&data.Mutex_u8)
		if err != nil {
			log.log(.Error, "failed adding u8 chunk during err = ", err)
			return
		}
	case .u16:
		atom.mutex_lock(&data.Mutex_u16)
		hd, err = hm.dynamic_add(&data.u16_chunk_data,U16_Chunk_Data{pal=Block_Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		atom.mutex_unlock(&data.Mutex_u16)
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
		atom.mutex_lock(&data.Mutex_u0)
		ok, err := hm.dynamic_remove(&data.u0_chunk_data, hd)
		atom.mutex_unlock(&data.Mutex_u0)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,hd)
			return false
		}
		if err != nil {
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err)
			return false
		}
	case .u1:
		atom.mutex_lock(&data.Mutex_u1)
		ok, err := hm.dynamic_remove(&data.u1_chunk_data, hd)
		atom.mutex_unlock(&data.Mutex_u1)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,hd)
			return false
		}
		if err != nil {
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err)
			return false
		}

	case .u2:
		atom.mutex_lock(&data.Mutex_u2)
		ok, err := hm.dynamic_remove(&data.u2_chunk_data, hd)
		atom.mutex_unlock(&data.Mutex_u2)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,hd)
			return false
		}
		if err != nil {
			log.log(.Error, "failed removing old u2 chunk during promotion, err = ", err)
			return false
		}

	case .u4:
		atom.mutex_lock(&data.Mutex_u4)
		ok, err := hm.dynamic_remove(&data.u4_chunk_data, hd)
		atom.mutex_unlock(&data.Mutex_u4)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,hd)
			return false
		}
		if err != nil {
			log.log(.Error, "failed removing old u4 chunk during promotion, err = ", err)
			return false
		}
	case .u8:
		atom.mutex_lock(&data.Mutex_u8)
		ok, err := hm.dynamic_remove(&data.u8_chunk_data, hd)
		atom.mutex_unlock(&data.Mutex_u8)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,hd)
			return false
		}
		if err != nil {
			log.log(.Error, "failed removing old u8 chunk during promotion, err = ", err)
			return false
		}
	case .u16:
		atom.mutex_lock(&data.Mutex_u16)
		ok, err := hm.dynamic_remove(&data.u16_chunk_data, hd)
		atom.mutex_unlock(&data.Mutex_u16)
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


get_vox_in_chunk :: proc(vox_chunk_data:^Vox_Chunk_Data,pos:[3]u8)->(block:Block_Palette_Data){
	vox_index:=pos_to_vox_index(pos)
	pal_index:=get_palette_index(vox_chunk_data,vox_index)
	return get_palette_by_index(vox_chunk_data,pal_index)
}
get_vox_in_chunk_index :: proc(vox_chunk_data:^Vox_Chunk_Data,vox_index:u16)->(item_hd:Item_HD){
	ab_chunk:=vox_chunk_data.backing_chunk_data_abstract
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

	if size == .u0 {
		return 0
	}
	pinfo:=&PAL_INFO[size]
	word_index:=vox_index>>pinfo.index_shift
	bit_offset:=(vox_index&pinfo.field_mask)<<pinfo.shift

	return u16((ab.data[word_index]>>u32(bit_offset))&pinfo.mask)

}

get_palette_by_index::proc(chunk:^Vox_Chunk_Data,pal_index:u16)->Block_Palette_Data{
	ab:=&chunk.backing_chunk_data_abstract
	assert(pal_index < ab.pal_count^)
	return ab.pal[pal_index]
}

update_vox_mask_bits::proc(chunk:^Vox_Chunk_Data,mask_index:u32,mask_bits:u32,item_hd:Item_HD){
	mask_data,ok:=hm.get(&chunk.backing_mask_data.hm,chunk.vox_mask_hd)
	if !ok {
		return
	}

	item,item_ok:=reg.get(&g.item_reg,item_hd)
	is_occupied:=false
	is_solid:=false
	is_opaque:=false
	if item_ok {
		is_occupied=item.is_occupied
		is_solid=item.is_solid
		is_opaque=item.is_opaque
	}

	if is_occupied {
		mask_data.is_occupied_mask[mask_index]|=mask_bits
	} else {
		mask_data.is_occupied_mask[mask_index]&=~mask_bits
	}
	if is_solid {
		mask_data.is_solid_mask[mask_index]|=mask_bits
	} else {
		mask_data.is_solid_mask[mask_index]&=~mask_bits
	}
	if is_opaque {
		mask_data.is_opaque_mask[mask_index]|=mask_bits
	} else {
		mask_data.is_opaque_mask[mask_index]&=~mask_bits
	}
}

change_palette_chain_count::proc(chunk:^Vox_Chunk_Data,pal_index:u16,add:bool){
	ab:=&chunk.backing_chunk_data_abstract
	current_index:=pal_index

	for _ in 0..<ab.pal_count^ {
		assert(current_index < ab.pal_count^,"invalid palette index in multiblock chain")
		if add {
			ab.pal[current_index].count += 1
		} else {
			assert(ab.pal[current_index].count > 0,"palette chain count underflow")
			ab.pal[current_index].count -= 1
		}
		next:=ab.pal[current_index].multy_block_index
		if next == 0 {
			return
		}
		current_index=next
	}
	assert(false,"cycle detected in multiblock palette chain")
}

set_palette_index::proc(chunk:^Vox_Chunk_Data,vox_index:u16,pal_index:u16,){
	ab:=&chunk.backing_chunk_data_abstract
	size:=ab.palette_size
	old_pal_index:=get_palette_index(chunk,vox_index)
	if old_pal_index == pal_index {
		return
	}
	if size == .u0 {
		assert(pal_index == 0)
		return
	}
	assert(pal_index < ab.pal_count^)

	change_palette_chain_count(chunk,old_pal_index,false)
	change_palette_chain_count(chunk,pal_index,true)

	pinfo:=&PAL_INFO[size]
	word_index:=vox_index>>pinfo.index_shift
	bit_offset:=(vox_index&pinfo.field_mask)<<pinfo.shift
	mask:=pinfo.mask<<u32(bit_offset)
	value:=u32(pal_index&u16(pinfo.mask))<<u32(bit_offset)
	ab.data[word_index]=(ab.data[word_index]&~mask)|value

	mask_index:=cast(u32)(vox_index>>5)
	bit:=u32(1)<<(vox_index&31)
	update_vox_mask_bits(chunk,mask_index,bit,ab.pal[pal_index].item)
}


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

	if preserve_data && old_pinfo.bits_per_vox > 0 {
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
	}

	if !hm.is_valid(&chunk.backing_mask_data.hm,chunk.vox_mask_hd) && new_size != .u0 && old_size == .u0 {
		mask_data:Vox_Mask_Data
		if preserve_data {
			item,item_ok:=reg.get(&g.item_reg,ab_chunk.pal[0].item)
			if item_ok {
				if item.is_occupied {
					mask_data.is_occupied_mask=~u32(0)
				}
				if item.is_opaque {
					mask_data.is_opaque_mask=~u32(0)
				}
				if item.is_solid {
					mask_data.is_solid_mask=~u32(0)
				}
			}
		}
		atom.mutex_lock(&chunk.backing_mask_data.Mutex)
		chunk.vox_mask_hd=hm.dynamic_add(&chunk.backing_mask_data.hm,mask_data)
		atom.mutex_unlock(&chunk.backing_mask_data.Mutex)
	}

	chunk.backing_chunk_data_hd=new_hd
	chunk.backing_chunk_data_abstract=new_chunk
	remove_backing_vox_chunk_data(chunk.backing_world_data,old_hd,old_size)
}


set_block_in_chunk::proc(
	chunk:^Vox_Chunk_Data,
	pos:[3]u8,
	item_hd:Item_HD,
	state:Block_State={},
){
	vox_index:=pos_to_vox_index(pos)
	pal_index:=get_or_add_palette_index(chunk,Block_Palette_Data{
		item=item_hd,
		state=state,
	})
	set_palette_index(chunk,vox_index,pal_index)
}

append_palette_child::proc(chunk:^Vox_Chunk_Data,pal_index:u16,child_pal_index:u16,depth:u16=0)->u16{
	ab:=&chunk.backing_chunk_data_abstract
	assert(pal_index < ab.pal_count^)
	assert(child_pal_index != 0,"palette index 0 is reserved for an empty cell")
	assert(depth < ab.pal_count^,"cycle detected while appending multiblock")
	node:=ab.pal[pal_index]

	if node.multy_block_index == 0 {
		node.multy_block_index=child_pal_index
	} else {
		node.multy_block_index=append_palette_child(chunk,node.multy_block_index,child_pal_index,depth+1)
	}
	node.count=0
	return get_or_add_palette_index(chunk,node)
}

// Adds a block at the end of the cell's existing chain. An empty cell gets a root block.
set_child_block_in_chunk::proc(
	chunk:^Vox_Chunk_Data,
	pos:[3]u8,
	item_hd:Item_HD,
	state:Block_State={},
){
	vox_index:=pos_to_vox_index(pos)
	old_pal_index:=get_palette_index(chunk,vox_index)
	if old_pal_index == 0 {
		set_block_in_chunk(chunk,pos,item_hd,state)
		return
	}

	child_pal_index:=get_or_add_palette_index(chunk,Block_Palette_Data{
		item=item_hd,
		state=state,
	})
	new_pal_index:=append_palette_child(chunk,old_pal_index,child_pal_index)
	set_palette_index(chunk,vox_index,new_pal_index)
}

truncate_palette_chain::proc(chunk:^Vox_Chunk_Data,pal_index:u16,target_pal_index:u16,depth:u16=0)->(new_pal_index:u16,found:bool){
	ab:=&chunk.backing_chunk_data_abstract
	assert(pal_index < ab.pal_count^)
	assert(depth < ab.pal_count^,"cycle detected while destroying multiblock")
	node:=ab.pal[pal_index]
	if pal_index == target_pal_index {
		return 0,true
	}
	if node.multy_block_index == 0 {
		return pal_index,false
	}
	new_child_index:u16
	new_child_index,found=truncate_palette_chain(chunk,node.multy_block_index,target_pal_index,depth+1)
	if !found {
		return pal_index,false
	}
	node.multy_block_index=new_child_index
	node.count=0
	return get_or_add_palette_index(chunk,node),true
}

// Removes the selected block and every child after it. target_pal_index is the palette
// node hit by the raycast, not merely the cell's root palette index.
destroy_block_in_chunk::proc(chunk:^Vox_Chunk_Data,pos:[3]u8,target_pal_index:u16)->(destroyed:bool){
	vox_index:=pos_to_vox_index(pos)
	old_pal_index:=get_palette_index(chunk,vox_index)
	if old_pal_index == 0 {
		return false
	}

	new_pal_index,found:=truncate_palette_chain(chunk,old_pal_index,target_pal_index)
	if !found {
		return false
	}
	set_palette_index(chunk,vox_index,new_pal_index)
	return true
}


// Bulk initialization helper. It does not update palette counts; the caller must do that after writing.
set_blocks_in_chunk_by_col_pal_index::proc(
	chunk:^Vox_Chunk_Data,
	pal_index:u16,
	xz:[2]u8,
	count:u8=32,
){
	ab:=&chunk.backing_chunk_data_abstract
	pinfo:=&PAL_INFO[ab.palette_size]
	assert(pal_index < ab.pal_count^)
	assert(count <= CHUNK_SIZE)

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

	mask_index:=cast(u32)xz[0]+cast(u32)xz[1]*CHUNK_SIZE
	mask_bits:u32
	if count == 32 {
		mask_bits=~u32(0)
	} else {
		mask_bits=(u32(1)<<u32(count))-1
	}
	update_vox_mask_bits(chunk,mask_index,mask_bits,ab.pal[pal_index].item)
}


// Do not recycle count==0 entries here: bulk generation assigns palette counts after its column writes.
get_or_add_palette_index::proc(chunk:^Vox_Chunk_Data,pal_d:Block_Palette_Data,preserve_data:bool=true)->(pal_index:u16){
	pal_d:=pal_d
	ad_chunk:=&chunk.backing_chunk_data_abstract
	if pal_d.multy_block_index != 0 {
		assert(pal_d.multy_block_index < ad_chunk.pal_count^,"invalid child palette index")
	}
	pal_count:=ad_chunk.pal_count^
	for i in 0..<pal_count{
		if ad_chunk.pal[i].item == pal_d.item &&
		   ad_chunk.pal[i].state == pal_d.state &&
		   ad_chunk.pal[i].multy_block_index == pal_d.multy_block_index
		{
			return cast(u16)i,
		}
	}

	if cast(int)pal_count >= len(ad_chunk.pal){
		assert(ad_chunk.palette_size != .u16,"voxel palette is full")
		promote_palette_chunk(chunk,preserve_data)
		ad_chunk=&chunk.backing_chunk_data_abstract
		pal_count=ad_chunk.pal_count^
	}

	pal_d.count=0
	ad_chunk.pal[pal_count]=pal_d
	ad_chunk.pal_count^+=1

	return pal_count
}


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


block_offset_to_u16::proc(offset:[3]f32)->(result:u16) {
	for axis in 0..<3 {
		magnitude:=cast(u16)(math.abs(offset[axis])*16.0+0.5)
		magnitude=min(magnitude,15)
		value:=magnitude
		if offset[axis] < 0 {value|=0x10}
		result|=value<<u16(axis*5)
	}
	return result
}
block_offset_from_u16::proc(packed:u16)->(result:[3]f32) {
	for axis in 0..<3 {
		value:=(packed>>u16(axis*5))&0x1F
		magnitude:=value&0x0F
		result[axis]=cast(f32)magnitude/16.0
		if value&0x10 != 0 {result[axis]=-result[axis]}
	}
	return result
}
