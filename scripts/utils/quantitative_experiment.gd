extends RefCounted

const PATHFINDER = preload("res://scripts/utils/pathfinding.gd")
const GENERATOR = preload("res://scripts/generators/dungeon_generator.gd")
const CA_GENERATOR = preload("res://scripts/generators/ca_dungeon_generator.gd")

const EXPERIMENT_SEED_COUNT = 50
const EXPERIMENT_HEATMAP_KEY = UHeat.COMBINED

const EXPERIMENT_PATH_TYPES = [0, 1]  # STRAIGHT=0, EXPLORER=1
const EXPERIMENT_PATH_TYPE_NAMES = { 0: "direto", 1: "explorador" }
const EXPERIMENT_SPAWN_MODES = [UGen.Spawn.RANDOM, UGen.Spawn.SMART]
const EXPERIMENT_SPAWN_MODE_NAMES = {
	UGen.Spawn.RANDOM: "aleatorio",
	UGen.Spawn.SMART: "inteligente"
}
const ROOM_SIZE_PRESETS = {
	"pequeno": { "min": 5, "max": 7  },
	"medio":   { "min": 9, "max": 11 },
	"grande":  { "min": 13, "max": 15 }
}

var _gridmap: GridMap
var _chart_plotter: Control

func run(gridmap: GridMap, chart_plotter: Control):
	_gridmap = gridmap
	_chart_plotter = chart_plotter

	var seeds: Array[int] = []
	for i in range(EXPERIMENT_SEED_COUNT):
		seeds.append(randi())

	for preset_name in ROOM_SIZE_PRESETS.keys():
		var preset = ROOM_SIZE_PRESETS[preset_name]

		for s in seeds:
			var geo_gen = GENERATOR.new()
			geo_gen.set_room_size(preset["min"], preset["max"])
			_run_for_seed(s, "geo_%s" % preset_name, geo_gen, func(): geo_gen.generate_dungeon(_gridmap))

			var ca_gen = CA_GENERATOR.new()
			ca_gen.set_room_size(preset["min"], preset["max"])
			_run_for_seed(s, "ca_%s" % preset_name, ca_gen, func(): ca_gen.generate_dungeon_ca(_gridmap))

	UGen.SPAWN = UGen.Spawn.SMART
	print("\nExperimento concluído")

func _run_for_seed(s: int, generator_name: String, generator_instance, generate_func: Callable):
	for spawn_mode in EXPERIMENT_SPAWN_MODES:
		seed(s)
		UHeat.clear_heatmaps()
		generate_func.call()

		UGen.SPAWN = spawn_mode
		generator_instance.spawn_dungeon_elements(_gridmap)

		_collect_and_save(s, generator_name, spawn_mode)

func _collect_and_save(s: int, generator_name: String, spawn_mode: int):
	var pathfinder = _init_pathfinder()
	var spawn_name = EXPERIMENT_SPAWN_MODE_NAMES[spawn_mode]

	for path_type in EXPERIMENT_PATH_TYPES:
		var path_name = EXPERIMENT_PATH_TYPE_NAMES[path_type]
		var x_values = []
		var y_values = []

		for room_index in range(UGen.rooms.size()):
			var path = _get_room_path(room_index, pathfinder, path_type)
			if path.is_empty():
				continue

			var influ = _get_path_influences(room_index, path)
			if influ[1].is_empty():
				continue

			x_values.append(range(influ[1].size()))
			y_values.append(influ[1])

		if x_values.is_empty():
			continue

		_chart_plotter.current_seed = s
		var filename = "%s_%s_%s_influ_moedas_inimigos" % [generator_name, spawn_name, path_name]
		_chart_plotter._save_csv_all(x_values, y_values, filename)

func _init_pathfinder():
	var pathfinder = PATHFINDER.new(_gridmap)
	var cell_size_2d = Vector2i(int(_gridmap.cell_size.x), int(_gridmap.cell_size.z))
	var map_region = Vector2i(UGen.MAP_SIZE, UGen.MAP_SIZE)
	pathfinder.setup_grid(map_region, cell_size_2d)
	return pathfinder

func _get_room_path(room_index: int, pathfinder, path_type: int) -> Array:
	var elem_pos = UGen.rooms_elements_pos[room_index]
	var portal1_pos_2d = Vector2i(elem_pos.portal1_pos.x, elem_pos.portal1_pos.z)
	var portal2_pos_2d = Vector2i(elem_pos.portal2_pos.x, elem_pos.portal2_pos.z)

	match path_type:
		0:  # STRAIGHT
			return pathfinder.find_path(portal1_pos_2d, portal2_pos_2d)
		1:  # EXPLORER
			var room_coins_pos: Array[Vector2i] = []
			for coin_pos in elem_pos.coin_pos:
				room_coins_pos.append(Vector2i(coin_pos.x, coin_pos.z))
			return pathfinder.find_explorer_path(portal1_pos_2d, room_coins_pos, portal2_pos_2d)

	return []

func _get_path_influences(room_index: int, path: Array) -> Array:
	var path_cell_influ = []
	var path_influences = []

	for cell in path:
		var cell_3d = Vector3i(cell.x, 0, cell.y)
		var value = UHeat.heatmaps[EXPERIMENT_HEATMAP_KEY][room_index].get(cell_3d, 0.0)
		path_cell_influ.append([cell_3d, value])
		path_influences.append(value)

	return [path_cell_influ, path_influences]

func _apply_room_size_preset(gen, preset: Dictionary):
	gen.set_room_size(preset["min"], preset["max"])
