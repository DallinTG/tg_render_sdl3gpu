package tg_pars

import "core:fmt"
import "core:os"
import settings ".."

Render_Mode :: enum u8 {
	Windowed,
	Borderless,
	Fullscreen,
}

Quality_Level :: enum u8 {
	Low,
	Medium,
	High,
	Ultra,
}

Direction :: enum {
	North,
	East,
	South,
	West,
}

Player_Class :: enum {
	Ranger,
	Engineer,
	Explorer,
}

Weather :: enum {
	Clear,
	Rain,
	Snow,
	Storm,
}

Audio_Effect :: enum u8 {
	None,
	Room,
	Cave,
}

Vec2 :: struct {
	x: f32,
	y: f32,
}

Vec3 :: struct {
	x: f32,
	y: f32,
	z: f32,
}

Color :: struct {
	r: u8,
	g: u8,
	b: u8,
	a: u8,
}

Window_Settings :: struct {
	title: string,
	width: int,
	height: int,
	position: [2]int,
	resizable: bool,
	mode: Render_Mode,
}

Texture_Settings :: struct {
	path: string,
	format: string,
	filtering: Quality_Level,
	mipmaps: bool,
	weights: [4]f32,
}

Graphics_Settings :: struct {
	vsync: bool,
	gamma: f32,
	resolution: [2]int,
	mode: Render_Mode,
	quality: Quality_Level,
	clear_color: Color,
	main_texture: Texture_Settings,
	fallback_texture: Texture_Settings,
	texture_formats: [3]string,
	samples: [3]int,
	supported_modes: [3]Render_Mode,
}

Audio_Settings :: struct {
	enabled: bool,
	output_device: string,
	master_volume: f32,
	channel_volumes: [4]f32,
	effect: Audio_Effect,
}

Item_Settings :: struct {
	id: u32,
	name: string,
	count: int,
	weight: f32,
	rarity: Quality_Level,
	description: string,
}

Player_Stats :: struct {
	health: i32,
	max_health: i32,
	stamina: i32,
	max_stamina: i32,
	modifiers: [3]f32,
}

Player_Settings :: struct {
	name: string,
	class: Player_Class,
	is_local: bool,
	position: Vec3,
	velocity: Vec3,
	stats: Player_Stats,
	inventory: [3]Item_Settings,
	hotbar: [4]int,
	aliases: [2]string,
}

Landmark_Settings :: struct {
	name: string,
	position: Vec3,
	rotation: Vec3,
	discovered: bool,
	description: string,
}

World_Settings :: struct {
	name: string,
	seed: i64,
	gravity: f32,
	spawn_points: [3]Vec3,
	landmarks: [2]Landmark_Settings,
	biomes: [3]string,
	weather: Weather,
	nested_grid: [2][3]i16,
}

Server_Settings :: struct {
	name: string,
	address: string,
	port: u16,
	priority: i32,
	enabled: bool,
	features: [3]string,
}

Big_Settings :: struct {
	version: u32,
	app_name: string,
	welcome_message: string,
	enabled: bool,
	max_fps: int,
	scale: f32,
	window: Window_Settings,
	graphics: Graphics_Settings,
	audio: Audio_Settings,
	player: Player_Settings,
	world: World_Settings,
	servers: [2]Server_Settings,
	labels: [4]string,
	difficulty_levels: [4]Quality_Level,
	nested_matrix: [2][3]f32,
	direction_positions: [Direction]Vec3,
}

Container_Settings :: struct {
	numbers: [dynamic]i32,
	recent_positions: [dynamic; 8]Vec3,
	text_values: [dynamic]string,
	scores: map[string]int,
	mode_names: map[Render_Mode]string,
	named_positions: map[string]Vec3,
}

Flat_Settings :: struct {
	bool_value: bool,
	int_value: int,
	signed_value: i64,
	unsigned_value: u16,
	float_value: f32,
	text_value: string,
	mode: Render_Mode,
	values: [4]i32,
}

FLAT_TEST_FILE :: "settings_test_flat.cfg"
BIG_TEST_FILE :: "settings_test_big.cfg"
CONTAINER_TEST_FILE :: "settings_test_containers.cfg"
ALL_TEST_FILE :: "settings_test_all.cfg"

