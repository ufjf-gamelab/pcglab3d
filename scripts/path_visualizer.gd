extends Node3D

@export var arrow_scene: PackedScene
@export var grid_map: GridMap
@export var arrow_height_offset: float = 0.05

var _arrows: Array[Node3D] = []

var destinations : Array[Vector3i] = []

const BASE_Z_OFFSET = 0.3
var n_intersection :int = 0

func clear_path():
	for a in _arrows:
		a.queue_free()
	_arrows.clear()
	destinations.clear()
	n_intersection = 0

func _tile_to_world_center(tile: Vector3i) -> Vector3:
	var local_pos = grid_map.map_to_local(tile)
	var world_pos = grid_map.to_global(local_pos)

	return world_pos + Vector3.UP * arrow_height_offset

func draw_path(tile_path: Array[Vector3i]):
	clear_path()

	if tile_path.size() < 2:
		return

	for i in range(tile_path.size() - 1):
		var from_tile = tile_path[i]
		var to_tile = tile_path[i + 1]

		var from_pos = _tile_to_world_center(from_tile)
		var to_pos = _tile_to_world_center(to_tile)

		_create_arrow(from_pos, to_pos, to_tile)

func _create_arrow(from: Vector3, to: Vector3, int_to: Vector3i):
	var adjusted_int_to = Vector3i(int_to.x, int_to.y + n_intersection, int_to.z)
	if !destinations.has(adjusted_int_to):
		destinations.append(adjusted_int_to)
	else:
		n_intersection += 1
	
	var arrow = arrow_scene.instantiate()
	add_child(arrow)

	var dir = to - from
	var length = dir.length()
	if length == 0:
		return
	
	# Calcula offset atual
	var z_offset = n_intersection * BASE_Z_OFFSET

	# Eleva o from e o to de acordo com o z_offset atual
	from += Vector3.UP * z_offset
	to += Vector3.UP * z_offset
	
	# Posiciona a seta na origem
	arrow.global_position = from
	
	# Direciona a seta para o to
	arrow.look_at(to, Vector3.UP)
	
	# Inverte a frente da seta
	arrow.rotate_y(PI)
	
	# Adiciona seta na lista de setas
	_arrows.append(arrow)
