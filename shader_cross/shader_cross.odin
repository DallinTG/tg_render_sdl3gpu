package shader_cross


import "core:fmt"
import "core:c"
import sdl3"vendor:sdl3"

when ODIN_OS == .Windows do foreign import lib "SDL3_shadercross-3.0.0-windows-VC-x64/bin/shadercross.exe"
// when ODIN_OS == .Linux   do foreign import lib "SDL3_shadercross-3.0.0-linux-x64/bin/shadercross"
when ODIN_OS == .Linux   do foreign import lib "sc-linux-x64/bin/shadercross"
/*
  Simple DirectMedia Layer Shader Cross Compiler
  Copyright (C) 2024 Sam Lantinga <slouken@libsdl.org>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*/

_ :: lib

/**
* Printable format: "%d.%d.%d", MAJOR, MINOR, MICRO
*/
SHADERCROSS_MAJOR_VERSION :: 3
SHADERCROSS_MINOR_VERSION :: 0
SHADERCROSS_MICRO_VERSION :: 0

ShaderCross_IOVarType :: enum u32 {
	UNKNOWN = 0,
	INT8    = 1,
	UINT8   = 2,
	INT16   = 3,
	UINT16  = 4,
	INT32   = 5,
	UINT32  = 6,
	INT64   = 7,
	UINT64  = 8,
	FLOAT16 = 9,
	FLOAT32 = 10,
	FLOAT64 = 11,
}

ShaderCross_ShaderStage :: enum u32 {
	VERTEX   = 0,
	FRAGMENT = 1,
	COMPUTE  = 2,
}

ShaderCross_IOVarMetadata :: struct {
	name:        cstring,               /**< The UTF-8 name of the variable. */
	location:    sdl3.Uint32,                /**< The location of the variable. */
	vector_type: ShaderCross_IOVarType, /**< The vector type of the variable. */
	vector_size: sdl3.Uint32,                /**< The number of components in the vector type of the variable. */
}

ShaderCross_GraphicsShaderResourceInfo :: struct {
	num_samplers:         sdl3.Uint32, /**< The number of samplers defined in the shader. */
	num_storage_textures: sdl3.Uint32, /**< The number of storage textures defined in the shader. */
	num_storage_buffers:  sdl3.Uint32, /**< The number of storage buffers defined in the shader. */
	num_uniform_buffers:  sdl3.Uint32, /**< The number of uniform buffers defined in the shader. */
}

ShaderCross_GraphicsShaderMetadata :: struct {
	resource_info: ShaderCross_GraphicsShaderResourceInfo, /**< Sub-struct containing the resource info of the shader. */
	num_inputs:    sdl3.Uint32,                                 /**< The number of inputs defined in the shader. */
	inputs:        ^ShaderCross_IOVarMetadata,             /**< The inputs defined in the shader. */
	num_outputs:   sdl3.Uint32,                                 /**< The number of outputs defined in the shader. */
	outputs:       ^ShaderCross_IOVarMetadata,             /**< The outputs defined in the shader. */
}

ShaderCross_ComputePipelineMetadata :: struct {
	num_samplers:                   sdl3.Uint32, /**< The number of samplers defined in the shader. */
	num_readonly_storage_textures:  sdl3.Uint32, /**< The number of readonly storage textures defined in the shader. */
	num_readonly_storage_buffers:   sdl3.Uint32, /**< The number of readonly storage buffers defined in the shader. */
	num_readwrite_storage_textures: sdl3.Uint32, /**< The number of read-write storage textures defined in the shader. */
	num_readwrite_storage_buffers:  sdl3.Uint32, /**< The number of read-write storage buffers defined in the shader. */
	num_uniform_buffers:            sdl3.Uint32, /**< The number of uniform buffers defined in the shader. */
	threadcount_x:                  sdl3.Uint32, /**< The number of threads in the X dimension. */
	threadcount_y:                  sdl3.Uint32, /**< The number of threads in the Y dimension. */
	threadcount_z:                  sdl3.Uint32, /**< The number of threads in the Z dimension. */
}

