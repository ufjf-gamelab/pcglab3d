extends Node3D
class_name DungeonDresser

signal rebuilt

@export var gridmap: GridMap
@export var cover_border := 2

@export_group("Terrain")
@export var floor_scene: PackedScene
@export var wall_scene: PackedScene
@export var corner_scene: PackedScene
@export var crossing_scene: PackedScene
@export var cover_scene: PackedScene

@export_group("Markers")
@export var coin_scene: PackedScene
@export var enemy_scene: PackedScene
@export var portal_scene: PackedScene
@export var spawn_scene: PackedScene
@export var campfire_scene: PackedScene

@onready var markers := {
	UGen.COIN_ID: coin_scene,
	UGen.NPC_ID: enemy_scene,
	UGen.PORTAL_ID: portal_scene,
	UGen.PLAYER_SPAWN_ID: spawn_scene,
	UGen.BANNER_ID: campfire_scene,
}

var last_signature := 0
var room_by_cell := {}
var room_groups: Array[Node3D] = []
var outside_group: Node3D

func _ready():
	global_transform = gridmap.global_transform

func _process(_delta):
	if grid_signature() != last_signature:
		rebuild()

func grid_signature() -> int:
	var signature := 0
	for cell in gridmap.get_used_cells():
		signature = signature * 31 + hash(cell) + gridmap.get_cell_item(cell)
	return signature

func rebuild():
	last_signature = grid_signature()
	for child in get_children():
		child.free()
	create_groups()

	var walkable := walkable_cells()
	var area := map_area().grow(cover_border)
	for x in range(area.position.x, area.end.x):
		for y in range(area.position.y, area.end.y):
			dress_cell(Vector2i(x, y), walkable)
	for vertex in vertices_around(walkable):
		dress_vertex(vertex, walkable)
	rebuilt.emit()

func create_groups():
	room_by_cell.clear()
	room_groups.clear()
	outside_group = add_group("Outside")
	for index in UGen.rooms.size():
		room_groups.append(add_group("Room%d" % index))
		for cell in UGen.rooms[index]:
			room_by_cell[Vector2i(cell.x, cell.z)] = index

func add_group(group_name: String) -> Node3D:
	var group := Node3D.new()
	group.name = group_name
	add_child(group)
	return group

func group_for(cell: Vector2i) -> Node3D:
	if room_by_cell.has(cell):
		return room_groups[room_by_cell[cell]]
	return outside_group

func walkable_cells() -> Dictionary:
	var walkable := {}
	for cell in gridmap.get_used_cells():
		if gridmap.get_cell_item(cell) >= UGen.FLOOR_ID:
			walkable[Vector2i(cell.x, cell.z)] = true
	return walkable

func map_area() -> Rect2i:
	var area := Rect2i()
	for cell in gridmap.get_used_cells():
		area = area.merge(Rect2i(cell.x, cell.z, 1, 1))
	return area

func vertices_around(cells: Dictionary) -> Dictionary:
	var vertices := {}
	for cell: Vector2i in cells:
		for offset in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
			vertices[cell + offset] = true
	return vertices

func dress_cell(cell: Vector2i, walkable: Dictionary):
	var spot := Vector3(cell.x, 0, cell.y)
	var group := group_for(cell)
	if not walkable.has(cell):
		place(cover_scene, group, spot, 0)
		return

	place(floor_scene, group, spot, 0)

	var marker: PackedScene = markers.get(gridmap.get_cell_item(Vector3i(cell.x, 0, cell.y)))
	if marker:
		place(marker, group, spot, 0)

func dress_vertex(vertex: Vector2i, walkable: Dictionary):
	var top_left := walkable.has(vertex)
	var top_right := walkable.has(vertex + Vector2i(1, 0))
	var bottom_left := walkable.has(vertex + Vector2i(0, 1))
	var bottom_right := walkable.has(vertex + Vector2i(1, 1))

	var north := top_left != top_right
	var south := bottom_left != bottom_right
	var west := top_left != bottom_left
	var east := top_right != bottom_right

	var spot := Vector3(vertex.x + 0.5, 0, vertex.y + 0.5)
	var group := group_for(first_walkable(vertex, walkable))
	match [north, south, west, east]:
		[true, true, true, true]: place(crossing_scene, group, spot, 0)
		[true, true, false, false]: place(wall_scene, group, spot, 270 if top_left else 90)
		[false, false, true, true]: place(wall_scene, group, spot, 180 if top_left else 0)
		[false, true, true, false]: place(corner_scene, group, spot, 0)
		[false, true, false, true]: place(corner_scene, group, spot, 90)
		[true, false, false, true]: place(corner_scene, group, spot, 180)
		[true, false, true, false]: place(corner_scene, group, spot, 270)

func first_walkable(vertex: Vector2i, walkable: Dictionary) -> Vector2i:
	for cell in [vertex, vertex + Vector2i(1, 0), vertex + Vector2i(0, 1), vertex + Vector2i(1, 1)]:
		if walkable.has(cell):
			return cell
	return vertex

func place(scene: PackedScene, group: Node3D, spot: Vector3, degrees: float):
	var piece: Node3D = scene.instantiate()
	piece.position = spot
	piece.rotation_degrees.y = degrees
	group.add_child(piece)
