extends Item
class_name Lantern

signal fuel_changed(curr_fuel)

@export var max_fuel := 30.0

@onready var pivot: HangingItem = $LanternPivot
@onready var light: Light3D = $LanternPivot/Model/LanternLight

var fuel := 0.0

func _ready():
	fuel = max_fuel
	# O pivô usa a rotação do modelo do player pra lanterna ficar sempre em pé
	pivot.yaw_source = player.get_node("Model")
	pivot.hang()

func _physics_process(delta):
	if not held or fuel <= 0.0 or player.is_dead():
		return
	fuel = max(fuel - delta, 0.0)
	fuel_changed.emit(fuel)
	if fuel == 0.0:
		light.visible = false

func is_emitting_light() -> bool:
	return held and fuel > 0.0

func refill():
	fuel = max_fuel
	light.visible = true
	fuel_changed.emit(fuel)
