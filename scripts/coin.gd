extends Area3D

var moedas = 0

func _ready():
	connect("body_entered", _on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("Players"):
		moedas += 1
		print("Moedas: " + str(moedas))
		queue_free()