make_big_settings :: proc() -> Big_Settings {
	return Big_Settings{
		version = 7,
		app_name = "Voxel Workshop",
		welcome_message = "Welcome, \"Pilot\"! Use the north gate, then continue.",
		enabled = true,
		max_fps = 240,
		scale = 1.25,
		window = Window_Settings{
			title = "Workshop Window",
			width = 1600,
			height = 900,
			position = {32, 64},
			resizable = true,
			mode = .Borderless,
		},
		graphics = Graphics_Settings{
			vsync = false,
			gamma = 1.5,
			resolution = {2560, 1440},
			mode = .Fullscreen,
			quality = .Ultra,
			clear_color = Color{r = 12, g = 34, b = 56, a = 255},
			main_texture = Texture_Settings{
				path = "textures/world\terrain, high.png",
				format = "RGBA8",
				filtering = .High,
				mipmaps = true,
				weights = {0.5, 0.25, 0.125, 0.0625},
			},
			fallback_texture = Texture_Settings{
				path = "textures/fallback.png",
				format = "RGB8",
				filtering = .Low,
				mipmaps = false,
				weights = {1.0, 0.5, 0.25, 0.125},
			},
			texture_formats = {"RGBA8", "BC7", "ASTC_4x4"},
			samples = {1, 2, 4},
			supported_modes = {.Windowed, .Borderless, .Fullscreen},
		},
		audio = Audio_Settings{
			enabled = true,
			output_device = "USB DAC, output = primary",
			master_volume = 0.75,
			channel_volumes = {1.0, 0.5, 0.25, 0.125},
			effect = .Cave,
		},
		player = Player_Settings{
			name = "Astra-7",
			class = .Engineer,
			is_local = true,
			position = Vec3{12.5, -3.25, 7.0},
			velocity = Vec3{0.5, 0.0, -1.25},
			stats = Player_Stats{
				health = 87,
				max_health = 100,
				stamina = 43,
				max_stamina = 60,
				modifiers = {1.25, 0.5, -0.25},
			},
			inventory = {
				Item_Settings{id = 101, name = "Copper Gear", count = 12, weight = 0.5, rarity = .Low, description = "Basic part, used for crafting."},
				Item_Settings{id = 205, name = "Crystal Core", count = 2, weight = 2.0, rarity = .Ultra, description = "A rare \"bright\" energy source."},
				Item_Settings{id = 309, name = "Field Rations", count = 8, weight = 0.25, rarity = .Low, description = "Packed for long journeys."},
			},
			hotbar = {0, 2, 1, 5},
			aliases = {"Ace", "Builder, One"},
		},
		world = World_Settings{
			name = "The Shattered Reach",
			seed = 1234567890123,
			gravity = 0.5,
			spawn_points = {Vec3{0.0, 64.0, 0.0}, Vec3{128.0, 70.0, -32.0}, Vec3{-16.0, 42.0, 96.0}},
			landmarks = {
				Landmark_Settings{name = "Old Tower", position = Vec3{10.0, 80.0, 20.0}, rotation = Vec3{0.0, 0.5, 0.0}, discovered = true, description = "A tower overlooking the valley."},
				Landmark_Settings{name = "Deep Vault", position = Vec3{-100.0, -20.0, 44.0}, rotation = Vec3{0.25, 0.0, 0.75}, discovered = false, description = "Sealed door, key required."},
			},
			biomes = {"pine forest", "red desert", "ice shelf"},
			weather = .Storm,
			nested_grid = {{1, 2, 3}, {-4, 5, 6}},
		},
		servers = {
			Server_Settings{name = "Local", address = "127.0.0.1", port = 27015, priority = 1, enabled = true, features = {"creative", "debug", "single-player"}},
			Server_Settings{name = "Community", address = "play.example.net", port = 30120, priority = 2, enabled = false, features = {"survival", "trading", "events"}},
		},
		labels = {"alpha", "beta build", "release candidate", "stable"},
		difficulty_levels = {.Low, .Medium, .High, .Ultra},
		nested_matrix = {{0.5, 1.25, -2.0}, {3.5, 4.25, 8.0}},
		direction_positions = {
			.North = Vec3{0.0, 0.0, -1.0},
			.East = Vec3{1.0, 0.0, 0.0},
			.South = Vec3{0.0, 0.0, 1.0},
			.West = Vec3{-1.0, 0.0, 0.0},
		},
	}
}

