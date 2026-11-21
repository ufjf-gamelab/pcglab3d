extends Item
class_name Shield

@export var block_speed_factor := 0.4
@export var block_start_time := 0.15
@export var block_angle := 70.0
@export var block_blend_time := 0.15
@export var block_knockback := 0.6
@export var bash_speed := 1.5
@export var bash_hit_time := 0.25
@export var bash_range := 1.0
@export var bash_angle := 70.0
@export var bash_knockback := 2.5
@export var bash_cancel_time := 0.5

var blocking := false
var block_started_at := 0.0
var block_tween: Tween
var block_stun := 0.0
var block_push := Vector3.ZERO
var bashing := false
var bash_elapsed := 0.0
var bash_done := false
var locomotion_blend := Vector2.ZERO

func _physics_process(delta):
	# Enquanto o escudo abaixa o AnimationTree ainda está ligado, então as pernas continuam acompanhando o movimento
	if not blocking and not bashing and player.block_tree.active:
		update_block_locomotion(delta)

func can_block() -> bool:
	return true

func try_block(source: Node3D) -> bool:
	if not is_blocking_from(source):
		return false
	block_hit(source)
	return true

func interrupt():
	if bashing:
		bashing = false
		player.block_tree.set("parameters/Bash/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	finish_block()

func start_block():
	blocking = true
	block_started_at = Time.get_ticks_msec() / 1000.0
	if block_tween:
		block_tween.kill()
	var block_tree := player.block_tree
	# Só troca de mixer se o AnimationTree ainda não estiver ligado
	if not block_tree.active:
		# Vai ter que sempre desligar um pra ligar o outro
		player.anim.active = false
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
	block_tween.tween_property(player.block_tree, "parameters/Upper/blend_amount", 0.0, block_blend_time)
	# Quando termina de abaixar, devolve o controle pro AnimationPlayer
	block_tween.tween_callback(finish_block)

func finish_block():
	if block_tween:
		block_tween.kill()
	blocking = false
	player.block_tree.active = false
	player.anim.active = true

func update_block(dir: Vector3, delta: float):
	var model := player.model
	var aim := player.camera.get_aim_direction(player.global_position)
	if aim != Vector3.ZERO:
		# Vetor pra ângulo
		var target_yaw := atan2(aim.x, aim.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, min(delta * player.turn_speed, 1.0))
	if block_stun > 0.0:
		block_stun -= delta
		dir = Vector3.ZERO
	player.velocity.x = dir.x * player.speed * block_speed_factor + block_push.x
	player.velocity.z = dir.z * player.speed * block_speed_factor + block_push.z
	block_push = block_push.move_toward(Vector3.ZERO, block_knockback * 4 * delta)
	player.move_and_slide()

func update_block_locomotion(delta: float):
	var model := player.model
	# Direção do modelo
	var facing := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
	var right := Vector3(-facing.z, 0, facing.x)
	var max_speed := player.speed * block_speed_factor

	# Projeta a velocidade pra saber o quanto o player tá andando pra frente e pro lado, e normaliza pelo max_speed
	var target := Vector2(player.velocity.dot(right), player.velocity.dot(facing)) / max_speed
	locomotion_blend = locomotion_blend.lerp(target, min(delta * player.locomotion_smoothing, 1.0))
	# Manda o ponto pro blend das pernas
	player.block_tree.set("parameters/Locomotion/blend_position", locomotion_blend)

func is_blocking_from(source: Node3D) -> bool:
	if not blocking or Time.get_ticks_msec() / 1000.0 - block_started_at < block_start_time:
		return false
	var model := player.model
	# Vetor do player até quem atacou
	var to_source := source.global_position - player.global_position
	# Tive que tirar a altura mas no futuro vai ter solução melhor
	to_source.y = 0
	var facing := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
	# Produto escalar pra saber se o ângulo do ataque tá dentro do ângulo de bloqueio
	return facing.dot(to_source.normalized()) >= cos(deg_to_rad(block_angle))

func block_hit(source: Node3D):
	# Fica travado o tempo da animação de block hit
	block_stun = player.anim.get_animation("block-hit").length
	var away := player.global_position - source.global_position
	away.y = 0
	block_push = away.normalized() * block_knockback
	player.block_tree.set("parameters/BlockHit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func shield_bash(dir: Vector3):
	bashing = true
	bash_elapsed = 0.0
	bash_done = false
	player.velocity = Vector3.ZERO
	player.face_aim(dir)
	player.block_tree.set("parameters/BashSpeed/scale", bash_speed)
	player.block_tree.set("parameters/Bash/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func update_bash(delta: float):
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	update_block_locomotion(delta)
	bash_elapsed += delta * bash_speed
	if not bash_done and bash_elapsed >= bash_hit_time:
		bash_done = true
		for enemy in get_tree().get_nodes_in_group("Enemies"):
			if is_in_bash_range(enemy):
				enemy.stagger(bash_knockback)
	if bash_elapsed >= player.anim.get_animation("block-attack").length:
		bashing = false

func can_cancel_bash() -> bool:
	# Depois do impacto dá pra cancelar o resto da animação num ataque
	return bash_done and bash_elapsed >= bash_cancel_time

func is_in_bash_range(target: Node3D) -> bool:
	var model := player.model
	var to_target := target.global_position - player.global_position
	to_target.y = 0
	if to_target.length() > bash_range:
		return false
	# 
	var facing := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
	return facing.dot(to_target.normalized()) >= cos(deg_to_rad(bash_angle))
