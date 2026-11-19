extends Node3D
class_name Item

enum StowSlot { HIDDEN, BACK }

@export var hold_transform := Transform3D.IDENTITY
@export var stow_slot := StowSlot.HIDDEN
@export var stow_transform := Transform3D.IDENTITY
@export var use_arm_pose := false

var player: Player
var held := false

func hold(slot: Node3D):
	held = true
	visible = true
	attach(slot, hold_transform)

func stow(slot: Node3D):
	held = false
	visible = stow_slot != StowSlot.HIDDEN
	attach(slot, stow_transform if visible else transform)

func attach(slot: Node3D, slot_transform: Transform3D):
	# Na primeira vez o item ainda não tá na árvore, então só adiciona
	# Depois disso só troca de pai, sem manter o transform global
	if get_parent() == null:
		slot.add_child(self)
	elif get_parent() != slot:
		reparent(slot, false)
	transform = slot_transform

# Daqui pra baixo são as funções que cada item sobrescreve se precisar, o padrão é não fazer nada
func interrupt():
	pass

func can_attack() -> bool:
	return false

func can_block() -> bool:
	return false

func try_block(_source: Node3D) -> bool:
	return false

func is_emitting_light() -> bool:
	return false

func refill():
	pass
