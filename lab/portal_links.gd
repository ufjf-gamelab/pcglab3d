extends MeshInstance3D
class_name PortalLinks

@export var color := Color(0.4509804, 1, 0.3764706)
@export var arc_height := 0.25
@export var segments := 24

var last_links := 0

func _process(_delta):
	if UGen.portal_links.hash() != last_links:
		rebuild()

func rebuild():
	last_links = UGen.portal_links.hash()
	material_override.albedo_color = color
	var lines := ImmediateMesh.new()
	for from in UGen.portal_links:
		var to = UGen.portal_links[from]
		if to != null:
			draw_arc(lines, Vector3(from), Vector3(to))
	mesh = lines

func draw_arc(lines: ImmediateMesh, from: Vector3, to: Vector3):
	var top := from.distance_to(to) * arc_height
	lines.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in segments + 1:
		var t := float(i) / segments
		var lift := 1.0 + top * sin(t * PI)
		lines.surface_add_vertex(from.lerp(to, t) + Vector3.UP * lift)
	lines.surface_end()
