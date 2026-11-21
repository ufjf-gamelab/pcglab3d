extends PlayerState

func enter(msg := {}):
	var shield: Shield = player.equipment.off_hand
	shield.shield_bash(msg.get("dir", Vector3.ZERO))

func physics_update(delta: float):
	var shield: Shield = player.equipment.off_hand
	shield.update_bash(delta)
	# Sempre passa pro block porque ele que é esperto o suficiente pra saber o que fazer agora
	if not shield.bashing:
		machine.transition_to("Block")
		return
	if shield.can_cancel_bash() and not Input.is_action_pressed("block") and player.consume_buffered_attack():
		machine.transition_to("Attack", {"dir": player.get_move_direction().normalized()})

func can_swap_item() -> bool:
	return false
