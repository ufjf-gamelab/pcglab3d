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

func _on_portal_body_entered(body: Node3D, portal_pos: Vector3i):
	if body.name == "Player":
		var arrival = Gen.portal_links[portal_pos]
		if !body.portal_cooldown and arrival:
			body.teleport_to(arrival)
			
func _on_banner_player_entered(portal_pos: Vector3i):
	print("Entrou")

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
				3: obj.add_to_group("Coins") 
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
					
			world.add_child(obj)
			obj.global_position = world_pos
			
			# Coloca apenas chão naquele local  do gridmap
			gridmap.set_cell_item(cell, 2)

func _ready():
	enter_creation_mode()

func toggle_mode() -> void:
	if mode == Mode.CREATION:
		enter_play_mode()
	else:
		enter_creation_mode()

func get_cell_pos(entity):
	var world_pos = entity.global_position
	var local_pos = gridmap.to_local(world_pos)
	
	#var cell_pos = gridmap.local_to_map(local_pos)
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

func _unhandled_input(event):
	# Captura evento de geração da dungeon e chama Autoload Gen
	if event.is_action_pressed("generate_dungeon"):
		Gen.generate_dungeon(gridmap)
		
	# Captura evento de mudança de modo e chama a toggle_mode()
	if event.is_action_pressed("toggle_mode"):
		toggle_mode()
