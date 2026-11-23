extends Node
class_name Health

signal life_changed(curr_life)
signal died

@export var max_life := 2

var life := 0

func _ready():
	life = max_life

func take_damage(amount: int):
	life -= amount
	life_changed.emit(life)
	if life <= 0:
		died.emit()
