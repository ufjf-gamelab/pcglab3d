extends CharacterBody3D

@export var max_life := 2
var life := max_life

@export var speed := 2.5

# Tempo de transição das animações
@export var anim_blend_time := 0.15
# Tempo de transição das animações de ataque pra não ficar muito lento
@export var attack_blend_time := 0.05
@export var chain_blend_time := 0.12
@export var combo_reset_time := 0.6
@export var attack_buffer_time := 0.2
@export var block_enabled := false
@export var block_speed_factor := 0.4
@export var block_start_time := 0.15
@export var block_angle := 70.0
@export var block_blend_time := 0.15
@export var locomotion_smoothing := 8.0
@export var combo: Array[AttackData] = []
# Velocidade que o modelo gira
@export var turn_speed := 15.0

@onready var anim: AnimationPlayer = $Model/AnimationPlayer
# Vou precisar de uma só pra misturar as pernas com o tronco
@onready var block_tree: AnimationTree = $Model/BlockTree
@onready var attack_area: Area3D = $"Model/Rig_Medium/Skeleton3D/RightHand/AttackArea"
@onready var model: Node3D = $Model
@onready var camera_pivot: IsometricCamera = $Pivot

var walked_tiles: Array[Vector3i] = []
var last_tile: Vector3i = Vector3i(-9999, -9999, -9999)

signal update_life(curr_life)

var portal_cooldown := false

var attacking := false
var enemies_hit := []
var combo_index := 0
var queued_attack := false
var last_attack_end := -100.0
var attack_elapsed := 0.0
var attack_pressed_at := -100.0
var blocking := false
var block_started_at := 0.0
var block_tween: Tween
var locomotion_blend := Vector2.ZERO

var dying := false

# Faz a animação de morte e remove do mapa
func on_die():
	anim.play("die")
	await anim.animation_finished
	await get_tree().create_timer(2).timeout
	queue_free()

# Recebe dano
func take_damage(amount, source: Node3D = null):
	if source and is_blocking_from(source):
		block_hit()
		return

	life -= amount
	#print("Vida Player:", life)
	emit_signal("update_life", life)
	
	if life <= 0:
		dying = true
		end_attack()
		finish_block()
		on_die()

func _ready():
	anim.playback_default_blend_time = anim_blend_time
	anim.play("idle")
	
	attack_area.monitoring = false
	
	# Conecta sinais às funções
	attack_area.body_entered.connect(_on_attack_area_body_entered)

# Ativa hitbox do ataque
func enable_attack():
	attack_area.monitoring = true

# Desativa hitbox do ataque
func disable_attack():
	attack_area.monitoring = false

func end_attack():
	disable_attack()
	attacking = false
	queued_attack = false
	last_attack_end = Time.get_ticks_msec() / 1000.0

func start_block():
	blocking = true
	block_started_at = Time.get_ticks_msec() / 1000.0
	if block_tween:
		block_tween.kill()
	# Só troca de mixer se o AnimationTree ainda não estiver ligado
	if not block_tree.active:
		# Vai ter que sempre desligar um pra ligar o outro
		anim.active = false
		block_tree.set("parameters/Upper/blend_amount", 0.0)
		block_tree.active = true
	block_tween = create_tween()
	block_tween.tween_property(block_tree, "parameters/Upper/blend_amount", 1.0, block_blend_time)

func end_block():
	if not blocking:
		return
	blocking = false
	if block_tween:
		block_tween.kill()
	block_tween = create_tween()
	# Leva o tronco de volta pra pose das pernas
	block_tween.tween_property(block_tree, "parameters/Upper/blend_amount", 0.0, block_blend_time)
	# Quando termina de abaixar, devolve o controle pro AnimationPlayer
	block_tween.tween_callback(finish_block)

func finish_block():
	if block_tween:
		block_tween.kill()
	blocking = false
	block_tree.active = false
	anim.active = true

func update_block(dir: Vector3, delta: float):
	var aim := camera_pivot.get_aim_direction(global_position)
	if aim != Vector3.ZERO:
		# Vetor pra ângulo
		var target_yaw := atan2(aim.x, aim.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, min(delta * turn_speed, 1.0))
	velocity.x = dir.x * speed * block_speed_factor
	velocity.z = dir.z * speed * block_speed_factor
	move_and_slide()

func update_block_locomotion(delta: float):
	# Direção do modelo
	var facing := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
	var right := Vector3(-facing.z, 0, facing.x)
	var max_speed := speed * block_speed_factor

	# Projeta a velocidade pra saber o quanto o player tá andando pra frente e pro lado, e normaliza pelo max_speed
	var target := Vector2(velocity.dot(right), velocity.dot(facing)) / max_speed
	locomotion_blend = locomotion_blend.lerp(target, min(delta * locomotion_smoothing, 1.0))
	# Manda o ponto pro blend das pernas
	block_tree.set("parameters/Locomotion/blend_position", locomotion_blend)

