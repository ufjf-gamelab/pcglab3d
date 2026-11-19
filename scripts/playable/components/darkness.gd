extends Node
class_name Darkness

@export var dark_hit_interval := 3.0
@export var dark_damage := 1

@onready var player: Player = owner

# Antes quando eu usava bool dava errado, porque dava pra ter várias fogueiras
var lights_near := 0
var dark_time := 0.0

func _physics_process(delta):
	if player.is_dead():
		return
	if is_lit():
		dark_time = 0.0
		return
	dark_time += delta
	if dark_time >= dark_hit_interval:
		dark_time = 0.0
		player.take_damage(dark_damage)

func is_lit() -> bool:
	return lights_near > 0 or player.equipment.is_emitting_light()

func enter_light():
	lights_near += 1

func exit_light():
	lights_near = max(lights_near - 1, 0)
