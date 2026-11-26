extends Node3D


@onready var gridmap := $NavigationRegion3D/GridMap
@onready var builder: Builder = $Builder
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
@onready var portal_links: PortalLinks = $PortalLinks
@onready var path_visualizer := $PathVisualizer
@onready var experiment_screen: ExperimentScreen = $ExperimentScreen


# Total de moedas na dungeon
var total_coins: int = 0
# Moedas coletadas
var collected_coins = 0


# Define se ao sair do modo jogável, restaura o gridmap original ou não
const RESET_ON_TOGGLE_OR_DIE := true


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
	&"pathfinding", &"toggle_experiment",
	&"save", &"load",
	&"tool_select", &"tool_build", &"tool_erase", &"tool_link", &"tool_move",
	&"structure_1", &"structure_2", &"structure_3", &"structure_4",
	&"structure_5", &"structure_6", &"structure_7",
]

const STRUCTURE_KEYS := {
	&"structure_1": UGen.WALL_ID, &"structure_2": UGen.FLOOR_ID, &"structure_3": UGen.COIN_ID,
	&"structure_4": UGen.NPC_ID, &"structure_5": UGen.PORTAL_ID, &"structure_6": UGen.PLAYER_SPAWN_ID,
	&"structure_7": UGen.BANNER_ID,
}


# Modo construção
var tool := Builder.Tool.SELECT
var selected_room := -1
var show_links := true
var auto_heatmap := true
var chart_open := false
var experiment_open := false

func _ready():
	UHeat.heatmap_multimesh = $HeatmapVisualizer/HeatmapMultiMesh
	enter_creation_mode()
	edit_tools.chart_opened.connect(_on_chart_opened)
	edit_tools.chart_closed.connect(_on_chart_closed)
	edit_tools.chart_plotter.room_changed.connect(_on_chart_room_changed)
	experiment_screen.running_changed.connect(action_menu.set_modes_locked)
	experiment_screen.open_requested.connect(_open_experiment_run)
	victory_screen.get_node("Content/BackButton").pressed.connect(_on_back_button_pressed)
	action_menu.action_pressed.connect(_run_action)
	action_menu.tool_pressed.connect(_set_tool)
	action_menu.structure_pressed.connect(_on_structure_pressed)
	builder.structure_changed.connect(_on_structure_changed)
	builder.cell_hovered.connect(_on_cell_hovered)
	builder.cell_changed.connect(_on_cell_changed)
	builder.cell_selected.connect(_on_cell_selected)
	builder.move_started.connect(_on_move_started)
	builder.move_canceled.connect(_on_move_canceled)
	action_menu.set_seed(edit_tools.dungeon_seed)
	dresser.entity_placed.connect(_on_entity_placed)
	edit_tools.on_generate_dungeon_pressed()

func _on_back_button_pressed():
	get_tree().paused = false
	victory_screen.visible = false
	toggle_mode()

func show_selector():
	builder.selector.visible = tool != Builder.Tool.SELECT
	builder.selector_container.visible = tool == Builder.Tool.BUILD

func hide_selector():
	builder.selector.visible = false
	builder.selector_container.visible = false

func _on_portal_body_entered(body: Node3D, portal_pos: Vector3i):
	if body.name == "Player":
		var arrival = UGen.portal_links.get(portal_pos)
		
		for i in range(UGen.rooms_elements_pos.size()):
			var room = UGen.rooms_elements_pos[i]
			if (room.portal1_pos == arrival or 
				room.portal2_pos == arrival):
					_activate_room_portals(i)
		
		if !body.portal_cooldown and arrival:
			body.teleport_to(arrival)
			_show_room(_room_of(arrival))

func _on_entity_placed(entity: Node3D, cell: Vector3i):
	if entity.is_in_group("Coins"):
		entity.collect_coin.connect(_on_player_collect_coin)
	elif entity.is_in_group("Portals"):
		entity.portal_cell = cell
		entity.mesh.visible = UGen.is_portal_linked(cell)
		entity.get_node("Area3D").body_entered.connect(_on_portal_body_entered.bind(cell))
	elif entity.is_in_group("Players"):
		entity.health.life_changed.connect(_on_player_update_life)
		var lantern: Lantern = entity.equipment.find_item(Lantern)
		if lantern:
			lantern.fuel_changed.connect(_on_player_update_fuel)

func _player() -> Player:
	return get_tree().get_first_node_in_group("Players")

func _show_room(index: int):
	active_room = index
	_apply_active_room()

