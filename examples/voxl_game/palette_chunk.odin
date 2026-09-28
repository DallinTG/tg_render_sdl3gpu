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
	// u6,
	u8,
	// u10,
	// u12,
	// u14,
	u16,
}
Palette_Info::struct{
	bits_per_vox:int,
	bits_per_chunk:int,
	bytes_per_chunk:int,
	max_pal_size:int

}
PALETTES_INFO:[Palette_Sizes]Palette_Info:{
	.u0 = {
		bits_per_vox = 0,
		bits_per_chunk = 0,
		bytes_per_chunk = 0,
		max_pal_size = 1,
	},
	.u1 = {
		bits_per_vox = 1,
		bits_per_chunk = 1 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE,
		bytes_per_chunk = 1 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8,
		max_pal_size = 2,
	},
	.u2 = {
		bits_per_vox = 2,
		bits_per_chunk = 2 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE,
		bytes_per_chunk = 2 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8,
		max_pal_size = 4,
	},
	.u4 = {
		bits_per_vox = 4,
		bits_per_chunk = 4 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE,
		bytes_per_chunk = 4 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8,
		max_pal_size = 16,
	},
	// .u6 = {
	// 	bits_per_vox = 6,
	// 	bits_per_chunk = 6 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE,
	// 	bytes_per_chunk = 6 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8,
	// 	max_pal_size = 64,
	// },
	.u8 = {
		bits_per_vox = 8,
		bits_per_chunk = 8 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE,
		bytes_per_chunk = 8 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8,
		max_pal_size = 256,
	},
	// .u10 = {
	// 	bits_per_vox = 10,
	// 	bits_per_chunk = 10 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE,
	// 	bytes_per_chunk = 10 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8,
	// 	max_pal_size = 1024,
	// },
	// .u12 = {
	// 	bits_per_vox = 12,
	// 	bits_per_chunk = 12 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE,
	// 	bytes_per_chunk = 12 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8,
	// 	max_pal_size = 4096,
	// },
	// .u14 = {
	// 	bits_per_vox = 14,
	// 	bits_per_chunk = 14 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE,
	// 	bytes_per_chunk = 14 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8,
	// 	max_pal_size = 16384,
	// },
	.u16 = {
		bits_per_vox = 16,
		bits_per_chunk = 16 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE,
		bytes_per_chunk = 16 * CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE/8,
		max_pal_size = CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE,
	},
}

Chunks_Vox_Data::struct{
	u0_chunk_data:	U0_Chunk_Data_HM,
	u1_chunk_data:	U1_Chunk_Data_HM,
	u2_chunk_data:	U2_Chunk_Data_HM,
	u4_chunk_data:	U4_Chunk_Data_HM,
	// u6_chunk_data:	U6_Chunk_Data_HM,
	u8_chunk_data:	U8_Chunk_Data_HM,
	// u10_chunk_data:	U10_Chunk_Data_HM,
	// u12_chunk_data:	U12_Chunk_Data_HM,
	// u14_chunk_data:	U14_Chunk_Data_HM,
	u16_chunk_data:	U16_Chunk_Data_HM,
}

Palette_Data::struct{
	item:Item_HD,
	count:u16,
}

Palett_Chunk_Data_HD::distinct hm.Handle64
Palett_Chunk_HD::struct{
	hd:Palett_Chunk_Data_HD,
	size:Palette_Sizes,
}

