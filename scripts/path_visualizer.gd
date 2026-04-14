extends Node3D

@export var arrow_scene: PackedScene
@export var grid_map: GridMap
@export var arrow_height_offset: float = 0.2

var _arrows: Array[Node3D] = []

func clear_path():
	for a in _arrows:
		a.queue_free()
	_arrows.clear()

func draw_path(tile_path: Array[Vector3i]):
	clear_path()

	if tile_path.size() < 2:
		return

	for i in range(tile_path.size() - 1):
		var from_tile = tile_path[i]
		var to_tile = tile_path[i + 1]

		var from_pos = _tile_to_world_center(from_tile)
		var to_pos = _tile_to_world_center(to_tile)

		_create_arrow(from_pos, to_pos)

func _tile_to_world_center(tile: Vector3i) -> Vector3:
	var local_pos = grid_map.map_to_local(tile)
	var world_pos = grid_map.to_global(local_pos)

	return world_pos + Vector3.UP * arrow_height_offset

func _create_arrow(from: Vector3, to: Vector3):
	var arrow = arrow_scene.instantiate()
	add_child(arrow)

	var dir = to - from
	var length = dir.length()

	if length == 0:
		return

	dir = dir.normalized()

	# Cria Basis
	var arrow_basis = Basis.looking_at(dir, Vector3.UP)
	# Inverte a frente da seta
	arrow_basis = arrow_basis.rotated(Vector3.UP, PI)
	# Ajusta comprimento da seta
	arrow_basis = arrow_basis.scaled(Vector3(1, 1, length))
	# Cria transform
	var arrow_transform = Transform3D(arrow_basis, from)
	# Passa transform para a seta
	arrow.global_transform = arrow_transform

	_arrows.append(arrow)
