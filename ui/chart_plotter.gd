extends Control

@onready var chart: LineChart = %LineChart
@onready var room_label: Label = %Room
@onready var heatmap_label: Label = %Heatmap
@onready var seed_label: Label = %Seed
@onready var close_button: Button = %Close
@onready var previous_button: Button = %Previous
@onready var next_button: Button = %Next
@onready var download_button: Button = %Download

signal close_button_pressed
signal room_changed(room: int)

var current_seed: int = 0

var rooms: Array = []

var x: Array
var y: Array
var rooms_x_values: Array
var rooms_y_values: Array
var chart_pos
var scale_y

const HEATMAP_NAMES = {
	UHeat.ENEMIES: "inimigos",
	UHeat.COINS: "moedas",
	UHeat.BANNERS: "estandartes",
	UHeat.PORTALS: "portais",
}

const HEATMAP_LABELS = {
	UHeat.ENEMIES: "Inimigos",
	UHeat.COINS: "Moedas",
	UHeat.BANNERS: "Fogueiras",
	UHeat.PORTALS: "Portais",
}

func _ready():
	x = []
	y = []
	rooms_x_values = []
	rooms_y_values = []
	chart_pos = 0

	visible = false
	
	close_button.pressed.connect(_on_close_pressed)
	previous_button.pressed.connect(_on_previous_pressed)
	next_button.pressed.connect(_on_next_pressed)
	download_button.pressed.connect(_on_download_pressed)
	for button in [close_button, previous_button, next_button, download_button]:
		button.focus_mode = Control.FOCUS_NONE

func _get_heatmap_name() -> String:
	return "_".join(PackedStringArray(UHeat.visible_layers.map(func(layer): return HEATMAP_NAMES[layer])))

func _on_download_pressed():
	var heatmap_name = _get_heatmap_name()
	_save_csv_all(rooms_x_values, rooms_y_values, "todas_salas_influ_%s" % heatmap_name)

func _save_csv_all(x_values: Array, y_values: Array, filename: String):
	var folder = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/pcglab3d/seed_%d" % current_seed
	# Cria a pasta se não existir
	if not DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_absolute(folder)
	
	var path = folder + "/%s.csv" % filename
	var file = FileAccess.open(path, FileAccess.WRITE)
	
	if file == null:
		return
	
	file.store_line("sala,tile,influencia")
	for i in range(x_values.size()):
		for j in range(x_values[i].size()):
			file.store_line("%d,%s,%s" % [i, x_values[i][j], y_values[i][j]])
	file.close()

func _get_global_max(arrays):
	var global_max_val = -10000
	for array in arrays:
		var local_max = get_max_abs_from_array(array)
		if local_max > global_max_val:
			global_max_val = local_max
	return global_max_val

func show_charts(x_values, y_values, room_indexes):
	visible = true
	rooms = room_indexes
	chart_pos = mini(chart_pos, rooms.size() - 1)
	rooms_x_values = x_values
	rooms_y_values = y_values
	
	scale_y = _get_global_max(rooms_y_values)

	show_chart(rooms_x_values[chart_pos], rooms_y_values[chart_pos])

func show_room(room: int):
	var pos := rooms.find(room)
	if pos == -1:
		return
	chart_pos = pos
	show_chart(rooms_x_values[chart_pos], rooms_y_values[chart_pos])

func get_max_abs_from_array(array) -> float:
	var max_val := 0.0

	for value in array:
		max_val = max(max_val, abs(value))

	return max_val

func _has_only_positive_influence() -> bool:
	return not UHeat.is_bipolar(UHeat.visible_layers)

func _chart_y_domain(value: float) -> Vector2:
	if _has_only_positive_influence():
		return Vector2(0, value)
	return Vector2(-value, value)

func show_chart(x_val, y_val):
	x = x_val
	y = y_val
	var nice_max = _get_nice_max(scale_y)
	
	var domain := _chart_y_domain(nice_max)
	chart.set_data(x, y, domain.x, domain.y)
	room_label.text = "Sala %d de %d" % [rooms[chart_pos] + 1, UGen.rooms.size()]
	heatmap_label.text = " + ".join(PackedStringArray(UHeat.visible_layers.map(func(layer): return HEATMAP_LABELS[layer])))
	heatmap_label.visible = not UHeat.visible_layers.is_empty()
	chart.visible = heatmap_label.visible
	%Empty.visible = not heatmap_label.visible
	download_button.disabled = not heatmap_label.visible
	seed_label.text = "seed %d" % current_seed

func _get_nice_max(value: float) -> float:
	if value <= 0:
		return 1.0

	var magnitude = pow(10.0, floor(log(value) / log(10.0)))
	var normalized = value / magnitude

	if normalized <= 1.0:
		return 1.0 * magnitude
	elif normalized <= 2.0:
		return 2.0 * magnitude
	elif normalized <= 5.0:
		return 5.0 * magnitude
	else:
		return 10.0 * magnitude

func _on_close_pressed() -> void:
	visible = false
	chart_pos = 0
	rooms_x_values = []
	rooms_y_values = []
	x = []
	y = []
	close_button_pressed.emit()

func _on_next_pressed() -> void:
	if chart_pos == rooms_x_values.size() - 1:
		chart_pos = 0
	else:
		chart_pos += 1
	
	show_chart(rooms_x_values[chart_pos], rooms_y_values[chart_pos])
	room_changed.emit(rooms[chart_pos])

func _on_previous_pressed() -> void:
	chart_pos = wrapi(chart_pos - 1, 0, rooms_x_values.size())
	show_chart(rooms_x_values[chart_pos], rooms_y_values[chart_pos])
	room_changed.emit(rooms[chart_pos])