make_flat_settings :: proc() -> Flat_Settings {
	return Flat_Settings{
		bool_value = true,
		int_value = -12345,
		signed_value = -1234567890123,
		unsigned_value = 65000,
		float_value = 0.625,
		text_value = "quoted \"text\", with comma",
		mode = .Borderless,
		values = {-10, 0, 25, 100},
	}
}

make_alternate_flat_settings :: proc() -> Flat_Settings {
	value := Flat_Settings{
		bool_value = false,
		int_value = 9876,
		signed_value = 987654321012,
		unsigned_value = 1234,
		float_value = 2.75,
		text_value = "alternate profile, \"quoted\" text",
		mode = .Fullscreen,
		values = {7, 14, 21, 28},
	}
	return value
}

make_alternate_big_settings :: proc() -> Big_Settings {
	value := make_big_settings()
	value.version = 19
	value.app_name = "Voxel Workshop - Test Instance B"
	value.welcome_message = "Second profile: welcome, \"Navigator\"!"
	value.enabled = false
	value.max_fps = 144
	value.scale = 0.875
	value.window.title = "Secondary Window"
	value.window.width = 1280
	value.window.height = 720
	value.window.position = {901, 407}
	value.window.mode = .Windowed
	value.graphics.vsync = true
	value.graphics.gamma = 2.2
	value.graphics.resolution = {1920, 1080}
	value.graphics.mode = .Windowed
	value.graphics.quality = .Medium
	value.graphics.clear_color = Color{r = 200, g = 150, b = 100, a = 220}
	value.graphics.main_texture.path = "textures/alternate/main.png"
	value.graphics.fallback_texture.path = "textures/alternate/fallback.png"
	value.audio.enabled = false
	value.audio.output_device = "Secondary Speakers"
	value.audio.master_volume = 0.33
	value.audio.effect = .Room
	value.player.name = "Navigator-B"
	value.player.class = .Ranger
	value.player.is_local = false
	value.player.position = Vec3{-44.5, 18.25, 99.0}
	value.player.stats.health = 55
	value.player.stats.max_health = 80
	value.player.inventory[0].name = "Silver Gear"
	value.world.name = "The Mirror Expanse"
	value.world.seed = -987654321
	value.world.gravity = 1.25
	value.world.weather = .Snow
	value.world.biomes = {"moss valley", "black dunes", "crystal coast"}
	value.servers[0].name = "Secondary Local"
	value.servers[0].address = "192.168.1.42"
	value.servers[0].port = 28015
	value.labels = {"second", "profile B", "test values", "not defaults"}
	value.difficulty_levels = {.Ultra, .High, .Medium, .Low}
	value.nested_matrix = {{-1.5, 2.25, 9.0}, {10.5, -11.25, 12.75}}
	value.direction_positions = {
		.North = Vec3{0.0, 2.0, -2.0},
		.East = Vec3{2.0, 0.0, 0.0},
		.South = Vec3{0.0, 0.0, 2.0},
		.West = Vec3{-2.0, 0.0, 0.0},
	}
	return value
}

make_alternate_container_settings :: proc() -> Container_Settings {
	value := Container_Settings{}
	append(&value.numbers, 99, 88, -77, 1234, 0)
	append(&value.recent_positions, Vec3{-1.0, -2.0, -3.0}, Vec3{15.25, 16.5, 17.75})
	append(&value.text_values, "secondary", "different list, with commas", "second \"quoted\" value")

	value.scores = make(map[string]int)
	value.scores["alpha"] = 901
	value.scores["night shift"] = -802
	value.scores["alternate release"] = 703

	value.mode_names = make(map[Render_Mode]string)
	value.mode_names[.Windowed] = "Windowed B"
	value.mode_names[.Borderless] = "Borderless B"
	value.mode_names[.Fullscreen] = "Fullscreen B"

	value.named_positions = make(map[string]Vec3)
	value.named_positions["secondary spawn"] = Vec3{-10.0, 128.0, 20.0}
	value.named_positions["testing range"] = Vec3{2048.0, 128.0, -1024.0}
	return value
}

