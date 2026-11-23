extends Node3D
class_name PlayerCamera

@export var mouse_sensitivity := 0.15 # TODO um menu que muda isso
@export var min_pitch := -75.0
@export var max_pitch := -10.0
@export var min_distance := 3.0
@export var max_distance := 10.0
@export var zoom_step := 1.0
@export var smoothing := 10.0

@onready var camera: Camera3D = $Camera

# Copei o offset antigo que estavam usando
var target_yaw := 180.0
var target_pitch := -31.0
var target_distance := 5.8

func _ready():
	rotation_degrees = Vector3(target_pitch, target_yaw, 0)
	camera.position.z = target_distance
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# Pra identificar quando o jogo é pausado e despausado
func _notification(notification_id: int):
	if notification_id == NOTIFICATION_PAUSED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif notification_id == NOTIFICATION_UNPAUSED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta):
	var t: float = min(delta * smoothing, 1.0)
	rotation_degrees.y = lerp(rotation_degrees.y, target_yaw, t)
	rotation_degrees.x = lerp(rotation_degrees.x, target_pitch, t)
	camera.position.z = lerp(camera.position.z, target_distance, t)

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		target_yaw -= event.relative.x * mouse_sensitivity
		target_pitch = clamp(target_pitch - event.relative.y * mouse_sensitivity, min_pitch, max_pitch)

	if event.is_action_pressed("zoom_in"):
		target_distance = max(min_distance, target_distance - zoom_step)
	if event.is_action_pressed("zoom_out"):
		target_distance = min(max_distance, target_distance + zoom_step)

func get_forward() -> Vector3:
	var f := -global_basis.z
	f.y = 0
	return f.normalized()

func get_right() -> Vector3:
	var r := global_basis.x
	r.y = 0
	return r.normalized()
