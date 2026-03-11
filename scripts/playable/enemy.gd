extends CharacterBody3D

@export var max_life := 2
var life := max_life

@onready var anim: AnimationPlayer = $Model/AnimationPlayer

var die := false

func _process(_delta: float) -> void:
	if not die:
		anim.play("idle")

# Recebe dano
func take_damage(amount):
	life -= amount
	print("Vida:", life)

	if life <= 0:
		die = true
		on_die()

# Faz a animação de morte e remove do mapa
func on_die():
	anim.play("die")
	await anim.animation_finished
	queue_free()
