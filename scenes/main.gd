extends Node3D

@onready var my_grid_map = $GridMap

# Captura evento de geração da dungeon e chama Autoload Gen
func _unhandled_input(event):
	if event.is_action_pressed("generate_dungeon"):
		Gen.generate_dungeon(my_grid_map)