make_empty_container_settings :: proc() -> Container_Settings {
	value := Container_Settings{}
	value.scores = make(map[string]int)
	value.mode_names = make(map[Render_Mode]string)
	value.named_positions = make(map[string]Vec3)
	return value
}

big_settings_round_trip :: proc() -> bool {
	expected := make_big_settings()
	actual := Big_Settings{}

	if !tg_write(BIG_TEST_FILE, &expected) {
		fmt.printf("  tg_write failed for %s\n", BIG_TEST_FILE)
		return false
	}

	if !tg_read(BIG_TEST_FILE, &actual) {
		fmt.printf("  tg_read returned false for %s\n", BIG_TEST_FILE)
		return false
	}

	if expected != actual {
		fmt.println("  Big_Settings differs after write/read")
		return false
	}

	return true
}

flat_round_trip :: proc() -> bool {
	expected := make_flat_settings()
	actual := Flat_Settings{}

	if !tg_write(FLAT_TEST_FILE, &expected) {
		fmt.printf("  tg_write failed for %s\n", FLAT_TEST_FILE)
		return false
	}
	if !tg_read(FLAT_TEST_FILE, &actual) {
		fmt.printf("  tg_read returned false for %s\n", FLAT_TEST_FILE)
		return false
	}
	if expected != actual {
		fmt.println("  Flat_Settings differs after write/read")
		return false
	}
	return true
}

make_container_settings :: proc() -> Container_Settings {
	value := Container_Settings{}
	append(&value.numbers, 10, -20, 30, 400)
	append(&value.recent_positions, Vec3{1.0, 2.0, 3.0}, Vec3{-4.0, 5.5, 6.0}, Vec3{7.25, 8.0, -9.0})
	append(&value.text_values, "alpha", "two, with commas", "escaped \"quote\"")

	value.scores = make(map[string]int)
	value.scores["alpha"] = 10
	value.scores["beta"] = -20
	value.scores["release candidate"] = 300

	value.mode_names = make(map[Render_Mode]string)
	value.mode_names[.Windowed] = "Windowed Mode"
	value.mode_names[.Borderless] = "Borderless Mode"
	value.mode_names[.Fullscreen] = "Fullscreen Mode"

	value.named_positions = make(map[string]Vec3)
	value.named_positions["spawn"] = Vec3{0.0, 64.0, 0.0}
	value.named_positions["far point"] = Vec3{1024.0, -32.0, 512.0}
	return value
}

container_settings_equal :: proc(a, b: ^Container_Settings) -> bool {
	if len(a.numbers) != len(b.numbers) || len(a.recent_positions) != len(b.recent_positions) || len(a.text_values) != len(b.text_values) {
		return false
	}

	for i in 0..<len(a.numbers) {
		if a.numbers[i] != b.numbers[i] {
			return false
		}
	}

	for i in 0..<len(a.recent_positions) {
		if a.recent_positions[i] != b.recent_positions[i] {
			return false
		}
	}

	for i in 0..<len(a.text_values) {
		if a.text_values[i] != b.text_values[i] {
			return false
		}
	}

	if len(a.scores) != len(b.scores) || len(a.mode_names) != len(b.mode_names) || len(a.named_positions) != len(b.named_positions) {
		return false
	}

	for key, value in a.scores {
		other, ok := b.scores[key]
		if !ok || other != value {
			return false
		}
	}

	for key, value in a.mode_names {
		other, ok := b.mode_names[key]
		if !ok || other != value {
			return false
		}
	}

	for key, value in a.named_positions {
		other, ok := b.named_positions[key]
		if !ok || other != value {
			return false
		}
	}

	return true
}

