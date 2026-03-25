extends HBoxContainer

@onready var label: Label = $Label

func update_coin_count():
	label.text = str(int(label.text) + 1)
