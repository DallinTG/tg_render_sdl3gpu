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

Mesh_Handle :: distinct Handle

// Mesh_CPU::struct{
// 	vertex_buf:[dynamic]u8,
// 	index_buf:[dynamic]u8,
// 	attribute_type:typeid,
// }
 
// Mesh_CPU::struct{
// 	vertex_buf:[dynamic]u8,
// 	index_buf:[dynamic]u32,
// 	attribute_type:typeid,
// }

Mesh_CPU::struct{
	vertex_buf:Generic_Buffer,
	
	index_buf:[dynamic]u32,
	// index_buf:[]u32,
	index_buf_used:u32,
	attribute_type:typeid,
	attribute_size:int,
	
	name:string,//for debuging
}



Mesh_GPU::struct{
	is_good:bool,
	vertex_buf:^sdl.GPUBuffer,
	index_buf:^sdl.GPUBuffer,
	transfer_buf:^sdl.GPUTransferBuffer,
	index_count:u32,
	attribute_type:typeid,
}
Mesh::struct{
	handle:Mesh_Handle,
	cpu:Mesh_CPU,
	gpu:Mesh_GPU,
}

TRIANGLE_INDEXES:[]u32:{
	0+4*0, 1+4*0, 2+4*0,
}
QUAD_INDEXES:[]u32:{
	0+4*0, 1+4*0, 2+4*0, 0+4*0, 2+4*0, 3+4*0,
}
CUBE_INDEXES:[]u32:{
	0+4*0, 1+4*0, 2+4*0, 0+4*0, 2+4*0, 3+4*0,
	0+4*1, 1+4*1, 2+4*1, 0+4*1, 2+4*1, 3+4*1,
	0+4*2, 1+4*2, 2+4*2, 0+4*2, 2+4*2, 3+4*2,
	0+4*3, 1+4*3, 2+4*3, 0+4*3, 2+4*3, 3+4*3,
	0+4*4, 1+4*4, 2+4*4, 0+4*4, 2+4*4, 3+4*4,
	0+4*5, 1+4*5, 2+4*5, 0+4*5, 2+4*5, 3+4*5,
}

create_mesh::proc(cpu_mesh:Mesh_CPU, max_num_verts:int = 50000, max_num_indices:int = 50000*2,debug_name:string = "not_named") ->(mesh_hd:Mesh_Handle){
	mesh_attribute_info:=type_info_of(cpu_mesh.attribute_type)
	mesh:Mesh


	vertices_byte_size:=(max_num_verts*mesh_attribute_info.size)
	indices_byte_size:=(max_num_indices*size_of(u32))
	
	

	// vertices_byte_size:=len(cpu_mesh.vertex_buf)+(rezerved_buf_size*mesh_attribute_info.size)
	// indices_byte_size:=len(cpu_mesh.index_buf) * size_of(cpu_mesh.index_buf[0])+(rezerved_buf_size*size_of(u32))
	mesh.cpu = cpu_mesh
	mesh.cpu.attribute_size = mesh_attribute_info.size
	mesh.cpu.name = debug_name
	// fmt.print(mesh_attribute_info.size,"\n")

	mesh.gpu.vertex_buf = sdl.CreateGPUBuffer(s.gpu_device,{
		usage={.GRAPHICS_STORAGE_READ},
		size = cast(u32)vertices_byte_size,
	})

	mesh.gpu.index_buf = sdl.CreateGPUBuffer(s.gpu_device,{
		usage={.GRAPHICS_STORAGE_READ},
		size = cast(u32)indices_byte_size,
	})

	mesh.gpu.transfer_buf = sdl.CreateGPUTransferBuffer(s.gpu_device,{
		usage = .UPLOAD,
		size = cast(u32)(vertices_byte_size + indices_byte_size),
	})
	// fmt.print(vertices_byte_size, indices_byte_size,vertices_byte_size + indices_byte_size ,"\n\n\n\n\n")
	mesh_hd=hm.add(&s.meshes, mesh)
	return
}
delete_mesh::proc(mesh_hd:Mesh_Handle){
	mesh:=get_mesh(mesh_hd)
	delete(mesh.cpu.index_buf)
	// delete(mesh.cpu.vertex_buf)
	delete_buffer(&mesh.cpu.vertex_buf)
	sdl.ReleaseGPUBuffer(s.gpu_device, mesh.gpu.index_buf)
	sdl.ReleaseGPUBuffer(s.gpu_device, mesh.gpu.vertex_buf)
	hm.remove(&s.meshes,mesh_hd)
	
}
update_mesh::proc(mesh_hd:Mesh_Handle){
	mesh:=get_mesh(mesh_hd)
	vertices_byte_size := len(mesh.cpu.vertex_buf.buffer.buf)
	indices_byte_size:=len(mesh.cpu.index_buf) * size_of(mesh.cpu.index_buf[0])
	transfer_mem := transmute([^]byte)sdl.MapGPUTransferBuffer(s.gpu_device, mesh.gpu.transfer_buf, false)//TODO may be ablle to remove the mem copyes by seting the transfer buff as cpu data
	// mem.copy(transfer_mem, raw_data(mesh.cpu.vertex_buf.buffer.buf), cast(int)vertices_byte_size)
	copy(transfer_mem[:vertices_byte_size],mesh.cpu.vertex_buf.buffer.buf[:])
	mem.copy(transfer_mem[vertices_byte_size:], raw_data(mesh.cpu.index_buf), indices_byte_size)
	sdl.UnmapGPUTransferBuffer(s.gpu_device, mesh.gpu.transfer_buf)
	copy_cmd_buf:=sdl.AcquireGPUCommandBuffer(s.gpu_device)	
	copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)

	if vertices_byte_size > 0 {
		sdl.UploadToGPUBuffer(
			copy_pass = copy_pass,
			source = {
				transfer_buffer = mesh.gpu.transfer_buf,
				offset = 0,
			},
			destination = {
				buffer = mesh.gpu.vertex_buf, 
				size = cast(u32)vertices_byte_size,
			},
			cycle = false,
		)
	}

	if indices_byte_size > 0 {
		sdl.UploadToGPUBuffer(
			copy_pass = copy_pass,
			source = {
				transfer_buffer = mesh.gpu.transfer_buf,
				offset = cast(u32)vertices_byte_size,
			},
			destination = {
				buffer = mesh.gpu.index_buf,
				size = cast(u32)indices_byte_size,
			},
			cycle = false,
		)
	}

	mesh.gpu.index_count = mesh.cpu.index_buf_used
	sdl.EndGPUCopyPass(copy_pass)
	ok := sdl.SubmitGPUCommandBuffer(copy_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")

	
	// sdl.ReleaseGPUTransferBuffer(s.gpu_device, mesh.gpu.transfer_buf)
}
get_mesh::proc(mesh_hd:Mesh_Handle, )->(mesh:^Mesh){
	mesh = hm.get(&s.meshes, mesh_hd)
	return
}

