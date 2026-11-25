extends Node3D

var camera_position:Vector3
var camera_rotation:Vector3

var zoom:float = 30.0 # 30 = Standard zoom level, in meters

var active := true

# Visão inicial do jogo
@export var home_position := Vector3(20, 0, 20)
@export var home_rotation := Vector3(-35, 0, 0)
@export var home_zoom := 80.0

# Bloqueia só o controle do jogador
var input_locked := false

@onready var camera = $EditCamera

func _ready():
	# Começa na visão inicial
	camera_position = home_position
	camera_rotation = home_rotation
	zoom = home_zoom
	position = home_position
	rotation_degrees = home_rotation
	camera.position = Vector3(0, 0, zoom)

# Leva a câmera de volta à visão inicial, interpolando
func go_home():
	camera_position = home_position
	var delta_y := wrapf(home_rotation.y - rotation_degrees.y, -180.0, 180.0)
	camera_rotation = Vector3(home_rotation.x, rotation_degrees.y + delta_y, home_rotation.z)
	zoom = home_zoom

func _process(delta):
	if not active:
		return
	
	# Set position and rotation to targets
	
	position = position.lerp(camera_position, delta * 8)
	rotation_degrees = rotation_degrees.lerp(camera_rotation, delta * 6)
	
	# Smoothly update zoom
	
	camera.position = camera.position.lerp(Vector3(0, 0, zoom), delta * 8)
	
	handle_input(delta)

# Handle input

func handle_input(_delta):
	
	if not active or input_locked:
		return
	
	# Rotation
	
	var input := Vector3.ZERO
	
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")
	
	input = input.rotated(Vector3.UP, rotation.y).normalized()
	
	camera_position += input / 4
	
	# Zoom in/out
	
	if Input.is_action_just_released("zoom_in"):
		zoom = max(15, zoom - 5) # 15 = Minimum zoom level, in meters
		
	if Input.is_action_just_released("zoom_out"):
		zoom = min(80, zoom + 5) # 80 = Maximum zoom level, in meters
	
	# Back to center
	
	if Input.is_action_pressed("camera_center"):
		go_home()

func _input(event):
	
	if not active:
		return
	
	if input_locked:
		return
	
	# Rotate camera using mouse (hold 'middle' mouse button)
	
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("camera_rotate"):
			camera_rotation += Vector3(0, -event.relative.x / 10, 0)
