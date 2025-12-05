extends CharacterBody3D

@export var speed := 5.0
@export var gravity := 9.8
@export var jump_force := 4.0

func _physics_process(_delta):
	var dir = Vector3.ZERO

	if Input.is_action_pressed("move_back"):
		dir.z -= 1
	if Input.is_action_pressed("move_forward"):
		dir.z += 1
	if Input.is_action_pressed("move_right"):
		dir.x -= 1
	if Input.is_action_pressed("move_left"):
		dir.x += 1

	if dir != Vector3.ZERO:
		dir = dir.normalized()

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	move_and_slide()
