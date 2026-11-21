extends CharacterBody3D
class_name Player

@export var speed := 2.5

# Tempo de transição das animações
@export var anim_blend_time := 0.15
@export var attack_buffer_time := 0.2
@export var locomotion_smoothing := 8.0
# Velocidade que o modelo gira
@export var turn_speed := 15.0

@onready var anim: AnimationPlayer = $"Animation Player"
# Vou precisar de uma só pra misturar as pernas com o tronco
@onready var block_tree: AnimationTree = $Block
@onready var model: Node3D = $Model
@onready var camera: IsometricCamera = $Camera
@onready var health: Health = $Health
@onready var darkness: Darkness = $Darkness
@onready var equipment: Equipment = $Equipment
@onready var state_machine: StateMachine = $"State Machine"

var walked_tiles: Array[Vector3i] = []
var last_tile: Vector3i = Vector3i(-9999, -9999, -9999)

var portal_cooldown := false

var attack_pressed_at := -100.0

func _ready():
	anim.playback_default_blend_time = anim_blend_time
	anim.play("idle")
	health.died.connect(_on_died)

func is_dead() -> bool:
	return health.life <= 0

# Recebe dano
func take_damage(amount, source: Node3D = null):
	if source and equipment.try_block(source):
		return
	health.take_damage(amount)

func _on_died():
	state_machine.transition_to("Dead")

func _unhandled_input(event):
	if is_dead() or not state_machine.state.can_swap_item():
		return
	if event.is_action_pressed("swap_item"):
		equipment.swap_off_hand()
		state_machine.transition_to("Move")

func get_move_direction() -> Vector3:
	# Movimento relativo à câmera orbital
	var input_x := Input.get_axis("move_left", "move_right")
	var input_z := Input.get_axis("move_back", "move_forward")
	return camera.get_right() * input_x + camera.get_forward() * input_z

func face_aim(dir: Vector3):
	var aim := camera.get_aim_direction(global_position)
	if aim != Vector3.ZERO:
		model.rotation.y = atan2(aim.x, aim.z)
	elif dir != Vector3.ZERO:
		model.rotation.y = atan2(dir.x, dir.z)

func record_tile():
	# Registra tile percorrido caso seja diferente do último da lista
	var current_tile = Vector3i(roundi(global_position.x), 0, roundi(global_position.z))
	if current_tile != last_tile:
		walked_tiles.append(current_tile)
		last_tile = current_tile

func consume_buffered_attack() -> bool:
	if Time.get_ticks_msec() / 1000.0 - attack_pressed_at <= attack_buffer_time:
		attack_pressed_at = -100.0
		return true
	return false

# Teleporta o player para o próximo portal
func teleport_to(pos: Vector3):
	portal_cooldown = true
	set_deferred("global_position", pos)
	velocity = Vector3.ZERO
	await get_tree().create_timer(0.2).timeout
	portal_cooldown = false

func _physics_process(delta):
	if is_dead():
		return

	if Input.is_action_just_pressed("attack"):
		attack_pressed_at = Time.get_ticks_msec() / 1000.0

	state_machine.physics_update(delta)