ShaderCross_SPIRV_Info :: struct {
	bytecode:      ^sdl3.Uint8,                  /**< The SPIRV bytecode. */
	bytecode_size: i32,                     /**< The length of the SPIRV bytecode. */
	entrypoint:    cstring,                 /**< The entry point function name for the shader in UTF-8. */
	shader_stage:  ShaderCross_ShaderStage, /**< The shader stage to transpile the shader with. */
	props:         sdl3.PropertiesID,            /**< A properties ID for extensions. Should be 0 if no extensions are needed. */
}

SHADERCROSS_PROP_SHADER_DEBUG_ENABLE_BOOLEAN         :: "SDL_shadercross.spirv.debug.enable"
SHADERCROSS_PROP_SHADER_DEBUG_NAME_STRING            :: "SDL_shadercross.spirv.debug.name"
SHADERCROSS_PROP_SHADER_CULL_UNUSED_BINDINGS_BOOLEAN :: "SDL_shadercross.spirv.cull_unused_bindings"
SHADERCROSS_PROP_SPIRV_PSSL_COMPATIBILITY_BOOLEAN    :: "SDL_shadercross.spirv.pssl.compatibility"
SHADERCROSS_PROP_SPIRV_MSL_VERSION_STRING            :: "SDL_shadercross.spirv.msl.version"

ShaderCross_HLSL_Define :: struct {
	name:  cstring, /**< The define name. */
	value: cstring, /**< An optional value for the define. Can be NULL. */
}

ShaderCross_HLSL_Info :: struct {
	source:       cstring,                  /**< The HLSL source code for the shader. */
	entrypoint:   cstring,                  /**< The entry point function name for the shader in UTF-8. */
	include_dir:  cstring,                  /**< The include directory for shader code. Optional, can be NULL. */
	defines:      ^ShaderCross_HLSL_Define, /**< An array of defines. Optional, can be NULL. If not NULL, must be terminated with a fully NULL define struct. */
	shader_stage: ShaderCross_ShaderStage,  /**< The shader stage to compile the shader with. */
	props:        sdl3.PropertiesID,             /**< A properties ID for extensions. Should be 0 if no extensions are needed. */
}

