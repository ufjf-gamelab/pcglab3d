extends Node3D

const CA_GENERATOR = preload("res://scripts/generators/ca_dungeon_generator.gd")
const GENERATOR = preload("res://scripts/generators/dungeon_generator.gd")
const PATHFINDER = preload("res://scripts/utils/pathfinding.gd")

@onready var gridmap := $NavigationRegion3D/GridMap
@onready var builder := $Builder
@onready var world := $World
@onready var edit_camera := $View/EditCamera
@onready var player_camera := $View/PlayerCamera
@onready var creation_ui := $UI/CreationUI
@onready var game_hud := $UI/GameHUD
@onready var view := $View
@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var heatmap_panel: HeatmapInfoPanel = $UI/CreationUI/Top/HeatmapInfoPanel
@onready var health_bar: ProgressBar = $UI/GameHUD/LightBar
@onready var coins_ui: HBoxContainer = $UI/GameHUD/Coins
@onready var life_hearts: HBoxContainer = $UI/GameHUD/LifeHearts
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun := $Sun
@onready var chart_plotter: Control = $UI/CreationUI/ChartPlotter
@onready var path_visualizer: Node3D = $PathVisualizer

@export var max_life_time := 20.0
var life_time := max_life_time
var life_active := false

var collected_coins = 0

var used_banners := []

enum Mode { CREATION, PLAY }
var mode = Mode.CREATION

var paths = []
var paths_influences = []

var plane:Plane # Used for raycasting mouse

enum Pathfing {STRAIGHT, EXPLORER}
const PATH_TYPE = Pathfing.STRAIGHT
const LIGHT_AWARE = false

func _ready():
	UHeat.heatmap_multimesh = $HeatmapVisualizer/HeatmapMultiMesh
	enter_creation_mode()
	health_bar.max_value = max_life_time
	health_bar.value = max_life_time
	chart_plotter.close_button_pressed.connect(_on_chart_close_button_pressed)
	chart_plotter.next_button_pressed.connect(_on_chart_next_button_pressed)
	
	plane = Plane(Vector3.UP, Vector3.ZERO)

func _process(delta):
	if mode == Mode.PLAY:
		update_player_camera(delta)
		_update_life_timer(delta)

func show_selector():
	builder.selector.visible = true
	builder.selector_container.visible = true

func hide_selector():
	builder.selector.visible = false
	builder.selector_container.visible = false

func _on_chart_next_button_pressed(curr_room_chart):
	_visualize_path_by_room_index(curr_room_chart)

func _on_chart_close_button_pressed():
	builder.set_process(true)
	view.active = true
	path_visualizer.clear_path()
	show_selector()

func _set_life_smooth(new_value):
	var tween = create_tween()
	tween.tween_property(health_bar, "value", new_value, 0.4)

func _update_life_timer(delta):
	if mode != Mode.PLAY:
		return
		
	if not life_active:
		return
		
	life_time -= delta
	life_time = max(life_time, 0.0)
	
	health_bar.value = life_time

	if life_time <= 0:
		_on_player_dead()

func _on_player_dead():
	var player = world.get_node_or_null("Player")
	life_active = false
	
	if player:
		player.dying = true
		var anim_player = player.get_node("Model/AnimationPlayer")
		anim_player.play("die")
		await anim_player.animation_finished
		await get_tree().create_timer(1.0).timeout
	
	toggle_mode()

func _on_portal_body_entered(body: Node3D, portal_pos: Vector3i):
	if body.name == "Player":
		var arrival = UGen.portal_links[portal_pos]
		if !body.portal_cooldown and arrival:
			body.teleport_to(arrival)

func _on_banner_player_entered(banner_pos: Vector3i):
	used_banners.append(banner_pos)
	life_time = max_life_time
	_set_life_smooth(life_time)
	life_active = false # Congela timer	

func _on_banner_player_exit():
	life_active = true # Descongela timer

func _on_player_collect_coin():
	collected_coins += 1
	coins_ui.update_coin_count(collected_coins)

func _on_player_update_life(curr_life):
	life_hearts.update_hearts(curr_life)
	if (curr_life <= 0):
		await get_tree().create_timer(2.0).timeout
		toggle_mode()

func _handle_chart(influences):
	builder.set_process(false)
	hide_selector()
	
	var x = []
	for influence in influences:
		x.append(range(influence.size()))
	chart_plotter.show_charts(x, influences)