func _apply_active_room():
	for index in dresser.room_groups.size():
		dresser.room_groups[index].visible = _is_room_visible(index)

func _is_room_visible(index: int) -> bool:
	return active_room == -1 or index == active_room

func _room_of(cell: Vector3i) -> int:
	for index in UGen.rooms.size():
		if Vector3i(cell.x, 0, cell.z) in UGen.rooms[index]:
			return index
	return -1

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
		if event.is_action_pressed(action, false, true):
			_run_action(action)

func _run_action(action: StringName):
	if experiment_screen.running:
		return
	if experiment_open and action not in [&"toggle_experiment", &"show_editor"]:
		return
	if action != &"toggle_mode" and mode != Mode.CREATION:
		return

	match action:
		&"generate_dungeon":
			edit_tools.dungeon_seed = action_menu.get_seed()
			UGen.SPAWN = action_menu.get_spawn_mode()
			edit_tools.on_generate_dungeon_pressed(action_menu.get_selected_generator())
			action_menu.set_seed(edit_tools.used_seed)
			selected_room = mini(selected_room, UGen.rooms.size() - 1)
			_show_room_info()
		&"random_seed":
			action_menu.set_seed(randi())
		&"toggle_mode":
			edit_tools.clear_heatmaps()
			action_menu.set_heatmap(&"hide_heatmaps")
			toggle_mode()
		&"show_enemies_heatmaps", &"show_coins_heatmaps", &"show_banners_heatmaps", \
		&"show_recharges_heatmaps", &"show_combined_heatmaps":
			edit_tools.toggle_heatmap(action)
			if not UHeat.heatmap_multimesh.visible:
				action_menu.set_heatmap(&"hide_heatmaps")
			else:
				action_menu.set_heatmap(action)
			edit_tools.refresh_chart()
		&"hide_heatmaps":
			edit_tools.clear_heatmaps()
			action_menu.set_heatmap(&"hide_heatmaps")
			edit_tools.refresh_chart()
		&"recalculate_heatmaps":
			edit_tools.recalculate_heatmaps()
		&"pathfinding":
			edit_tools.on_pathfinding_pressed()
		&"toggle_experiment":
			_set_experiment_open(not experiment_open)
		&"show_editor":
			_set_experiment_open(false)
		&"save":
			builder.save_map()
		&"load":
			builder.load_map()
		&"tool_select":
			_set_tool(Builder.Tool.SELECT)
		&"tool_build":
			_set_tool(Builder.Tool.BUILD)
		&"tool_erase":
			_set_tool(Builder.Tool.ERASE)
		&"tool_link":
			_set_tool(Builder.Tool.LINK)
		&"tool_move":
			_set_tool(Builder.Tool.MOVE)
		&"structure_1", &"structure_2", &"structure_3", &"structure_4", \
		&"structure_5", &"structure_6", &"structure_7":
			builder.select_structure(STRUCTURE_KEYS[action])
		&"toggle_auto_heatmap":
			auto_heatmap = not auto_heatmap
		&"toggle_portal_links":
			show_links = not show_links
			portal_links.visible = show_links
		&"toggle_path":
			path_visualizer.visible = not path_visualizer.visible

func _on_chart_opened():
	chart_open = true
	_apply_builder_state()

func _on_chart_room_changed(room: int):
	selected_room = room
	_show_room_info()

func _on_chart_closed():
	chart_open = false
	view.active = true
	_apply_builder_state()

func _set_experiment_open(open: bool):
	experiment_open = open
	experiment_screen.visible = open
	action_menu.set_experiment_open(open)
	view.input_locked = open
	_apply_builder_state()

func _open_experiment_run(run_info: Dictionary):
	_set_experiment_open(false)
	action_menu.set_seed(run_info.seed)
	action_menu.set_generator(run_info.generator)
	action_menu.set_spawn_mode(run_info.spawn)
	edit_tools.dungeon_seed = run_info.seed
	UGen.SPAWN = run_info.spawn
	edit_tools.on_generate_dungeon_pressed(run_info.generator, Vector2i(run_info.size.min, run_info.size.max))
	selected_room = -1
	_show_room_info()

	var heatmap: StringName = edit_tools.HEATMAP_ACTIONS[run_info.heatmap]
	edit_tools.PATH_TYPE = run_info.path
	edit_tools.recalculate_heatmaps(heatmap)
	action_menu.set_heatmap(heatmap)
	edit_tools.on_pathfinding_pressed()

func _set_tool(new_tool: Builder.Tool):
	builder.cancel_move()
	tool = new_tool
	builder.tool = tool
	action_menu.set_tool(tool)
	_apply_builder_state()

