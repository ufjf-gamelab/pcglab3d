extends Node3D
class_name HangingItem

var yaw_source: Node3D

func _process(_delta):
	hang()

func hang():
	if yaw_source == null:
		return
	var item_scale := global_basis.get_scale()
	var yaw := yaw_source.global_rotation.y
	global_basis = Basis.from_euler(Vector3(0, yaw, 0)).scaled(item_scale)
