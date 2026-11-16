extends Node3D

@export var structures: Array[Structure] = []

var map:DataMap

var index:int = 0 # Index of structure being built

@export var selector:Node3D # The 'cursor'
@export var selector_container:Node3D # Node that holds a preview of the structure
@export var view_camera:Camera3D # Used for raycasting mouse
@export var gridmap:GridMap
@export var cash_display:Label

var plane:Plane # Used for raycasting mouse

func _ready():
	
	map = DataMap.new()
	plane = Plane(Vector3.UP, Vector3.ZERO)
	
	# Create new MeshLibrary dynamically, can also be done in the editor
	# See: https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html
	
	var mesh_library = MeshLibrary.new()
		
	for structure in structures:
		var id = mesh_library.get_last_unused_item_id()
		
		mesh_library.create_item(id)
		
		# Instancia a cena
		var scene_instance = structure.model.instantiate()
		
		mesh_library.set_item_mesh(id, _merge_meshes(scene_instance))
		
		# Percorre os filhos do nó raiz
		for child in scene_instance.get_children():
			# Caso encontre colisão filha direta do nó raiz
			if child is CollisionShape3D:
#				# Adiciona forma ao item
				mesh_library.set_item_shapes(id, [child.shape, child.transform])
		
		# Remove a instância da memória
		scene_instance.queue_free()
	
	# Adiciona a meshLibrary criada à meshLibrary do GridMap
	gridmap.mesh_library = mesh_library
	
	update_structure()
	
func _process(delta):
	
	# Controls
	action_rotate() # Rotates selection 90 degrees
	action_structure_toggle() # Toggles between structures
	
	action_save() # Saving
	action_load() # Loading
	action_load_resources() # Loading from resources
	
	# Map position based on mouse
	var world_position = plane.intersects_ray(
		view_camera.project_ray_origin(get_viewport().get_mouse_position()),
		view_camera.project_ray_normal(get_viewport().get_mouse_position()))

	var gridmap_position = Vector3(round(world_position.x), 0, round(world_position.z))
	selector.position = lerp(selector.position, gridmap_position, min(delta * 40, 1.0))
	
	action_build(gridmap_position)
	action_demolish(gridmap_position)

func _merge_meshes(root: Node) -> ArrayMesh:
	var merged := ArrayMesh.new()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = node.mesh
		if mesh == null:
			continue
		var xform := _transform_relative_to(node, root)
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			arrays[Mesh.ARRAY_TANGENT] = null
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in range(vertices.size()):
				vertices[i] = xform * vertices[i]
			arrays[Mesh.ARRAY_VERTEX] = vertices
			if arrays[Mesh.ARRAY_NORMAL] != null:
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i in range(normals.size()):
					normals[i] = (xform.basis * normals[i]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = normals
			merged.add_surface_from_arrays(mesh.surface_get_primitive_type(surface), arrays)
			var material: Material = node.material_override
			if material == null:
				material = node.get_surface_override_material(surface)
			if material == null:
				material = mesh.surface_get_material(surface)
			merged.surface_set_material(merged.get_surface_count() - 1, material)
	return merged

func _transform_relative_to(node: Node3D, root: Node) -> Transform3D:
	var xform := node.transform
	var parent := node.get_parent()
	while parent != root and parent is Node3D:
		xform = parent.transform * xform
		parent = parent.get_parent()
	return xform

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
	if Input.is_action_just_pressed("build"):
		
		var previous_tile = gridmap.get_cell_item(gridmap_position)
		gridmap.set_cell_item(gridmap_position, index, gridmap.get_orthogonal_index_from_basis(selector.basis))
		
		if previous_tile != index:
			map.cash -= structures[index].price
			
			Audio.play("sounds/placement-a.ogg, sounds/placement-b.ogg, sounds/placement-c.ogg, sounds/placement-d.ogg", -20)

# Demolish (remove) a structure
func action_demolish(gridmap_position):
	if Input.is_action_just_pressed("demolish"):
		if gridmap.get_cell_item(gridmap_position) != -1:
			gridmap.set_cell_item(gridmap_position, -1)
			
			Audio.play("sounds/removal-a.ogg, sounds/removal-b.ogg, sounds/removal-c.ogg, sounds/removal-d.ogg", -20)

# Rotates the 'cursor' 90 degrees
func action_rotate():
	if Input.is_action_just_pressed("rotate"):
		selector.rotate_y(deg_to_rad(90))
		
		Audio.play("sounds/rotate.ogg", -30)

# Toggle between structures to build
func action_structure_toggle():
	if Input.is_action_just_pressed("structure_next"):
		index = wrap(index + 1, 0, structures.size())
		Audio.play("sounds/toggle.ogg", -30)
	
	if Input.is_action_just_pressed("structure_previous"):
		index = wrap(index - 1, 0, structures.size())
		Audio.play("sounds/toggle.ogg", -30)

	update_structure()

# Update the structure visual in the 'cursor'
func update_structure():
	# Clear previous structure preview in selector
	for n in selector_container.get_children():
		selector_container.remove_child(n)
		
	# Create new structure preview in selector
	var _model = structures[index].model.instantiate()
	selector_container.add_child(_model)
	_model.position.y += 0.25

# Saving/load
func action_save():
	if Input.is_action_just_pressed("save"):
		print("Saving map...")
		
		map.structures.clear()
		for cell in gridmap.get_used_cells():
			var data_structure:DataStructure = DataStructure.new()
			data_structure.position = Vector2i(cell.x, cell.z)
			data_structure.orientation = gridmap.get_cell_item_orientation(cell)
			data_structure.structure = gridmap.get_cell_item(cell)
			map.structures.append(data_structure)
			
		ResourceSaver.save(map, "user://map.res")
	
func action_load():
	if Input.is_action_just_pressed("load"):
		print("Loading map...")
		
		gridmap.clear()
		
		map = ResourceLoader.load("user://map.res")
		if not map:
			map = DataMap.new()
		for cell in map.structures:
			gridmap.set_cell_item(Vector3i(cell.position.x, 0, cell.position.y), cell.structure, cell.orientation)

func action_load_resources():
	if Input.is_action_just_pressed("load_resources"):
		print("Loading map...")
		
		gridmap.clear()
		
		map = ResourceLoader.load("res://sample map/map.res")
		if not map:
			map = DataMap.new()
		for cell in map.structures:
			gridmap.set_cell_item(Vector3i(cell.position.x, 0, cell.position.y), cell.structure, cell.orientation)
