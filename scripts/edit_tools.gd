extends Node
class_name EditTools

const CA_GENERATOR = preload("res://scripts/generators/ca_dungeon_generator.gd")
const GENERATOR = preload("res://scripts/generators/dungeon_generator.gd")
const PATHFINDER = preload("res://scripts/utils/pathfinding.gd")
const EXPERIMENT = preload("res://scripts/utils/quantitative_experiment.gd")

enum Generator { GEOMETRIC, CELLULAR, BSP }

signal chart_opened
signal chart_closed
signal experiment_state_changed(running: bool)

@export var gridmap: GridMap
@export var nav_region: NavigationRegion3D
@export var heatmap_panel: HeatmapInfoPanel
@export var chart_plotter: Control
@export var path_visualizer: Node3D
@export var edit_camera: Camera3D
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

# Used for raycasting mouse (aproveitado do builder)
var plane: Plane

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
	chart_plotter.next_button_pressed.connect(_on_chart_next_button_pressed)
	plane = Plane(Vector3.UP, Vector3.ZERO)

func clear_heatmaps():
	UHeat.deactivate_heatmaps()
	heatmap_panel.clear()

func toggle_heatmap(action: StringName):
	match action:
		&"show_enemies_heatmaps":
			UHeat.toggle_enemy_heatmaps(gridmap, heatmap_panel)
		&"show_coins_heatmaps":
			UHeat.toggle_coin_heatmaps(gridmap, heatmap_panel)
		&"show_banners_heatmaps":
			UHeat.toggle_banner_heatmaps(gridmap, heatmap_panel)
		&"show_recharges_heatmaps":
			UHeat.toggle_recharge_heatmaps(gridmap, heatmap_panel)
		&"show_combined_heatmaps":
			UHeat.toggle_combined_heatmaps(gridmap, heatmap_panel)

func recalculate_heatmaps():
	UGen.update_elements_pos(gridmap)
	UHeat.recalculate_heatmaps(gridmap, heatmap_panel)

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
	heatmap_panel.clear()
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
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_LAYERS
	navigation_mesh.agent_radius = 0.1
	navigation_mesh.cell_height = 0.01
	
	var source := NavigationMeshSourceGeometryData3D.new()

	NavigationServer3D.parse_source_geometry_data(navigation_mesh,source,gridmap)

	NavigationServer3D.bake_from_source_geometry_data(navigation_mesh, source)

	nav_region.navigation_mesh = navigation_mesh

func _handle_chart(influences):
	chart_opened.emit()
	
	var x = []
	for influence in influences:
		x.append(range(influence.size()))
		
	chart_plotter.current_seed = used_seed
	chart_plotter.show_charts(x, influences)

func on_pathfinding_pressed():
	if PATH_TYPE == Pathfing.FREE and player_walked_paths.is_empty():
		print("Nenhum caminho livre registrado. Jogue primeiro.")
		return
		
	var pathfinder = _pathfinder_init()
	
	paths = []
	paths_influences = []
	var influences = []
	
	for i in range((UGen.rooms).size()):
		var path = _get_room_path(i, pathfinder)
		
		if path == []:
			continue
		
		paths.append(path)
		
		var influ = _get_path_influences(i, path)
		if influ[1] == []:
			print("Nenhum tipo de mapa de influência selecionado.")
			return
		paths_influences.append(influ[0])
		influences.append(influ[1])
	
	_handle_chart(influences)
	_visualize_path_by_room_index(0)

func on_select_room_path():
	# Map position based on mouse
	var world_position = plane.intersects_ray(
		edit_camera.project_ray_origin(get_viewport().get_mouse_position()),
		edit_camera.project_ray_normal(get_viewport().get_mouse_position()))

	# GridMap position based on mouse
	var gridmap_position = Vector3(round(world_position.x), 0, round(world_position.z))
	
	var pathfinder = _pathfinder_init()
	var path
	
	for i in range((UGen.rooms).size()):
		var room = UGen.rooms[i]
		if gridmap_position in room:
			path = _get_room_path(i, pathfinder)
			
			if path == []:
				print("Jogador não passou por essa sala!")
				return
			
			var influ = _get_path_influences(i, path)
			
			if influ[1] == []:
				print("Nenhum tipo de mapa de influência selecionado.")
				return
			
			chart_opened.emit()
			
			chart_plotter.current_seed = used_seed
			chart_plotter.current_room_index = i
			chart_plotter.show_chart(range(influ[1].size()), influ[1], true)
			
			var path_3d: Array[Vector3i] = []

			for tuple in influ[0]:
				path_3d.append(tuple[0])
			
			path_visualizer.draw_path(path_3d)

func _on_chart_next_button_pressed(curr_room_chart):
	_visualize_path_by_room_index(curr_room_chart)

func _on_chart_close_button_pressed():
	path_visualizer.clear_path()
	chart_closed.emit()

func _visualize_path_by_room_index(room_index):
	var path_3d: Array[Vector3i] = []
	
	var room_tuples = paths_influences[room_index]
	
	for tuple in room_tuples:
		path_3d.append(tuple[0])
	
	path_visualizer.draw_path(path_3d)

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
