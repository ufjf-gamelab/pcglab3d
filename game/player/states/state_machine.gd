extends Node
class_name StateMachine

@export var initial_state: PlayerState

var state: PlayerState

func _ready():
	for child in get_children():
		child.player = owner
		child.machine = self
	state = initial_state

func transition_to(state_name: StringName, msg := {}):
	# O msg é um jeito de passar de forma genérica qualquer coisa importante, aprendi no GDQuest
	state.exit()
	state = get_node(NodePath(state_name))
	state.enter(msg)

func physics_update(delta: float):
	state.physics_update(delta)
