extends PlayerState

func enter(_msg := {}):
	var shield: Shield = player.equipment.off_hand
	if not shield.blocking:
		shield.start_block()

func physics_update(delta: float):
	var shield: Shield = player.equipment.off_hand
	var dir := player.get_move_direction().normalized()
	player.record_tile()

	var weapon := player.equipment.main_hand
	if weapon and weapon.can_attack() and player.consume_buffered_attack():
		if shield.blocking and Input.is_action_pressed("block"):
			machine.transition_to("Bash", {"dir": dir})
			return
		machine.transition_to("Attack", {"dir": dir})
		return

	if Input.is_action_pressed("block"):
		shield.update_block(dir, delta)
		shield.update_block_locomotion(delta)
		return

	# Forço um update quando para o block, pro buffer ser de ataque, não de bash
	shield.end_block()
	machine.transition_to("Move")
	machine.physics_update(delta)
