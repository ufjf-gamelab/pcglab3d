extends HBoxContainer

@onready var hearts = get_children()

func update_hearts(curr_life):
	for i in range(hearts.size()):
		hearts[i].visible = i < curr_life
