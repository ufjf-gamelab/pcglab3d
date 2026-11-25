extends PlayerState

func physics_update(delta: float):
	var dir := player.get_move_direction()
	player.record_tile()

	var weapon := player.equipment.main_hand
	if weapon and weapon.can_attack() and player.consume_buffered_attack():
		machine.transition_to("Attack", {"dir": dir.normalized()})
		return

	var off_hand := player.equipment.off_hand
	if off_hand and off_hand.can_block() and Input.is_action_pressed("block"):
		machine.transition_to("Block")
		# Tenho que forçar o update pra pegar na frame que eu clico
		machine.physics_update(delta)
		return

	var model := player.model
	var speed := player.speed
	if dir != Vector3.ZERO:
		dir = dir.normalized()
		player.velocity.x = dir.x * speed
		player.velocity.z = dir.z * speed

		if player.anim.current_animation != "walk":
			player.anim.play("walk")

		# Gira só o modelo, para a câmera não girar junto
		# Pra girar suavemente preciso transformar um vetor em um ângulo, e encontrei essa função que faz isso usando só os eixos X e Z
		var target_yaw := atan2(dir.x, dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, min(delta * player.turn_speed, 1.0))
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, speed)
		player.velocity.z = move_toward(player.velocity.z, 0, speed)

		if player.anim.current_animation != "idle":
			player.anim.play("idle")

	player.move_and_slide()