func _on_structure_pressed(index: int):
	builder.select_structure(index)

func _on_structure_changed(index: int):
	action_menu.set_structure(index)
	_set_tool(Builder.Tool.BUILD)

func _on_cell_hovered(cell: Vector3i):
	action_menu.set_cell(cell, _room_of(cell))

func _on_cell_changed(cell: Vector3i):
	var old_room := _room_of(cell)
	UGen.refresh_rooms(gridmap)
	var room := _room_of(cell)
	if auto_heatmap:
		for changed_room in {old_room: true, room: true}:
			if changed_room != -1:
				edit_tools.recalculate_room_heatmaps(changed_room)
	if selected_room in [old_room, room]:
		_show_room_info()

func _on_move_started(cell: Vector3i):
	dresser.set_entity_visible(cell, false)

func _on_move_canceled(cell: Vector3i):
	dresser.set_entity_visible(cell, true)

func _on_cell_selected(cell: Vector3i):
	selected_room = _room_of(cell)
	_show_room_info()
	edit_tools.show_room_chart(selected_room)

func _show_room_info():
	if selected_room == -1:
		action_menu.hide_room_info()
		return

	var counts := {}
	for cell in UGen.rooms[selected_room]:
		var item: int = gridmap.get_cell_item(cell)
		counts[item] = counts.get(item, 0) + 1

	var entry = UGen.rooms_elements_pos[selected_room].portal1_pos
	var exit = UGen.rooms_elements_pos[selected_room].portal2_pos

	var arrives_from := []
	for from in UGen.portal_links:
		if UGen.portal_links[from] == entry and _room_of(from) != selected_room:
			arrives_from.append(_room_of(from) + 1)

	var leads_to := []
	var destination = UGen.portal_links.get(exit)
	if destination != null:
		leads_to.append(_room_of(destination) + 1)

	action_menu.show_room_info(selected_room + 1, {
		"tiles": UGen.rooms[selected_room].size(),
		"enemies": counts.get(UGen.NPC_ID, 0),
		"coins": counts.get(UGen.COIN_ID, 0),
		"campfires": counts.get(UGen.BANNER_ID, 0),
		"arrives_from": arrives_from,
		"leads_to": leads_to,
	})

func _apply_builder_state():
	var active := mode == Mode.CREATION and not experiment_open
	action_menu.set_palette_visible(active and not chart_open)
	if active:
		builder.process_mode = Node.PROCESS_MODE_INHERIT
		builder.set_process(true)
		show_selector()
	else:
		builder.process_mode = Node.PROCESS_MODE_DISABLED
		hide_selector()

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

func enter_creation_mode():
	mode = Mode.CREATION
	_show_room(-1)
	
	victory_screen.visible = false
	
	# Coleta e separa o caminho livre antes de destruir o player
	var player = _player()
	if player and player.walked_tiles.size() > 0:
		edit_tools.split_walked_path_by_room(player.walked_tiles)
	
	# Salva vida atual antes de destruir o player
	if player:
		saved_life = player.health.life
	
	sun.visible = true

	_apply_builder_state()
	
	dresser.set_entities_active(false)
	if RESET_ON_TOGGLE_OR_DIE:
		dresser.reset_entities()
	
	edit_camera.current = true

	view.active = true

	creation_ui.visible = true
	action_menu.visible = true
	game_hud.visible = false
	portal_links.visible = show_links

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
	
	dresser.set_entities_active(true)
	
	total_coins = get_tree().get_nodes_in_group("Coins").size()
	
	
	# ativa portal de saída da sala 0
	_activate_room_portals(0)

	edit_camera.current = false
	
	view.active = false

	creation_ui.visible = false
	action_menu.visible = false
	game_hud.visible = true
	portal_links.visible = false
	
	var player = _player()
	if player:
		_show_room(_room_of(get_cell_pos(player)))
		player.camera.make_current()
		var lantern: Lantern = player.equipment.find_item(Lantern)
		if lantern:
			health_bar.max_value = lantern.max_fuel
			health_bar.value = lantern.fuel
		
		# Reseta contadores
		if RESET_ON_TOGGLE_OR_DIE:
			collected_coins = 0
			coins_ui.update_coin_count(0)
			player.health.life = player.health.max_life
			life_hearts.update_hearts(player.health.life)
		else:
			coins_ui.update_coin_count(collected_coins)
			
			if saved_life <= 0:
				player.health.life = player.health.max_life
			else:
				player.health.life = saved_life
			
			life_hearts.update_hearts(player.health.life)
