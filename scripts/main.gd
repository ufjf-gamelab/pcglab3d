extends Node3D


@onready var gridmap := $NavigationRegion3D/GridMap
@onready var builder := $Builder
@onready var world := $World
@onready var edit_camera := $View/EditCamera
@onready var creation_ui := $UI/CreationUI
@onready var game_hud := $UI/GameHUD
@onready var view := $View
@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var health_bar: ProgressBar = $UI/GameHUD/LightBar
@onready var coins_ui: HBoxContainer = $UI/GameHUD/Coins
@onready var life_hearts: HBoxContainer = $UI/GameHUD/LifeHearts
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun := $Sun
@onready var victory_screen: Control = $UI/VictoryScreen
@onready var action_menu: ActionMenu = $ActionMenu
@onready var edit_tools: EditTools = $EditTools


# Máximo de energia
@export var max_energy_time := 10.0
# Energia atual
var energy_time := max_energy_time
# Decaimento de energia ativo
var energy_active := false

# Total de moedas na dungeon
var total_coins: int = 0
# Moedas coletadas
var collected_coins = 0

# Estandartes utilizados
var used_banners := []



# Define se ao sair do modo jogável, restaura o gridmap original ou não
const RESET_ON_TOGGLE_OR_DIE := true
var gridmap_snapshot: Dictionary = {}  # {Vector3i: int}


# Vidas do player (corações)
var saved_life: int = 0  

# Modo de jogo
enum Mode { CREATION, PLAY }
var mode = Mode.CREATION


# Ações do menu lateral
const INPUT_ACTIONS: Array[StringName] = [
	&"ca_generate_dungeon", &"generate_dungeon", &"toggle_mode",
	&"show_enemies_heatmaps", &"show_coins_heatmaps", &"show_banners_heatmaps",
	&"show_recharges_heatmaps", &"show_combined_heatmaps", &"recalculate_heatmaps",
	&"pathfinding", &"select_room", &"run_quantitative_experiment",
	&"save", &"load",
]


# Modo construção
var build_mode := false
var chart_open := false

func _ready():
	UHeat.heatmap_multimesh = $HeatmapVisualizer/HeatmapMultiMesh
	enter_creation_mode()
	health_bar.max_value = max_energy_time
	health_bar.value = max_energy_time
	edit_tools.chart_opened.connect(_on_chart_opened)
	edit_tools.chart_closed.connect(_on_chart_closed)
	edit_tools.experiment_state_changed.connect(_on_experiment_state_changed)
	victory_screen.get_node("Content/BackButton").pressed.connect(_on_back_button_pressed)
	action_menu.action_pressed.connect(_run_action)
	edit_tools.on_generate_dungeon_pressed()

func _on_back_button_pressed():
	get_tree().paused = false
	victory_screen.visible = false
	toggle_mode()

func _process(delta):
	if mode == Mode.PLAY:
		_update_energy_timer(delta)

func _take_gridmap_snapshot():
	gridmap_snapshot.clear()
	for cell in gridmap.get_used_cells():
		gridmap_snapshot[cell] = gridmap.get_cell_item(cell)

func _recover_gridmap_snapshot():
	gridmap.clear()
	for cell in gridmap_snapshot.keys():
		gridmap.set_cell_item(cell, gridmap_snapshot[cell])

func show_selector():
	builder.selector.visible = true
	builder.selector_container.visible = true

func hide_selector():
	builder.selector.visible = false
	builder.selector_container.visible = false

func _set_life_smooth(new_value):
	var tween = create_tween()
	tween.tween_property(health_bar, "value", new_value, 0.4)

func _update_energy_timer(delta):
	if mode != Mode.PLAY:
		return
		
	if not energy_active:
		return
		
	energy_time -= delta
	energy_time = max(energy_time, 0.0)
	
	health_bar.value = energy_time

	if energy_time <= 0:
		_on_player_dead()

func _on_player_dead():
	var player = world.get_node_or_null("Player")
	energy_active = false
	
	# Para todos os inimigos imediatamente
	for enemy in get_tree().get_nodes_in_group("Enemies"):
		enemy.state = enemy.State.IDLE
		#enemy.player = null
	
	if player:
		player.dying = true
		var anim_player = player.get_node("Model/AnimationPlayer")
		anim_player.play("die")
		await anim_player.animation_finished
		await get_tree().create_timer(1.0).timeout
	
	saved_life = 0
	toggle_mode()

func _on_portal_body_entered(body: Node3D, portal_pos: Vector3i):
	if body.name == "Player":
		var arrival = UGen.portal_links[portal_pos]
		
		for i in range(UGen.rooms_elements_pos.size()):
			var room = UGen.rooms_elements_pos[i]
			if (room.portal1_pos == arrival or 
				room.portal2_pos == arrival):
					_activate_room_portals(i)
		
		if !body.portal_cooldown and arrival:
			body.teleport_to(arrival)
			
			energy_time = max_energy_time
			_set_life_smooth(energy_time)
			energy_active = false

func _on_portal_body_exited(_body: Node3D, _portal_pos: Vector3i):
	energy_active = true # Descongela timer

func _on_banner_player_entered(banner_pos: Vector3i):
	used_banners.append(banner_pos)
	energy_time = max_energy_time
	_set_life_smooth(energy_time)
	energy_active = false # Congela timer

func _on_banner_player_exit():
	energy_active = true # Descongela timer

func _on_player_collect_coin():
	collected_coins += 1
	coins_ui.update_coin_count(collected_coins)
	if collected_coins >= total_coins:
		victory_screen.visible = true
		get_tree().paused = true