append_to_mesh::proc(mesh:^Mesh_CPU,indices:[]u32,vertices:$T/[]$E, shift_indices:bool=true){
	// attribute_info:=type_info_of(mesh.attribute_type,)
	// assert(mesh != nil)
	// assert(mesh.attribute_type != nil)
	// mesh_attribute_info:=type_info_of(mesh.attribute_type)
	// attribute_info:=type_info_of(E,)
	attribute_size:=size_of(E)
	assert(mesh.attribute_size == attribute_size, "mesh vertex data size must == incoming vertices size")
	indices:=indices
	if shift_indices{
		for &ind in &indices{
			// ind += mesh.index_buf_used
			ind += cast(u32)(len(mesh.vertex_buf.buffer.buf)/mesh.attribute_size)
			// ind += mesh.vertex_count
		}
	}
	vertices_byte_size:= len(vertices) * attribute_size
	// indices_byte_size:= len(indices) * size_of(indices[0])
	
	// resize_dynamic_array(&mesh.vertex_buf, vertices_byte_size + cast(int)mesh.vertex_buf_used)
	// resize_dynamic_array(&mesh.index_buf,  len(indices) + cast(int)mesh.index_buf_used)
	
	// mem.copy(raw_data(mesh.vertex_buf[mesh.vertex_buf_used:]), raw_data(vertices), vertices_byte_size)
	// mem.copy(raw_data(mesh.index_buf[mesh.index_buf_used:]), raw_data(indices), indices_byte_size)
	buffer_write_slice(&mesh.vertex_buf,vertices)
	append(&mesh.index_buf, ..indices)
	
	// mesh.vertex_count += cast(u32)len(vertices)
	// mesh.vertex_buf_used += cast(u32)vertices_byte_size
	mesh.index_buf_used += cast(u32)len(indices)
}

//this sets the verts in a spusific location in the mesh if you do not know what you are doing you problobly want append_to_mesh()
set_verts_in_mesh::proc(mesh:^Mesh_CPU,indices:[]u32,indices_offset:int,vertices:$T/[]$E,vertices_offset:int, shift_indices:bool=true){
	attribute_size:=size_of(E)
	assert(mesh.attribute_size == attribute_size, "mesh vertex data size must == incoming vertices size")
	// fmt.print("vert_offset:",vertices_offset , "   index_offset:",indices_offset,"\n")
	if shift_indices{
		for ind , count in indices{
			// fmt.print(count,"\n")
			mesh.index_buf[indices_offset+count] = ind + cast(u32)vertices_offset
			// fmt.print("indices",mesh.index_buf[indices_offset+count],"\n")
		}
	}
	vertices_byte_size:= len(vertices) * attribute_size
	// mem.copy(raw_data(mesh.vertex_buf[vertices_offset*attribute_size:]), raw_data(vertices), vertices_byte_size)
	mem.copy(raw_data(mesh.vertex_buf.buffer.buf[vertices_offset*attribute_size:]), raw_data(vertices), vertices_byte_size)
	// fmt.print("vert",vertices[:],"\n")

	// append(&mesh.index_buf, ..indices)
}

append_mesh_to_mesh::proc(mesh_form:^Mesh_CPU,mesh_to:^Mesh_CPU){
	// append_to_mesh(mesh_to,mesh_form.index_buf[:],mesh_form.vertex_buf[:])
	append_to_mesh(mesh_to,mesh_form.index_buf[:],mesh_form.vertex_buf.buffer.buf[:])
}
clear_mesh_cpu::proc(mesh:^Mesh_CPU){
	clear(&mesh.index_buf)
	// clear(&mesh.vertex_buf)
	clear_buffer(&mesh.vertex_buf)
	mesh.index_buf_used = 0
	// mesh.vertex_buf_used = 0
	// mesh.vertex_count = 0
}
transform_verts::proc(verts:$T/[]$E , mat:matrix[4, 4]f32 = Mat4(1)){
	vec4:Vec4
	for &v , i in verts{
		vec4 = {v.pos.x,  v.pos.y,  v.pos.z,  1.0}
		v.pos =  mat * vec4 
	}
}
