extends Node3D

@onready var gridmap = $GridMap
@onready var builder := $Builder
@onready var world := $World
@onready var edit_camera := $View/EditCamera
@onready var player_camera := $View/PlayerCamera
@onready var creation_ui := $UI/CreationUI
@onready var game_hud := $UI/GameHUD
@onready var view := $View

enum Mode { CREATION, PLAY }
var mode = Mode.CREATION

func update_player_camera(delta):
	var player = world.get_node_or_null("Player")
	if not player:
		return

	# Camera jogavel atras do player
	var target_pos = player.global_position + Vector3(0, 3, -5)
	player_camera.global_position = player_camera.global_position.lerp(target_pos, delta * 5)

func _process(delta):
	if mode == Mode.PLAY:
		update_player_camera(delta)

func spawn_play_objects_from_gridmap():
	# Mapeamento dos IDs do GridMap para cenas reais
	var tile_to_scene = {
		3: preload("res://scenes/playable/coin.tscn"),
		4: preload("res://scenes/playable/enemy.tscn"),
		5: preload("res://scenes/playable/portal.tscn"),
		6: preload("res://scenes/playable/player.tscn"),
	}

	# IDs que precisam ter chão
	var needs_floor = [3, 4, 5, 6]

	for cell in gridmap.get_used_cells():
		# Captura ID da MeshLibrary naquele tile
		var id = gridmap.get_cell_item(cell)

		# Captura posicao local e converte para global
		var local_pos = gridmap.map_to_local(cell)
		var world_pos = gridmap.to_global(local_pos)

		# Instacia objetos
		if tile_to_scene.has(id):
			var obj = tile_to_scene[id].instantiate()
			if id == 6:
				obj.name = "Player"
			world.add_child(obj)
			obj.global_position = world_pos

func _ready():
	enter_creation_mode()

func toggle_mode():
	if mode == Mode.CREATION:
		enter_play_mode()
	else:
		enter_creation_mode()

func enter_creation_mode():
	mode = Mode.CREATION

	builder.set_process(true)
	
	for child in world.get_children():
		child.queue_free()

	gridmap.visible = true
	
	edit_camera.current = true
	player_camera.current = false

	view.active = true

	creation_ui.visible = true
	game_hud.visible = false

func enter_play_mode():
	mode = Mode.PLAY

	builder.set_process(false)
	spawn_play_objects_from_gridmap()

	gridmap.visible = true

	edit_camera.current = false
	player_camera.current = true
	
	view.active = false

	creation_ui.visible = false
	game_hud.visible = true
	
	var player = world.get_node_or_null("Player")
	if player:
		player_camera.global_position = player.global_position + Vector3(0, 3, -5)
		player_camera.look_at(player.global_position)

func _unhandled_input(event):
	# Captura evento de geração da dungeon e chama Autoload Gen
	if event.is_action_pressed("generate_dungeon"):
		Gen.generate_dungeon(gridmap)
		
	# Captura evento de mudança de modo e chama a toggle_mode()
	if event.is_action_pressed("toggle_mode"):
		toggle_mode()
