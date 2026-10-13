package voxl_game

import "core:time"
import tg"../../../tg_render_sdl3gpu"
import sdl "vendor:sdl3"
import "core:log"
import "core:mem"
import "core:hash"
import "core:c"
import "core:fmt"
import "core:thread"
// import hm "../../handle_map_static_virtual"
import hm "core:container/handle_map"
import an"../../ansi"
import lin"core:math/linalg"
import cl"../../clay-odin"
import st"core:strings"
import steam "../../steamworks"
import reg "../../registry"
import "base:intrinsics"


Item_Reg::reg.Registry(Item_Info,Item_HD)
Item_HD::hm.Handle32 // this is a hd used to qwicly ref an item but this hd can change every restart do not save it to disk it is much faster than a Item_ID
Item_ID::reg.Reg_ID // this is a id used to ref a item for things like saveing it is stable and will never change. it is much slower than a Item_HD

Material_Reg::reg.Registry(Material_Info,Material_HD)
Material_HD::hm.Handle32 // this is a hd used to qwicly ref an item but this hd can change every restart do not save it to disk it is much faster than a Item_ID
Material_ID::reg.Reg_ID // this is a id used to ref a item for things like saveing it is stable and will never change. it is much slower than a Item_HD

Item_Tags :: bit_set[Item_Tag]
Item_Tag::enum{
	// ==========================================
	// 🧊 VOXEL WORLD PHYSICS & INTERACTION
	// ==========================================
	Is_Solid,          // Collides with entities; stands as a full block
	Is_Fluid,          // Flowing liquid physics (water, lava)
	Is_Gas,            // Volatile/floating gases (smoke, steam)
	Is_Transparent,    // Renderer passes light through (glass, ice)
	Is_Opaque,         // Blocks rendering and raycasts completely
	Can_Burn,          // Catches fire and spreads it to neighbors
	Is_Fireproof,      // Immune to fire and explosion damage
	Emits_Light,       // Acts as a static or dynamic voxel light source
	Has_Gravity,       // Falls down if there is no block underneath (sand, gravel)
	Is_Replacable,     // Can be placed directly over (tall grass, flowers, water)
	Is_Climbable,      // Entities can move upward through it (ladders, vines)
	Slippery,          // Lowers friction for physics entities (ice, slime)
	Sticky,            // High friction; slows down or stops entities (honey)
	Bouncy,            // Reflects velocity on collision (trampoline, slime block)
	Is_Fragile,        // Breaks instantly when touched/walked on (lilypads, thin ice)

	// ==========================================
	// 🎒 CLASSIFICATION & INVENTORY MANAGEMENT
	// ==========================================
	Is_Block,          // Item can be placed into the world grid
	Is_Tool,           // Can execute functional actions or increase block damage
	Is_Armor,          // Can be equipped to a player or entity armor slot
	Is_Weapon,         // Primarily designed for combat hitboxes
	Is_Edible,         // Can be consumed directly for stats/buffs
	Is_Drinkable,      // Liquid containers (potions, milk)
	Is_Deployable,     // Spawns an entity instead of placing a block (boats, minecarts)
	Is_Currency,       // Used by trading systems (gold coins, emeralds)
	Is_Quest_Item,     // Locked item; cannot be dropped or deleted by players
	Is_Hidden,         // Excluded from creative menus or recipe finders

	// ==========================================
	// 🛠️ TOOL TYPE ARCHETYPES
	// ==========================================

	// ==========================================
	// ⚔️ COMBAT, WEAPONS & EQUIPMENT
	// ==========================================
	Weapon_Melee,      // Standard close-quarters weapon (swords, daggers)
	Weapon_Ranged,     // Needs projectiles to fire (bows, crossbows)
	Weapon_Magic,      // Consumes mana/energy to fire a projectile or spell
	Armor_Head,        // Helmet slot
	Armor_Chest,       // Chestplate slot
	Armor_Legs,        // Leggings slot
	Armor_Feet,        // Boots slot
	Can_Parry,         // Item can block or deflect incoming physical attacks
	Deals_Fire_Damage,  // Applies status effect "On Fire"
	Deals_Frost_Damage, // Slows targets down
	Deals_Toxic_Damage, // Applies Damage Over Time (DOT) poison effects

	// ==========================================
	// 🍞 CONSUMABLES, FLORA & ALCHEMY
	// ==========================================
	Is_Raw,            // Raw item that can cause illness (raw meat)
	Is_Cooked,         // Processed food; safe and provides higher recovery
	Is_Poisonous,      // Bad to consume; applies negative buffs
	Is_Medicinal,      // Restores health directly
	Is_Ingredient,     // Used solely in crafting recipes (sugar, flour, herbs)
	Is_Seed,           // Can be planted into tilled earth to grow crops
	Is_Spore,          // Grows on dark/damp surfaces (mushrooms)

	// ==========================================
	// ⚙️ LOGIC & REDSTONE / AUTOMATION
	// ==========================================
	Is_Power_Source,   // Outputs logic signals (levers, buttons, redstone torches)
	Is_Conductor,      // Transmits signal logic to neighboring blocks (wires)
	Is_Consumer,       // Uses a logic signal to trigger actions (doors, pistons, lights)
	Is_Container,      // Holds extra dynamic inventory arrays (chests, hoppers)
	Allows_Comparator, // Outputs a signal strength based on internal item count
}
Item_Info::struct{
	reg_id:Item_ID,
	handle:Item_HD,
	
	tags:Item_Tags,
	material_hd:Material_HD,
	name:string,

	light_emission:[3]u8,//rgb 0-31 
	// texture_id:tg.Texture_ID_Types,
	// texture_face_index:u16,

	model_data:Model_Data,
	texture_data:Texture_Data,

	tier:		Item_Tier,
	rarity:		Item_Rarity,
	
	is_solid: bool,//used for psicks
	is_occupied:bool,//if false will not render
	is_opaque:bool,////if false will not hide nabers faces basickly it lets it be transperint

}

