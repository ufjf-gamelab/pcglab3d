extends StaticBody3D

var active := true
signal player_entered_banner_area()

func _on_reset_timer_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Players") and active:
		active = false
		player_entered_banner_area.emit()
