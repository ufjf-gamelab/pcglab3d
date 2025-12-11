extends CharacterBody3D

@export var speed := 5.0
@export var gravity := 9.8
@export var jump_force := 4.0

var anim: AnimationPlayer

func _ready():
	anim = $Model/AnimationPlayer
	anim.play("idle")

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

		if anim.current_animation != "walk":
			anim.play("walk")

		look_at(global_transform.origin + Vector3(-dir.x, 0, -dir.z), Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

		if anim.current_animation != "idle":
			anim.play("idle")

	move_and_slide()
