// package ctm
// 
// import "core:fmt"
// import "core:image"
// import "core:image/png"
// import "core:os"
// import "core:strings"
// import c "core:c"
// import stb_image "vendor:stb/image"
// 
// // CTM_Report describes the work performed by gen_conected_textures.
// CTM_Report :: struct {
// 	folders_found:  int,
// 	source_images:  int,
// 	files_generated: int,
// 	errors:         int,
// }
// 
// // Each value identifies one quadrant from the five source panels:
// //   0..3   = panel A: top-left, top-right, bottom-left, bottom-right
// //   4..7   = panel B
// //   8..11  = panel C
// //   12..15 = panel D
// //   16..19 = panel E
// // Each CT tile is assembled from four quadrants in TL, TR, BL, BR order.
// CTM_LAYOUT: [47][4]u8 = {
// 	{ 0,  1,  2,  3},
// 	{ 0, 13,  2, 15},
// 	{12, 13, 14, 15},
// 	{12,  1, 14,  3},
// 	{ 0, 13, 10, 19},
// 	{12,  1, 18, 11},
// 	{ 8, 17, 10, 19},
// 	{12, 13, 18, 19},
// 	{16,  5, 18, 19},
// 	{16, 17, 18,  7},
// 	{ 4, 17,  6, 19},
// 	{ 4,  5, 18, 19},
// 	{ 0,  1, 10, 11},
// 	{ 0, 13, 10,  7},
// 	{12, 13,  6,  7},
// 	{12,  1,  6, 11},
// 	{ 8, 17,  2, 15},
// 	{16,  9, 14,  3},
// 	{16, 17, 14, 15},
// 	{16,  9, 18, 11},
// 	{ 4, 17, 18, 19},
// 	{16, 17,  6, 19},
// 	{16, 17,  6,  7},
// 	{16,  5, 18,  7},
// 	{ 8,  9, 10, 11},
// 	{ 8,  5, 10,  7},
// 	{ 4,  5,  6,  7},
// 	{ 4,  9,  6, 11},
// 	{ 8, 17, 10,  7},
// 	{12, 13,  6, 19},
// 	{ 8,  5, 10, 19},
// 	{12, 13, 18,  7},
// 	{ 4,  5,  6, 19},
// 	{ 4,  5, 18,  7},
// 	{16,  5,  6, 19},
// 	{ 4, 17, 18,  7},
// 	{ 8,  9,  2,  3},
// 	{ 8,  5,  2, 15},
// 	{ 4,  5, 14, 15},
// 	{ 4,  9, 14,  3},
// 	{16,  5, 14, 15},
// 	{ 4,  9, 18, 11},
// 	{ 4, 17, 14, 15},
// 	{16,  9,  6, 11},
// 	{ 4, 17,  6,  7},
// 	{16,  5,  6,  7},
// 	{16, 17, 18, 19},
// }
// 
// // gen_conected_textures recursively searches root_path for directories whose
// // names begin with "CT_". Every such directory is searched for PNG files whose
// // names begin with "SRC_". Each matching source strip creates CT0..CT46 files
// // alongside the source image. Existing CT*.png files are overwritten.
// //
// // Source strip format: five square panels placed left-to-right (A, B, C, D, E).
// // Example: five 16x16 panels form an 80x16 PNG. The source file is kept.
// //
// // Returns counts so the caller can report the result to its own UI/log.
// gen_conected_textures :: proc(root_path: string) -> (report: CTM_Report) {
// 	fmt.eprintfln("")
// 	fmt.eprintfln("============================================================")
// 	fmt.eprintfln("[CTM] GENERATOR START")
// 	fmt.eprintfln("[CTM] Root path: %s", root_path)
// 	fmt.eprintfln("============================================================")
// 	if !os.is_directory(root_path) {
// 		fmt.eprintfln("CTM: root path is not a directory: %s", root_path)
// 		report.errors += 1
// 		return
// 	}
// 
// 
// 	fmt.eprintfln("[CTM] Root directory exists")
// 	fmt.eprintfln("[CTM] Beginning recursive directory scan")
// 
// 	scan_directory(root_path, &report)
// 
// 	fmt.eprintfln("")
// 	fmt.eprintfln("============================================================")
// 	fmt.eprintfln("[CTM] GENERATION COMPLETE")
// 	fmt.eprintfln("[CTM] CT folders found: %d", report.folders_found)
// 	fmt.eprintfln("[CTM] Source images found: %d", report.source_images)
// 	fmt.eprintfln("[CTM] Output files generated: %d", report.files_generated)
// 	fmt.eprintfln("[CTM] Errors: %d", report.errors)
// 	fmt.eprintfln("============================================================")
// 	return
// }
// 
// scan_directory :: proc(directory: string, report: ^CTM_Report) {
// 	fmt.print("scaning directory",directory,"\n")
// 	entries, read_err := os.read_directory_by_path(directory, 0, context.allocator)
// 	if read_err != nil {
// 		fmt.eprintfln("[CTM][ERROR] Could not read directory: %s", directory)
// 		fmt.eprintfln("[CTM][ERROR] Reason: %v", read_err)
// 		report.errors += 1
// 		fmt.eprintfln("[CTM][SCAN] STOP: %s", directory)
// 		return
// 	}
// 	defer os.file_info_slice_delete(entries, context.allocator)
// 
// 
// 	fmt.eprintfln("[CTM][SCAN] Directory read successfully")
// 	fmt.eprintfln("[CTM][SCAN] Entries found: %d", len(entries))
// 
// 	for entry in entries {
// 		if entry.type != .Directory do continue
// 
// 		if strings.has_prefix(entry.name, "CT_") {
// 			report.folders_found += 1
// 			source_count := process_ct_folder(entry.fullpath, report)
// 			if source_count == 0 {
// 				fmt.eprintfln("CTM: no SRC_*.png source strip found in %s", entry.fullpath)
// 				report.errors += 1
// 			}
// 		}
// 
// 		// Continue recursively so CT_ folders can exist at any depth.
// 
// 		fmt.eprintfln("[CTM][SCAN] Entering subdirectory: %s", entry.fullpath)
// 		scan_directory(entry.fullpath, report)
// 		fmt.eprintfln("[CTM][SCAN] Returned from subdirectory: %s", entry.fullpath)
// 	}
// }
// 
// process_ct_folder :: proc(directory: string, report: ^CTM_Report) -> (source_count: int) {
// 	entries, read_err := os.read_directory_by_path(directory, 0, context.allocator)
// 	if read_err != nil {
// 		fmt.eprintfln("CTM: could not read CT folder %s: %v", directory, read_err)
// 		report.errors += 1
// 		return
// 	}
// 	defer os.file_info_slice_delete(entries, context.allocator)
// 
// 	for entry in entries {
// 		if entry.type != .Regular do continue
// 		if !strings.has_prefix(entry.name, "SRC_") do continue
// 		if len(entry.name) < 4 || !strings.equal_fold(entry.name[len(entry.name)-4:], ".png") do continue
// 
// 		source_count += 1
// 		report.source_images += 1
// 		source_stem := os.stem(entry.name)
// 		suffix := source_stem[4:]
// 		if len(suffix) == 0 {
// 			fmt.eprintfln("CTM: source file has no name after SRC_: %s", entry.fullpath)
// 			report.errors += 1
// 			continue
// 		}
// 
// 		generate_from_source(entry.fullpath, directory, suffix, report)
// 	}
// 
// 	return
// }
// 
// generate_from_source :: proc(source_path, output_directory, suffix: string, report: ^CTM_Report) {
// 	source, load_err := png.load_from_file(source_path)
// 	if load_err != nil || source == nil {
// 		fmt.eprintfln("CTM: failed to load %s: %v", source_path, load_err)
// 		report.errors += 1
// 		return
// 	}
// 	defer image.destroy(source)
// 
// 	if source.depth != 8 || source.height <= 0 || source.height%2 != 0 || source.width != source.height*5 {
// 		fmt.eprintfln("CTM: invalid source dimensions for %s (expected 5 square 8-bit panels; got %dx%d, depth %d)", source_path, source.width, source.height, source.depth)
// 		report.errors += 1
// 		return
// 	}
// 
// 	channels := source.channels
// 	if channels < 1 || channels > 4 {
// 		fmt.eprintfln("CTM: unsupported channel count for %s: %d", source_path, channels)
// 		report.errors += 1
// 		return
// 	}
// 
// 	source_pixels := source.pixels.buf[:]
// 	expected_size := source.width*source.height*channels
// 	if len(source_pixels) != expected_size {
// 		fmt.eprintfln("CTM: invalid pixel buffer size for %s", source_path)
// 		report.errors += 1
// 		return
// 	}
// 
// 	tile_size := source.height
// 	half_size := tile_size/2
// 	row_size := half_size*channels
// 
// 	output_pixels := make([]u8, tile_size*tile_size*channels)
// 	defer delete(output_pixels)
// 
// 	for tile_index in 0..<47 {
// 		for output_quadrant in 0..<4 {
// 			component := int(CTM_LAYOUT[tile_index][output_quadrant])
// 	
// 			source_panel := component / 4
// 			source_quadrant := component % 4
// 	
// 			source_x := source_panel*tile_size + (source_quadrant%2)*half_size
// 			source_y := (source_quadrant/2)*half_size
// 	
// 			output_x := (output_quadrant%2)*half_size
// 			output_y := (output_quadrant/2)*half_size
// 	
// 			for y in 0..<half_size {
// 				src_index := ((source_y+y)*source.width+source_x)*channels
// 				dst_index := ((output_y+y)*tile_size+output_x)*channels
// 				copy(output_pixels[dst_index:dst_index+row_size],source_pixels[src_index:src_index+row_size])
// 			}
// 		}
// 
// 		output_name := fmt.aprintf("CT%d_%s.png", tile_index, suffix)
// 		output_path, path_err := os.join_path([]string{output_directory, output_name}, context.allocator)
// 		delete(output_name)
// 
// 		if path_err != nil {
// 			fmt.eprintfln("CTM: could not build output path in %s", output_directory)
// 			report.errors += 1
// 			continue
// 		}
// 
// 		output_c_path, c_path_err := strings.clone_to_cstring(output_path, context.allocator)
// 		if c_path_err != nil {
// 			fmt.eprintfln("CTM: could not convert output path: %s", output_path)
// 			report.errors += 1
// 			delete(output_path)
// 			continue
// 		}
// 
// 		write_result := stb_image.write_png(
// 			output_c_path,
// 			c.int(tile_size),
// 			c.int(tile_size),
// 			c.int(channels),
// 			rawptr(&output_pixels[0]),
// 			c.int(tile_size*channels),
// 		)
// 
// 		delete(output_c_path)
// 
// 		if write_result == 0 {
// 			fmt.eprintfln("CTM: failed to save %s", output_path)
// 			report.errors += 1
// 		} else {
// 			report.files_generated += 1
// 		}
// 
// 		delete(output_path)
// 	}
// }


