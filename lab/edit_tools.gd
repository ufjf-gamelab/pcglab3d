extends Node
class_name EditTools

const CA_GENERATOR = preload("res://generation/generators/ca_dungeon_generator.gd")
const GENERATOR = preload("res://generation/generators/dungeon_generator.gd")
const PATHFINDER = preload("res://lab/pathfinding/pathfinding.gd")
const EXPERIMENT = preload("res://lab/experiment/quantitative_experiment.gd")

enum Generator { GEOMETRIC, CELLULAR, BSP }

signal chart_opened
signal chart_closed
signal experiment_state_changed(running: bool)

@export var gridmap: GridMap
@export var nav_region: NavigationRegion3D
@export var dresser: DungeonDresser
@export var chart_plotter: Control
@export var path_visualizer: Node3D
@export var view: Node3D
@export var experiment_overlay: ExperimentOverlay

# Seed predefinida
@export var dungeon_seed: int = 1464125454
# Seed utilizada
var used_seed: int = 0

# Caminhos do tipo atual encontrados na dungeon
var paths = []
# Valores de influência do tipo atual exibido ao longo dos caminhos
var paths_influences = []

# Caminho percorrido pelo jogador
var player_walked_paths: Array = [] # Array[Array[Vector3i]]

# Tipo de caminho
enum Pathfing {STRAIGHT, EXPLORER, FREE}
const PATH_TYPE: Pathfing = Pathfing.EXPLORER

# Se tá tendo o experimento, pra bloquear
var experiment_running := false

var _experiment = null

func _ready():
	chart_plotter.close_button_pressed.connect(_on_chart_close_button_pressed)

func clear_heatmaps():
	UHeat.deactivate_heatmaps()

func toggle_heatmap(action: StringName):
	match action:
		&"show_enemies_heatmaps":
			UHeat.toggle_enemy_heatmaps(gridmap)
		&"show_coins_heatmaps":
			UHeat.toggle_coin_heatmaps(gridmap)
		&"show_banners_heatmaps":
			UHeat.toggle_banner_heatmaps(gridmap)
		&"show_recharges_heatmaps":
			UHeat.toggle_recharge_heatmaps(gridmap)
		&"show_combined_heatmaps":
			UHeat.toggle_combined_heatmaps(gridmap)

func recalculate_heatmaps():
	var action := visible_heatmap_action()
	UGen.update_elements_pos(gridmap)
	UHeat.recalculate_heatmaps(gridmap)
	if action != &"":
		toggle_heatmap(action)
	refresh_chart()

func recalculate_room_heatmaps(room_index: int):
	if UHeat.heatmaps[UHeat.COMBINED].size() <= room_index:
		recalculate_heatmaps()
		return
	UGen.update_room_elements_pos(gridmap, room_index)
	UHeat.recalculate_room_heatmaps(gridmap, room_index)
	refresh_visible_heatmap()
	refresh_chart()

func refresh_visible_heatmap():
	var action := visible_heatmap_action()
	if action != &"":
		UHeat.deactivate_heatmaps()
		toggle_heatmap(action)

func visible_heatmap_action() -> StringName:
	var actions := {
		UHeat.ENEMIES: &"show_enemies_heatmaps",
		UHeat.COINS: &"show_coins_heatmaps",
		UHeat.BANNERS: &"show_banners_heatmaps",
		UHeat.RECHARGES: &"show_recharges_heatmaps",
		UHeat.COMBINED: &"show_combined_heatmaps",
	}
	for key in actions:
		if UHeat.curr_visible_heatmap[key]:
			return actions[key]
	return &""

func _handle_seed():
	# Se seed for 0, gera uma aleatória c.c. usa a definida
	if dungeon_seed == 0:
		used_seed = randi()  # gera seed
	else:
		used_seed = dungeon_seed
		
	seed(used_seed)
	print("\nSeed usada: ", used_seed)

func on_generate_dungeon_pressed(type := Generator.GEOMETRIC):
	_handle_seed()
	UHeat.deactivate_heatmaps()
	UHeat.clear_heatmaps()
	match type:
		Generator.CELLULAR:
			var ca_generator = CA_GENERATOR.new()
			ca_generator.generate_dungeon_ca(gridmap)
			ca_generator.spawn_dungeon_elements(gridmap)
		Generator.GEOMETRIC, Generator.BSP:
			var generator = GENERATOR.new()
			generator.generate_dungeon(gridmap)
			generator.spawn_dungeon_elements(gridmap)
	rebuild_navigation_mesh()

func rebuild_navigation_mesh():
	dresser.rebuild()

	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_LAYERS
	navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navigation_mesh.agent_radius = 0.1
	navigation_mesh.cell_height = 0.01
	
	var source := NavigationMeshSourceGeometryData3D.new()

	NavigationServer3D.parse_source_geometry_data(navigation_mesh, source, dresser)

	NavigationServer3D.bake_from_source_geometry_data(navigation_mesh, source)

	nav_region.navigation_mesh = navigation_mesh

