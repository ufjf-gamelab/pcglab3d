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
@onready var dresser: DungeonDresser = $DungeonDresser


# Total de moedas na dungeon
var total_coins: int = 0
# Moedas coletadas
var collected_coins = 0

# Estandartes utilizados
var used_banners := []



# Define se ao sair do modo jogável, restaura o gridmap original ou não
const RESET_ON_TOGGLE_OR_DIE := true
var gridmap_snapshot: Dictionary = {}  # {Vector3i: int}


var active_room := -1

# Vidas do player (corações)
var saved_life: int = 0  

# Modo de jogo
enum Mode { CREATION, PLAY }
var mode = Mode.CREATION


# Ações do menu lateral
const INPUT_ACTIONS: Array[StringName] = [
	&"generate_dungeon", &"toggle_mode",
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
	edit_tools.chart_opened.connect(_on_chart_opened)
	edit_tools.chart_closed.connect(_on_chart_closed)
	edit_tools.experiment_state_changed.connect(_on_experiment_state_changed)
	victory_screen.get_node("Content/BackButton").pressed.connect(_on_back_button_pressed)
	action_menu.action_pressed.connect(_run_action)
	dresser.rebuilt.connect(_apply_active_room)
	edit_tools.on_generate_dungeon_pressed()

func _on_back_button_pressed():
	get_tree().paused = false
	victory_screen.visible = false
	toggle_mode()

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
			_show_room(_room_of(arrival))

func _show_room(index: int):
	active_room = index
	_apply_active_room()

func _apply_active_room():
	for index in dresser.room_groups.size():
		dresser.room_groups[index].visible = _is_room_visible(index)

	for child in world.get_children():
		if child.name == "Player":
			continue
		child.visible = _is_room_visible(_room_of(get_cell_pos(child)))

func _is_room_visible(index: int) -> bool:
	return active_room == -1 or index == active_room

func _room_of(cell: Vector3i) -> int:
	for index in UGen.rooms.size():
		if Vector3i(cell.x, 0, cell.z) in UGen.rooms[index]:
			return index
	return -1

func _on_banner_player_entered(banner_pos: Vector3i):
	used_banners.append(banner_pos)

func _on_player_update_fuel(curr_fuel):
	health_bar.value = curr_fuel

func _on_player_collect_coin():
	collected_coins += 1
	coins_ui.update_coin_count(collected_coins)
	if collected_coins >= total_coins:
		victory_screen.visible = true
		get_tree().paused = true

func _on_player_update_life(curr_life):
	life_hearts.update_hearts(curr_life)
	if (curr_life <= 0):
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
		&"generate_dungeon":
			edit_tools.on_generate_dungeon_pressed(action_menu.get_selected_generator())
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
		3: preload("res://game/objects/coin.tscn"),
		4: preload("res://game/enemy/enemy.tscn"),
		5: preload("res://game/objects/portal.tscn"),
		6: preload("res://game/player/player.tscn"),
		7: preload("res://game/objects/campfire.tscn")
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
					# Portal recebe célula em que se encontra
					obj.portal_cell = cell
				6: 
					obj.add_to_group("Players")
					obj.name = "Player"
				7:
					obj.add_to_group("Banners")
					obj.player_entered_banner_area.connect(_on_banner_player_entered.bind(cell))
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
	_show_room(-1)
	
	victory_screen.visible = false
	
	# Coleta e separa o caminho livre antes de destruir o player
	var player = world.get_node_or_null("Player")
	if player and player.walked_tiles.size() > 0:
		edit_tools.split_walked_path_by_room(player.walked_tiles)
	
	# Salva vida atual antes de destruir o player
	if player:
		saved_life = player.health.life
	
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
	
	total_coins = get_tree().get_nodes_in_group("Coins").size()
	
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
		_show_room(_room_of(get_cell_pos(player)))
		player.health.life_changed.connect(_on_player_update_life)
		var lantern: Lantern = player.equipment.find_item(Lantern)
		if lantern:
			lantern.fuel_changed.connect(_on_player_update_fuel)
			health_bar.max_value = lantern.max_fuel
			health_bar.value = lantern.fuel
		
		# Reseta contadores
		if RESET_ON_TOGGLE_OR_DIE:
			collected_coins = 0
			coins_ui.update_coin_count(0)
			player.health.life = player.health.max_life
			life_hearts.update_hearts(player.health.life)
			used_banners.clear()
		else:
			coins_ui.update_coin_count(collected_coins)
			
			if saved_life <= 0:
				player.health.life = player.health.max_life
			else:
				player.health.life = saved_life
			
			life_hearts.update_hearts(player.health.life)
