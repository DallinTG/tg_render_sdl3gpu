package tg_render

import "base:runtime"
import "core:bytes"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:os"
import str"core:strings"
import "core:path/slashpath"
import "core:fmt"
import "core:reflect"
import lin"core:math/linalg"
import "core:hash"
import an"ansi"
import "core:image"
import "core:image/jpeg"
import "core:image/bmp"
import "core:image/png"
import "core:image/tga"

import stb"vendor:stb/image"

// import hm "handle_map_static_virtual"
import hm "core:container/handle_map"
import reg "registry"


Texture_GPU_Handle :: distinct Handle
Texture_HD :: distinct Handle


// Texture_Groop :: hm.Handle_Map(Texture_GPU_Data, Texture_GPU_Handle, 1024*10)
Texture_Groop :: hm.Dynamic_Handle_Map(Texture_GPU_Data, Texture_GPU_Handle)
Texture_Arr_Groop::enum{
	tex_8x8,
	tex_16x16,
	tex_32x32,
	tex_64x64,
	tex_128x128,
	// tex_184x184,
	tex_256x256,
	tex_512x512,
	tex_1024x1024,
	tex_2048x2048,
	tex_4096x4096,
	font_256x256,
}
TEXTURE_ARR_INFO:[Texture_Arr_Groop]Texture_Setup:{
	.tex_8x8 =       {w_h = {8, 8},       layer_count = 100 ,format = .R8G8B8A8_UNORM},
	.tex_16x16 =     {w_h = {16, 16},     layer_count = 2000 ,format = .R8G8B8A8_UNORM},
	.tex_32x32 =     {w_h = {32, 32},     layer_count = 100 ,format = .R8G8B8A8_UNORM},
	.tex_64x64 =     {w_h = {64, 64},     layer_count = 100 ,format = .R8G8B8A8_UNORM},
	.tex_128x128 =   {w_h = {128, 128},   layer_count = 100 ,format = .R8G8B8A8_UNORM},
	// .tex_184x184 =   {w_h = {184, 184},   layer_count = 100 ,format = .R8G8B8A8_UNORM},
	.tex_256x256 =   {w_h = {256, 256},   layer_count = 100  ,format = .R8G8B8A8_UNORM},
	.tex_512x512 =   {w_h = {512, 512},   layer_count = 10  ,format = .R8G8B8A8_UNORM},
	.tex_1024x1024 = {w_h = {1024, 1024}, layer_count = 10  ,format = .R8G8B8A8_UNORM},
	.tex_2048x2048 = {w_h = {2048, 2048}, layer_count = 1   ,format = .R8G8B8A8_UNORM},
	.tex_4096x4096 = {w_h = {4096, 4096}, layer_count = 1   ,format = .R8G8B8A8_UNORM},
	.font_256x256 = {w_h =  {256, 256},   layer_count = 10  ,format = .R8_UNORM},
	
}
Texture_Arr_Data::struct{
	tex_hd:Texture_GPU_Handle,
	layers_used:u32,
	format:sdl.GPUTextureFormat,
}
Texture_Setup::struct{
	w_h:[2]u32,
	layer_count:u32,
	format:sdl.GPUTextureFormat,
}

Texture_ID_Types::union{
	string,
	[2]string,
	u32,
	[2]u32,
	Textures_E,
	Icons_E,
}

Texture :: struct {
	handle: Texture_HD,
	reg_id:reg.Reg_ID,
	id:		[2]u32,
	hd:     Texture_GPU_Handle,
	layer:  u32,
	groop_index:Texture_Arr_Groop,
	w_h:    [2]i32,
	offset: [2]i32,
}

Texture_GPU_Data::struct{
	handle: Texture_GPU_Handle,

	format: sdl.GPUTextureFormat,
	data:^sdl.GPUTexture,
	layer_count:u32,
	w:u32,
	h:u32,
}

Load_Texture_Option :: enum {
	// Will multiply the alpha value of the each pixel into the its RGB values. Useful if you want
	// to use `set_blend_mode(.Premultiplied_Alpha)`
	Premultiply_Alpha,
}
Load_Texture_Options :: bit_set[Load_Texture_Option]
TEXTURE_NONE :: Texture_GPU_Handle {}

