extends Node3D
class_name Builder

signal structure_changed(index: int)
signal cell_hovered(cell: Vector3i)
signal cell_changed(cell: Vector3i)
signal cell_selected(cell: Vector3i)
signal move_started(cell: Vector3i)
signal move_canceled(cell: Vector3i)

enum Tool { SELECT, BUILD, ERASE, LINK, MOVE }

@export var structures: Array[Structure] = []

var map:DataMap

var index:int = 0 # Index of structure being built
var tool := Tool.SELECT
var moving_from = null

@export var selector:Node3D # The 'cursor'
@export var selector_container:Node3D # Node that holds a preview of the structure
@export var view_camera:Camera3D # Used for raycasting mouse
@export var gridmap:GridMap
@export var cash_display:Label
@export var portal_links: PortalLinks

var plane:Plane # Used for raycasting mouse

func _ready():
	map = DataMap.new()
	plane = Plane(Vector3.UP, Vector3.ZERO)

	# Create new MeshLibrary dynamically, can also be done in the editor
	# See: https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html
	
	var mesh_library = MeshLibrary.new()
	for structure in structures:
		mesh_library.create_item(mesh_library.get_last_unused_item_id())
	
	# Adiciona a meshLibrary criada à meshLibrary do GridMap
	gridmap.mesh_library = mesh_library
	
	update_structure()
	
func _process(delta):
	
	# Controls
	action_rotate() # Rotates selection 90 degrees
	
	# Map position based on mouse
	var world_position = plane.intersects_ray(
		view_camera.project_ray_origin(get_viewport().get_mouse_position()),
		view_camera.project_ray_normal(get_viewport().get_mouse_position()))

	var gridmap_position = Vector3(round(world_position.x), 0, round(world_position.z))
	selector.position = lerp(selector.position, gridmap_position, min(delta * 40, 1.0))
	
	cell_hovered.emit(Vector3i(gridmap_position))
	if not UGen.BUILD_AREA.has_point(Vector2i(gridmap_position.x, gridmap_position.z)):
		return
	match tool:
		Tool.SELECT:
			action_select(gridmap_position)
		Tool.BUILD:
			action_build(gridmap_position)
		Tool.ERASE:
			action_demolish(gridmap_position)
		Tool.LINK:
			action_link(Vector3i(gridmap_position))
		Tool.MOVE:
			action_move(Vector3i(gridmap_position))

# Retrieve the mesh from a PackedScene, used for dynamically creating a MeshLibrary
func get_mesh(packed_scene):
	var scene_state:SceneState = packed_scene.get_state()
	for i in range(scene_state.get_node_count()):
		if(scene_state.get_node_type(i) == "MeshInstance3D"):
			for j in scene_state.get_node_property_count(i):
				var prop_name = scene_state.get_node_property_name(i, j)
				if prop_name == "mesh":
					var prop_value = scene_state.get_node_property_value(i, j)
					
					return prop_value.duplicate()

# Build (place) a structure
func action_build(gridmap_position):
	if Input.is_action_pressed("build") and not _mouse_over_ui():
		
		var previous_tile = gridmap.get_cell_item(gridmap_position)
		gridmap.set_cell_item(gridmap_position, index, gridmap.get_orthogonal_index_from_basis(selector.basis))
		
		if previous_tile != index:
			cell_changed.emit(Vector3i(gridmap_position))
			UGen.unlink_portal(Vector3i(gridmap_position))
			map.cash -= structures[index].price
			
			Audio.play("assets/audio/placement_a.ogg, assets/audio/placement_b.ogg, assets/audio/placement_c.ogg, assets/audio/placement_d.ogg", -20)

func action_link(cell: Vector3i):
	var on_portal := gridmap.get_cell_item(cell) == UGen.PORTAL_ID
	if Input.is_action_just_pressed("build") and on_portal and not _mouse_over_ui():
		portal_links.preview_from = cell
	if portal_links.preview_from == null:
		return
	portal_links.preview_to = selector.position
	if Input.is_action_just_released("build"):
		if on_portal and cell != portal_links.preview_from:
			UGen.portal_links[portal_links.preview_from] = cell
		portal_links.preview_from = null

func action_select(gridmap_position):
	if Input.is_action_just_pressed("build") and not _mouse_over_ui():
		cell_selected.emit(Vector3i(gridmap_position))

