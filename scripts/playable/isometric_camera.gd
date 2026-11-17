extends Node3D
class_name IsometricCamera

@export var pitch := -35.264
@export var yaw := 45.0
@export var distance := 20.0
@export var size := 7.0
@export var min_size := 4.0
@export var max_size := 14.0
@export var zoom_step := 1.0
@export var follow_smoothing := 8.0
@export var zoom_smoothing := 10.0
@export var rotate_step := 90.0
@export var rotate_smoothing := 10.0

@onready var camera: Camera3D = $Camera

var target_size := size
var target_yaw := yaw

func _ready():
	top_level = true
	global_position = get_parent().global_position
	rotation_degrees = Vector3(pitch, yaw, 0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 0, distance)
	camera.size = size
	target_size = size
	target_yaw = yaw
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta):
	var target: Vector3 = get_parent().global_position
	global_position = global_position.lerp(target, min(delta * follow_smoothing, 1.0))
	camera.size = lerp(camera.size, target_size, min(delta * zoom_smoothing, 1.0))
	rotation.y = lerp_angle(rotation.y, deg_to_rad(target_yaw), min(delta * rotate_smoothing, 1.0))

func _unhandled_input(event):
	if event.is_action_pressed("camera_rotate_left"):
		target_yaw += rotate_step
	if event.is_action_pressed("camera_rotate_right"):
		target_yaw -= rotate_step
	if event.is_action_pressed("zoom_in"):
		target_size = max(min_size, target_size - zoom_step)
	if event.is_action_pressed("zoom_out"):
		target_size = min(max_size, target_size + zoom_step)

func get_forward() -> Vector3:
	var f := -global_basis.z
	f.y = 0
	return f.normalized()

func get_right() -> Vector3:
	var r := global_basis.x
	r.y = 0
	return r.normalized()

func get_aim_direction(from: Vector3) -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var normal := camera.project_ray_normal(mouse)
	var hit = Plane(Vector3.UP, from.y).intersects_ray(origin, normal)
	if hit == null:
		return Vector3.ZERO
	var dir: Vector3 = hit - from
	dir.y = 0
	return dir.normalized()
