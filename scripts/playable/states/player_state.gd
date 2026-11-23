extends Node
class_name PlayerState

var player: Player
var machine: StateMachine

func enter(_msg := {}):
	pass

func exit():
	pass

func physics_update(_delta: float):
	pass

func can_swap_item() -> bool:
	return true