func _on_pathfinding_pressed():
	var pathfinder = _pathfinder_init()
	
	paths = []
	paths_influences = []
	var influences = []
	
	for i in range((UGen.rooms).size()):
		var path = _get_room_path(i, pathfinder)
		
		paths.append(path)
		
		if LIGHT_AWARE:
			continue
		
		var influ = _get_path_influences(i, path)
		if influ[1] == []:
			print("Nenhum tipo de mapa de influência selecionado.")
			return
		paths_influences.append(influ[0])
		influences.append(influ[1])
	
	if LIGHT_AWARE:
		paths = _build_light_aware_global_path(paths, pathfinder)
		for i in range(paths.size()):
			var influ = _get_path_influences(i, paths[i])
			if influ[1] == []:
				print("Nenhum tipo de mapa de influência selecionado.")
				return
			paths_influences.append(influ[0])
			influences.append(influ[1])
	
	_handle_chart(influences)
	_visualize_path_by_room_index(0)

func _get_room_banners(room_index: int) -> Array[Vector2i]:
	var banners_pos: Array[Vector2i] = []
	
	var elements = UGen.rooms_elements_pos[room_index]
	
	for b in elements.banner_pos:
		banners_pos.append(Vector2i(b.x, b.z))
	
	return banners_pos

func _get_path_to_nearest_banner(pos: Vector2i, banners: Array[Vector2i], pathfinder):
	var best_path = []
	var best_cost = INF

	for b in banners:
		var path = pathfinder.find_path(pos, b)
		var cost = path.size()
		
		if cost < best_cost:
			best_cost = cost
			best_path = path
	
	return best_path

func _walk_path(room_path: Array[Vector2i], sim_light, cell_time, room_index: int, pathfinder, room_coins, deep: int) -> Dictionary:
	var banners = _get_room_banners(room_index)
	var new_room_path: Array[Vector2i] = []
	
	var room_coins_pos : Array[Vector2i]
	if deep == 0:
		room_coins_pos = []
		for coin_pos in UGen.rooms_elements_pos[room_index].coin_pos:
			room_coins_pos.append(Vector2i(coin_pos.x, coin_pos.z))
	else:
		room_coins_pos = room_coins
	
	for i in range(room_path.size()):
		var current_pos = room_path[i]
		var exit_portal = room_path[room_path.size()-1]
		
		if (room_coins_pos.has(current_pos)):
			room_coins_pos.erase(current_pos)
		
		if (banners.has(current_pos)):
			sim_light = max_life_time + cell_time
		
		new_room_path.append(current_pos)
		
		sim_light -= cell_time
		
		if sim_light <= 0:
			print("Não foi possível completar o caminho! A luz acabou!")
			break
		
		# Se for o tile de saída, finaliza a execução da sala
		if current_pos == exit_portal:
			break
		
		# Verifica a cada 5 tiles
		if i % 5 == 0:
			var path_to_nearest_banner = _get_path_to_nearest_banner(current_pos, banners, pathfinder)
			
			if path_to_nearest_banner != null:
				var time_to_banner = path_to_nearest_banner.size() * cell_time
				
				# Margem de segurança
				if time_to_banner >= sim_light - 2.0:
					# Precisa ir até o estandarte
					print("Desviando para o estandarte na sala ", room_index)
					
					# Adiciona caminho até o estandarte
					for tile in path_to_nearest_banner:
						new_room_path.append(tile)
					
					# Gasta o tempo da ida até o estandarte
					sim_light -= time_to_banner
					
					# Recarrega
					sim_light = max_life_time
					
					var curr_pos = new_room_path[new_room_path.size()-1]
					if PATH_TYPE == Pathfing.STRAIGHT:
						var exit_path = pathfinder.find_path(curr_pos, exit_portal)
						
						# Chama recursivamente a função para completar o caminho
						var result = _walk_path(exit_path, sim_light, cell_time, room_index, pathfinder, room_coins_pos, deep+1)
						
						new_room_path += result.path
						sim_light = result.life
						break
					elif PATH_TYPE == Pathfing.EXPLORER:
						pass
						var exit_path = pathfinder.find_explorer_path(curr_pos, room_coins_pos, exit_portal)
						# Chama recursivamente a função para completar o caminho
						var result = _walk_path(exit_path, sim_light, cell_time, room_index, pathfinder, room_coins_pos, deep+1)
						
						new_room_path += result.path
						sim_light = result.life
						break
	
	return {
		"path": new_room_path,
		"life": sim_light
	}

func _build_light_aware_global_path(gen_paths: Array, pathfinder) -> Array:
	var safe_paths: Array = []
	
	var sim_life := max_life_time
	var cell_time := 1.0 / 2.5 # speed = 2.5m/s ; cell_size = 1m
	
	for room_index in range(gen_paths.size()):
		var room_path: Array[Vector2i] = gen_paths[room_index]
		
		var result: Dictionary = _walk_path(room_path, sim_life, cell_time, room_index, pathfinder, [], 0)
		
		safe_paths.append(result.path)
		sim_life = result.life
	
	return safe_paths