U0_Chunk_Data::	struct{handle:Palett_Chunk_Data_HD,pal:[PALETTES_INFO[.u0].max_pal_size]	Palette_Data, pal_count:u32,}
U1_Chunk_Data::	struct{handle:Palett_Chunk_Data_HD,pal:[PALETTES_INFO[.u1].max_pal_size]	Palette_Data, pal_count:u32,data:[PALETTES_INFO[.u1].bytes_per_chunk]byte,}
U2_Chunk_Data::	struct{handle:Palett_Chunk_Data_HD,pal:[PALETTES_INFO[.u2].max_pal_size]	Palette_Data, pal_count:u32,data:[PALETTES_INFO[.u2].bytes_per_chunk]byte,}
U4_Chunk_Data::	struct{handle:Palett_Chunk_Data_HD,pal:[PALETTES_INFO[.u4].max_pal_size]	Palette_Data, pal_count:u32,data:[PALETTES_INFO[.u4].bytes_per_chunk]byte,}
// U6_Chunk_Data::	struct{handle:Palett_Chunk_Data_HD,pal:[PALETTES_INFO[.u6].max_pal_size]	Palette_Data, pal_count:u32,data:[PALETTES_INFO[.u6].bytes_per_chunk]byte,}
U8_Chunk_Data::	struct{handle:Palett_Chunk_Data_HD,pal:[PALETTES_INFO[.u8].max_pal_size]	Palette_Data, pal_count:u32,data:[PALETTES_INFO[.u8].bytes_per_chunk]byte,}
// U10_Chunk_Data::struct{handle:Palett_Chunk_Data_HD,pal:[PALETTES_INFO[.u10].max_pal_size]	Palette_Data, pal_count:u32,data:[PALETTES_INFO[.u10].bytes_per_chunk]byte,}
// U12_Chunk_Data::struct{handle:Palett_Chunk_Data_HD,pal:[PALETTES_INFO[.u12].max_pal_size]	Palette_Data, pal_count:u32,data:[PALETTES_INFO[.u12].bytes_per_chunk]byte,}
// U14_Chunk_Data::struct{handle:Palett_Chunk_Data_HD,pal:[PALETTES_INFO[.u14].max_pal_size]	Palette_Data, pal_count:u32,data:[PALETTES_INFO[.u14].bytes_per_chunk]byte,}
U16_Chunk_Data::struct{handle:Palett_Chunk_Data_HD,pal:[PALETTES_INFO[.u16].max_pal_size]	Palette_Data, pal_count:u32,data:[PALETTES_INFO[.u16].bytes_per_chunk]byte,}

U0_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U0_Chunk_Data,	Palett_Chunk_Data_HD)
U1_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U1_Chunk_Data,	Palett_Chunk_Data_HD)
U2_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U2_Chunk_Data,	Palett_Chunk_Data_HD)
U4_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U4_Chunk_Data,	Palett_Chunk_Data_HD)
// U6_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U6_Chunk_Data,	Palett_Chunk_Data_HD)
U8_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U8_Chunk_Data,	Palett_Chunk_Data_HD)
// U10_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U10_Chunk_Data,	Palett_Chunk_Data_HD)
// U12_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U12_Chunk_Data,	Palett_Chunk_Data_HD)
// U14_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U14_Chunk_Data,	Palett_Chunk_Data_HD)
U16_Chunk_Data_HM::	hm.Dynamic_Handle_Map(U16_Chunk_Data,	Palett_Chunk_Data_HD)


Chunk_Abstract::struct{
	pal:[]Palette_Data,
	pal_count:^u32,
	data:[]byte,
	size:Palette_Sizes,
}