init_texture_arr_groop::proc(){
	TEXTURE_ARR_INFO:=TEXTURE_ARR_INFO
	for &tex, i in &s.texture_arr_groop{
		h:=TEXTURE_ARR_INFO[i].w_h.x
		w:=TEXTURE_ARR_INFO[i].w_h.x
		l_c:=TEXTURE_ARR_INFO[i].layer_count
		format:=TEXTURE_ARR_INFO[i].format
		s.texture_arr_groop[i].tex_hd = create_gpu_texture(width = w,height = h , layer_count = l_c , type = .D2_ARRAY, format = format)
		s.texture_arr_groop[i].format = format
	}

}

// This adds the img data to the gpu and then lets you draw it whith a Texture_ID_Types whitch is created by {filename: string,mod_name: string}
reg_texture_from_file::proc(filename: string,mod_name: string = "")->(hd:Texture_HD,raw_id:[2]u32){
	ARR_INFO:=TEXTURE_ARR_INFO
	img, img_err:=load_cpu_texture_file(filename)
	tex_id:=str.trim_suffix(filename,".png")
	tex_id=str.to_lower(tex_id,s.frame_allocator)
	id:[2]string={tex_id,mod_name}
	hd,raw_id=reg_texture_from_bits(img,id)
	return hd,raw_id
}

reg_all_texture_from_dir_path::proc(dir: string,mod_name: string = ""){
	all_fil_info,err:=os.read_all_directory_by_path(dir, context.temp_allocator)
	if err != nil{
		log.log(.Warning,"\nreg_all_texture_from_dir failed",err,"\n\n\n\n\n")
		return
	}
	for &fil in all_fil_info{
		if fil.type ==.Regular{
			temp_path:=[2]string{dir, fil.name}
			path,err:=os.join_path(temp_path[:],context.temp_allocator)
			if err == nil{
				reg_texture_from_file(path,mod_name)
			}
		}else{

		}
	}
	return
}

reg_all_texture_from_loaded_directory::proc(all_fil_info: []runtime.Load_Directory_File,mod_name: string = "",extra_info:^[$Enum_T]Image){
	for &fil in all_fil_info{
		img,err:=image.load_from_bytes(fil.data,{},context.temp_allocator)
		if err != nil{
			assert(err == nil, fmt.tprint("image.load_from_bytes() has faild on file:",fil.name,err,"\n\n"))
			continue
		}
		hd,id:=reg_texture_from_bits(img,[2]string{mod_name,fil.name})
		enum_v,ok:=reflect.enum_from_name(Enum_T,format_string(fil.name,".png"))

		if ok{

			extra_info[enum_v].hd = hd
			extra_info[enum_v].id = id
		}else{
			log.log(.Warning,"bad Enum",fil.name,"\n",str.trim_suffix(fil.name,".png"),"\n")
		}
	}
	return
}

format_string::proc(str_:string, remove_suffix:string="")->(new_str:string){
	ok:bool
	new_str,ok=str.replace_all(str.trim_suffix( str.to_ada_case(slashpath.name(str_),context.temp_allocator),remove_suffix),".","_",context.temp_allocator)
	return
}

