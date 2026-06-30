extends Node3D

@export var arrow_scene: PackedScene
@export var grid_map: GridMap
@export var arrow_height_offset: float = 0.05

var _arrows: Array[Node3D] = []

const BASE_Z_OFFSET = 0.5
var tile_visit_count: Dictionary = {}  # Vector3i -> float
var last_arrow_tip_offset: float = 0

#var n_intersection :int = 0

func clear_path():
	for a in _arrows:
		a.queue_free()
	_arrows.clear()
	tile_visit_count.clear()
	last_arrow_tip_offset = 0

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
	# Se o tile de inicio for igual a final, para a função
	var dir = to - from
	if dir.length() == 0:
		return
	
	# Pega os offsets de cada extremidade da seta
	var from_offset = last_arrow_tip_offset
	var visits = tile_visit_count.get(int_to, 0)
	var to_offset = visits * BASE_Z_OFFSET
	
	# Aplica os offsets
	from += Vector3.UP * from_offset
	to += Vector3.UP * to_offset
	
	# Atualiza offset do tile de destino para a próxima seta que passar por ele
	tile_visit_count[int_to] = visits + 1
	last_arrow_tip_offset = to_offset
	
	# Cria uma instância da seta e adiciona como filha
	var arrow = arrow_scene.instantiate()
	add_child(arrow)
	# Posiciona a seta na origem
	arrow.global_position = from
	# Direciona a seta para o to
	arrow.look_at(to, Vector3.UP)
	# Aumenta o comprimento da seta
	var distance = from.distance_to(to)
	arrow.scale.z = distance
	# Adiciona seta na lista de setas
	_arrows.append(arrow)
