extends StaticBody3D

var active := true
signal player_entered_banner_area()

func _on_light_area_body_entered(body: Node3D) -> void:
	if not body.is_in_group("Players"):
		return
	body.enter_light()
	if active:
		active = false
		body.refill_fuel()
		player_entered_banner_area.emit()

func _on_light_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("Players"):
		body.exit_light()