container_round_trip :: proc() -> bool {
	expected := make_container_settings()
	actual := Container_Settings{}
	actual.scores = make(map[string]int)
	actual.mode_names = make(map[Render_Mode]string)
	actual.named_positions = make(map[string]Vec3)

	if !tg_write(CONTAINER_TEST_FILE, &expected) {
		fmt.printf("  tg_write failed for %s\n", CONTAINER_TEST_FILE)
		return false
	}
	if !tg_read(CONTAINER_TEST_FILE, &actual) {
		fmt.printf("  tg_read returned false for %s\n", CONTAINER_TEST_FILE)
		return false
	}
	if !container_settings_equal(&expected, &actual) {
		fmt.println("  dynamic arrays, fixed-capacity dynamic arrays, or maps differ after write/read")
		return false
	}
	return true
}

all_settings_single_file_round_trip :: proc() -> bool {
	err := os.write_entire_file(ALL_TEST_FILE, "")
	if err != nil {
		fmt.printf("  could not reset %s: %v\n", ALL_TEST_FILE, err)
		return false
	}

	// Two different instances of every settings type, all in the same file.
	expected_flat_a := make_flat_settings()
	expected_flat_b := make_alternate_flat_settings()
	expected_big_a := make_big_settings()
	expected_big_b := make_alternate_big_settings()
	expected_containers_a := make_container_settings()
	expected_containers_b := make_alternate_container_settings()

	if !tg_write(ALL_TEST_FILE, &expected_flat_a, "flat_primary") { return false }
	if !tg_write(ALL_TEST_FILE, &expected_big_a, "big_primary") { return false }
	if !tg_write(ALL_TEST_FILE, &expected_containers_a, "containers_primary") { return false }
	if !tg_write(ALL_TEST_FILE, &expected_flat_b, "flat_secondary") { return false }
	if !tg_write(ALL_TEST_FILE, &expected_big_b, "big_secondary") { return false }
	if !tg_write(ALL_TEST_FILE, &expected_containers_b, "containers_secondary") { return false }

	actual_flat_a := Flat_Settings{}
	actual_flat_b := Flat_Settings{}
	if !tg_read(ALL_TEST_FILE, &actual_flat_a, "flat_primary") || actual_flat_a != expected_flat_a {
		fmt.println("  combined-file block 'flat_primary' failed round-trip")
		return false
	}
	if !tg_read(ALL_TEST_FILE, &actual_flat_b, "flat_secondary") || actual_flat_b != expected_flat_b {
		fmt.println("  combined-file block 'flat_secondary' failed round-trip")
		return false
	}

	actual_big_a := Big_Settings{}
	actual_big_b := Big_Settings{}
	if !tg_read(ALL_TEST_FILE, &actual_big_a, "big_primary") || actual_big_a != expected_big_a {
		fmt.println("  combined-file block 'big_primary' failed round-trip")
		return false
	}
	if !tg_read(ALL_TEST_FILE, &actual_big_b, "big_secondary") || actual_big_b != expected_big_b {
		fmt.println("  combined-file block 'big_secondary' failed round-trip")
		return false
	}

	actual_containers_a := make_empty_container_settings()
	actual_containers_b := make_empty_container_settings()
	if !tg_read(ALL_TEST_FILE, &actual_containers_a, "containers_primary") || !container_settings_equal(&expected_containers_a, &actual_containers_a) {
		fmt.println("  combined-file block 'containers_primary' failed round-trip")
		return false
	}
	if !tg_read(ALL_TEST_FILE, &actual_containers_b, "containers_secondary") || !container_settings_equal(&expected_containers_b, &actual_containers_b) {
		fmt.println("  combined-file block 'containers_secondary' failed round-trip")
		return false
	}

	// The two instances of each type must actually use different values.
	if expected_flat_a == expected_flat_b || expected_big_a == expected_big_b || container_settings_equal(&expected_containers_a, &expected_containers_b) {
		fmt.println("  test setup error: alternate settings values are not different")
		return false
	}

	return true
}