func is_blocking_from(source: Node3D) -> bool:
	if not blocking or Time.get_ticks_msec() / 1000.0 - block_started_at < block_start_time:
		return false
	# Vetor do player até quem atacou
	var to_source := source.global_position - global_position
	# Tive que tirar a altura mas no futuro vai ter solução melhor
	to_source.y = 0
	var facing := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
	# Produto escalar pra saber se o ângulo do ataque tá dentro do ângulo de bloqueio
	return facing.dot(to_source.normalized()) >= cos(deg_to_rad(block_angle))

func block_hit():
	block_tree.set("parameters/BlockHit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func consume_buffered_attack() -> bool:
	if Time.get_ticks_msec() / 1000.0 - attack_pressed_at <= attack_buffer_time:
		attack_pressed_at = -100.0
		return true
	return false

func next_combo_index() -> int:
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_attack_end <= combo_reset_time and combo_index < combo.size() - 1:
		return combo_index + 1
	return 0

# Método de ataque
func attack(index: int, dir: Vector3):
	combo_index = index
	queued_attack = false
	attacking = true
	attack_elapsed = 0.0
	enemies_hit.clear()
	disable_attack()
	velocity = Vector3.ZERO
	var aim := camera_pivot.get_aim_direction(global_position)
	if aim != Vector3.ZERO:
		model.rotation.y = atan2(aim.x, aim.z)
	elif dir != Vector3.ZERO:
		model.rotation.y = atan2(dir.x, dir.z)
	var data: AttackData = combo[index]
	var blend := attack_blend_time if index == 0 else chain_blend_time
	if data.reverse:
		var end_time := anim.get_animation(data.animation).length - data.start_time
		anim.play_section(data.animation, 0.0, end_time, blend, -data.speed, true)
	else:
		anim.play_section(data.animation, data.start_time, -1.0, blend, data.speed)

func update_attack(dir: Vector3, delta: float):
	var current: AttackData = combo[combo_index]
	if not anim.is_playing() or anim.current_animation != current.animation:
		end_attack()
		return

	attack_elapsed += delta * current.speed
	var t := attack_elapsed
	if t >= current.hit_start and t <= current.hit_end:
		enable_attack()
		for body in attack_area.get_overlapping_bodies():
			_on_attack_area_body_entered(body)
	else:
		disable_attack()

	if t < current.chain_end and combo_index < combo.size() - 1 and consume_buffered_attack():
		queued_attack = true

	if queued_attack and t >= current.chain_start:
		attack(combo_index + 1, dir)
	elif dir != Vector3.ZERO and not queued_attack and t >= current.cancel_start:
		end_attack()

# Algum corpo entrou na area de ataque do player
func _on_attack_area_body_entered(body: Node3D) -> void:
	if not body.has_method("take_damage"):
		return
		
	if body in enemies_hit:
		return
		
	enemies_hit.append(body)
	body.take_damage(combo[combo_index].damage)
	
# Teleporta o player para o próximo portal
func teleport_to(pos: Vector3):
	portal_cooldown = true
	set_deferred("global_position", pos)
	velocity = Vector3.ZERO
	await get_tree().create_timer(0.2).timeout
	portal_cooldown = false

func _physics_process(delta):
	if dying:
		return

	if Input.is_action_just_pressed("attack"):
		attack_pressed_at = Time.get_ticks_msec() / 1000.0
	
	# Movimento relativo à câmera orbital
	var input_x := Input.get_axis("move_left", "move_right")
	var input_z := Input.get_axis("move_back", "move_forward")
	var dir: Vector3 = camera_pivot.get_right() * input_x + camera_pivot.get_forward() * input_z

	if attacking:
		update_attack(dir.normalized(), delta)
		return
	
	# Registra tile percorrido caso seja diferente do último da lista
	var current_tile = Vector3i(roundi(global_position.x), 0, roundi(global_position.z))
	if current_tile != last_tile:
		walked_tiles.append(current_tile)
		last_tile = current_tile

	if not combo.is_empty() and consume_buffered_attack():
		# Atacar solta o escudo
		finish_block()
		attack(next_combo_index(), dir.normalized())
		return

	if block_enabled and Input.is_action_pressed("block"):
		if not blocking:
			start_block()
		update_block(dir.normalized(), delta)
		update_block_locomotion(delta)
		return
	elif blocking:
		end_block()

	if dir != Vector3.ZERO:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed

		if anim.current_animation != "walk":
			anim.play("walk")

		# Gira só o modelo, para a câmera não girar junto
		# Pra girar suavemente preciso transformar um vetor em um ângulo, e encontrei essa função que faz isso usando só os eixos X e Z
		var target_yaw := atan2(dir.x, dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, min(delta * turn_speed, 1.0))
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

		if anim.current_animation != "idle":
			anim.play("idle")

	move_and_slide()

	# Enquanto o escudo abaixa o AnimationTree ainda está ligado, então as pernas continuam acompanhando o movimento
	if block_tree.active:
		update_block_locomotion(delta)
