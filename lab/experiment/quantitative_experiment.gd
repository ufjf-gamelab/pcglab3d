extends RefCounted

const PATHFINDER = preload("res://lab/pathfinding/pathfinding.gd")
const GENERATOR = preload("res://generation/generators/dungeon_generator.gd")
const CA_GENERATOR = preload("res://generation/generators/ca_dungeon_generator.gd")

const CELLULAR = 1
const EXPLORER = 1
const GENERATOR_FILE_NAMES = ["geometricas", "celular"]
const PATH_FILE_NAMES = ["direto", "explorador"]
const SPAWN_FILE_NAMES = ["aleatorio", "inteligente"]

signal run_finished(index: int)

var cancelled := false

func cancel():
	cancelled = true

static func build_runs(config: Dictionary) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	for dungeon_seed in config.seeds:
		for generator in config.generators:
			for size in config.sizes:
				for spawn in config.spawn_modes:
					for path in config.path_types:
						runs.append({
							"seed": dungeon_seed, "generator": generator, "size": size,
							"spawn": spawn, "path": path, "heatmap": config.heatmap,
							"rooms": [], "csv": "", "done": false,
						})
	return runs

# Roda num GridMap fora da cena, pra dungeon do editor não mudar
func run(gridmap: GridMap, runs: Array[Dictionary], folder: String):
	var grid: GridMap = gridmap.duplicate()
	var state := _save_state()
	DirAccess.make_dir_recursive_absolute(folder)

	var index := 0
	while index < runs.size() and not cancelled:
		var dungeon := runs[index]
		_generate(grid, dungeon)
		while index < runs.size() and _same_dungeon(runs[index], dungeon) and not cancelled:
			_measure(grid, runs[index], folder)
			run_finished.emit(index)
			index += 1
			await Engine.get_main_loop().process_frame

	_restore_state(state)
	grid.free()

func _same_dungeon(a: Dictionary, b: Dictionary) -> bool:
	return a.seed == b.seed and a.generator == b.generator and a.size == b.size and a.spawn == b.spawn

func _generate(grid: GridMap, run_info: Dictionary):
	seed(run_info.seed)
	UHeat.clear_heatmaps()
	var generator
	if run_info.generator == CELLULAR:
		generator = CA_GENERATOR.new()
		generator.set_room_size(run_info.size.min, run_info.size.max)
		generator.generate_dungeon_ca(grid)
	else:
		generator = GENERATOR.new()
		generator.set_room_size(run_info.size.min, run_info.size.max)
		generator.generate_dungeon(grid)
	UGen.SPAWN = run_info.spawn
	generator.spawn_dungeon_elements(grid)
	UGen.update_elements_pos(grid)
	UHeat.recalculate_heatmaps(grid)

func _measure(grid: GridMap, run_info: Dictionary, folder: String):
	var pathfinder = PATHFINDER.new(grid)
	pathfinder.setup_grid(Vector2i(UGen.MAP_SIZE, UGen.MAP_SIZE), Vector2i(int(grid.cell_size.x), int(grid.cell_size.z)))

	var lines := PackedStringArray(["sala,tile,influencia"])
	for room in UGen.rooms.size():
		var heatmap := _room_heatmap(run_info.heatmap, room)
		var values := []
		for cell in _room_path(room, pathfinder, run_info.path):
			values.append(heatmap.get(Vector3i(cell.x, 0, cell.y), 0.0))
		run_info.rooms.append(values)
		for tile in values.size():
			lines.append("%d,%d,%s" % [room, tile, values[tile]])

	var file_name := "%d_%s_%s_%s_%s.csv" % [
		run_info.seed, GENERATOR_FILE_NAMES[run_info.generator], run_info.size.file_name,
		SPAWN_FILE_NAMES[run_info.spawn], PATH_FILE_NAMES[run_info.path],
	]
	run_info.csv = folder.path_join(file_name)
	var file := FileAccess.open(run_info.csv, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	run_info.done = true

func _room_heatmap(key: String, room: int) -> Dictionary:
	if key == UHeat.RECHARGES:
		var maps: Array[Dictionary] = [
			UHeat.heatmaps[UHeat.ENTRY_PORTALS][room], UHeat.heatmaps[UHeat.EXIT_PORTALS][room], UHeat.heatmaps[UHeat.BANNERS][room],
		]
		return UHeat.create_combined_heatmap(maps)
	return UHeat.heatmaps[key][room]

func _room_path(room: int, pathfinder, path_type: int) -> Array:
	var elements = UGen.rooms_elements_pos[room]
	var entry := Vector2i(elements.portal1_pos.x, elements.portal1_pos.z)
	var exit := Vector2i(elements.portal2_pos.x, elements.portal2_pos.z)
	if path_type == EXPLORER:
		var coins: Array[Vector2i] = []
		for coin in elements.coin_pos:
			coins.append(Vector2i(coin.x, coin.z))
		return pathfinder.find_explorer_path(entry, coins, exit)
	return pathfinder.find_path(entry, exit)

func _save_state() -> Dictionary:
	return {
		"rooms": UGen.rooms.duplicate(true),
		"elements": UGen.rooms_elements_pos.duplicate(true),
		"links": UGen.portal_links.duplicate(true),
		"first": UGen.firstPortal,
		"last": UGen.lastPortal,
		"quantity": UGen.rooms_elements_quantity.duplicate(true),
		"spawn": UGen.SPAWN,
		"heatmaps": UHeat.heatmaps.duplicate(true),
		"visible": UHeat.curr_visible_heatmap.duplicate(),
		"shown": UHeat.heatmap_multimesh.visible,
	}

func _restore_state(state: Dictionary):
	UGen.rooms = state.rooms
	UGen.rooms_elements_pos = state.elements
	UGen.portal_links = state.links
	UGen.firstPortal = state.first
	UGen.lastPortal = state.last
	UGen.rooms_elements_quantity = state.quantity
	UGen.SPAWN = state.spawn
	UHeat.heatmaps = state.heatmaps
	UHeat.curr_visible_heatmap = state.visible
	UHeat.heatmap_multimesh.visible = state.shown
