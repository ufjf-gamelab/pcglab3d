extends CharacterBody3D

@export var max_life := 2
var life := max_life

@export var speed := 3.0
@export var attack_distance := 0.8

@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var agent: NavigationAgent3D = $NavigationAgent3D

var player : Node3D
var chasing := false
var die := false

func _physics_process(_delta):
	if die:
		return

	if chasing and player:
		agent.target_position = player.global_position

		var next_pos = agent.get_next_path_position()

		var direction = (next_pos - global_position).normalized()

		velocity = direction * speed
		move_and_slide()

		# virar para o player
		look_at(player.global_position)

		# atacar
		if global_position.distance_to(player.global_position) < attack_distance:
			anim.play("attack-melee-right")
		else:
			anim.play("walk")

	else:
		anim.play("idle")

# Player entrou na área
func _on_detection_area_body_entered(body):
	if body.name == "Player":
		player = body
		chasing = true

# Recebe dano
func take_damage(amount):
	life -= amount
	print("Vida:", life)

	if life <= 0:
		die = true
		on_die()

# Faz a animação de morte e remove do mapa
func on_die():
	anim.play("die")
	await anim.animation_finished
	queue_free()
