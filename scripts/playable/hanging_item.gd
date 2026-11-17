extends Node3D
class_name HangingItem

func _process(_delta):
	var item_scale := global_basis.get_scale()
	var yaw := (owner as Node3D).global_rotation.y
	global_basis = Basis.from_euler(Vector3(0, yaw, 0)).scaled(item_scale)