named_block_overwrite_test :: proc() -> bool {
	// Overwrite only the primary Big_Settings block with a distinctly changed value.
	expected_big := make_big_settings()
	expected_big.max_fps = 360
	expected_big.app_name = "Voxel Workshop - Overwritten Primary"

	if !tg_write(ALL_TEST_FILE, &expected_big, "big_primary") {
		fmt.println("  failed to overwrite block 'big_primary'")
		return false
	}

	actual_big := Big_Settings{}
	if !tg_read(ALL_TEST_FILE, &actual_big, "big_primary") || actual_big != expected_big {
		fmt.println("  overwritten block 'big_primary' did not round-trip")
		return false
	}

	// The other Big_Settings block must retain its different original values.
	expected_big_secondary := make_alternate_big_settings()
	actual_big_secondary := Big_Settings{}
	if !tg_read(ALL_TEST_FILE, &actual_big_secondary, "big_secondary") || actual_big_secondary != expected_big_secondary {
		fmt.println("  overwriting 'big_primary' damaged 'big_secondary'")
		return false
	}

	expected_flat_primary := make_flat_settings()
	actual_flat_primary := Flat_Settings{}
	if !tg_read(ALL_TEST_FILE, &actual_flat_primary, "flat_primary") || actual_flat_primary != expected_flat_primary {
		fmt.println("  overwriting 'big_primary' damaged 'flat_primary'")
		return false
	}

	expected_flat_secondary := make_alternate_flat_settings()
	actual_flat_secondary := Flat_Settings{}
	if !tg_read(ALL_TEST_FILE, &actual_flat_secondary, "flat_secondary") || actual_flat_secondary != expected_flat_secondary {
		fmt.println("  overwriting 'big_primary' damaged 'flat_secondary'")
		return false
	}

	expected_containers_primary := make_container_settings()
	actual_containers_primary := make_empty_container_settings()
	if !tg_read(ALL_TEST_FILE, &actual_containers_primary, "containers_primary") || !container_settings_equal(&expected_containers_primary, &actual_containers_primary) {
		fmt.println("  overwriting 'big_primary' damaged 'containers_primary'")
		return false
	}

	expected_containers_secondary := make_alternate_container_settings()
	actual_containers_secondary := make_empty_container_settings()
	if !tg_read(ALL_TEST_FILE, &actual_containers_secondary, "containers_secondary") || !container_settings_equal(&expected_containers_secondary, &actual_containers_secondary) {
		fmt.println("  overwriting 'big_primary' damaged 'containers_secondary'")
		return false
	}

	return true
}

unnamed_read_by_type_test :: proc() -> bool {
	// Without a name, select the first Big_Settings block (big_primary), not big_secondary.
	expected := make_big_settings()
	expected.max_fps = 360
	expected.app_name = "Voxel Workshop - Overwritten Primary"
	actual := Big_Settings{}
	if !tg_read(ALL_TEST_FILE, &actual) {
		fmt.println("  unnamed read did not find the first Big_Settings block")
		return false
	}
	return actual == expected
}

report_test :: proc(name: string, passed_test: bool, passed, failed: ^int) {
	if passed_test {
		fmt.printf("[PASS] %s\n", name)
		passed^ += 1
	} else {
		fmt.printf("[FAIL] %s\n", name)
		failed^ += 1
	}
}

main :: proc() {
	// Clean the combined-file test target. The three separate-file tests each overwrite their own files.
	err := os.write_entire_file(ALL_TEST_FILE, "")
	if err != nil {
		fmt.printf("Could not reset %s: %v\n", ALL_TEST_FILE, err)
		return
	}

	passed := 0
	failed := 0

	report_test("flat values in separate file", flat_round_trip(), &passed, &failed)
	report_test("large nested settings in separate file", big_settings_round_trip(), &passed, &failed)
	report_test("dynamic arrays, fixed-capacity arrays and maps in separate file", container_round_trip(), &passed, &failed)
	report_test("multiple differently-valued blocks per type in one file", all_settings_single_file_round_trip(), &passed, &failed)
	report_test("named block overwrite preserves the other blocks", named_block_overwrite_test(), &passed, &failed)
	report_test("unnamed read selects first block matching the type", unnamed_read_by_type_test(), &passed, &failed)

	fmt.printf("\nSettings tests: %d passed, %d failed\n", passed, failed)
	fmt.printf("Separate files: %s, %s, %s\nCombined file: %s\n", FLAT_TEST_FILE, BIG_TEST_FILE, CONTAINER_TEST_FILE, ALL_TEST_FILE)
	if failed != 0 {
		panic("settings round-trip tests failed; inspect the output files and fix the failing reader/writer cases")
	}
}