Material_Tags :: bit_set[Material_Tag]
Material_Tag::enum{

	Is_Organic,        // Wood, plants, Stone
	Is_Metal,          // Iron, copper, bronze, adamantine
	Is_Gem,            // Diamonds, rubies, quartz crystals
	Is_Fabric,         // Wool, carpets, banners, clothing

	has_wood_v,
	has_stone_v,

}
Tools::enum{
	Tool_Pickaxe,
	Tool_Axe,
	Tool_Shovel,
	Tool_Hoe,
	Tool_Shears,
	Tool_Hammer,
	Tool_Wrench,
}
Material_Info::struct{
	reg_id:Material_ID,
	handle:Material_HD,

	name:string,
	material_tags:	Material_Tags,

	tex_id:reg.Reg_ID,

	hardness:	f32,
	durability:	i32,
	has_tools:	bit_set[Tools],
	col:		[4]f32,
	tier:		Item_Tier,
	rarity:		Item_Rarity,
}
Item_Tier::enum{
	Non,
	_1,
	_2,
	_3,
	_4,
	_5,
	_6,
}
Item_Rarity::enum{
	Non,
	Common,
	Uncommon,
	Rare,
	Epic,
	Legendary,
	Mythic,
	Devine,
	MOFASNSASD
}


Model_Data :: struct {
	cube_indices:[Model_Sides]int,
	extra_count:int,
}
Texture_Data :: struct {
	sides:[Model_Sides]int,
	extra_count:int,
}

init_all_item_data::proc(){
	init_texture_facees()
	init_geometry_facees()
	g.cube_face_geometry =  create_cube_face_geometry()
	reg_materials()
	reg_items()
	
	update_geometry_facees()
	update_texture_facees()
}
init_texture_facees::proc(){
	g.texture_facees = tg.init_indexed_gpu_data(tg.Vert_Face_Texure,"texture_facees_gpu_data",bind_to_vert = false,bind_to_frag = true)
}
init_geometry_facees::proc(){
	g.geometry_facees = tg.init_indexed_gpu_data(tg.Vert_Face_Geometry,"geometry_facees_gpu_data",bind_to_vert = true,bind_to_frag = false)
}

