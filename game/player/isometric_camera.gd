extends Camera3D
class_name IsometricCamera

@export var pitch := -35.264
@export var yaw := 45.0
@export var distance := 20.0
@export var start_size := 7.0
@export var min_size := 4.0
@export var max_size := 14.0
@export var zoom_step := 1.0
@export var follow_smoothing := 8.0
@export var zoom_smoothing := 10.0
@export var rotate_step := 90.0
@export var rotate_smoothing := 10.0

var target_size := start_size
var target_yaw := yaw
var current_yaw := 0.0
var focus := Vector3.ZERO

func _ready():
	# Não herda a rotação do player
	top_level = true
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = start_size
	target_size = start_size
	target_yaw = yaw
	current_yaw = deg_to_rad(yaw)
	focus = get_parent().global_position
	update_transform()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta):
	var target: Vector3 = get_parent().global_position
	focus = focus.lerp(target, min(delta * follow_smoothing, 1.0))
	size = lerp(size, target_size, min(delta * zoom_smoothing, 1.0))
	current_yaw = lerp_angle(current_yaw, deg_to_rad(target_yaw), min(delta * rotate_smoothing, 1.0))
	update_transform()

func update_transform():
	rotation = Vector3(deg_to_rad(pitch), current_yaw, 0)
	global_position = focus + global_basis.z * distance

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
	# Raio do mouse até o chão
	var origin := project_ray_origin(mouse)
	var normal := project_ray_normal(mouse)
	var hit = Plane(Vector3.UP, from.y).intersects_ray(origin, normal)
	if hit == null:
		return Vector3.ZERO
	var dir: Vector3 = hit - from
	dir.y = 0
	return dir.normalized()