package ctm

import "core:fmt"
import "core:image"
import "core:image/png"
import "core:os"
import "core:strings"
import c "core:c"
import stb_image "vendor:stb/image"


CTM_Report :: struct {
	folders_found:  int,
	source_images:  int,
	files_generated: int,
	errors:         int,
}


// The five panels in the source image, left to right.
CTM_Panel :: enum u8 {
	full,
	none,
	vertical,
	horizontal,
	corner,
}


// Every entry specifies which source panel supplies that quadrant.
//
// Quadrant order:
// 0 = top-left
// 1 = top-right
// 2 = bottom-left
// 3 = bottom-right
//
// The source quadrant is always copied to the same output quadrant.
//
// Source panel order:
// 0 = Full
// 1 = None
// 2 = Vertical
// 3 = Horizontal
// 4 = Corner

CTM_LAYOUT: [47][4]CTM_Panel = {
	{.full, .full, .full, .full},
	{.full, .horizontal, .full, .horizontal},
	{.horizontal, .horizontal, .horizontal, .horizontal},
	{.horizontal, .full, .horizontal, .full},

	{.full, .horizontal, .vertical, .corner},
	{.horizontal, .full, .corner, .vertical},
	{.vertical, .corner, .vertical, .corner},
	{.horizontal, .horizontal, .corner, .corner},

	{.corner, .none, .corner, .corner},
	{.corner, .corner, .corner, .none},
	{.none, .corner, .none, .corner},
	{.none, .none, .corner, .corner},

	{.full, .full, .vertical, .vertical},
	{.full, .horizontal, .vertical, .none},
	{.horizontal, .horizontal, .none, .none},
	{.horizontal, .full, .none, .vertical},

	{.vertical, .corner, .full, .horizontal},
	{.corner, .vertical, .horizontal, .full},
	{.corner, .corner, .horizontal, .horizontal},
	{.corner, .vertical, .corner, .vertical},

	{.none, .corner, .corner, .corner},
	{.corner, .corner, .none, .corner},
	{.corner, .corner, .none, .none},
	{.corner, .none, .corner, .none},

	{.vertical, .vertical, .vertical, .vertical},
	{.vertical, .none, .vertical, .none},
	{.none, .none, .none, .none},
	{.none, .vertical, .none, .vertical},

	{.vertical, .corner, .vertical, .none},
	{.horizontal, .horizontal, .none, .corner},
	{.vertical, .none, .vertical, .corner},
	{.horizontal, .horizontal, .corner, .none},

	{.none, .none, .none, .corner},
	{.none, .none, .corner, .none},
	{.corner, .none, .none, .corner},
	{.none, .corner, .corner, .none},

	{.vertical, .vertical, .full, .full},
	{.vertical, .none, .full, .horizontal},
	{.none, .none, .horizontal, .horizontal},
	{.none, .vertical, .horizontal, .full},

	{.corner, .none, .horizontal, .horizontal},
	{.none, .vertical, .none, .vertical},
	{.none, .corner, .horizontal, .horizontal},
	{.corner, .vertical, .none, .vertical},

	{.none, .corner, .none, .none},
	{.corner, .none, .none, .none},
	{.corner, .corner, .corner, .corner},
}


