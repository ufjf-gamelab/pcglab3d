extends PlayerState

func enter(msg := {}):
	# Atacar solta o escudo
	player.equipment.interrupt_off_hand()
	var sword: Sword = player.equipment.main_hand
	sword.attack(sword.next_combo_index(), msg.get("dir", Vector3.ZERO))

func physics_update(delta: float):
	var sword: Sword = player.equipment.main_hand
	sword.update_attack(player.get_move_direction().normalized(), delta)
	if not sword.attacking:
		machine.transition_to("Move")

func can_swap_item() -> bool:
	return false
