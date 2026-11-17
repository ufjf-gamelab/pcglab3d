extends CharacterBody3D

@export var max_life := 5
@export var speed := 2.0
@export var attack_distance := 0.6
@export var attack_cooldown := 0.5
@export var attack_damage := 1
@export var attack_speed := 1.5
@export var hit_start := 0.2
@export var hit_end := 0.36
@export var knockback := 0.8

var player : Node3D = null
var life := max_life
var state : State = State.IDLE
var has_hit := false

enum State {
	IDLE,
	CHASE,
	ATTACK_PREPARE,
	STAGGER,
	DEAD
}

@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var attack_area := $"Model/Rig_Medium/Skeleton3D/RightHand/Area3D"

 
func _ready():
	agent.path_desired_distance = 0.2
	agent.target_desired_distance = 0.2
	agent.avoidance_enabled = true
	agent.radius = 0.5

	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	
	anim.animation_started.connect(_on_animation_started)
	anim.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	if state == State.DEAD:
		return

	if anim.current_animation == "attack-melee-right":
		var t := anim.current_animation_position
		attack_area.monitoring = t >= hit_start and t <= hit_end

	match state:
		State.IDLE:
			idle_state()
		
		State.CHASE:
			chase_state()

		State.STAGGER:
			stagger_state(delta)

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

	if state != State.ATTACK_PREPARE:
		return

	anim.play("attack-melee-right", -1, attack_speed)

func _on_animation_started(anim_name):
	if state == State.DEAD:
		return
	if anim_name == "attack-melee-right":
		has_hit = false

func _on_animation_finished(anim_name):
	if state == State.DEAD:
		return
	if anim_name == "attack-melee-right":
		attack_area.monitoring = false
		if player:
			state = State.CHASE
		else:
			state = State.IDLE
	elif anim_name == "hit":
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

	if has_hit:
		return

	if body.name == "Player" and body.life > 0:
		has_hit = true
		# Agora tem que passar o próprio inimigo pra saber a direção do ataque
		body.take_damage(attack_damage, self)

func take_damage(amount):
	if state == State.DEAD:
		return

	life -= amount
	if life <= 0:
		die()
	else:
		stagger()

func stagger():
	state = State.STAGGER
	attack_area.monitoring = false
	velocity = Vector3.ZERO
	if player:
		var away := global_position - player.global_position
		away.y = 0
		velocity = away.normalized() * knockback
	anim.play("hit", 0.05)
	anim.seek(0, true)

func stagger_state(delta):
	velocity = velocity.move_toward(Vector3.ZERO, knockback * 4 * delta)
	move_and_slide()

func die():
	state = State.DEAD

	velocity = Vector3.ZERO
	move_and_slide()

	player = null
	attack_area.monitoring = false
	$CollisionShape3D.set_deferred("disabled", true)

	anim.play("die")
	await anim.animation_finished
	await get_tree().create_timer(2).timeout
	queue_free()
