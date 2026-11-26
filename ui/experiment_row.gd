extends Button

func setup(values: Array):
	for i in values.size():
		$HBox.get_child(i).text = values[i]
