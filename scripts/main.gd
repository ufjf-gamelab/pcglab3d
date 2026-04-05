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

@export var max_life_time := 20.0
var life_time := max_life_time
var life_active := false

var collected_coins = 0

var used_banners := []

enum Mode { CREATION, PLAY }
var mode = Mode.CREATION

var paths = []
var paths_influences = []

func _ready():
	UHeat.heatmap_multimesh = $HeatmapVisualizer/HeatmapMultiMesh
	enter_creation_mode()
	health_bar.max_value = max_life_time
	health_bar.value = max_life_time

func _process(delta):
	if mode == Mode.PLAY:
		update_player_camera(delta)
		_update_life_timer(delta)

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

func handle_chart(influences):
	var x = []
	for influence in influences:
		x.append(range(influence.size()))
	chart_plotter.show_charts(x, influences)

func _on_pathfinding_pressed():
	var pathfinder = PATHFINDER.new(gridmap)
	var cell_size_2d = Vector2i(gridmap.cell_size.x, gridmap.cell_size.z)
	var map_region = Vector2i(UGen.MAP_SIZE, UGen.MAP_SIZE)
	pathfinder.setup_grid(map_region, cell_size_2d)
	
	paths = []
	paths_influences = []
	var influences = []
	
	for i in range((UGen.rooms).size()):
		var elem_pos = UGen.rooms_elements_pos[i]
		var portal1_pos_2d = Vector2i(elem_pos.portal1_pos.x, elem_pos.portal1_pos.z)
		var portal2_pos_2d = Vector2i(elem_pos.portal2_pos.x, elem_pos.portal2_pos.z)
		
		var path = pathfinder.find_path(portal1_pos_2d, portal2_pos_2d)
		paths.append(path)
		
		var path_influ = {}
		var room_influ = []
		for cell in path:
			var cell_3d = Vector3i(cell.x, 0, cell.y)
			path_influ[cell_3d] = UHeat.heatmaps.combined[i][cell_3d]
			room_influ.append(UHeat.heatmaps.combined[i][cell_3d])
			
		influences.append(room_influ)
		paths_influences.append(path_influ)
		
	handle_chart(influences)

func _on_ca_generate_dungeon_pressed():
	var ca_generator = CA_GENERATOR.new()
	ca_generator.generate_dungeon_ca(gridmap)
	ca_generator.spawn_dungeon_elements(gridmap)
	rebuild_navigation_mesh()

func _on_generate_dungeon_pressed():
	var generator = GENERATOR.new()
	generator.generate_dungeon(gridmap)
	generator.spawn_dungeon_elements(gridmap)
	rebuild_navigation_mesh()

func _unhandled_input(event):
	# Captura evento de geração da dungeon com automatos celulares
	if event.is_action_pressed("ca_generate_dungeon"):
		_on_ca_generate_dungeon_pressed()

	# Captura evento de geração da dungeon com salas em X, T e +
	if event.is_action_pressed("generate_dungeon"):
		_on_generate_dungeon_pressed()

	# Captura evento de mudança de modo e chama a toggle_mode()
	if event.is_action_pressed("toggle_mode"):
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
		UHeat.recalculate_heatmaps(gridmap, heatmap_panel)
	
	# Calcula caminho entre portais das salas
	if event.is_action_pressed("pathfinding"):
		print("Calculando caminhos...")
		_on_pathfinding_pressed()

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