get_chunk_vox_data::proc(data:^Chunks_Vox_Data,hd:Palett_Chunk_HD)->(ab_chunk:Chunk_Abstract,ok:bool){
	switch hd.size{
	case.u0:
		chunk,ok:=hm.dynamic_get(&data.u0_chunk_data,hd.hd)
		if !ok{
			// log.log(.Error,"bad chunk data",hd,)
			ok = false
			return
		}
		// ab_chunk.data = chunk.data[:]
		ab_chunk.pal  = chunk.pal[:]
		ab_chunk.pal_count = &chunk.pal_count
		ab_chunk.size = hd.size
	case.u1:
		chunk,ok:=hm.dynamic_get(&data.u1_chunk_data,hd.hd)
		if !ok{
			// log.log(.Error,"bad chunk data",hd,)
			ok = false
			return
		}
		ab_chunk.data = chunk.data[:]
		ab_chunk.pal  = chunk.pal[:]
		ab_chunk.pal_count = &chunk.pal_count
		ab_chunk.size = hd.size
	case.u2:
		chunk,ok:=hm.dynamic_get(&data.u2_chunk_data,hd.hd)
		if !ok{
			// log.log(.Error,"bad chunk data",hd,)
			ok = false
			return
		}
		ab_chunk.data = chunk.data[:]
		ab_chunk.pal  = chunk.pal[:]
		ab_chunk.pal_count = &chunk.pal_count
		ab_chunk.size = hd.size
	case.u4:
		chunk,ok:=hm.dynamic_get(&data.u4_chunk_data,hd.hd)
		if !ok{
			// log.log(.Error,"bad chunk data",hd,)
			ok = false
			return
		}
		ab_chunk.data = chunk.data[:]
		ab_chunk.pal  = chunk.pal[:]
		ab_chunk.pal_count = &chunk.pal_count
		ab_chunk.size = hd.size
	// case.u6:
	// 	chunk,ok:=hm.dynamic_get(&data.u6_chunk_data,hd.hd)
	// 	if !ok{
	// 		// log.log(.Error,"bad chunk data",hd,)
	// 		ok = false
	// 		return
	// 	}
	// 	ab_chunk.data = chunk.data[:]
	// 	ab_chunk.pal  = chunk.pal[:]
	// 	ab_chunk.pal_count = &chunk.pal_count
	// 	ab_chunk.size = hd.size
	case.u8:
		chunk,ok:=hm.dynamic_get(&data.u8_chunk_data,hd.hd)
		if !ok{
			// log.log(.Error,"bad chunk data",hd,)
			ok = false
			return
		}
		ab_chunk.data = chunk.data[:]
		ab_chunk.pal  = chunk.pal[:]
		ab_chunk.pal_count = &chunk.pal_count
		ab_chunk.size = hd.size
	// case.u10:
	// 	chunk,ok:=hm.dynamic_get(&data.u10_chunk_data,hd.hd)
	// 	if !ok{
	// 		// log.log(.Error,"bad chunk data",hd,)
	// 		ok = false
	// 		return
	// 	}
	// 	ab_chunk.data = chunk.data[:]
	// 	ab_chunk.pal  = chunk.pal[:]
	// 	ab_chunk.pal_count = &chunk.pal_count
	// 	ab_chunk.size = hd.size
	// case.u12:
	// 	chunk,ok:=hm.dynamic_get(&data.u12_chunk_data,hd.hd)
	// 	if !ok{
	// 		// log.log(.Error,"bad chunk data",hd,)
	// 		ok = false
	// 		return
	// 	}
	// 	ab_chunk.data = chunk.data[:]
	// 	ab_chunk.pal  = chunk.pal[:]
	// 	ab_chunk.pal_count = &chunk.pal_count
	// 	ab_chunk.size = hd.size
	// case.u14:
	// 	chunk,ok:=hm.dynamic_get(&data.u14_chunk_data,hd.hd)
	// 	if !ok{
	// 		// log.log(.Error,"bad chunk data",hd,)
	// 		ok = false
	// 		return
	// 	}
	// 	ab_chunk.data = chunk.data[:]
	// 	ab_chunk.pal  = chunk.pal[:]
	// 	ab_chunk.pal_count = &chunk.pal_count
	// 	ab_chunk.size = hd.size
	case.u16:
		chunk,ok:=hm.dynamic_get(&data.u16_chunk_data,hd.hd)
		if !ok{
			// log.log(.Error,"bad chunk data",hd,)
			ok = false
			return
		}
		ab_chunk.data = chunk.data[:]
		ab_chunk.pal  = chunk.pal[:]
		ab_chunk.pal_count = &chunk.pal_count
		ab_chunk.size = hd.size
	}
	ok = true
	return
}
new_chunk_vox_data::proc(data:^Chunks_Vox_Data, size:Palette_Sizes)->(new_p_hd:Palett_Chunk_HD,ok:bool){
	// Remove the old chunk from its old handle map.
	new_p_hd.size = size
	switch size {
	case .u0:
		hd, err := hm.dynamic_add(&data.u0_chunk_data,U0_Chunk_Data{pal=Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		new_p_hd.hd = hd
		if err != nil {
			log.log(.Error, "failed adding u0 chunk during err = ", err)
			return
		}
	case .u1:
		hd, err := hm.dynamic_add(&data.u1_chunk_data,U1_Chunk_Data{pal=Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		new_p_hd.hd = hd
		if err != nil {
			log.log(.Error, "failed adding u1 chunk during err = ", err)
			return
		}
	case .u2:
		hd, err := hm.dynamic_add(&data.u2_chunk_data,U2_Chunk_Data{pal=Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		new_p_hd.hd = hd
		if err != nil {
			log.log(.Error, "failed adding u2 chunk during err = ", err)
			return
		}
	case .u4:
		hd, err := hm.dynamic_add(&data.u4_chunk_data,U4_Chunk_Data{pal=Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		new_p_hd.hd = hd
		if err != nil {
			log.log(.Error, "failed adding u4 chunk during err = ", err)
			return
		}
	// case .u6:
	// 	hd, err := hm.dynamic_add(&data.u6_chunk_data,U6_Chunk_Data{pal=Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
	// 	new_p_hd.hd = hd
	// 	if err != nil {
	// 		log.log(.Error, "failed adding u6 chunk during err = ", err)
	// 		return
	// 	}
	case .u8:
		hd, err := hm.dynamic_add(&data.u8_chunk_data,U8_Chunk_Data{pal=Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		new_p_hd.hd = hd
		if err != nil {
			log.log(.Error, "failed adding u8 chunk during err = ", err)
			return
		}
	// case .u10:
	// 	hd, err := hm.dynamic_add(&data.u10_chunk_data,U10_Chunk_Data{pal=Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
	// 	new_p_hd.hd = hd
	// 	if err != nil {
	// 		log.log(.Error, "failed adding u10 chunk during err = ", err)
	// 		return
	// 	}
	// case .u12:
	// 	hd, err := hm.dynamic_add(&data.u12_chunk_data,U12_Chunk_Data{pal=Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
	// 	new_p_hd.hd = hd
	// 	if err != nil {
	// 		log.log(.Error, "failed adding u12 chunk during err = ", err)
	// 		return
	// 	}
	// case .u14:
	// 	hd, err := hm.dynamic_add(&data.u14_chunk_data,U14_Chunk_Data{pal=Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
	// 	new_p_hd.hd = hd
	// 	if err != nil {
	// 		log.log(.Error, "failed adding u14 chunk during err = ", err)
	// 		return
	// 	}
	case .u16:
		hd, err := hm.dynamic_add(&data.u16_chunk_data,U16_Chunk_Data{pal=Palette_Data{item={0,0},count=CHUNK_SIZE*CHUNK_SIZE*CHUNK_SIZE},pal_count = 1})
		new_p_hd.hd = hd
		if err != nil {
			log.log(.Error, "failed adding u16 chunk during err = ", err)
			return
		}
	}
	ok = true
	return
}
remove_chunk_data::proc(data:^Chunks_Vox_Data,p_hd:Palett_Chunk_HD)->(ok:bool){
	// Remove the old chunk from its old handle map.
	switch p_hd.size {
	case .u0:
		ok, err := hm.dynamic_remove(&data.u0_chunk_data, p_hd.hd)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,p_hd.hd)
			return false
		}
		if err != nil {
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err)
			return false
		}
	case .u1:
		ok, err := hm.dynamic_remove(&data.u1_chunk_data, p_hd.hd)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,p_hd.hd)
			return false
		}
		if err != nil {
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err)
			return false
		}

	case .u2:
		ok, err := hm.dynamic_remove(&data.u2_chunk_data, p_hd.hd)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,p_hd.hd)
			return false
		}
		if err != nil {
			log.log(.Error, "failed removing old u2 chunk during promotion, err = ", err)
			return false
		}

	case .u4:
		ok, err := hm.dynamic_remove(&data.u4_chunk_data, p_hd.hd)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,p_hd.hd)
			return false
		}
		if err != nil {
			log.log(.Error, "failed removing old u4 chunk during promotion, err = ", err)
			return false
		}

	// case .u6:
	// 	ok, err := hm.dynamic_remove(&data.u6_chunk_data, p_hd.hd)
	// 	if !ok{
	// 		log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,p_hd.hd)
	// 		return false
	// 	}
	// 	if err != nil {
	// 		log.log(.Error, "failed removing old u6 chunk during promotion, err = ", err)
	// 		return false
	// 	}

	case .u8:
		ok, err := hm.dynamic_remove(&data.u8_chunk_data, p_hd.hd)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,p_hd.hd)
			return false
		}
		if err != nil {
			log.log(.Error, "failed removing old u8 chunk during promotion, err = ", err)
			return false
		}

	// case .u10:
	// 	ok, err := hm.dynamic_remove(&data.u10_chunk_data, p_hd.hd)
	// 	if !ok{
	// 		log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,p_hd.hd)
	// 		return false
	// 	}
	// 	if err != nil {
	// 		log.log(.Error, "failed removing old u10 chunk during promotion, err = ", err)
	// 		return false
	// 	}

	// case .u12:
	// 	ok, err := hm.dynamic_remove(&data.u12_chunk_data, p_hd.hd)
	// 	if !ok{
	// 		log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,p_hd.hd)
	// 		return false
	// 	}
	// 	if err != nil {
	// 		log.log(.Error, "failed removing old u12 chunk during promotion, err = ", err)
	// 		return false
	// 	}

	// case .u14:
	// 	ok, err := hm.dynamic_remove(&data.u14_chunk_data, p_hd.hd)
	// 	if !ok{
	// 		log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,p_hd.hd)
	// 		return false
	// 	}
	// 	if err != nil {
	// 		log.log(.Error, "failed removing old u14 chunk during promotion, err = ", err)
	// 		return false
	// 	}

	case .u16:
		ok, err := hm.dynamic_remove(&data.u16_chunk_data, p_hd.hd)
		if !ok{
			log.log(.Error, "failed removing old u1 chunk during promotion, err = ", err,p_hd.hd)
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

// get_block_in_chunk::proc(data:^Chunks_Vox_Data,p_hd:Palett_Chunk_HD,pos:[3]int)->(item_hd:Item_HD){
// 	palettes_info:=PALETTES_INFO
// 	ab_chunk,ok:=get_chunk_vox_data(data,p_hd)
// 	if !ok{
// 		log.log(.Warning,"bad chunk data = {",data,"}","p_hd = ",p_hd,)
// 		return
// 	}

// 	vox_index := pos.x + pos.y*CHUNK_SIZE + pos.z*CHUNK_SIZE*CHUNK_SIZE

// 	// just some bounds checking for safty and ezy debuging
// 	if pos.x < 0 || pos.x >= CHUNK_SIZE || pos.y < 0 || pos.y >= CHUNK_SIZE || pos.z < 0 || pos.z >= CHUNK_SIZE {
// 		log.log(.Warning,"position outside chunk = ",pos," p_hd = ",p_hd)
// 		return
// 	}

// 	bits := palettes_info[ab_chunk.size].bits_per_vox

// 	if bits == 0{
// 		if ab_chunk.pal_count^ == 0{
// 			log.log(.Warning,"u0 chunk has empty palette, p_hd = ",p_hd)
// 			return
// 		}

// 		return ab_chunk.pal[0].item
// 	}

// 	bit_index := vox_index * bits
// 	byte_index := bit_index / 8
// 	bit_offset := bit_index % 8

// 	// Load enough bytes to cover the value.
// 	raw:u32 = 0

// 	for i in 0..<3{
// 		index := byte_index + i

// 		if index < len(ab_chunk.data){
// 			raw |= u32(ab_chunk.data[index]) << u32(i*8)
// 		}
// 	}

// 	mask := (u32(1) << u32(bits)) - 1
// 	pal_index := int((raw >> u32(bit_offset)) & mask)

// 	if pal_index >= len(ab_chunk.pal){
// 		log.log(.Warning,"bad palette index = ",pal_index,"palette len = ",len(ab_chunk.pal),"pos = ",pos,"p_hd = ",p_hd,)
// 		return
// 	}

// 	return ab_chunk.pal[pal_index].item
// }

get_block_in_chunk :: proc(data:^Chunks_Vox_Data,p_hd:Palett_Chunk_HD,pos:[3]int)->(item_hd:Item_HD){
	palettes_info:=PALETTES_INFO

	// just some bounds checking for safety and easy debugging
	if pos.x < 0 || pos.x >= CHUNK_SIZE || pos.y < 0 || pos.y >= CHUNK_SIZE || pos.z < 0 || pos.z >= CHUNK_SIZE {
		log.log(.Warning,"position outside chunk = ",pos," p_hd = ",p_hd)
		return
	}

	ab_chunk,ok:=get_chunk_vox_data(data,p_hd)
	if !ok{
		log.log(.Warning,"bad chunk data = ",data," p_hd = ",p_hd,)
		return
	}

	vox_index := pos.x + pos.y*CHUNK_SIZE + pos.z*CHUNK_SIZE*CHUNK_SIZE
	bits := palettes_info[ab_chunk.size].bits_per_vox

	if bits == 0{
		if ab_chunk.pal_count^ == 0{
			log.log(.Warning,"u0 chunk has empty palette, p_hd = ",p_hd)
			return
		}

		return ab_chunk.pal[0].item
	}

	pal_index:=get_palette_index(ab_chunk.data,bits,vox_index)

	if pal_index < 0 || pal_index >= int(ab_chunk.pal_count^){
		log.log(.Warning,"bad palette index = ",pal_index," palette count = ",ab_chunk.pal_count^," pos = ",pos," p_hd = ",p_hd,)
		return
	}

	return ab_chunk.pal[pal_index].item
}


// get_palette_index :: proc(data: []byte, bits: int, vox_index: int) -> int {
// 	if bits == 0 {
// 		return 0
// 	}

// 	bit_index := vox_index * bits
// 	byte_index := bit_index / 8
// 	bit_offset := bit_index % 8

// 	raw: u32 = 0

// 	for i in 0..<3 {
// 		index := byte_index + i
// 		if index < len(data) {
// 			raw |= u32(data[index]) << u32(i * 8)
// 		}
// 	}

// 	mask := (u32(1) << u32(bits)) - 1

// 	return int((raw >> u32(bit_offset)) & mask)
// }

get_palette_index :: proc(data: []byte,bits:int,vox_index:int)-> int {
	if bits == 0 {
		return 0
	}

	if bits <= 4 {
		vox_per_byte := 8 / bits
		byte_index := vox_index / vox_per_byte
		vox_in_byte := vox_index % vox_per_byte
		bit_offset := vox_in_byte * bits

		value := u32(data[byte_index])
		mask := (u32(1) << u32(bits)) - 1

		return int((value >> u32(bit_offset)) & mask)
	}

	if bits == 8 {
		return int(data[vox_index])
	}

	byte_index := vox_index * 2
	return int(u16(data[byte_index]) | u16(data[byte_index+1]) << 8)
}


// set_palette_index :: proc(data: []byte, bits: int, vox_index: int, pal_index: int) {
// 	if bits == 0 {
// 		return
// 	}

// 	bit_index := vox_index * bits
// 	byte_index := bit_index / 8
// 	bit_offset := bit_index % 8

// 	mask := (u32(1) << u32(bits)) - 1

// 	raw: u32 = 0

// 	for i in 0..<3 {
// 		index := byte_index + i
// 		if index < len(data) {
// 			raw |= u32(data[index]) << u32(i * 8)
// 		}
// 	}

// 	value_mask := mask << u32(bit_offset)

// 	raw = (raw & ~value_mask) |
// 		((u32(pal_index) & mask) << u32(bit_offset))

// 	for i in 0..<3 {
// 		index := byte_index + i
// 		if index < len(data) {
// 			data[index] = byte(raw >> u32(i * 8))
// 		}
// 	}
// }

set_palette_index :: proc(data: []byte,bits:int,vox_index:int,pal_index:int) {
	if bits == 0 {
		return
	}

	if bits <= 4 {
		vox_per_byte := 8 / bits
		byte_index := vox_index / vox_per_byte
		vox_in_byte := vox_index % vox_per_byte
		bit_offset := vox_in_byte * bits

		mask := (u32(1) << u32(bits)) - 1
		value_mask := byte(mask << u32(bit_offset))

		old_value := data[byte_index]
		new_value := byte((u32(pal_index) & mask) << u32(bit_offset))

		data[byte_index] = (old_value & ~value_mask) | new_value
		return
	}

	if bits == 8 {
		data[vox_index] = byte(pal_index)
		return
	}

	byte_index := vox_index * 2
	value := u16(pal_index)

	data[byte_index] = byte(value)
	data[byte_index+1] = byte(value >> 8)
}


promote_palette_chunk :: proc(
	data: ^Chunks_Vox_Data,
	old_hd: Palett_Chunk_HD,
	new_size: Palette_Sizes,
) -> (new_hd: Palett_Chunk_HD, ok: bool) {
	paletes_info:=PALETTES_INFO
	new_hd_ok:bool
	new_hd,new_hd_ok= new_chunk_vox_data(data, new_size)
	if !new_hd_ok{
		log.log(.Warning, "cant get new_hd failed promoting chunk to new_size=",new_size,"has failed old_hd =",old_hd,"new_hd =",new_hd)
		return
	}
	new_chunk,new_chunk_ok:=get_chunk_vox_data(data, new_hd)
	if !new_chunk_ok{
		log.log(.Warning, "cant get new_chunk failed promoting chunk to new_size=",new_size,"has failed old_hd =",old_hd,"new_hd =",new_hd)
		return
	}
	old_chunk,old_chunk_ok:=get_chunk_vox_data(data, old_hd)
	if !old_chunk_ok{
		log.log(.Warning, "cant get old_chun failed promoting chunk to new_size =",new_size,"has failed old_hd =",old_hd,"new_hd =",new_hd)
		return
	}

	copy(new_chunk.pal[:old_chunk.pal_count^],old_chunk.pal[:old_chunk.pal_count^])
	new_chunk.pal_count^ = old_chunk.pal_count^

	old_bits := paletes_info[old_chunk.size].bits_per_vox
	new_bits := paletes_info[new_chunk.size].bits_per_vox

	if old_bits != 0 {
		num_voxels := CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE
		for vox_index in 0..<num_voxels {
			pal_index := get_palette_index(old_chunk.data,old_bits,vox_index)
			set_palette_index(new_chunk.data,new_bits,vox_index,pal_index)
		}
	}

	ok = true
	return

}



set_block_in_chunk :: proc(
    data: ^Chunks_Vox_Data,
    p_hd: ^Palett_Chunk_HD,
    pos: [3]int,
    item_hd: Item_HD,
) -> bool {
	paletes_info:=PALETTES_INFO

    // ------------------------------------------------------------
    // Bounds check
    if pos.x < 0 || pos.x >= CHUNK_SIZE || pos.y < 0 || pos.y >= CHUNK_SIZE || pos.z < 0 || pos.z >= CHUNK_SIZE {
        log.log(.Warning,"position outside chunk = ",pos," p_hd = ",p_hd^,)
        return false
    }

    // ------------------------------------------------------------
    // Get the current chunk
    ab_chunk, ok := get_chunk_vox_data(data, p_hd^)
    if !ok {
        log.log(.Warning,"bad chunk data = ",data," p_hd = ",p_hd^,)
        return false
    }

    vox_index := pos.x + pos.y * CHUNK_SIZE + pos.z * CHUNK_SIZE * CHUNK_SIZE

    bits := paletes_info[ab_chunk.size].bits_per_vox

    // ------------------------------------------------------------
    // u0 means every voxel has palette index 0.
    // There is no voxel data buffer.
    if bits == 0 {
        if ab_chunk.pal_count^ == 0 {
            log.log(.Error,"u0 chunk has empty palette, p_hd = ",p_hd^,)
            return false
        }

        // Nothing needs to change.
        if ab_chunk.pal[0].item == item_hd {
            return true
        }

        // The chunk must become at least u1.
        next_size, next_ok := get_next_palett_size(ab_chunk.size)
        if !next_ok {
            log.log(.Error,"could not promote u0 chunk, p_hd = ",p_hd^,)
            return false
        }

        new_hd, promoted := promote_palette_chunk(data,p_hd^,next_size,)
        if !promoted {
            log.log(.Error,"failed promoting u0 chunk, p_hd = ",p_hd^,)
            return false
        }
        old_hd := p_hd^
        // The new chunk is now active.
        p_hd^ = new_hd
        // Remove the old u0 chunk.
        if !remove_chunk_data(data, old_hd) {
            log.log(.Error,"failed removing old u0 chunk, old_hd = ",old_hd,)
            return false
        }

        // Continue the operation on the promoted chunk.
        return set_block_in_chunk(data,p_hd,pos,item_hd,)
    }

// ------------------------------------------------------------
    // Read the old palette index BEFORE modifying the palette.
    old_pal_index := get_palette_index(ab_chunk.data,bits,vox_index,)
    if old_pal_index < 0 || old_pal_index >= int(ab_chunk.pal_count^) {
        log.log(.Warning,"bad old palette index = ",old_pal_index," palette count = ",ab_chunk.pal_count^," pos = ",pos," p_hd = ",p_hd^,)
        return false
    }

// ------------------------------------------------------------
    // Find the new palette entry.
    new_pal_index := -1
    for i in 0..<int(ab_chunk.pal_count^) {
        if ab_chunk.pal[i].item == item_hd {
            new_pal_index = i
            break
        }
    }

// ------------------------------------------------------------
    // Nothing changes.
    if new_pal_index == old_pal_index {
        return true
    }
// ------------------------------------------------------------
    // Item isn't in the palette.
    // Try to add it. If the palette is full, promote the chunk.
    if new_pal_index < 0 {
        new_pal_index, ok = add_palette_entry(&ab_chunk,item_hd,)
        if !ok {
            next_size, next_ok := get_next_palett_size(ab_chunk.size,)
            if !next_ok {
                log.log(.Error,"palette is full and cannot be promoted, p_hd = ",p_hd^,)
                return false
            }
            old_hd := p_hd^
            new_hd, promoted := promote_palette_chunk(data,old_hd,next_size,)
            if !promoted {
                log.log(.Error,"failed promoting palette, p_hd = ",old_hd,)
                return false
            }
            // Switch the caller's handle to the new chunk.
            p_hd^ = new_hd
            // The old chunk is no longer needed.
            if !remove_chunk_data(data, old_hd) {
                log.log(.Error,"failed removing old chunk after promotion, old_hd = ",old_hd,)
                return false
            }
            // Re-run against the new palette.
            return set_block_in_chunk(data,p_hd,pos,item_hd,)
        }
    }

// ------------------------------------------------------------
    // Update palette reference counts.
    if ab_chunk.pal[old_pal_index].count == 0 {
        log.log(.Warning,"old palette entry has zero references, old_pal_index = ",old_pal_index," pos = ",pos," p_hd = ",p_hd^,)
    } else {
        ab_chunk.pal[old_pal_index].count -= 1
    }

    ab_chunk.pal[new_pal_index].count += 1

// ------------------------------------------------------------
    // Write the new packed palette index.
    set_palette_index(ab_chunk.data,bits,vox_index,new_pal_index,)
    return true
}

add_palette_entry :: proc(
	chunk: ^Chunk_Abstract,
	item_hd: Item_HD,
) -> (pal_index: int, ok: bool) {

	pal_count := int(chunk.pal_count^)

	// See if the item is already in the palette.
	for i in 0..<pal_count {
		if chunk.pal[i].item == item_hd {
			return i, true
		}
	}

	// Palette is full.
	if pal_count >= len(chunk.pal) {
		return -1, false
	}

	pal_index = pal_count

	chunk.pal[pal_index] = Palette_Data{
		item  = item_hd,
		count = 0,
	}

	chunk.pal_count^ += 1

	return pal_index, true
}

//returns false if there is no next size
get_next_palett_size::proc(size:Palette_Sizes)->(next_size:Palette_Sizes, ok:bool){
	next_size=cast(Palette_Sizes)(cast(u8)size+1)
	if next_size > Palette_Sizes.u16{
		ok = false
		log.log(.Warning,"no next palette size")
		return 
	}
	 ok = true
	return
}

get_prev_palett_size::proc(size:Palette_Sizes)->(prev_size:Palette_Sizes, ok:bool){
	prev_size=cast(Palette_Sizes)(cast(u8)size-1)
	if prev_size > Palette_Sizes.u16|| prev_size < Palette_Sizes.u0{
		ok = false
		log.log(.Warning,"no prev palette size")
		return 
	}
ok = true
	return
}