update_texture_facees::proc(){
	tg.update_indexed_gpu_data(&g.texture_facees)
}
update_geometry_facees::proc(){
	tg.update_indexed_gpu_data(&g.geometry_facees)
}
add_texture_face::proc(
	tex_id:reg.Reg_ID,
	tint:[4]f32={1,1,1,1},
	tex_id_2:reg.Reg_ID=tg.BLANK_TEX_ID,
	tint_2:[4]f32={0,0,0,0},
	mask_tex_id:reg.Reg_ID=tg.BLANK_TEX_ID,
	mask_tint_l:[4]f32={0,0,0,0},
	mask_tint_d:[4]f32={0,0,0,0},
)->(index:int){
	data:DF_FACE_TYPE

	// data.uv[0] =  {0,0}
	// data.uv[1] =  {0,1}
	// data.uv[2] =  {1,1}
	// data.uv[3] =  {1,0}

	texture:=tg.get_texture_by_id(tex_id)

	data.img_index = cast(u32)texture.groop_index
	data.layer = texture.layer
	data.tint = tint

	texture_2:=tg.get_texture_by_id(tex_id_2)

	data.img_index_2 = cast(u32)texture_2.groop_index
	data.layer_2 = texture_2.layer
	data.tint_2 = tint_2

	mask_texture:=tg.get_texture_by_id(mask_tex_id)
	data.mask_index = cast(u32)mask_texture.groop_index
	data.mask_layer = mask_texture.layer
	data.mask_tint_l = mask_tint_l
	data.mask_tint_d = mask_tint_d

	index=tg.add_indexed_gpu_data(&g.texture_facees,data)
	return
}

// resends the data to the gpu
fill_sides_all_1_t::proc(index:int) -> (sides:[Model_Sides]int){
	sides[.pos_x] = index
	sides[.neg_x] = index
	sides[.pos_y] = index
	sides[.neg_y] = index
	sides[.pos_z] = index
	sides[.neg_z] = index
	return
}

DF_Items::enum{
	air,
	dirt,
	grass,
	stone_slate,
}
creae_df_items_info::proc()->(df_items_info:[DF_Items]Item_Info){
	i:=&df_items_info
	i[.air] = Item_Info{
		
	}
	dirt_t_id:=add_texture_face(reg.id(Textures.Dirt))
	i[.dirt] = Item_Info{
		texture_data = {sides = fill_sides_all_1_t(dirt_t_id)},
		model_data = g.cube_face_geometry,
		is_occupied = true,
		is_opaque = true,
		is_solid = true,
		name = "Dirt",
	}
	grass_t_id:=add_texture_face(reg.id(Textures.Grass_Overlay),{.2,.7,.3,1})
	grass_side_t_id:=add_texture_face(reg.id(Textures.Dirt),{1,1,1,1},reg.id(Textures.Grass_Side_Overlay),{.2,.7,.3,1})
	i[.grass] = Item_Info{
		texture_data = {
			sides = [Model_Sides]int{
				.pos_x = grass_side_t_id,
				.neg_x = grass_side_t_id,
				.pos_y = grass_t_id,
				.neg_y = dirt_t_id,
				.pos_z = grass_side_t_id,
				.neg_z = grass_side_t_id,
				.extra = {},
			}
		},
		model_data = g.cube_face_geometry,
		is_occupied = true,
		is_opaque = true,
		is_solid = true,
		name = "Grass",
	}
	stone_slate_t_id:=add_texture_face(reg.id(Textures.Stone_Slate),{1,1,1,1})
	i[.stone_slate] = Item_Info{
		texture_data = {sides = fill_sides_all_1_t(stone_slate_t_id)},
		model_data = g.cube_face_geometry,
		is_occupied = true,
		is_opaque = true,
		is_solid = true,
		name = "Slate",
	}
	return
}