// This adds the img data to the gpu and then lets you draw it whith {tex_id:Texture_ID_Types}
reg_texture_from_bits::proc(img: ^image.Image,tex_id:Texture_ID_Types, format: sdl.GPUTextureFormat = .R8G8B8A8_UNORM,)->(hd:Texture_HD,raw_id:[2]u32,){
	assert(img != nil,fmt.tprint("img data is nil"," tex_id:",tex_id))
	id:=get_texture_id(tex_id)
	ARR_INFO:=TEXTURE_ARR_INFO
	// tex_map:=&s.texture_arr_map
	tex_groop:=&s.texture_arr_groop
	for &tex, i in tex_groop{
		if cast(u32)img.width <= ARR_INFO[i].w_h.x && cast(u32)img.height <= ARR_INFO[i].w_h.y && ARR_INFO[i].format == format{

			chanle_count:=4
			if format == .R8_UNORM{
				chanle_count = 1
			}
			if  reg.has_id(&s.textures_reg,id) {	//check if somthing is allredy using that id if so replace it insted of making a new one
				hd=reg.get_hd(&s.textures_reg,id)
				text:=reg.get(&s.textures_reg,hd)
				uplode_data_to_gpu_texture(tex.tex_hd, img.pixels.buf[:], img.width, img.height, layer = text.layer, chanle_count = chanle_count)
				raw_id = id
			}else{
				if tex.layers_used + 1 >ARR_INFO[i].layer_count{ // Stops the game frome alocating more than the max textures
					fmt.print(an.ansy("max Number of textures reached for:",col = .red),cast(Texture_Arr_Groop)i,"count:",tex.layers_used,"Max Count:",ARR_INFO[i].layer_count," \n")
					return Texture_HD{0,0},[2]u32{0,0}
				}
				uplode_data_to_gpu_texture(tex.tex_hd, img.pixels.buf[:], img.width, img.height, layer = tex.layers_used, chanle_count = chanle_count)
				value:=Texture{
					id = id,
					hd = tex.tex_hd,
					layer = tex.layers_used,
					groop_index = i,
					w_h = {cast(i32)img.width,cast(i32)img.height},
					offset = {cast(i32)ARR_INFO[i].w_h.x- cast(i32)img.width ,cast(i32)ARR_INFO[i].w_h.x-cast(i32)img.width },
				}
				hd=reg.add(&s.textures_reg,value,id)
				raw_id = id
				tex.layers_used += 1
			}
			return hd, raw_id
		}
	}
	return Texture_HD{0,0},[2]u32{0,0}
}
reg_bad_defalt_texture::proc(){
	per:[4]u8:{255,0,255,255}
	pixles:[][4]u8={
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
	}
	img,ok:=image.pixels_to_image(pixles[:],8,8)
	hd,_:=reg_texture_from_bits(&img,[2]u32{0,0})
	s.bad_texture_hd = hd
}
reg_white_defalt_texture::proc(){
	per:[4]u8:{255,255,255,255}
	pixles:[][4]u8={
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
		per, per, per, per, per, per, per, per,
	}
	img,ok:=image.pixels_to_image(pixles[:],8,8)
	hd,_:=reg_texture_from_bits(&img,[2]u32{0,1})
	s.white_texture_hd = hd
}

//this is slow and you should use get_texture_by_hd() insted
get_texture_by_id::proc(tex_id:Texture_ID_Types)->(tex:^Texture){//TODO THIS NEEDS TO BE REWORKED
	ok:bool
	tex = reg.get_by_id(&s.textures_reg,get_texture_id(tex_id))
	if tex == nil{
		tex = reg.get_by_id(&s.textures_reg,get_texture_id([2]u32{0,1}))
	}
	return
}
get_texture::proc(tex_hd:Texture_HD)->(tex:^Texture){//TODO THIS NEEDS TO BE REWORKED
	tex = reg.get(&s.textures_reg,tex_hd)
	if tex==nil{
		tex = reg.get(&s.textures_reg,s.bad_texture_hd)
		assert(tex!=nil,"bad get_texture()")
	}
	return
}
get_texture_id::proc(tex_id:Texture_ID_Types)->(new_tex_id:[2]u32){
	mod_id_u32:u32
	tex_id_u32:u32
	switch id in tex_id {
	case string:
		tex_id_u32 = hash.murmur32(transmute([]u8)id)
	case [2]string:
		tex_id_u32 = hash.murmur32(transmute([]u8)id.y)
		if id.x == ""{
			mod_id_u32 = 0
		}else{
			mod_id_u32 = hash.murmur32(transmute([]u8)id.x)
		}
	case u32:
		tex_id_u32 = id
	case [2]u32:
		tex_id_u32 = id.y
		mod_id_u32 = id.x
	case Icons_E:
		mod_id_u32 =Icons_Data[id].id.x
		tex_id_u32 =Icons_Data[id].id.y
	case Textures_E:
		mod_id_u32 =Textures_Data[id].id.x
		tex_id_u32 =Textures_Data[id].id.y 
	}
	new_tex_id = {mod_id_u32,tex_id_u32}
	return
}

// THIS is a internal helper proc you shiuld problobly us 
// reg_texture_from_bits() or reg_texture_from_file()
load_texture_from_file :: proc(filename: string, options: Load_Texture_Options = {}) -> Texture_GPU_Handle {
	img, img_err :=load_cpu_texture_file(filename, options)
	if img_err != nil {
		log.errorf("Error loading texture '%v': %v", filename, img_err)
		return {0,0}
	}
	return load_texture_from_bytes_raw(img.pixels.buf[:], img.width, img.height, .R8G8B8A8_UNORM)
}

