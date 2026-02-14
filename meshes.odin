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
import hm "handle_map_static_virtual"
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
	vertex_buf:[dynamic]u8,
	vertex_buf_used:u32,
	index_buf:[dynamic]u32,
	index_buf_used:u32,
	attribute_type:typeid,
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


create_mesh::proc(cpu_mesh:Mesh_CPU) ->(mesh_hd:Mesh_Handle){
	mesh:Mesh
	vertices_byte_size:=len(cpu_mesh.vertex_buf)
	indices_byte_size:=len(cpu_mesh.index_buf) * size_of(cpu_mesh.index_buf[0])
	mesh.cpu = cpu_mesh
	// mesh.gpu.vertex_buf = sdl.CreateGPUBuffer(s.gpu_device,{
	// 	usage={.VERTEX},
	// 	size = cast(u32)vertices_byte_size,
	// })
	// mesh.gpu.index_buf = sdl.CreateGPUBuffer(s.gpu_device,{
	// 	usage={.INDEX},
	// 	size = cast(u32)indices_byte_size,
	// })
	
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
	mesh_hd=hm.add(&s.meshes, mesh)
	return
}
update_mesh::proc(mesh:Mesh_Handle){
	mesh:=get_mesh(mesh)
	vertices_byte_size:=len(mesh.cpu.vertex_buf)
	indices_byte_size:=len(mesh.cpu.index_buf) * size_of(mesh.cpu.index_buf[0])
	transfer_mem := transmute([^]byte)sdl.MapGPUTransferBuffer(s.gpu_device, mesh.gpu.transfer_buf, false)
	mem.copy(transfer_mem, raw_data(mesh.cpu.vertex_buf), vertices_byte_size)
	mem.copy(transfer_mem[vertices_byte_size:], raw_data(mesh.cpu.index_buf), indices_byte_size)	
	copy_pass: = sdl.BeginGPUCopyPass(s.copy_cmd_buf)
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
	
	mesh.gpu.index_count = mesh.cpu.index_buf_used
	sdl.EndGPUCopyPass(copy_pass)
	ok := sdl.SubmitGPUCommandBuffer(s.copy_cmd_buf);	assert(ok, "SDL SubmitGPUCommandBuffer Failed")
	sdl.ReleaseGPUTransferBuffer(s.gpu_device, mesh.gpu.transfer_buf)
}
get_mesh::proc(mesh_hd:Mesh_Handle, )->(mesh:^Mesh){
	mesh = hm.get(s.meshes, mesh_hd)
	return
}

append_to_mesh::proc(mesh:^Mesh_CPU,indices:[]u32,vertices:$T/[]$E, shift_indices:bool=true){
	// attribute_info:=type_info_of(mesh.attribute_type,)
	mesh_attribute_info:=type_info_of(mesh.attribute_type)
	attribute_info:=type_info_of(E,)
	
	assert(mesh_attribute_info.size == attribute_info.size, "mesh vertex data size must == incoming vertices size")
	indices:=indices
	if shift_indices{
		for &ind in &indices{
			ind += mesh.index_buf_used
		}
	}
	vertices_byte_size:= len(vertices) * attribute_info.size
	indices_byte_size:= len(indices) * size_of(indices[0])
	
	resize_dynamic_array(&mesh.vertex_buf, vertices_byte_size + cast(int)mesh.vertex_buf_used)
	resize_dynamic_array(&mesh.index_buf,  len(indices) + cast(int)mesh.index_buf_used)
	
	mem.copy(raw_data(mesh.vertex_buf[mesh.vertex_buf_used:]), raw_data(vertices), vertices_byte_size)
	mem.copy(raw_data(mesh.index_buf[mesh.index_buf_used:]), raw_data(indices), indices_byte_size)
	
	mesh.vertex_buf_used += cast(u32)vertices_byte_size
	mesh.index_buf_used += cast(u32)len(indices)
}

append_mesh_to_mesh::proc(mesh_form:^Mesh_CPU,mesh_to:^Mesh_CPU){
	append_to_mesh(mesh_to,mesh_form.index_buf[:],mesh_form.vertex_buf[:])
}

Mesh_vert::union{
	Mesh,
	Mesh_CPU,
}
draw_triangle_ex :: proc(mesh: ^Mesh_CPU, pos:Vec3, verts:$T/[3]$E , origin: Vec3 = {}, rot: f32 = 0,tex:Texture_GPU_Handle = {}) {

	// v0, v1, v2: Vec2
	new_v:[3]E = verts
	when intrinsics.type_has_field(E, "col"){
		// fmt.print("\n\nhas col\n")
	}

	when intrinsics.type_has_field(E, "pos"){
	// Rotation adapted from Raylib's "DrawTexturePro"
		if rot == 0 {
			x := pos.x - origin.x
			y := pos.y - origin.y
			z := pos.z - origin.z
			new_v[0].pos = { x + verts[0].pos.x, y + verts[0].pos.y, z + verts[0].pos.z}
			new_v[1].pos = { x + verts[1].pos.x, y + verts[1].pos.y, z + verts[1].pos.z}
			new_v[2].pos = { x + verts[2].pos.x, y + verts[2].pos.y, z + verts[2].pos.z}
		} else {
			sin_rot := math.sin(rot)
			cos_rot := math.cos(rot)
			x := pos.x
			y := pos.y
			z := pos.z
			dx := -origin.x
			dy := -origin.y
			dz := -origin.z
	
			new_v[0].pos = {
				x + (dx + verts[0].pos.x) * cos_rot - (dy + verts[0].pos.y) * sin_rot,
				y + (dx + verts[0].pos.x) * sin_rot + (dy + verts[0].pos.y) * cos_rot,
				z + dz,
			}
			
			new_v[1].pos = {
				x + (dx + verts[1].pos.x) * cos_rot - (dy + verts[1].pos.y) * sin_rot,
				y + (dx + verts[1].pos.x) * sin_rot + (dy + verts[1].pos.y) * cos_rot,
				z + dz,
			}
	
			new_v[2].pos = {
				x + (dx + verts[2].pos.x) * cos_rot - (dy + verts[2].pos.y) * sin_rot,
				y + (dx + verts[2].pos.x) * sin_rot + (dy + verts[2].pos.y) * cos_rot,
				z + dz,
			}
		}
	}
	append_to_mesh(mesh, {0, 1, 2}, new_v[:])
}