@(default_calling_convention="c", link_prefix="SDL_")
foreign lib {
	/**
	* Initializes SDL_shadercross
	*
	* \threadsafety This should only be called once, from a single thread.
	* \returns true on success, false otherwise.
	*/
	ShaderCross_Init :: proc() -> i32 ---

	/**
	* De-initializes SDL_shadercross
	*
	* \threadsafety This should only be called once, from a single thread.
	*/
	ShaderCross_Quit :: proc() ---

	/**
	* Get the supported shader formats that SPIRV cross-compilation can output
	*
	* \threadsafety It is safe to call this function from any thread.
	* \returns GPU shader formats supported by SPIRV cross-compilation.
	*/
	ShaderCross_GetSPIRVShaderFormats :: proc() -> sdl3.GPUShaderFormat ---

	/**
	* Transpile to MSL code from SPIRV code.
	*
	* You must SDL_free the returned string once you are done with it.
	*
	* These are the optional properties that can be used:
	*
	* - `SDL_SHADERCROSS_PROP_SPIRV_MSL_VERSION_STRING`: specifies the MSL version that should be emitted. Defaults to 1.2.0.
	*
	* \param info a struct describing the shader to transpile.
	* \returns an SDL_malloc'd string containing MSL code.
	*/
	ShaderCross_TranspileMSLFromSPIRV :: proc(info: ^ShaderCross_SPIRV_Info) -> rawptr ---

	/**
	* Transpile to HLSL code from SPIRV code.
	*
	* You must SDL_free the returned string once you are done with it.
	*
	* These are the optional properties that can be used:
	*
	* - `SDL_SHADERCROSS_PROP_SPIRV_PSSL_COMPATIBILITY_BOOLEAN`: generates PSSL-compatible shader.
	*
	* \param info a struct describing the shader to transpile.
	* \returns an SDL_malloc'd string containing HLSL code.
	*/
	ShaderCross_TranspileHLSLFromSPIRV :: proc(info: ^ShaderCross_SPIRV_Info) -> rawptr ---

	/**
	* Compile DXBC bytecode from SPIRV code.
	*
	* You must SDL_free the returned buffer once you are done with it.
	*
	* \param info a struct describing the shader to transpile.
	* \param size filled in with the bytecode buffer size.
	* \returns an SDL_malloc'd buffer containing DXBC bytecode.
	*/
	ShaderCross_CompileDXBCFromSPIRV :: proc(info: ^ShaderCross_SPIRV_Info, size: ^i32) -> rawptr ---

	/**
	* Compile DXIL bytecode from SPIRV code.
	*
	* You must SDL_free the returned buffer once you are done with it.
	*
	* \param info a struct describing the shader to transpile.
	* \param size filled in with the bytecode buffer size.
	* \returns an SDL_malloc'd buffer containing DXIL bytecode.
	*/
	ShaderCross_CompileDXILFromSPIRV :: proc(info: ^ShaderCross_SPIRV_Info, size: ^i32) -> rawptr ---

	/**
	* Compile an SDL GPU shader from SPIRV code. If your shader source is HLSL, you should obtain SPIR-V bytecode from SDL_ShaderCross_CompileSPIRVFromHLSL().
	*
	* \param device the SDL GPU device.
	* \param info a struct describing the shader to transpile.
	* \param resource_info a struct describing resource info of the shader. Can be obtained from SDL_ShaderCross_ReflectGraphicsSPIRV().
	* \param props a properties object filled in with extra shader metadata.
	* \returns a compiled SDL_GPUShader.
	*
	* \threadsafety It is safe to call this function from any thread.
	*/
	ShaderCross_CompileGraphicsShaderFromSPIRV :: proc(device: ^sdl3.GPUDevice, info: ^ShaderCross_SPIRV_Info, resource_info: ^ShaderCross_GraphicsShaderResourceInfo, props: sdl3.PropertiesID) -> ^sdl3.GPUShader ---

	/**
	* Compile an SDL GPU compute pipeline from SPIRV code. If your shader source is HLSL, you should obtain SPIR-V bytecode from SDL_ShaderCross_CompileSPIRVFromHLSL().
	*
	* \param device the SDL GPU device.
	* \param info a struct describing the shader to transpile.
	* \param metadata a struct describing shader metadata. Can be obtained from SDL_ShaderCross_ReflectComputeSPIRV().
	* \param props a properties object filled in with extra shader metadata.
	* \returns a compiled SDL_GPUComputePipeline.
	*
	* \threadsafety It is safe to call this function from any thread.
	*/
	ShaderCross_CompileComputePipelineFromSPIRV :: proc(device: ^sdl3.GPUDevice, info: ^ShaderCross_SPIRV_Info, metadata: ^ShaderCross_ComputePipelineMetadata, props: sdl3.PropertiesID) -> ^sdl3.GPUComputePipeline ---

	/**
	* Reflect graphics shader info from SPIRV code. If your shader source is HLSL, you should obtain SPIR-V bytecode from SDL_ShaderCross_CompileSPIRVFromHLSL(). This must be freed with SDL_free() when you are done with the metadata.
	*
	* \param bytecode the SPIRV bytecode.
	* \param bytecode_size the length of the SPIRV bytecode.
	* \param props a properties object filled in with extra shader metadata, provided by the user.
	* \returns A metadata struct on success, NULL otherwise. The struct must be free'd when it is no longer needed.
	*
	* \threadsafety It is safe to call this function from any thread.
	*/
	ShaderCross_ReflectGraphicsSPIRV :: proc(bytecode: ^sdl3.Uint8, bytecode_size: i32, props: sdl3.PropertiesID) -> ^ShaderCross_GraphicsShaderMetadata ---

	/**
	* Reflect compute pipeline info from SPIRV code. If your shader source is HLSL, you should obtain SPIR-V bytecode from SDL_ShaderCross_CompileSPIRVFromHLSL(). This must be freed with SDL_free() when you are done with the metadata.
	*
	* \param bytecode the SPIRV bytecode.
	* \param bytecode_size the length of the SPIRV bytecode.
	* \param props a properties object filled in with extra shader metadata, provided by the user.
	* \returns A metadata struct on success, NULL otherwise.
	*
	* \threadsafety It is safe to call this function from any thread.
	*/
	ShaderCross_ReflectComputeSPIRV :: proc(bytecode: ^sdl3.Uint8, bytecode_size: i32, props: sdl3.PropertiesID) -> ^ShaderCross_ComputePipelineMetadata ---

	/**
	* Get the supported shader formats that HLSL cross-compilation can output
	*
	* \returns GPU shader formats supported by HLSL cross-compilation.
	*
	* \threadsafety It is safe to call this function from any thread.
	*/
	ShaderCross_GetHLSLShaderFormats :: proc() -> sdl3.GPUShaderFormat ---

	/**
	* Compile to DXBC bytecode from HLSL code via a SPIRV-Cross round trip.
	*
	* You must SDL_free the returned buffer once you are done with it.
	*
	* These are the optional properties that can be used:
	*
	* - `SDL_SHADERCROSS_PROP_SHADER_DEBUG_ENABLE_BOOLEAN`: allows debug info to be emitted when relevant. Should only be used with debugging tools like Renderdoc.
	* - `SDL_SHADERCROSS_PROP_SHADER_DEBUG_ENABLE_BOOLEAN`: a UTF-8 name to be used with the shader. Relevant for use with debugging tools like Renderdoc.
	* - `SDL_SHADERCROSS_PROP_SHADER_CULL_UNUSED_BINDINGS_BOOLEAN`: When true, indicates that the compiler should not cull unused shader resources. This behavior is disabled by default.
	*
	* \param info a struct describing the shader to transpile.
	* \param size filled in with the bytecode buffer size.
	* \returns an SDL_malloc'd buffer containing DXBC bytecode.
	*
	* \threadsafety It is safe to call this function from any thread.
	*/
	ShaderCross_CompileDXBCFromHLSL :: proc(info: ^ShaderCross_HLSL_Info, size: ^i32) -> rawptr ---

	/**
	* Compile to DXIL bytecode from HLSL code via a SPIRV-Cross round trip.
	*
	* You must SDL_free the returned buffer once you are done with it.
	*
	* These are the optional properties that can be used:
	*
	* - `SDL_SHADERCROSS_PROP_SHADER_DEBUG_ENABLE_BOOLEAN`: allows debug info to be emitted when relevant. Should only be used with debugging tools like Renderdoc.
	* - `SDL_SHADERCROSS_PROP_SHADER_DEBUG_NAME_STRING`: a UTF-8 name to be used with the shader. Relevant for use with debugging tools like Renderdoc.
	* - `SDL_SHADERCROSS_PROP_SHADER_CULL_UNUSED_BINDINGS_BOOLEAN`: when true, indicates that the compiler should not cull unused shader resources. This behavior is disabled by default.
	*
	* \param info a struct describing the shader to transpile.
	* \param size filled in with the bytecode buffer size.
	* \returns an SDL_malloc'd buffer containing DXIL bytecode.
	*
	* \threadsafety It is safe to call this function from any thread.
	*/
	ShaderCross_CompileDXILFromHLSL :: proc(info: ^ShaderCross_HLSL_Info, size: ^i32) -> rawptr ---

	/**
	* Compile to SPIRV bytecode from HLSL code.
	*
	* You must SDL_free the returned buffer once you are done with it.
	*
	* These are the optional properties that can be used:
	*
	* - `SDL_SHADERCROSS_PROP_SHADER_DEBUG_ENABLE_BOOLEAN`: allows debug info to be emitted when relevant. Should only be used with debugging tools like Renderdoc.
	* - `SDL_SHADERCROSS_PROP_SHADER_DEBUG_NAME_STRING`: a UTF-8 name to be used with the shader. Relevant for use with debugging tools like Renderdoc.
	* - `SDL_SHADERCROSS_PROP_SHADER_CULL_UNUSED_BINDINGS_BOOLEAN`: when true, indicates that the compiler should not cull unused shader resources. This behavior is disabled by default.
	*
	* \param info a struct describing the shader to transpile.
	* \param size filled in with the bytecode buffer size.
	* \returns an SDL_malloc'd buffer containing SPIRV bytecode.
	*
	* \threadsafety It is safe to call this function from any thread.
	*/
	ShaderCross_CompileSPIRVFromHLSL :: proc(info: ^ShaderCross_HLSL_Info, size: ^i32) -> rawptr ---
}