// THIS is a internal helper proc you shiuld problobly us 
// reg_texture_from_bits() or reg_texture_from_file()
load_cpu_texture_file :: proc(filename: string, options: Load_Texture_Options = {}) -> (img:^image.Image, img_err:image.Error) {
	when FILESYSTEM_SUPPORTED {
		load_options := image.Options {
			.alpha_add_if_missing,
		}
		if .Premultiply_Alpha in options {
			load_options += { .alpha_premultiply }
		}
		img, img_err = image.load_from_file(filename, options = load_options, allocator = s.frame_allocator)
		if img_err != nil{
			true_file_path:=str.concatenate({TEXTUR_PATH, filename},s.frame_allocator)
			img, img_err = image.load_from_file(true_file_path, options = load_options, allocator = s.frame_allocator)
			if img_err != nil{log.error("cant find ",filename)}
		}
		if img_err != nil {
			log.errorf("Error loading texture '%v': %v", filename, img_err)
			return {}, img_err
		}

		return
	} else {
		log.errorf("load_texture_from_file failed: OS %v has no filesystem support! Tip: Use load_texture_from_bytes(#load(\"the_texture.png\")) instead.", ODIN_OS)
		return {}
	}
}

// THIS is a internal helper proc you shiuld problobly us 
// reg_texture_from_bits() or reg_texture_from_file()
load_texture_from_bytes :: proc(bytes:union{[][]u8,[]u8}, options: Load_Texture_Options = {}, layer_count:u32 = 1, layer:u32 = 0) -> (texture:Texture_GPU_Handle) {
	load_options := image.Options {
		.alpha_add_if_missing,
	}
	if .Premultiply_Alpha in options {
		load_options += { .alpha_premultiply }
	}
	
	img:^image.Image 
	buf_buf:[dynamic][]u8
	defer delete(buf_buf)
	img_err:image.Error
	switch byte in bytes{
	case []u8:
		img, img_err = image.load_from_bytes(byte, options = load_options, allocator = s.frame_allocator)
	case [][]u8:
		for byt , i in byte{
			img, img_err = image.load_from_bytes(byt, options = load_options, allocator = s.frame_allocator)
			append_elems(&buf_buf,img.pixels.buf[:])
		}
	}
	

	if img_err != nil {
		log.errorf("Error loading texture: %v", img_err)
		return {}
	}
	switch byte in bytes{
	case []u8:
		texture = load_texture_from_bytes_raw(img.pixels.buf[:], img.width, img.height, .R8G8B8A8_UNORM, layer_count = layer_count)
	case [][]u8:
		texture = load_texture_from_bytes_raw(buf_buf[:], img.width, img.height, .R8G8B8A8_UNORM, layer_count = layer_count)
	}
	return
}

// THIS is a internal helper proc you shiuld problobly us 
// reg_texture_from_bits() or reg_texture_from_file()
load_texture_array_from_file :: proc(filename:string, options: Load_Texture_Options = {}) -> (texture:Texture_GPU_Handle) {
	
	when FILESYSTEM_SUPPORTED {
		load_options := image.Options {
			.alpha_add_if_missing,
		}

		if .Premultiply_Alpha in options {
			load_options += { .alpha_premultiply }
		}
		
		img, img_err := image.load_from_file(filename, options = load_options, allocator = s.frame_allocator)
		if img_err != nil{
			true_file_path:=str.concatenate({TEXTUR_PATH, filename},s.frame_allocator)
			img, img_err = image.load_from_file(true_file_path, options = load_options, allocator = s.frame_allocator)
			if img_err != nil{log.error("cant find ",filename)}
		}
		if img_err != nil {
			log.errorf("Error loading texture '%v': %v", filename, img_err)
			return {}
		}

		texture = load_texture_from_bytes_raw(img.pixels.buf[:], img.width, img.height, .R8G8B8A8_UNORM)
	} else {
		log.errorf("load_texture_from_file failed: OS %v has no filesystem support! Tip: Use load_texture_from_bytes(#load(\"the_texture.png\")) instead.", ODIN_OS)
		texture = {}
	}

	return
}