// sand_hd:Item_HD
DF_FACE_TYPE::tg.Vert_Face_Texure
reg_items::proc(){
	df_items:=creae_df_items_info()
	for item, i in df_items{
		g.df_items[i] = reg.add(&g.item_reg,item,reg.id(i))
		// sand_hd=reg.add(&g.item_reg,sand_info,reg.id(DF_Items.dirt))
	}
	iterator:=hm.iterator_make(&g.material_reg.data)
	for mat,mat_hd in hm.iterate(&iterator){
			log.log(.Debug,"\n\n\n\n\n\n\n\n\n\n\n\n\n waffles",mat.material_tags)
		if .has_stone_v in mat.material_tags{
			{
				texture:=add_texture_face(reg.id(mat.tex_id),{1,1,1,1})
				name:=st.concatenate({mat.name," Stone"})
				item:Item_Info={
					name = name,
					tags = {.Is_Solid,.Is_Opaque,.Is_Block,},
					model_data = g.cube_face_geometry,
					texture_data = {sides = fill_sides_all_1_t(texture)},
					is_occupied = true,
					is_opaque = true,
					is_solid = true,
				}
				reg.add(&g.item_reg,item,reg.id([2]string{"DF",name}))
			}
			{
				texture:=add_texture_face(reg.id(mat.tex_id),{1,1,1,1},mask_tex_id = Textures_Dat[.Medium_Brick_Mask].id,mask_tint_l={.9,.9,1,1},mask_tint_d={1,1,.9,1})
				name:=st.concatenate({mat.name," Medium Brick"})
				item:Item_Info={
					name = name,
					tags = {.Is_Solid,.Is_Opaque,.Is_Block,},
					model_data = g.cube_face_geometry,
					texture_data = {sides = fill_sides_all_1_t(texture)},
					is_occupied = true,
					is_opaque = true,
					is_solid = true,
				}
				reg.add(&g.item_reg,item,reg.id([2]string{"DF",name}))
			}
			{
				texture:=add_texture_face(reg.id(mat.tex_id),{1,1,1,1},mask_tex_id = Textures_Dat[.Small_Brick_Mask].id,mask_tint_l={.9,.9,1,1},mask_tint_d={1,1,.9,1})
				name:=st.concatenate({mat.name," Small Brick"})
				item:Item_Info={
					name = name,
					tags = {.Is_Solid,.Is_Opaque,.Is_Block,},
					model_data = g.cube_face_geometry,
					texture_data = {sides = fill_sides_all_1_t(texture)},
					is_occupied = true,
					is_opaque = true,
					is_solid = true,
				}
				reg.add(&g.item_reg,item,reg.id([2]string{"DF",name}))
			}
			{
				texture:=add_texture_face(reg.id(mat.tex_id),{1,1,1,1},mask_tex_id = Textures_Dat[.Small_Cobblestone_Mask].id,mask_tint_l={.9,.9,1,1},mask_tint_d={1,1,.9,1})
				name:=st.concatenate({mat.name," Cobblestone"})
				item:Item_Info={
					name = name,
					tags = {.Is_Solid,.Is_Opaque,.Is_Block,},
					model_data = g.cube_face_geometry,
					texture_data = {sides = fill_sides_all_1_t(texture)},
					is_occupied = true,
					is_opaque = true,
					is_solid = true,
				}
				reg.add(&g.item_reg,item,reg.id([2]string{"DF",name}))
			}
			{
				texture:=add_texture_face(reg.id(mat.tex_id),{1,1,1,1},mask_tex_id = Textures_Dat[.Polished_Mask].id,mask_tint_l={.9,.9,1,1},mask_tint_d={1,1,.9,1})
				name:=st.concatenate({mat.name," Polished"})
				item:Item_Info={
					name = name,
					tags = {.Is_Solid,.Is_Opaque,.Is_Block,},
					model_data = g.cube_face_geometry,
					texture_data = {sides = fill_sides_all_1_t(texture)},
					is_occupied = true,
					is_opaque = true,
					is_solid = true,
				}
				reg.add(&g.item_reg,item,reg.id([2]string{"DF",name}))
			}
			{
				texture:=add_texture_face(reg.id(mat.tex_id),{1,1,1,1},mask_tex_id = Textures_Dat[.Large_Square_Tiles_Mask].id,mask_tint_l={.9,.9,1,1},mask_tint_d={1,1,.9,1})
				name:=st.concatenate({mat.name," Large Square Tiles"})
				item:Item_Info={
					name = name,
					tags = {.Is_Solid,.Is_Opaque,.Is_Block,},
					model_data = g.cube_face_geometry,
					texture_data = {sides = fill_sides_all_1_t(texture)},
					is_occupied = true,
					is_opaque = true,
					is_solid = true,
				}
				reg.add(&g.item_reg,item,reg.id([2]string{"DF",name}))
			}
		}
	}
}