gen_conected_textures :: proc(root_path: string) -> (report: CTM_Report) {
	fmt.eprintfln("")
	fmt.eprintfln("============================================================")
	fmt.eprintfln("[CTM] GENERATOR START")
	fmt.eprintfln("[CTM] Root path: %s", root_path)
	fmt.eprintfln("============================================================")

	if !os.is_directory(root_path) {
		fmt.eprintfln("[CTM][ERROR] Root path is not a directory: %s", root_path)
		report.errors += 1
		return
	}

	scan_directory(root_path, &report)

	fmt.eprintfln("")
	fmt.eprintfln("============================================================")
	fmt.eprintfln("[CTM] GENERATION COMPLETE")
	fmt.eprintfln("[CTM] CT folders found: %d", report.folders_found)
	fmt.eprintfln("[CTM] Source images found: %d", report.source_images)
	fmt.eprintfln("[CTM] Output files generated: %d", report.files_generated)
	fmt.eprintfln("[CTM] Errors: %d", report.errors)
	fmt.eprintfln("============================================================")

	return
}


scan_directory :: proc(directory: string, report: ^CTM_Report) {
	entries, read_err := os.read_directory_by_path(directory, 0, context.allocator)

	if read_err != nil {
		fmt.eprintfln("[CTM][ERROR] Could not read directory: %s (%v)", directory, read_err)
		report.errors += 1
		return
	}

	defer os.file_info_slice_delete(entries, context.allocator)

	for entry in entries {
		if entry.type != .Directory {
			continue
		}

		if strings.has_prefix(entry.name, "CT_") {
			report.folders_found += 1

			source_count := process_ct_folder(entry.fullpath, report)

			if source_count == 0 {
				fmt.eprintfln("[CTM][ERROR] No SRC_*.png files in %s", entry.fullpath)
				report.errors += 1
			}
		}

		scan_directory(entry.fullpath, report)
	}
}


