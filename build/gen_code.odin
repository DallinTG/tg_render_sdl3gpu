package build
/*
This program generates `images.odin` by going through the `images` folder and
opening each file. From each PNG file in there it will:

- Generate a pretty enum name for it
- Make a list of images where it maps each pretty enum name to an Image struct
- The Image struct contains the width and the height. This is determined by
    opening the PNG files.
- The Image struct also contains a `data = #load(THE_FILENAME)` field. That will
    make the compiler that later tries to compile `images.odin` load the file
    data at compile-time.
*/


import "core:os"
import "core:strings"
import "core:fmt"
import "core:path/slashpath"
import "core:image/png"
import "core:image"
import "core:hash"
import "core:encoding/cbor"

// Avoids 'unused import' error: "core:image/png" needs to be imported in order
// to make `img.load_from_bytes` understand PNG format.
_ :: png

INPUT_DIR :: "../assets/textures"
OUTPUT_FILE :: "../gen_code.odin"

F_Info::struct{
	suffix:string,
	mod_name:string,
	file_info:os.File_Info,

}
D_Info::struct{
	files:[dynamic]F_Info,
	dir_name:string,
}

all_dir_info:[dynamic]D_Info
create_enum_info_frome_dir_recers::proc(path:string, mod_name:string,recer_count:int=0){
	info:=new(D_Info)

	info.dir_name = mod_name
	d, d_err := os.open(path)
	defer os.close(d)
	input_files, _ := os.read_dir(d, -1, context.allocator)
	for i in input_files {

		new_info:F_Info
		switch {
		case strings.has_suffix(i.name, ".ttf"):
		new_info.suffix = ".ttf"
		case strings.has_suffix(i.name, ".png"):
		new_info.suffix = ".png"
		case strings.has_suffix(i.name, ".hlsl"):
		new_info.suffix = ".hlsl"
		case i.type == .Directory:
			fmt.print(i.fullpath,i.name,"\n")
			create_enum_info_frome_dir_recers(i.fullpath,i.name,recer_count+1)
			continue
		case:
			continue
		}

		new_info.mod_name = mod_name
		new_info.file_info = i
		append(&info.files, new_info)
	}
	if len(info.files) > 0{
		append(&all_dir_info,info^)
	}
	return
}

start_code_gen_main :: proc() {
	create_enum_info_frome_dir_recers("../assets","icons")
	for dir in all_dir_info{
		// fmt.print("dir_name ",dir.dir_name,"\n\n")
		// // fmt.print("root_parent ",dir.root_parent,"\n\n")
		// for fil in dir.files{
		// 	fmt.print("fil.mod_name ",fil.mod_name,"\n")

		// 	fmt.print("fil.suffix ",fil.suffix,"\n")
		// 	fmt.print("fil.name ",fil.file_info.name,"\n")
		// 	fmt.print("\n")
		// 	// fmt.print("fil.suffix ",fil.file_info,"\n")
			
		// }
		// fmt.print("_____________________________________________________\n")
	}


	d, d_err := os.open(INPUT_DIR)
	assert(d_err == nil, "Failed opening '" + INPUT_DIR + "' folder")
	defer os.close(d)

	input_files, _ := os.read_dir(d, -1, context.allocator)

	f, f_err := os.open(OUTPUT_FILE, {.Write, .Create, .Trunc}, {.Read_User, .Write_User, .Read_Group, .Read_Other})

	defer os.close(f)

	fmt.fprintln(f,
`// This file is generated. Re-generate it by running:
//	odin run generate_image_info
package tg_render

Image :: struct {
	width: int,
	height: int,
	id:[2]u32,
	hd:Texture_HD,//this will be set at runtime
	data: []u8,
}

`//Image_Name :: enum {`,
)
	for &dir in all_dir_info{
		fmt.fprintfln(f,"%v_E :: enum {{",strings.to_ada_case(slashpath.name(dir.dir_name)))
		for file in dir.files{
			// new_string,ok:=strings.replace_all(strings.trim_suffix( strings.to_ada_case(slashpath.name(file.file_info.name)),file.suffix),".","_")
			fmt.fprint(f,"	",format_string(file.file_info.name,file.suffix),",\n")
		}
		fmt.fprintfln(f,"}}")
		fmt.fprintfln(f,"")

		switch dir.dir_name{
			case "textures":
			print_img_data(f,&dir,"assets/textures")
			case "icons":
			print_img_data(f,&dir,"assets/textures/icons")
			case:
		}
	}
	

	// for i in images {
	// 	fmt.fprintfln(f, "	%v ,", strings.to_ada_case(slashpath.name(i.file_info.name)))
	// }

// 	fmt.fprintln(f,
// `}

// images := [Image_Name]Image {`,
// )

	// for i in images {
	// 	img, img_err := image.load_from_file(i.file_info.fullpath)

	// 	if img_err == nil {
	// 		enum_name := strings.to_ada_case(slashpath.name(i.file_info.name))
	// 		tex_id:=get_texture_id([2]string{i.mod_name,i.file_info.name})
	// 		fmt.fprintfln(f, "	.%v = {{  width = %v, height = %v, id = {{ %v,%v}, }},", enum_name, img.width, img.height, fmt.tprint(tex_id.x), fmt.tprint(tex_id.y))
	// 			// fmt.fprintfln(f, "	.%v = {{ data = #load(\"images/%v\"), width = %v, height = %v }},", enum_name, i.name, img.width, img.height)
	// 	}
	// }

	// fmt.fprintln(f, "}")
}