DF_Materials::enum{
	slate,
}

DF_STONE_HARDNESS::3
DF_STONE_DURABILITY::3
creae_df_materials_info::proc()->(df_items_info:[DF_Materials]Material_Info){
	i:=&df_items_info


	i[.slate] = Material_Info{
		name =			"Slate",
		material_tags =	{.has_stone_v,.Is_Organic,},
		hardness =		DF_STONE_HARDNESS,
		durability =	DF_STONE_DURABILITY,
		col =			{.063,.063,.263,1},
		tier =			.Non,
		rarity =		.Common,
		tex_id = Textures_Dat[.Stone_Slate].id,
	}
	return
}

reg_materials::proc(){
	df_materials:=creae_df_materials_info()
	for material, i in df_materials{
		g.df_materials[i] = reg.add(&g.material_reg,material,reg.id(i))
	}
}


create_cube_face_geometry :: proc() -> Model_Data {

	result: Model_Data


	result.cube_indices[.pos_x] = tg.add_indexed_gpu_data(
		&g.geometry_facees,
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 1, 1, 1, 1},
				{ 1, 0, 1, 1},
				{ 1, 0, 0, 1},
				{ 1, 1, 0, 1},
			},
			starting_shade = .65
		},
	)

	result.cube_indices[.neg_x] = tg.add_indexed_gpu_data(
		&g.geometry_facees,
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 0, 1, 0, 1},
				{ 0, 0, 0, 1},
				{ 0, 0, 1, 1},
				{ 0, 1, 1, 1},
			},
			starting_shade = .65
		},
	)

	result.cube_indices[.pos_y] = tg.add_indexed_gpu_data(
		&g.geometry_facees,
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 0, 1, 0, 1},
				{ 0, 1, 1, 1},
				{ 1, 1, 1, 1},
				{ 1, 1, 0, 1},
			},
			starting_shade = 1
		},
	)

	result.cube_indices[.neg_y] = tg.add_indexed_gpu_data(
		&g.geometry_facees,
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 1, 0, 0, 1},
				{ 1, 0, 1, 1},
				{ 0, 0, 1, 1},
				{ 0, 0, 0, 1},
			},
			starting_shade = .5
		},
	)

	result.cube_indices[.pos_z] = tg.add_indexed_gpu_data(
		&g.geometry_facees,
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 0, 1, 1, 1},
				{ 0, 0, 1, 1},
				{ 1, 0, 1, 1},
				{ 1, 1, 1, 1},
			},
			starting_shade = .8
		},
	)

	result.cube_indices[.neg_z] = tg.add_indexed_gpu_data(
		&g.geometry_facees,
		tg.Vert_Face_Geometry{
			uv =  {{0,0},{0,1},{1,1},{1,0}},
			pos = {
				{ 1, 1, 0, 1},
				{ 1, 0, 0, 1},
				{ 0, 0, 0, 1},
				{ 0, 1, 0, 1},
			},
			starting_shade = .8
		},
	)
	tg.update_indexed_gpu_data(&g.geometry_facees)

	return result
}