func action_move(cell: Vector3i):
	var item: int = gridmap.get_cell_item(cell)
	if Input.is_action_just_pressed("build") and is_movable(item) and not _mouse_over_ui():
		moving_from = cell
		update_structure(item)
		selector_container.visible = true
		move_started.emit(cell)
	if moving_from == null:
		return
	if Input.is_action_just_pressed("rotate"):
		cancel_move()
		return
	if Input.is_action_just_released("build"):
		if item == UGen.FLOOR_ID:
			move_piece(moving_from, cell)
			stop_move()
		else:
			cancel_move()

func cancel_move():
	if moving_from == null:
		return
	move_canceled.emit(moving_from)
	stop_move()

func stop_move():
	moving_from = null
	update_structure()
	selector_container.visible = false

func move_piece(from: Vector3i, to: Vector3i):
	gridmap.set_cell_item(to, gridmap.get_cell_item(from), gridmap.get_cell_item_orientation(from))
	gridmap.set_cell_item(from, UGen.FLOOR_ID)
	UGen.move_portal(from, to)
	cell_changed.emit(from)
	cell_changed.emit(to)
	Audio.play("assets/audio/placement_a.ogg, assets/audio/placement_b.ogg, assets/audio/placement_c.ogg, assets/audio/placement_d.ogg", -20)

func is_movable(item: int) -> bool:
	return item in [UGen.COIN_ID, UGen.NPC_ID, UGen.PORTAL_ID, UGen.PLAYER_SPAWN_ID, UGen.BANNER_ID]

# Demolish (remove) a structure
func action_demolish(gridmap_position):
	if Input.is_action_pressed("build") and not _mouse_over_ui():
		if gridmap.get_cell_item(gridmap_position) != -1:
			UGen.unlink_portal(Vector3i(gridmap_position))
			gridmap.set_cell_item(gridmap_position, -1)
			cell_changed.emit(Vector3i(gridmap_position))
			
			Audio.play("assets/audio/removal_a.ogg, assets/audio/removal_b.ogg, assets/audio/removal_c.ogg, assets/audio/removal_d.ogg", -20)

# Rotates the 'cursor' 90 degrees
func action_rotate():
	if Input.is_action_just_pressed("rotate") and not _mouse_over_ui():
		selector.rotate_y(deg_to_rad(90))
		
		Audio.play("assets/audio/rotate.ogg", -30)

# Toggle between structures to build
func _unhandled_input(event):
	if event.is_action_pressed("structure_next"):
		select_structure(next_buildable(1))
	
	if event.is_action_pressed("structure_previous"):
		select_structure(next_buildable(-1))

func select_structure(new_index: int):
	index = new_index
	Audio.play("assets/audio/toggle.ogg", -30)
	update_structure()
	structure_changed.emit(index)

func next_buildable(step: int) -> int:
	var next = wrap(index + step, 0, structures.size())
	while not structures[next].buildable:
		next = wrap(next + step, 0, structures.size())
	return next

# Update the structure visual in the 'cursor'
func update_structure(structure_index := index):
	# Clear previous structure preview in selector
	for n in selector_container.get_children():
		n.queue_free()
		
	# Create new structure preview in selector
	var _model = structures[structure_index].model.instantiate()
	_model.process_mode = Node.PROCESS_MODE_DISABLED
	for group in _model.get_groups():
		_model.remove_from_group(group)
	selector_container.add_child(_model)
	_model.position.y += 0.25

# Saving/load
func save_map():
	print("Saving map...")
	
	map.structures.clear()
	for cell in gridmap.get_used_cells():
		var data_structure:DataStructure = DataStructure.new()
		data_structure.position = Vector2i(cell.x, cell.z)
		data_structure.orientation = gridmap.get_cell_item_orientation(cell)
		data_structure.structure = gridmap.get_cell_item(cell)
		map.structures.append(data_structure)
		
	ResourceSaver.save(map, "user://map.res")

func load_map():
	print("Loading map...")
	
	gridmap.clear()
	
	map = ResourceLoader.load("user://map.res")
	if not map:
		map = DataMap.new()
	for cell in map.structures:
		gridmap.set_cell_item(Vector3i(cell.position.x, 0, cell.position.y), cell.structure, cell.orientation)

func _mouse_over_ui() -> bool:
	var mouse := get_viewport().get_mouse_position()
	for control: Control in get_tree().get_nodes_in_group("blocking_ui"):
		if control.is_visible_in_tree() and control.get_global_rect().has_point(mouse):
			return true
	return false
