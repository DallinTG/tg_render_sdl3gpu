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
	Tool_Pickaxe,      // Effective against stones/metals
	Tool_Axe,          // Effective against woods/organic structures
	Tool_Shovel,       // Effective against dirt/sand/gravel
	Tool_Hoe,          // Tills soil/clears leaf geometry quickly
	Tool_Shears,       // Snips plants or sheep without destroying the source block
	Tool_Hammer,       // Used for forging, crushing, or heavy knockback
	Tool_Wrench,       // Rotates blocks or dismantles machinery cleanly

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
	texture_id:tg.Texture_ID_Types,
	texture_face_index:u16,

	model_data:Model_Data,

	tier:		Item_Tier,
	rarity:		Item_Rarity
}

Material_Tags :: bit_set[Material_Tag]
Material_Tag::enum{
	// ==========================================
	// 🪵 BROAD LINEAGE & AUDIO/PARTICLE MATRIX
	// ==========================================
	Is_Organic,        // Wood, plants, leather, feathers
	Is_Stone,          // Cobblestone, deep slate, bricks, obsidian
	Is_Metal,          // Iron, copper, bronze, adamantine
	Is_Gem,            // Diamonds, rubies, quartz crystals
	Is_Flesh,          // Monster parts, meats, soft skin bodies
	Is_Glass,          // Brittle sand-fused structures
	Is_Fabric,         // Wool, carpets, banners, clothing

	// ==========================================
	// 🔥 MANUFACTURING & REFINING
	// ==========================================
	Can_Smelt,         // Can be processed inside a standard furnace
	Can_Blast,         // Requires high-tier blast furnace for processing
	Can_Crush,         // Can be broken down into dust/gravel variants via hammers
	Is_Fuel,           // Can be burned inside machines to power recipes (coal, logs)
	Is_Alloy,          // Created by combining multiple metals together
	Is_Radioactive,    // Emits ambient hazard damage or powers high-tech tiers

	// ==========================================
	// ⛏️ HARVEST RULES & MINING TIERS
	// ==========================================
	Is_Brittle,        // Shatters completely into nothing if mined without the right tool
	Tier_Wood,         // Can be broken by anything
	Tier_Stone,        // Requires at least a stone tool to drop items
	Tier_Iron,         // Requires an iron tool to drop items
	Tier_Diamond,      // Requires diamond tier tools or higher
	Tier_Mythic,       // Endgame requirement layer

	// ==========================================
	// 🎨 AESTHETICS & RARITY
	// ==========================================
	Is_Precious,       // Highly sought after; boosts trade values with NPCs
	Is_Crystalline,    // Shines or catches specular lighting maps
	Is_Weathered,      // Can age over time (like copper turning green)
	Is_Anomalous,      // Defies standard engine laws (e.g., anti-gravity material)
}
Material_Info::struct{
	reg_id:Material_ID,
	handle:Material_HD,

	name:string,
	material_tags:	Material_Tags,
	hardness:	f32,
	durability:	i32,
	col:		[3]f32,
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


init_all_item_data::proc(){
	init_texture_facees()
	init_geometry_facees()
	g.cube_face_geometry =  create_cube_face_geometry()
	reg_materials()
	reg_items()
	
	update_texture_facees()
	update_geometry_facees()
}
init_texture_facees::proc(){
	g.texture_facees = tg.init_indexed_gpu_data(tg.Vert_Face_Texure,"texture_facees_gpu_data")
}
init_geometry_facees::proc(){
	g.geometry_facees = tg.init_indexed_gpu_data(tg.Vert_Face_Geometry,"geometry_facees_gpu_data")
}

update_texture_facees::proc(){
	tg.update_indexed_gpu_data(&g.texture_facees)
}
update_geometry_facees::proc(){
	tg.update_indexed_gpu_data(&g.geometry_facees)
}
add_texture_face::proc(tex_id:tg.Texture_ID_Types, $T:typeid)->(index:int){
	texture:=tg.get_texture_by_id(.Software_Hourglass_Sand_Time_Wait)
	data:T
	when intrinsics.type_has_field(T, "img_index"){
		data.img_index = cast(u32)texture.groop_index
	}
	when intrinsics.type_has_field(T, "layer"){
		data.layer = texture.layer
	}
	when intrinsics.type_has_field(T, "layer"){
		data.uv[0] =  {0,0}
		data.uv[1] =  {0,1}
		data.uv[2] =  {1,1}
		data.uv[3] =  {1,0}
	}
	index=tg.add_indexed_gpu_data(&g.texture_facees,data)
	return
}

// resends the data to the gpu


sand_hd:Item_HD
DF_FACE_TYPE::tg.Vert_Face_Texure
reg_items::proc(){
	sand_info:Item_Info={
		texture_id = .Food_Drink_Glass_Juice_Cocktail,
		texture_face_index = cast(u16)add_texture_face(.Food_Drink_Glass_Juice_Cocktail,DF_FACE_TYPE),
		model_data = g.cube_face_geometry,
		// texture = tg.get_texture_by_id(.Software_Hourglass_Sand_Time_Wait)
	}
	sand_hd=reg.add(&g.item_reg,sand_info,{1,1})
}
reg_materials::proc(){

}


create_cube_face_geometry :: proc() -> Model_Data {
	result: Model_Data

	// result.cube_indices[.pos_x] = tg.add_indexed_gpu_data(
	// 	&g.geometry_facees,
	// 	tg.Vert_Face_Geometry{
	// 		pos = {
	// 			{1, 0, 0, 1},
	// 			{1, 0, 1, 1},
	// 			{1, 1, 1, 1},
	// 			{1, 1, 0, 1},
	// 		},
	// 	},
	// )

	// result.cube_indices[.neg_x] = tg.add_indexed_gpu_data(
	// 	&g.geometry_facees,
	// 	tg.Vert_Face_Geometry{
	// 		pos = {
	// 			{0, 0, 1, 1},
	// 			{0, 0, 0, 1},
	// 			{0, 1, 0, 1},
	// 			{0, 1, 1, 1},
	// 		},
	// 	},
	// )

	// result.cube_indices[.pos_y] = tg.add_indexed_gpu_data(
	// 	&g.geometry_facees,
	// 	tg.Vert_Face_Geometry{
	// 		pos = {
	// 			{0, 1, 0, 1},
	// 			{1, 1, 0, 1},
	// 			{1, 1, 1, 1},
	// 			{0, 1, 1, 1},
	// 		},
	// 	},
	// )

	// result.cube_indices[.neg_y] = tg.add_indexed_gpu_data(
	// 	&g.geometry_facees,
	// 	tg.Vert_Face_Geometry{
	// 		pos = {
	// 			{0, 0, 1, 1},
	// 			{1, 0, 1, 1},
	// 			{1, 0, 0, 1},
	// 			{0, 0, 0, 1},
	// 		},
	// 	},
	// )

	// result.cube_indices[.pos_z] = tg.add_indexed_gpu_data(
	// 	&g.geometry_facees,
	// 	tg.Vert_Face_Geometry{
	// 		pos = {
	// 			{1, 0, 1, 1},
	// 			{0, 0, 1, 1},
	// 			{0, 1, 1, 1},
	// 			{1, 1, 1, 1},
	// 		},
	// 	},
	// )

	// result.cube_indices[.neg_z] = tg.add_indexed_gpu_data(
	// 	&g.geometry_facees,
	// 	tg.Vert_Face_Geometry{
	// 		pos = {
	// 			{0, 0, 0, 1},
	// 			{1, 0, 0, 1},
	// 			{1, 1, 0, 1},
	// 			{0, 1, 0, 1},
	// 		},
	// 	},
	// )
// 
//___________________________________

	result.cube_indices[.pos_x] = tg.add_indexed_gpu_data(
		&g.geometry_facees,
		tg.Vert_Face_Geometry{
			pos = {
				{ 0,  0,  0, 1},
				{ 0, -1,  0, 1},
				{ 1, -1,  0, 1},
				{ 1,  0,  0, 1},
			},
		},
	)

	result.cube_indices[.neg_x] = tg.add_indexed_gpu_data(
		&g.geometry_facees,
		tg.Vert_Face_Geometry{
			pos = {
				{ 1,  0, -1, 1},
				{ 1, -1, -1, 1},
				{ 0, -1, -1, 1},
				{ 0,  0, -1, 1},
			},
		},
	)

	result.cube_indices[.pos_y] = tg.add_indexed_gpu_data(
		&g.geometry_facees,
		tg.Vert_Face_Geometry{
			pos = {
				{ 1,  0,  0, 1},
				{ 1, -1,  0, 1},
				{ 1, -1, -1, 1},
				{ 1,  0, -1, 1},
			},
		},
	)

	result.cube_indices[.neg_y] = tg.add_indexed_gpu_data(
		&g.geometry_facees,
		tg.Vert_Face_Geometry{
			pos = {
				{ 0,  0, -1, 1},
				{ 0, -1, -1, 1},
				{ 0, -1,  0, 1},
				{ 0,  0,  0, 1},
			},
		},
	)

	result.cube_indices[.pos_z] = tg.add_indexed_gpu_data(
		&g.geometry_facees,
		tg.Vert_Face_Geometry{
			pos = {
				{ 0,  0, -1, 1},
				{ 0,  0,  0, 1},
				{ 1,  0,  0, 1},
				{ 1,  0, -1, 1},
			},
		},
	)

	result.cube_indices[.neg_z] = tg.add_indexed_gpu_data(
		&g.geometry_facees,
		tg.Vert_Face_Geometry{
			pos = {
				{ 1, -1, -1, 1},
				{ 1, -1,  0, 1},
				{ 0, -1,  0, 1},
				{ 0, -1, -1, 1},
			},
		},
	)
	
	tg.update_indexed_gpu_data(&g.geometry_facees)

	return result
}