func _on_player_update_life(curr_life):
	life_hearts.update_hearts(curr_life)
	if (curr_life <= 0):
		# Se energy_active já é false, _on_player_dead já foi chamado
		if not energy_active:
			return
		await get_tree().create_timer(2.0).timeout
		toggle_mode()

func _unhandled_input(event):
	for action in INPUT_ACTIONS:
		if event.is_action_pressed(action):
			_run_action(action)

func _run_action(action: StringName):
	if edit_tools.experiment_running:
		return
	if action != &"toggle_mode" and mode != Mode.CREATION:
		return

	match action:
		&"ca_generate_dungeon":
			edit_tools.on_ca_generate_dungeon_pressed()
		&"generate_dungeon":
			edit_tools.on_generate_dungeon_pressed()
		&"toggle_mode":
			edit_tools.clear_heatmaps()
			toggle_mode()
		&"show_enemies_heatmaps", &"show_coins_heatmaps", &"show_banners_heatmaps", \
		&"show_recharges_heatmaps", &"show_combined_heatmaps":
			edit_tools.toggle_heatmap(action)
		&"recalculate_heatmaps":
			edit_tools.recalculate_heatmaps()
		&"pathfinding":
			print("Calculando caminhos...")
			edit_tools.on_pathfinding_pressed()
		&"select_room":
			print("Calculando caminho...")
			edit_tools.on_select_room_path()
		&"run_quantitative_experiment":
			edit_tools.run_experiment()
		&"save":
			builder.save_map()
		&"load":
			builder.load_map()
		&"toggle_build":
			_set_build_mode(not build_mode)

func _on_chart_opened():
	chart_open = true
	_apply_builder_state()

func _on_chart_closed():
	chart_open = false
	view.active = true
	_apply_builder_state()

func _on_experiment_state_changed(_running: bool):
	_apply_builder_state()

func _set_build_mode(enabled: bool):
	build_mode = enabled
	action_menu.set_build_mode(enabled)
	_apply_builder_state()

func _apply_builder_state():
	var active := build_mode and mode == Mode.CREATION and not edit_tools.experiment_running and not chart_open
	if active:
		builder.process_mode = Node.PROCESS_MODE_INHERIT
		builder.set_process(true)
		show_selector()
	else:
		builder.process_mode = Node.PROCESS_MODE_DISABLED
		hide_selector()

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
					obj.get_node("Area3D").body_exited.connect(_on_portal_body_exited.bind(cell))
					# Portal recebe célula em que se encontra
					obj.portal_cell = cell
				6: 
					obj.add_to_group("Players")
					obj.name = "Player"
				7:
					obj.add_to_group("Banners")
					obj.player_entered_banner_area.connect(_on_banner_player_entered.bind(cell))
					obj.player_exit_banner_area.connect(_on_banner_player_exit.bind())
					if cell in used_banners:
						obj.active = false
						
			# Feedback visual de dano
			if id == 4 or id == 6:
				obj.add_child(HitFlash.new())

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
	
	victory_screen.visible = false
	
	# Coleta e separa o caminho livre antes de destruir o player
	var player = world.get_node_or_null("Player")
	if player and player.walked_tiles.size() > 0:
		edit_tools.split_walked_path_by_room(player.walked_tiles)
	
	# Salva vida atual antes de destruir o player
	if player:
		saved_life = player.life
	
	sun.visible = true

	_apply_builder_state()
	
	if RESET_ON_TOGGLE_OR_DIE and not gridmap_snapshot.is_empty():
		_recover_gridmap_snapshot()
	else:
		recover_gridmap()
	
	for child in world.get_children():
		child.queue_free()
		
	edit_camera.current = true

	view.active = true

	creation_ui.visible = true
	action_menu.visible = true
	game_hud.visible = false

func _activate_room_portals(room_index: int):
	var room = UGen.rooms_elements_pos[room_index]

	for portal in get_tree().get_nodes_in_group("Portals"):
		# if portal.portal_cell == room.portal1_pos:
			#portal.set_active(true)

		if portal.portal_cell == room.portal2_pos:
			portal.set_active(true)
			
		else:
			portal.set_active(false)

func enter_play_mode():
	mode = Mode.PLAY
	
	sun.visible = false
	
	var env = world_environment.environment

	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.05, 0.2)
	env.ambient_light_energy = 0.2

	_apply_builder_state()
	
	_take_gridmap_snapshot()
	
	spawn_play_objects_from_gridmap()
	
	total_coins = 0
	for room in UGen.rooms_elements_pos:
		total_coins += room["coin_pos"].size()
	
	print(total_coins)
	
	# ativa portal de saída da sala 0
	_activate_room_portals(0)

	edit_camera.current = false
	
	view.active = false

	creation_ui.visible = false
	action_menu.visible = false
	game_hud.visible = true
	
	var player = world.get_node_or_null("Player")
	if player:
		player.update_life.connect(_on_player_update_life)
		
		# Reseta contadores
		if RESET_ON_TOGGLE_OR_DIE:
			collected_coins = 0
			coins_ui.update_coin_count(0)
			player.life = player.max_life
			life_hearts.update_hearts(player.life)
			energy_time = max_energy_time
			used_banners.clear()
		else:
			coins_ui.update_coin_count(collected_coins)
			
			if saved_life <= 0 or energy_time <= 0:
				energy_time = max_energy_time
				player.life = player.max_life
			else:
				player.life = saved_life
			
			life_hearts.update_hearts(player.life)
			
		energy_active = true
