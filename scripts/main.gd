extends Node3D

@onready var gridmap = $GridMap
@onready var builder := $Builder
@onready var world := $World
@onready var edit_camera := $View/EditCamera
@onready var player_camera := $View/PlayerCamera
@onready var creation_ui := $UI/CreationUI
@onready var game_hud := $UI/GameHUD
@onready var view := $View
@onready var heatmap_multimesh := $HeatmapVisualizer/HeatmapMultiMesh

@export var max_life_time := 10.0
var life_time := max_life_time
var life_active := false

var used_banners := []

enum Mode { CREATION, PLAY }
var mode = Mode.CREATION

var enemy_heatmap_visible := false
var coin_heatmap_visible := false
var banner_heatmap_visible := false

func _ready():
	enter_creation_mode()

func _process(delta):
	if mode == Mode.PLAY:
		update_player_camera(delta)
		update_life_timer(delta)

func update_life_timer(delta):
	if mode != Mode.PLAY:
		return
		
	if not life_active:
		return
		
	life_time -= delta
	life_time = max(life_time, 0.0)
	
	print("Life:", life_time)

	if life_time <= 0:
		
		on_player_dead()
	
func on_player_dead():
	var player = world.get_node_or_null("Player")
	life_active = false
	
	if player:
		player.dying = true
		var anim_player = player.get_node("Model/AnimationPlayer")
		anim_player.play("die")
		await anim_player.animation_finished
		await get_tree().create_timer(1.0).timeout
	
	toggle_mode()

func update_player_camera(delta):
	var player = world.get_node_or_null("Player")
	if not player:
		return

	# Camera jogavel atras do player
	var target_pos = player.global_position + Vector3(0, 3, -5)
	player_camera.global_position = player_camera.global_position.lerp(target_pos, delta * 5)

func _on_portal_body_entered(body: Node3D, portal_pos: Vector3i):
	if body.name == "Player":
		var arrival = Gen.portal_links[portal_pos]
		if !body.portal_cooldown and arrival:
			body.teleport_to(arrival)
			
func _on_banner_player_entered(banner_pos: Vector3i):
	used_banners.append(banner_pos)
	life_time = max_life_time
	life_active = false # Congela timer	
	
func _on_banner_player_exit():
	life_active = true # Descongela timer

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
		
		if life_time <= 0:
			life_time = max_life_time
		life_active = true

func show_heatmaps(heatmaps, positive_influence := false, cell_size := 1.0):
	var total_instances := 0
	var global_max := 0
	for heatmap in heatmaps:
		total_instances += heatmap.size()
		for value in heatmap.values():
			global_max = max(global_max, abs(value))
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.instance_count = total_instances

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(cell_size, cell_size)
	
	mm.mesh = mesh
	heatmap_multimesh.multimesh = mm

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/heatmap.gdshader")
	heatmap_multimesh.material_override = mat	

	var i := 0
	for heatmap in heatmaps:
		for cell: Vector3i in heatmap.keys():
			var intensity := float(abs(heatmap[cell])) / float(global_max)

			transform.origin = gridmap.map_to_local(cell) + Vector3(0, 0.05, 0)

			mm.set_instance_transform(i, transform)
			mm.set_instance_custom_data(i, Color(intensity, 1.0 if positive_influence else 0.0, 0.0, 0.0))
			i += 1
	
	heatmap_multimesh.visible = true

func toggle_enemy_heatmaps():
	if enemy_heatmap_visible:
		heatmap_multimesh.visible = false
		enemy_heatmap_visible = false
	else:
		var enemies_heatmaps = Gen.heatmaps["enemies"]
		show_heatmaps(enemies_heatmaps)
		enemy_heatmap_visible = true
		
func toggle_coin_heatmaps():
	if coin_heatmap_visible:
		heatmap_multimesh.visible = false
		coin_heatmap_visible = false
	else:
		var coins_heatmaps = Gen.heatmaps["coins"]
		show_heatmaps(coins_heatmaps, true)
		coin_heatmap_visible = true
		
func toggle_banner_heatmaps():
	if banner_heatmap_visible:
		heatmap_multimesh.visible = false
		banner_heatmap_visible = false
	else:
		var banners_heatmaps = Gen.heatmaps["banners"]
		show_heatmaps(banners_heatmaps, true)
		banner_heatmap_visible = true

func _unhandled_input(event):
	# Captura evento de geração da dungeon e chama Autoload Gen
	if event.is_action_pressed("generate_dungeon"):
		Gen.generate_dungeon(gridmap)
		
	# Captura evento de mudança de modo e chama a toggle_mode()
	if event.is_action_pressed("toggle_mode"):
		toggle_mode()
	
	# Captura evento de exibir heatmap de inimigos
	if event.is_action_pressed("show_enemies_heatmaps"):
		toggle_enemy_heatmaps()
		
	# Captura evento de exibir heatmap de moedas
	if event.is_action_pressed("show_coins_heatmaps"):
		toggle_coin_heatmaps()
		
	# Captura evento de exibir heatmap de estandartes
	if event.is_action_pressed("show_banners_heatmaps"):
		toggle_banner_heatmaps()
