package tg_render

import sdl "vendor:sdl3"
import "core:log"
// import "core:mem"
import str"core:strings"
import "core:fmt"
// import "core:math"
import "core:path/filepath"
import "core:encoding/json"
// import lin"core:math/linalg"
import "base:runtime"
import hm "handle_map_static_virtual"
import "core:os"

// import sc"shader_cross"

// import "core:image"
// import "core:image/jpeg"
// import "core:image/bmp"
// import "core:image/png"
// import "core:image/tga"
Shader_Handle :: distinct Handle
Shader :: struct{
	handle: Shader_Handle,
	shader:^sdl.GPUShader,
	shader_info:Shader_Info,
}

Shader_Info :: struct {
	samplers: u32,
	storage_textures: u32,
	storage_buffers: u32,
	uniform_buffers: u32,
	inputs:[dynamic]struct{
		name:string,
		type:Vertex_Element_Format_json, //needs to be cast to sdl.GPUVertexElementFormat
		// type_t:sdl.GPUVertexElementFormat,
		location:u32,
	},
	
	vertex_type:typeid,
	vertex_info:[]Vertex_Attrs_Info,
}

Vertex_Attrs_Info::struct{
	offset:u32,
	buff_slot:u32,
}
destroy_shader::proc(shader:^Shader){
	sdl.ReleaseGPUShader(s.gpu_device, shader.shader)
	// delete
}

get_shader::proc(shader_hd:Shader_Handle) -> (shader:^Shader){
	shader = hm.get(s.shaders,shader_hd)
	return shader
}

load_shader::proc(
	data:[]u8,
	info:Shader_Info,
	stage:sdl.GPUShaderStage,
	format:sdl.GPUShaderFormatFlag = .SPIRV,
	entrypoint:string = "main",
)->(shader_hd:Shader_Handle){

	entrypoint:=frame_cstring(entrypoint)
	shader_sdl:=sdl.CreateGPUShader(s.gpu_device,{
		code_size = len(data),
		code = raw_data(data),
		entrypoint = entrypoint,
		format = {format},
		stage = stage,
		num_uniform_buffers = info.uniform_buffers,
		num_samplers = info.samplers,
		num_storage_buffers = info.storage_buffers,
		num_storage_textures = info.storage_textures,
	})
	shader_data:Shader={
		shader_info = info,
		shader=shader_sdl,
	}
	shader_hd = hm.add(&s.shaders,shader_data)
	return
}

load_shader_file::proc(
	file_path:string,
	vertex_type:typeid,
	attrs_info:[]Vertex_Attrs_Info = nil,
	// stage:sdl.GPUShaderStage,
	// num_uniform_buffers:u32= 1,
	// num_samplers:u32= 0,
	// format:sdl.GPUShaderFormatFlag = {.SPIRV},
	// entrypoint:string = "main"
)->(shader_hd:Shader_Handle){

	format:sdl.GPUShaderFormatFlag
	format_ext:string
	stage:sdl.GPUShaderStage
	entrypoint:string = "main"
	
	switch filepath.ext(file_path){
	case ".vert":
		stage = .VERTEX
	case ".frag":
		stage = .FRAGMENT
	}
	
	suported_formats:= sdl.GetGPUShaderFormats(s.gpu_device)
	if .SPIRV in suported_formats{
		format = .SPIRV
		format_ext = ".spv"
	}else if .MSL in suported_formats{
		format = .MSL
		format_ext = ".msl"
		entrypoint = "main0"
	}else if .DXIL in suported_formats{
		format = .DXIL
		format_ext = ".dxil"
	}else{
		log.panicf("NO Suported Shader Format {}", suported_formats)
	}
	
	info:Shader_Info=load_shader_info(file_path)
	info.vertex_type = vertex_type
	info.vertex_info = attrs_info
	
	true_file_path:=str.concatenate({file_path, ".spv"},s.frame_allocator)
	data,ok:=os.read_entire_file_from_filename(true_file_path,s.frame_allocator)
	if !ok {
		true_file_path=str.concatenate({SHADER_PATH, true_file_path},s.frame_allocator)
		data,ok=os.read_entire_file_from_filename(true_file_path,s.frame_allocator)
		if !ok{ log.error("cant find ",file_path, " or ", true_file_path) }
	}
	shader_hd=load_shader(data = data, stage = stage, info = info, format = format, entrypoint=entrypoint)
	return shader_hd
}

load_shader_info :: proc(shaderfile: string) -> (result:Shader_Info) {

	json_filename := str.concatenate({shaderfile, ".json"}, s.frame_allocator)
	json_data, ok := os.read_entire_file_from_filename(json_filename, s.frame_allocator)
	if !ok{
		json_filename = str.concatenate({SHADER_PATH, shaderfile, ".json"}, s.frame_allocator)
		json_data, ok = os.read_entire_file_from_filename(json_filename, s.frame_allocator)
		if !ok{ log.error("cant find ",shaderfile," or ",json_filename) }
	}
	err := json.unmarshal(json_data, &result, allocator = s.frame_allocator); assert(err == nil)
	if err != nil{
		log.error("cant unmarshal" ,shaderfile)
	}

	return result
}

reset_frame_allocator :: proc() {
	free_all(s.frame_allocator)
}

// this only exsits to make parsing the json ezyer
Vertex_Element_Format_json :: enum i32 {
	INVALID,

	/* 32-bit Signed Integers */
	INT,
	INT2,
	INT3,
	INT4,

	/* 32-bit Unsigned Integers */
	UINT,
	UINT2,
	UINT3,
	UINT4,

	/* 32-bit Floats */
	float,
	float2,
	float3,
	float4,

	/* 8-bit Signed Integers */
	BYTE2,
	BYTE4,

	/* 8-bit Unsigned Integers */
	UBYTE2,
	UBYTE4,

	/* 8-bit Signed Normalized */
	BYTE2_NORM,
	BYTE4_NORM,

	/* 8-bit Unsigned Normalized */
	UBYTE2_NORM,
	UBYTE4_NORM,

	/* 16-bit Signed Integers */
	SHORT2,
	SHORT4,

	/* 16-bit Unsigned Integers */
	USHORT2,
	USHORT4,

	/* 16-bit Signed Normalized */
	SHORT2_NORM,
	SHORT4_NORM,

	/* 16-bit Unsigned Normalized */
	USHORT2_NORM,
	USHORT4_NORM,

	/* 16-bit Floats */
	HALF2,
	HALF4,
}