func _visualize_path_by_room_index(room_index):
	var path_3d: Array[Vector3i] = []
	
	var room_tuples = paths_influences[room_index]
	
	for tuple in room_tuples:
		path_3d.append(tuple[0])
	
	path_visualizer.draw_path(path_3d)
	hide_selector()

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

func _on_ca_generate_dungeon_pressed():
	UHeat.deactivate_heatmaps()
	heatmap_panel.clear()
	var ca_generator = CA_GENERATOR.new()
	ca_generator.generate_dungeon_ca(gridmap)
	ca_generator.spawn_dungeon_elements(gridmap)
	rebuild_navigation_mesh()

func _on_generate_dungeon_pressed():
	UHeat.deactivate_heatmaps()
	heatmap_panel.clear()
	var generator = GENERATOR.new()
	generator.generate_dungeon(gridmap)
	generator.spawn_dungeon_elements(gridmap)
	rebuild_navigation_mesh()

func _pathfinder_init():
	var pathfinder = PATHFINDER.new(gridmap)
	var cell_size_2d = Vector2i(gridmap.cell_size.x, gridmap.cell_size.z)
	var map_region = Vector2i(UGen.MAP_SIZE, UGen.MAP_SIZE)
	pathfinder.setup_grid(map_region, cell_size_2d)
	return pathfinder

func _get_room_path(room_index, pathfinder):
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

func _on_select_room_path():
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
			var influ = _get_path_influences(i, path)
			
			if influ[1] == []:
				print("Nenhum tipo de mapa de influência selecionado.")
				return
			
			builder.set_process(false)
			
			chart_plotter.show_chart(range(influ[1].size()), influ[1], true)
			
			var path_3d: Array[Vector3i] = []

			for tuple in influ[0]:
				path_3d.append(tuple[0])
			
			path_visualizer.draw_path(path_3d)
			hide_selector()

func _unhandled_input(event):
	# Captura evento de geração da dungeon com automatos celulares
	if event.is_action_pressed("ca_generate_dungeon"):
		_on_ca_generate_dungeon_pressed()

	# Captura evento de geração da dungeon com salas em X, T e +
	if event.is_action_pressed("generate_dungeon"):
		_on_generate_dungeon_pressed()

	# Captura evento de mudança de modo e chama a toggle_mode()
	if event.is_action_pressed("toggle_mode"):
		UHeat.deactivate_heatmaps()
		heatmap_panel.clear()
		toggle_mode()

	# Captura evento de exibir heatmap de inimigos
	if event.is_action_pressed("show_enemies_heatmaps"):
		UHeat.toggle_enemy_heatmaps(gridmap, heatmap_panel)

	# Captura evento de exibir heatmap de moedas
	if event.is_action_pressed("show_coins_heatmaps"):
		UHeat.toggle_coin_heatmaps(gridmap, heatmap_panel)

	# Captura evento de exibir heatmap de estandartes
	if event.is_action_pressed("show_banners_heatmaps"):
		UHeat.toggle_banner_heatmaps(gridmap, heatmap_panel)
	
	# Captura evento de exibir heatmap combinando influências
	if event.is_action_pressed("show_combined_heatmaps"):
		UHeat.toggle_combined_heatmaps(gridmap, heatmap_panel)

	# Captura evento de exibir heatmap combinando influências
	if event.is_action_pressed("recalculate_heatmaps"):
		UGen.update_elements_pos(gridmap)
		UHeat.recalculate_heatmaps(gridmap, heatmap_panel)
	
	# Calcula caminho entre portais das salas
	if event.is_action_pressed("pathfinding"):
		print("Calculando caminhos...")
		_on_pathfinding_pressed()
		
	# Escolhe sala e exibe grafico apenas dela
	if event.is_action_pressed("select_room"):
		print("Calculando caminho...")
		_on_select_room_path()

