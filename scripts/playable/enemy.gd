extends CharacterBody3D

@export var max_life := 2
var life := max_life

@onready var anim: AnimationPlayer = $Model/AnimationPlayer

func _process(_delta: float) -> void:
	anim.play("idle")

# Recebe dano
func take_damage(amount):
	life -= amount
	print("Vida:", life)

	if life <= 0:
		die()

# Faz a animação de morte e remove do mapa
func die():
	anim.play("die")
	await anim.animation_finished
	queue_free()