process_ct_folder :: proc(directory: string, report: ^CTM_Report) -> (source_count: int) {
	entries, read_err := os.read_directory_by_path(directory, 0, context.allocator)

	if read_err != nil {
		fmt.eprintfln("[CTM][ERROR] Could not read CT folder: %s (%v)", directory, read_err)
		report.errors += 1
		return
	}

	defer os.file_info_slice_delete(entries, context.allocator)

	for entry in entries {
		if entry.type != .Regular {
			continue
		}

		if !strings.has_prefix(entry.name, "SRC_") {
			continue
		}

		if len(entry.name) <= 8 || !strings.equal_fold(entry.name[len(entry.name)-4:], ".png") {
			continue
		}

		source_stem := os.stem(entry.name)
		suffix := source_stem[4:]

		if len(suffix) == 0 {
			fmt.eprintfln("[CTM][ERROR] Empty source name: %s", entry.fullpath)
			report.errors += 1
			continue
		}

		source_count += 1
		report.source_images += 1

		generate_from_source(entry.fullpath, directory, suffix, report)
	}

	return
}


// Copies one quadrant from one of the five source panels into the same
// quadrant of the output texture.
//
// Source pixels are laid out as five square panels horizontally:
//
// | Full | None | Vertical | Horizontal | Corner |
//
// Every panel has tile_size * tile_size pixels.
copy_ctm_quadrant :: proc(
	source_pixels: []u8,
	output_pixels: []u8,
	source_width: int,
	tile_size: int,
	channels: int,
	panel: CTM_Panel,
	quadrant: int,
) {
	half := tile_size/2

	quadrant_x := quadrant%2
	quadrant_y := quadrant/2

	source_x := int(panel)*tile_size + quadrant_x*half
	source_y := quadrant_y*half

	output_x := quadrant_x*half
	output_y := quadrant_y*half

	row_bytes := half*channels

	for y in 0..<half {
		src_index := ((source_y+y)*source_width+source_x)*channels
		dst_index := ((output_y+y)*tile_size+output_x)*channels

		copy(
			output_pixels[dst_index:dst_index+row_bytes],
			source_pixels[src_index:src_index+row_bytes],
		)
	}
}


