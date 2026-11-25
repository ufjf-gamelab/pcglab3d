extends StaticBody3D

@export var activated := true

@onready var mesh := $PortalMesh
@onready var area := $Area3D

var portal_cell: Vector3i

func set_active(value: bool):
	activated = value

	mesh.visible = activated
	area.set_deferred("monitoring", activated)
	area.set_deferred("monitorable", activated)
