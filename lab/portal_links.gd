extends MeshInstance3D
class_name PortalLinks

@export var color := Color(0.30588236, 0.6313726, 1)
@export var arc_height := 0.25
@export var segments := 24
@export var arrow_size := 0.6

var preview_from = null
var preview_to := Vector3.ZERO

func _process(_delta):
	if not visible:
		return
	for portal in get_tree().get_nodes_in_group("Portals"):
		portal.mesh.visible = UGen.is_portal_linked(portal.portal_cell)

	material_override.albedo_color = color
	var lines := ImmediateMesh.new()
	for from in UGen.portal_links:
		var to = UGen.portal_links[from]
		if to != null:
			draw_arc(lines, Vector3(from), Vector3(to))
	if preview_from != null:
		draw_arc(lines, Vector3(preview_from), preview_to)
	mesh = lines

func draw_arc(lines: ImmediateMesh, from: Vector3, to: Vector3):
	var points: PackedVector3Array = []
	for i in segments + 1:
		points.append(arc_point(from, to, float(i) / segments))
	draw_line(lines, points)

	var tip := arc_point(from, to, 0.75)
	var direction := (tip - arc_point(from, to, 0.7)).normalized()
	var back := -direction * arrow_size
	var side := direction.cross(Vector3.UP).normalized() * arrow_size * 0.5
	draw_line(lines, PackedVector3Array([tip + back + side, tip, tip + back - side]))

func arc_point(from: Vector3, to: Vector3, t: float) -> Vector3:
	var top := from.distance_to(to) * arc_height
	return from.lerp(to, t) + Vector3.UP * (1.0 + top * sin(t * PI))

func draw_line(lines: ImmediateMesh, points: PackedVector3Array):
	lines.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point in points:
		lines.surface_add_vertex(point)
	lines.surface_end()
