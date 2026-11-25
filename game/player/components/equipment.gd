extends Node
class_name Equipment

@export var main_hand_scene: PackedScene
@export var off_hand_scenes: Array[PackedScene] = []
@export var main_hand_slot: Node3D
@export var off_hand_slot: Node3D
@export var back_slot: Node3D
@export var arm_pose: SkeletonModifier3D

@onready var player: Player = owner

var main_hand: Item
var off_hand: Item
var off_hand_items: Array[Item] = []
var off_hand_index := 0

func _ready():
	if main_hand_scene:
		main_hand = create_item(main_hand_scene)
		main_hand.hold(main_hand_slot)
	for scene in off_hand_scenes:
		var item := create_item(scene)
		off_hand_items.append(item)
		stow(item)
	equip_off_hand(0)

func create_item(scene: PackedScene) -> Item:
	var item: Item = scene.instantiate()
	item.player = player
	return item

func stow(item: Item):
	item.stow(back_slot if item.stow_slot == Item.StowSlot.BACK else off_hand_slot)

func equip_off_hand(index: int):
	if off_hand_items.is_empty():
		return
	# Guarda o que tava na mão antes de pegar o próximo
	if off_hand:
		off_hand.interrupt()
		stow(off_hand)
	off_hand_index = index
	off_hand = off_hand_items[index]
	off_hand.hold(off_hand_slot)
	arm_pose.active = off_hand.use_arm_pose

func swap_off_hand():
	equip_off_hand((off_hand_index + 1) % off_hand_items.size())

func all_items() -> Array[Item]:
	var items: Array[Item] = []
	if main_hand:
		items.append(main_hand)
	items.append_array(off_hand_items)
	return items

# Atualmente só a UI usa pra achar a tocha
func find_item(type: Script) -> Item:
	for item in all_items():
		if is_instance_of(item, type):
			return item
	return null

func interrupt_off_hand():
	for item in off_hand_items:
		item.interrupt()

func interrupt_all():
	for item in all_items():
		item.interrupt()

func try_block(source: Node3D) -> bool:
	return off_hand != null and off_hand.held and off_hand.try_block(source)

func is_emitting_light() -> bool:
	for item in all_items():
		if item.is_emitting_light():
			return true
	return false

func refill():
	for item in all_items():
		item.refill()
