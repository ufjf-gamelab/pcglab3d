extends PlayerState

# Faz a animação de morte e remove do mapa
func enter(_msg := {}):
	player.equipment.interrupt_all()
	player.anim.play("die")
	await player.anim.animation_finished
	await get_tree().create_timer(2).timeout
	player.queue_free()

func can_swap_item() -> bool:
	return false