// THIS is a internal helper proc you shiuld problobly us 
// reg_texture_from_bits() or reg_texture_from_file()
load_texture_from_bytes_raw :: proc(
	bytes: union{[][]u8,[]u8}, 
	width: int, 
	height: int, 
	format: sdl.GPUTextureFormat  = .R8G8B8A8_UNORM, 
	type:sdl.GPUTextureType = .D2,
	layer_count: u32 = 1,
) -> (texture:Texture_GPU_Handle) {

	texture = create_gpu_texture(
		width = cast(u32)width,
		height = cast(u32)height,
		format = format,
		type = type,
		layer_count = layer_count,
	)
	if texture == TEXTURE_NONE {
		return {}
	}
	// texture_ptr := hm.get(s.textures, texture.handle)
	switch byte in bytes{
	case []u8:
		uplode_data_to_gpu_texture(texture,byte,width,height)
	case [][]u8:
		for byt in byte{
			uplode_data_to_gpu_texture(texture,byt,width,height)
		}
	}
	return
}

// THIS is a internal helper proc you shiuld problobly us 
// reg_texture_from_bits() or reg_texture_from_file()
create_gpu_texture::proc(
	width: u32, 
	height: u32, 
	format: sdl.GPUTextureFormat  = .R8G8B8A8_UNORM, 
	type:sdl.GPUTextureType = .D2,
	layer_count: u32 = 1,
	texture_groop:^Texture_Groop = nil,
) -> (Texture_GPU_Handle){
	texture_groop:=texture_groop
	if texture_groop == nil{
		texture_groop = &s.texture_groop
	}
	assert(width > 0 && height > 0,"create_gpu_texture failed w_h must be width > 0 && height > 0")
	tex := sdl.CreateGPUTexture(s.gpu_device,createinfo={
		type = type,
		format=format,
		usage = {.SAMPLER},
		width = width,
		height = height,
		layer_count_or_depth = layer_count,
		num_levels = 1,
	})
	texture_data:Texture_GPU_Data={
		w=width,
		h=height,
		layer_count = layer_count,
		format=format,
		data=tex,
	}
	backend_tex := hm.add(texture_groop, texture_data)
	
	return backend_tex
}

// THIS is a internal helper proc you shiuld problobly us 
// reg_texture_from_bits() or reg_texture_from_file()
uplode_data_to_gpu_texture::proc(texture:Texture_GPU_Handle,	bytes: []u8, width: int, height: int, layer:u32 = 0,chanle_count:int = 4){
	tex_ptr := get_gpu_texture(texture)
	assert(cast(u32)width<=tex_ptr.w && cast(u32)height<=tex_ptr.h,"texture data must be = or < texture ")
	assert(s.gpu_device != nil, "s.gpu_device dos not exsist")
	pixels_byte_size := width * height * chanle_count
	tex_transfer_buf := sdl.CreateGPUTransferBuffer(s.gpu_device,{
		usage = .UPLOAD,
		size = cast(u32)(pixels_byte_size),
	})
	tex_transfer_mem := sdl.MapGPUTransferBuffer(s.gpu_device, tex_transfer_buf, false)
	mem.copy(tex_transfer_mem, raw_data(bytes), pixels_byte_size)
	sdl.UnmapGPUTransferBuffer(s.gpu_device, tex_transfer_buf)
	copy_cmd_buf := sdl.AcquireGPUCommandBuffer(s.gpu_device)
	copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)

	sdl.UploadToGPUTexture(copy_pass, 
		{transfer_buffer = tex_transfer_buf},
		{texture = tex_ptr.data, layer = layer, w = cast(u32)width, h = cast(u32)height, d = 1},
		false,
	)
	sdl.EndGPUCopyPass(copy_pass)
	ok := sdl.SubmitGPUCommandBuffer(copy_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")
	sdl.ReleaseGPUTransferBuffer(s.gpu_device, tex_transfer_buf)
}

destroy_texture :: proc(th: Texture_GPU_Handle, texture_groop:^Texture_Groop = nil) {
	texture_groop:=texture_groop
	if texture_groop == nil{
		texture_groop = &s.texture_groop
	}
	tex := hm.get(texture_groop, th)

	if tex == nil {
		return
	}
	// Free the GPU resource
    sdl.ReleaseGPUTexture(s.gpu_device, tex.data)
    
	hm.remove(texture_groop, th)
}

get_gpu_texture::proc(tex_h:Texture_GPU_Handle,texture_groop:^Texture_Groop = nil,)->(data:^Texture_GPU_Data){
	texture_groop:=texture_groop
	if texture_groop == nil{
		texture_groop = &s.texture_groop
	}
	return hm.get(&s.texture_groop,tex_h)
}






FILESYSTEM_SUPPORTED :: ODIN_OS != .JS && ODIN_OS != .Freestanding