func spawn_play_objects_from_gridmap():
	# Mapeamento dos IDs do GridMap para cenas reais
	var tile_id_to_scene = {
		3: preload("res://scenes/playable/coin.tscn"),
		4: preload("res://scenes/playable/enemy.tscn"),
		5: preload("res://scenes/playable/portal.tscn"),
		6: preload("res://scenes/playable/player.tscn"),
		7: preload("res://scenes/playable/banner.tscn")
	}

	for cell in gridmap.get_used_cells():
		# Captura ID da MeshLibrary naquele tile
		var id = gridmap.get_cell_item(cell)

		# Verifica se é um tile que necessita de instância
		if tile_id_to_scene.has(id):
			# Captura posicao local e converte para global
			var local_pos = gridmap.map_to_local(cell)
			var world_pos = gridmap.to_global(local_pos)
			
			# Instacia objetos
			var obj = tile_id_to_scene[id].instantiate()
			
			match id:
				3: 
					obj.add_to_group("Coins")
					obj.collect_coin.connect(_on_player_collect_coin.bind()) 
				4: obj.add_to_group("Enemies")
				5: 
					obj.add_to_group("Portals")
					obj.get_node("Area3D").body_entered.connect(_on_portal_body_entered.bind(cell))
				6: 
					obj.add_to_group("Players")
					obj.name = "Player"
				7:
					obj.add_to_group("Banners")
					obj.player_entered_banner_area.connect(_on_banner_player_entered.bind(cell))
					obj.player_exit_banner_area.connect(_on_banner_player_exit.bind())
					if cell in used_banners:
						obj.active = false
						
			world.add_child(obj)
			obj.global_position = world_pos
			
			# Coloca apenas chão naquele local do gridmap
			gridmap.set_cell_item(cell, 2)

func toggle_mode() -> void:
	if mode == Mode.CREATION:
		enter_play_mode()
	else:
		enter_creation_mode()

func get_cell_pos(entity):
	var world_pos = entity.global_position
	var local_pos = gridmap.to_local(world_pos)
	
	# var cell_pos = gridmap.local_to_map(local_pos)
	var cell_pos = Vector3i(0, 0, 0)
	
	if local_pos.x - int(local_pos.x) >= 0.5:
		cell_pos.x = ceil(local_pos.x)
	else:
		cell_pos.x = floor(local_pos.x)
		
	if local_pos.z - int(local_pos.z) >= 0.5:
		cell_pos.z = ceil(local_pos.z)
	else:
		cell_pos.z = floor(local_pos.z)

	return cell_pos

func recover_gridmap():
	var coins = get_tree().get_nodes_in_group("Coins")
	var enemies = get_tree().get_nodes_in_group("Enemies")
	var portals = get_tree().get_nodes_in_group("Portals")
	var players = get_tree().get_nodes_in_group("Players")
	var banners = get_tree().get_nodes_in_group("Banners")
	
	for coin in coins:
		var cell_pos = get_cell_pos(coin)
		gridmap.set_cell_item(cell_pos, 3)
		
	for enemy in enemies:
		var cell_pos = get_cell_pos(enemy)
		gridmap.set_cell_item(cell_pos, 4)
		
	for portal in portals:
		var cell_pos = get_cell_pos(portal)
		gridmap.set_cell_item(cell_pos, 5)
	
	for player in players:
		var cell_pos = get_cell_pos(player)
		gridmap.set_cell_item(cell_pos, 6)
		
	for banner in banners:
		var cell_pos = get_cell_pos(banner)
		gridmap.set_cell_item(cell_pos, 7)

func enter_creation_mode():
	mode = Mode.CREATION
	
	sun.visible = true

	builder.set_process(true)
	
	recover_gridmap()
	
	for child in world.get_children():
		child.queue_free()
		
	edit_camera.current = true
	player_camera.current = false

	view.active = true

	creation_ui.visible = true
	game_hud.visible = false

func enter_play_mode():
	mode = Mode.PLAY
	
	sun.visible = false
	
	var env = world_environment.environment

	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.05, 0.2)
	env.ambient_light_energy = 0.2

	builder.set_process(false)
	spawn_play_objects_from_gridmap()

	edit_camera.current = false
	player_camera.current = true
	
	view.active = false

	creation_ui.visible = false
	game_hud.visible = true
	
	var player = world.get_node_or_null("Player")
	if player:
		player_camera.global_position = player.global_position + Vector3(0, 3, -5)
		player_camera.look_at(player.global_position)
		player.update_life.connect(_on_player_update_life)
		
		if life_time <= 0:
			life_time = max_life_time
		life_active = true

func rebuild_navigation_mesh():
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_LAYERS
	navigation_mesh.agent_radius = 0.1
	navigation_mesh.cell_height = 0.01
	
	var source := NavigationMeshSourceGeometryData3D.new()

	NavigationServer3D.parse_source_geometry_data(navigation_mesh,source,gridmap)

	NavigationServer3D.bake_from_source_geometry_data(navigation_mesh, source)

	$NavigationRegion3D.navigation_mesh = navigation_mesh

func update_player_camera(delta):
	var player = world.get_node_or_null("Player")
	if not player:
		return

	# Camera jogavel atras do player
	var target_pos = player.global_position + Vector3(0, 3, -5)
	player_camera.global_position = player_camera.global_position.lerp(target_pos, delta * 5)
