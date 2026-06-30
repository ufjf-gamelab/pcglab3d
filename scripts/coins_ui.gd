extends HBoxContainer

@onready var label: Label = $Label

func update_coin_count(value):
	label.text = str(value)