print_img_data::proc(f:^os.File,dir:^D_Info,load_path:string){
	
	fmt.fprintfln(f,"%v_Dir  := #load_directory(\"%v\")",strings.to_ada_case(slashpath.name(dir.dir_name)),load_path)
	fmt.fprintfln(f,"%v_Data := [%v_E]Image {{",strings.to_ada_case(slashpath.name(dir.dir_name)),strings.to_ada_case(slashpath.name(dir.dir_name)))
	for file in dir.files{
	img, img_err := image.load_from_file(file.file_info.fullpath)
		if img_err == nil {
			enum_name := strings.to_ada_case(slashpath.name(file.file_info.name))
			tex_id:=get_texture_id([2]string{file.mod_name,file.file_info.name})
			fmt.fprintfln(f, "	.%v = {{  width = %v, height = %v, id = {{ %v,%v},  }},", enum_name, img.width, img.height, fmt.tprint(tex_id.x), fmt.tprint(tex_id.y),)
	
				// fmt.fprintfln(f, "	.%v = {{ data = #load(\"images/%v\"), width = %v, height = %v }},", enum_name, i.name, img.width, img.height)
		}
	}
	fmt.fprintfln(f,"}}")
	fmt.fprintfln(f,"")
}

format_string::proc(str:string, remove_suffix:string="")->(new_str:string){
	ok:bool
	new_str,ok=strings.replace_all(strings.trim_suffix( strings.to_ada_case(slashpath.name(str)),remove_suffix),".","_")
	return
}
get_texture_id::proc(tex_id:Texture_ID_Types)->(new_tex_id:[2]u32){
	mod_id_u32:u32
	tex_id_u32:u32
	switch id in tex_id {
	case string:
		tex_id_u32 = hash.murmur32(transmute([]u8)id)
	case [2]string:
		tex_id_u32 = hash.murmur32(transmute([]u8)id.x)
		if id.y == ""{
			mod_id_u32 = 0
		}else{
			mod_id_u32 = hash.murmur32(transmute([]u8)id.y)
		}
	case u32:
		tex_id_u32 = id
	case [2]u32:
		tex_id_u32 = id.x
		mod_id_u32 = id.y
	}
	new_tex_id = {tex_id_u32,mod_id_u32}
	return
}

Texture_ID_Types::union{
	string,
	[2]string,
	u32,
	[2]u32,
}
