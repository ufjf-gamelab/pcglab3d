extends Item
class_name Sword

# Tempo de transição das animações de ataque pra não ficar muito lento
@export var attack_blend_time := 0.05
@export var chain_blend_time := 0.12
@export var combo_reset_time := 0.6
@export var combo: Array[AttackData] = []

@onready var attack_area: Area3D = $AttackArea

var attacking := false
var enemies_hit := []
var combo_index := 0
var queued_attack := false
var last_attack_end := -100.0
var attack_elapsed := 0.0

func _ready():
	attack_area.monitoring = false

	# Conecta sinais às funções
	attack_area.body_entered.connect(_on_attack_area_body_entered)

func can_attack() -> bool:
	return not combo.is_empty()

func interrupt():
	end_attack()

# Ativa hitbox do ataque
func enable_attack():
	attack_area.monitoring = true

# Desativa hitbox do ataque
func disable_attack():
	attack_area.monitoring = false

func end_attack():
	disable_attack()
	attacking = false
	queued_attack = false
	last_attack_end = Time.get_ticks_msec() / 1000.0

func next_combo_index() -> int:
	# Se atacar logo depois de terminar um golpe continua o combo
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_attack_end <= combo_reset_time and combo_index < combo.size() - 1:
		return combo_index + 1
	return 0

# Método de ataque
func attack(index: int, dir: Vector3):
	combo_index = index
	queued_attack = false
	attacking = true
	attack_elapsed = 0.0
	enemies_hit.clear()
	disable_attack()
	player.velocity = Vector3.ZERO
	player.face_aim(dir)
	var data: AttackData = combo[index]
	var blend := attack_blend_time if index == 0 else chain_blend_time
	var anim := player.anim
	if data.reverse:
		var end_time := anim.get_animation(data.animation).length - data.start_time
		anim.play_section(data.animation, 0.0, end_time, blend, -data.speed, true)
	else:
		anim.play_section(data.animation, data.start_time, -1.0, blend, data.speed)

func update_attack(dir: Vector3, delta: float):
	var current: AttackData = combo[combo_index]
	var anim := player.anim
	if not anim.is_playing() or anim.current_animation != current.animation:
		end_attack()
		return

	attack_elapsed += delta * current.speed
	var t := attack_elapsed
	if t >= current.hit_start and t <= current.hit_end:
		enable_attack()
		# Quem tava dentro já não é pego, então tenho que checar sempre
		for body in attack_area.get_overlapping_bodies():
			_on_attack_area_body_entered(body)
	else:
		disable_attack()

	# Bufferzinho
	if t < current.chain_end and combo_index < combo.size() - 1 and player.consume_buffered_attack():
		queued_attack = true

	if queued_attack and t >= current.chain_start:
		attack(combo_index + 1, dir)
	elif dir != Vector3.ZERO and not queued_attack and t >= current.cancel_start:
		end_attack()

# Algum corpo entrou na area de ataque do player
func _on_attack_area_body_entered(body: Node3D) -> void:
	if not body.has_method("take_damage"):
		return
		
	if body in enemies_hit:
		return
		
	enemies_hit.append(body)
	body.take_damage(combo[combo_index].damage)
