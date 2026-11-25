extends Area3D

signal collect_coin

func _ready():
	connect("body_entered", _on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("Players"):
		emit_signal("collect_coin")
		queue_free()
