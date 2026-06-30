extends CharacterBody3D

@export var max_life := 2
@export var speed := 2.0
@export var attack_distance := 0.6
@export var attack_cooldown := 0.5
@export var attack_damage := 1

var player : Node3D = null
var life := max_life
var state : State = State.IDLE

enum State {
	IDLE,
	CHASE,
	ATTACK_PREPARE,
	DEAD
}

@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var attack_area := $"Model/character-orc/Skeleton3D/RightHand/Area3D"

 
func _ready():
	agent.path_desired_distance = 0.2
	agent.target_desired_distance = 0.2
	agent.avoidance_enabled = true
	agent.radius = 0.5

	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	
	anim.animation_started.connect(_on_animation_started)
	anim.animation_finished.connect(_on_animation_finished)

func _physics_process(_delta):
	if state == State.DEAD:
		return

	match state:
		State.IDLE:
			idle_state()
		
		State.CHASE:
			chase_state()

# IDLE
func idle_state():
	velocity = Vector3.ZERO
	
	if anim.current_animation != "idle":
		anim.play("idle")
		
# CHASE
func chase_state():
	if player == null or player.life <= 0:
		state = State.IDLE
		return

	var distance = global_position.distance_to(player.global_position)
	if distance < attack_distance:
		attack()
		return

	agent.set_target_position(player.global_position)
	var next_pos = agent.get_next_path_position()
	var direction = next_pos - global_position

	if direction.length() < 0.05:
		return

	direction = direction.normalized()

	velocity = direction * speed
	move_and_slide()

	look_at(next_pos)

	if anim.current_animation != "walk":
		anim.play("walk")

# ATTACK
func attack():
	state = State.ATTACK_PREPARE

	velocity = Vector3.ZERO
	move_and_slide()

	await get_tree().create_timer(attack_cooldown).timeout

	if state == State.DEAD:
		return

	anim.play("attack-melee-right")

func _on_animation_started(anim_name):
	if state == State.DEAD:
		return
	if anim_name == "attack-melee-right":
		attack_area.monitoring = true

func _on_animation_finished(anim_name):
	if state == State.DEAD:
		return
	if anim_name == "attack-melee-right":
		attack_area.monitoring = false
		if player:
			state = State.CHASE
		else:
			state = State.IDLE

func _on_detection_area_body_entered(body):
	if state == State.DEAD:
		return

	if body.name == "Player":
		player = body
		state = State.CHASE

func _on_detection_area_body_exited(body):
	if state == State.DEAD:
		return

	if body.name == "Player":
		player = null
		state = State.IDLE

func _on_attack_area_body_entered(body):
	if state == State.DEAD:
		return

	if body.name == "Player" and body.life > 0:
		body.take_damage(attack_damage)

func take_damage(amount):
	if state == State.DEAD:
		return

	life -= amount
	if life <= 0:
		die()

func die():
	state = State.DEAD

	velocity = Vector3.ZERO
	move_and_slide()

	player = null
	attack_area.monitoring = false

	anim.play("die")
	await anim.animation_finished
	await get_tree().create_timer(2).timeout
	queue_free()