func _handle_chart(influences, rooms):
	chart_opened.emit()
	
	var x = []
	for influence in influences:
		x.append(range(influence.size()))
		
	chart_plotter.current_seed = used_seed
	chart_plotter.show_charts(x, influences, rooms)

func on_pathfinding_pressed():
	if PATH_TYPE == Pathfing.FREE and player_walked_paths.is_empty():
		print("Nenhum caminho livre registrado. Jogue primeiro.")
		return
		
	var pathfinder = _pathfinder_init()
	
	paths = []
	paths_influences = []
	var influences = []
	var rooms = []
	
	for i in range((UGen.rooms).size()):
		var path = _get_room_path(i, pathfinder)
		
		if path == []:
			continue
		
		paths.append(path)
		rooms.append(i)
		
		var influ = _get_path_influences(i, path)
		paths_influences.append(influ[0])
		influences.append(influ[1])
	
	_handle_chart(influences, rooms)
	_visualize_paths()

func refresh_chart():
	if chart_plotter.visible:
		on_pathfinding_pressed()

func show_room_chart(room: int):
	if chart_plotter.visible:
		chart_plotter.show_room(room)

func _on_chart_close_button_pressed():
	path_visualizer.clear_path()
	chart_closed.emit()

func _visualize_paths():
	var paths_3d := []
	
	for room_tuples in paths_influences:
		var path_3d: Array[Vector3i] = []
		for tuple in room_tuples:
			path_3d.append(tuple[0])
		paths_3d.append(path_3d)
	
	path_visualizer.draw_paths(paths_3d)

func _get_path_influences(room_index, path): # [ [ [Vector3i, int] ], [int] ]
	var path_cell_influ = []
	var path_influences = []
	for key in UHeat.curr_visible_heatmap.keys():
		if UHeat.curr_visible_heatmap[key]:
			for cell in path:
				var cell_3d = Vector3i(cell.x, 0, cell.y)
				var tuple = [cell_3d, UHeat.heatmaps[key][room_index][cell_3d]]
				path_cell_influ.append(tuple)
				path_influences.append(UHeat.heatmaps[key][room_index][cell_3d])

	if path_cell_influ.is_empty():
		for cell in path:
			path_cell_influ.append([Vector3i(cell.x, 0, cell.y), 0])

	return [path_cell_influ, path_influences]

func _pathfinder_init():
	var pathfinder = PATHFINDER.new(gridmap)
	var cell_size_2d = Vector2i(gridmap.cell_size.x, gridmap.cell_size.z)
	var map_region = Vector2i(UGen.MAP_SIZE, UGen.MAP_SIZE)
	pathfinder.setup_grid(map_region, cell_size_2d)
	return pathfinder

func _get_room_path(room_index, pathfinder):
	# FREE, retorna o caminho livre do jogador
	if PATH_TYPE == Pathfing.FREE:
		if room_index < player_walked_paths.size():
			return player_walked_paths[room_index].map(func(t): return Vector2i(t.x, t.z))
		else:
			return []
	
	var elem_pos = UGen.rooms_elements_pos[room_index]
	
	var portal1_pos_2d = Vector2i(elem_pos.portal1_pos.x, elem_pos.portal1_pos.z)
	var portal2_pos_2d = Vector2i(elem_pos.portal2_pos.x, elem_pos.portal2_pos.z)
	
	var path
	if (PATH_TYPE == Pathfing.STRAIGHT):
		path = pathfinder.find_path(portal1_pos_2d, portal2_pos_2d)
	elif (PATH_TYPE == Pathfing.EXPLORER):
		var room_coins_pos : Array[Vector2i] = []
		for coin_pos in elem_pos.coin_pos:
			room_coins_pos.append(Vector2i(coin_pos.x, coin_pos.z))
	
		path = pathfinder.find_explorer_path(portal1_pos_2d, room_coins_pos, portal2_pos_2d)
	
	return path

func split_walked_path_by_room(all_tiles: Array[Vector3i]):
	player_walked_paths.clear()

	for i in range(UGen.rooms.size()):
		var room = UGen.rooms[i]
		var room_path: Array[Vector3i] = []

		for tile in all_tiles:
			if tile in room and (room_path.is_empty() or room_path.back() != tile):
				room_path.append(tile)
		player_walked_paths.append(room_path)

func run_experiment():
	experiment_running = true
	experiment_state_changed.emit(true)

	view.go_home()
	view.input_locked = true

	_experiment = EXPERIMENT.new()
	_experiment.progress.connect(experiment_overlay.update_progress)
	experiment_overlay.cancel_pressed.connect(_experiment.cancel)
	experiment_overlay.start()

	await _experiment.run(gridmap, chart_plotter)

	experiment_overlay.cancel_pressed.disconnect(_experiment.cancel)
	var output_folder = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/pcglab3d"
	experiment_overlay.finish(_experiment.cancelled, output_folder)
	_experiment = null

	experiment_running = false
	view.input_locked = false
	experiment_state_changed.emit(false)
