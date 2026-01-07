extends CharacterBody3D

@export var speed := 4.0
@export var gravity := 9.8
@export var jump_force := 4.0
@export var attack_damage := 1

@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var attack_area: Area3D = $"Model/character-human/Skeleton3D/RightHand/AttackArea"

var portal_cooldown := false

var attacking := false
var enemies_hit := []

var dying := false

func _ready():
	anim.play("idle")
	
	attack_area.monitoring = false
	
	# Conecta sinais às funções
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	anim.animation_finished.connect(_on_animation_finished)
	anim.animation_started.connect(_on_animation_started)

# Início de alguma animação
func _on_animation_started(anim_name):
	if anim_name == "attack-melee-right":
		enable_attack()

# Final de alguma animação
func _on_animation_finished(anim_name):
	if anim_name == "attack-melee-right":
		disable_attack()

# Ativa hitbox do ataque
func enable_attack():
	attack_area.monitoring = true
	attacking = true

# Desativa hitbox do ataque
func disable_attack():
	attack_area.monitoring = false
	attacking = false

# Método de ataque
func attack():
	enemies_hit.clear()
	velocity = Vector3.ZERO
	anim.play("attack-melee-right")

# Algum corpo entrou na area de ataque do player
func _on_attack_area_body_entered(body: Node3D) -> void:
	if not body.has_method("take_damage"):
		return
		
	if body in enemies_hit:
		return
		
	enemies_hit.append(body)
	body.take_damage(attack_damage)
	
# Teleporta o player para o próximo portal
func teleport_to(pos: Vector3):
	portal_cooldown = true
	set_deferred("global_position", pos)
	velocity = Vector3.ZERO
	await get_tree().create_timer(0.2).timeout
	portal_cooldown = false


func _physics_process(_delta):
	if attacking or dying:
		return
	
	var dir = Vector3.ZERO

	if Input.is_action_pressed("move_back"):
		dir.z -= 1
	if Input.is_action_pressed("move_forward"):
		dir.z += 1
	if Input.is_action_pressed("move_right"):
		dir.x -= 1
	if Input.is_action_pressed("move_left"):
		dir.x += 1
	if Input.is_action_just_pressed("attack"):
		attack()
		return

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