generate_from_source :: proc(
	source_path: string,
	output_directory: string,
	suffix: string,
	report: ^CTM_Report,
) {
	source, load_err := png.load_from_file(source_path)

	if load_err != nil || source == nil {
		fmt.eprintfln("[CTM][ERROR] Failed to load %s: %v", source_path, load_err)
		report.errors += 1
		return
	}

	defer image.destroy(source)

	// Five square source panels, each split into four equal quadrants.
	if source.depth != 8 || source.height <= 0 || source.width != source.height*5 || source.height%2 != 0 {
		fmt.eprintfln(
			"[CTM][ERROR] Invalid source dimensions: %s (%dx%d, depth %d)",
			source_path,
			source.width,
			source.height,
			source.depth,
		)
		report.errors += 1
		return
	}

	channels := source.channels

	if channels < 1 || channels > 4 {
		fmt.eprintfln("[CTM][ERROR] Unsupported channel count: %d (%s)", channels, source_path)
		report.errors += 1
		return
	}

	source_pixels := source.pixels.buf[:]
	expected_size := source.width*source.height*channels

	if len(source_pixels) != expected_size {
		fmt.eprintfln("[CTM][ERROR] Invalid pixel buffer: %s", source_path)
		report.errors += 1
		return
	}

	tile_size := source.height
	output_pixels := make([]u8, tile_size*tile_size*channels)
	defer delete(output_pixels)

	// Generate all 47 CTM textures.
	for tile_index in 0..<47 {
		for quadrant in 0..<4 {
			copy_ctm_quadrant(
				source_pixels,
				output_pixels,
				source.width,
				tile_size,
				channels,
				CTM_LAYOUT[tile_index][quadrant],
				quadrant,
			)
		}

		write_ctm_texture(
			output_pixels,
			output_directory,
			suffix,
			tile_index,
			tile_size,
			channels,
			report,
		)
	}
}


write_ctm_texture :: proc(
	pixels: []u8,
	output_directory: string,
	suffix: string,
	tile_index: int,
	tile_size: int,
	channels: int,
	report: ^CTM_Report,
) {
	output_name := fmt.aprintf("CT%d_%s.png", tile_index, suffix)

	output_path, path_err := os.join_path(
		[]string{output_directory, output_name},
		context.allocator,
	)

	delete(output_name)

	if path_err != nil {
		fmt.eprintfln("[CTM][ERROR] Could not build output path in %s", output_directory)
		report.errors += 1
		return
	}

	defer delete(output_path)

	output_c_path, c_path_err := strings.clone_to_cstring(output_path, context.allocator)

	if c_path_err != nil {
		fmt.eprintfln("[CTM][ERROR] Could not convert output path: %s", output_path)
		report.errors += 1
		return
	}

	defer delete(output_c_path)

	write_result := stb_image.write_png(
		output_c_path,
		c.int(tile_size),
		c.int(tile_size),
		c.int(channels),
		rawptr(&pixels[0]),
		c.int(tile_size*channels),
	)

	if write_result == 0 {
		fmt.eprintfln("[CTM][ERROR] Failed to save %s", output_path)
		report.errors += 1
		return
	}

	report.files_generated += 1
}