item_info_list_ui_box::proc(ui_box_handle:tg.UI_Box_Handle){
	ui_box,cl_inst,ok,vis:=tg.start_ui_box(ui_box_handle)
	index:=cast(u32)ui_box_handle.idx
	if !ok {return}

	if !vis {return}
	if cl.UI(cl.ID("item_info_list_ui_box_container",index))(tg.ui_box_dec(ui_box_handle,sizing ={cl.SizingFit({0,cast(f32)cl_inst.wh.x*.8}),cl.SizingFit({0,cast(f32)cl_inst.wh.y*.8})} , do_sizing = true,attachment = {.RightTop,.RightTop})) {

		
		if cl.UI(cl.ID("drag_box_item_info_list_ui_box",index))(
			tg.ui_drag_box_dec(ui_box_handle,s.input_events.mouse_move)
		){
			cl.Text("Item Info List",tg.text_dec(text_size_id = .small))
		}
		tg.inspector_go_back_button(&ui_box.inspector,cast(u32)ui_box_handle.idx)

	
		pading:=tg.get_ui_pading(.small)
		tg.clear_fields(&ui_box.inspector)
		tg.collect_fields(&ui_box.inspector)
		if cl.UI(cl.ID("item_info_list_constrante",index))(tg.defalt_box_dec(clip = {vertical=true,childOffset=cl.GetScrollOffset()},child_alignment = {.Left,.Top} )){
			id:u32
			iterator:=hm.iterator_make(&g.item_reg.data)
			for item,item_hd in hm.iterate(&iterator){
				if cl.UI(cl.ID("item_info_list_constrante_row_spacer_3",cast(u32)item_hd.idx))({layout = {sizing = {cl.SizingFit(),cl.SizingFit()},layoutDirection = .LeftToRight,},}){
					cl.TextDynamic(item.name,tg.text_dec(text_size_id = .small))
					if cl.Hovered(){
						if tg.is_input_event(.ui_l_c){
							g.temp_using_item_hd = item_hd
						}
					}
				}
			}
		// 	for &fild ,fild_index in &ui_box.inspector.fields{
		// 		if cl.UI(cl.ID("inspector_constrante_row",cast(u32)fild_index))({
		// 			layout = {
		// 				sizing = {cl.SizingGrow(),cl.SizingFit()},
		// 				layoutDirection = .LeftToRight,
		// 			},
		// 		}
		// 		){
		// 			if cl.UI(cl.ID("inspector_constrante_row_spacer_1",cast(u32)fild_index))({layout = {sizing = {cl.SizingFit(),cl.SizingFit()},layoutDirection = .LeftToRight,},}){
		// 				cl.TextDynamic(fild.name,tg.text_dec(text_size_id = .small))
		// 			}
		// 			if cl.UI(cl.ID("inspector_constrante_row_spacer_2",cast(u32)fild_index))({layout = {sizing = {cl.SizingGrow(),cl.SizingFit()},layoutDirection = .LeftToRight,},}){
		// 				cl.Text("     ",tg.text_dec())
		// 			}
		// 			if cl.UI(cl.ID("inspector_constrante_row_spacer_3",cast(u32)fild_index))({layout = {sizing = {cl.SizingFit(),cl.SizingFit()},layoutDirection = .LeftToRight,},}){

		// 			}
		// 		}
		// 	}
		}
		item_info_list_ui_box_click(ui_box_handle)
	}
}

// ui_item::proc(item_hd:Item_HD){
// 	item,ok:=reg.get(&g.item_reg,item_hd)
// 	textur:=item.texture_data.sides[.pos_x]
// 	if cl.UI(cl.ID("Player_larg_icon", cast(u32)player.info.l_player_icon_id+index))(tg.defalt_img_box_dec(cast(rawptr)&player.info.l_player_icon_gpu_hd,size = player_icon_size)) {
// 	}

// }

item_info_list_ui_box_click::proc(ui_box_handle:tg.UI_Box_Handle){
	ui_box,ok:=tg.get_ui_box(ui_box_handle)
	if !ok {return}
	if ui_box == nil{return}
	if cl.Hovered(){
		if tg.is_input_event(.ui_l_c,always_consume_d = true){
			ui_box.last_interact = s.time.time
		}
	}
}
