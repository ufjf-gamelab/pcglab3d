extends Control

@onready var chart: Chart = $VBoxContainer/Chart
@onready var next_button: Button = $VBoxContainer/HBoxContainer/Next
@onready var download_button: Button = $VBoxContainer/HBoxContainer/Download

signal close_button_pressed
signal next_button_pressed(chart_pos)

var current_seed: int = 0

var current_room_index: int = 0

var f: Function

var cp: ChartProperties
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
	UHeat.COMBINED: "combinado",
	UHeat.RECHARGES: "recargas"
}

const ONLY_POSITIVE_INFLUENCE_VALUES = {
	UHeat.ENEMIES: true,
	UHeat.COINS: true,
	UHeat.BANNERS: true,
	UHeat.COMBINED: false,
	UHeat.RECHARGES: true
}

func _ready():
	x = []
	y = []
	rooms_x_values = []
	rooms_y_values = []
	chart_pos = 0

	cp = ChartProperties.new()
	cp.colors.frame = Color("#161a1d")
	cp.colors.background = Color.TRANSPARENT
	cp.colors.grid = Color("#283442")
	cp.colors.ticks = Color("#283442")
	cp.colors.text = Color.WHITE_SMOKE
	cp.draw_bounding_box = false
	cp.title = "Valores de influência ao longo do caminho"
	cp.x_label = "Tile"
	cp.y_label = "Influência"
	cp.x_scale = 5
	cp.y_scale = 5
	cp.interactive = true

	f = Function.new(
		x, y, "Influência",
		{ 
			color = Color("#36a2eb"),
			marker = Function.Marker.CIRCLE,
			type = Function.Type.LINE,
			interpolation = Function.Interpolation.LINEAR
		}
	)
	
	chart.plot([f], cp)
	
	chart.x_labels_function = func(value):
		return str(int(round(value)))

	visible = false
	
	download_button.pressed.connect(_on_download_pressed)

func _get_heatmap_name() -> String:
	for key in UHeat.curr_visible_heatmap.keys():
		if UHeat.curr_visible_heatmap[key]:
			return HEATMAP_NAMES[key]
	return "desconhecido"

func _on_download_pressed():
	var heatmap_name = _get_heatmap_name()
	if rooms_x_values.is_empty():
		# Modo sala única (show_chart externo)
		_save_csv_single(x, y, "sala%d_influ_%s" % [current_room_index, heatmap_name])
	else:
		# Modo todas as salas (show_charts)
		_save_csv_all(rooms_x_values, rooms_y_values, "todas_salas_influ_%s" % heatmap_name)

func _save_csv_single(x_val: Array, y_val: Array, filename: String):
	var folder = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/pcglab3d/seed_%d" % current_seed

	print(y_val)

	# Cria a pasta se não existir
	if not DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_absolute(folder)
	
	var path = folder + "/%s.csv" % filename
	var file = FileAccess.open(path, FileAccess.WRITE)
	
	if file == null:
		print("Erro ao abrir arquivo: ", FileAccess.get_open_error())
		return
	
	file.store_line("tile,influencia")
	for i in range(x_val.size()):
		file.store_line("%s,%s" % [x_val[i], y_val[i]])
	file.close()
	print("CSV salvo em: ", ProjectSettings.globalize_path(path))

func _save_csv_all(x_values: Array, y_values: Array, filename: String):
	var folder = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/pcglab3d/seed_%d" % current_seed
	# Cria a pasta se não existir
	if not DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_absolute(folder)
	
	var path = folder + "/%s.csv" % filename
	var file = FileAccess.open(path, FileAccess.WRITE)
	
	if file == null:
		print("Erro ao abrir arquivo: ", FileAccess.get_open_error())
		return
	
	file.store_line("sala,tile,influencia")
	for i in range(x_values.size()):
		for j in range(x_values[i].size()):
			file.store_line("%d,%s,%s" % [i, x_values[i][j], y_values[i][j]])
	file.close()
	print("CSV salvo em: ", path)

func _togle_chart():
	if visible == true:
		visible = false
	else:
		visible = true

func _get_global_max(arrays):
	var global_max_val = -10000
	for array in arrays:
		var local_max = get_max_abs_from_array(array)
		if local_max > global_max_val:
			global_max_val = local_max
	return global_max_val

func show_charts(x_values, y_values):
	_togle_chart()
	rooms_x_values = x_values
	rooms_y_values = y_values
	
	scale_y = _get_global_max(rooms_y_values)

	show_chart(rooms_x_values[chart_pos], rooms_y_values[chart_pos], false)

func get_max_abs_from_array(array) -> float:
	var max_val := 0.0

	for value in array:
		max_val = max(max_val, abs(value))

	return max_val

func _has_only_positive_influence() -> bool:
	for key in UHeat.curr_visible_heatmap.keys():
		if UHeat.curr_visible_heatmap[key]:
			return ONLY_POSITIVE_INFLUENCE_VALUES[key]
	return false

func _define_chart_domain(value: float):
	if _has_only_positive_influence():
		chart.set_y_domain(0, value)
	else:
		chart.set_y_domain(-value, value)

func show_chart(x_val, y_val, external_call: bool):
	x = x_val
	y = y_val
	var nice_max
	
	if external_call:
		_togle_chart()
		next_button.visible = false
		
		var max_y := get_max_abs_from_array(y)
		nice_max = _get_nice_max(max_y)
	else:
		nice_max = _get_nice_max(scale_y)
	
	_define_chart_domain(nice_max)
	cp.y_scale = 8
	
	var max_x = x[x.size()-1]
	cp.x_scale = int(max_x/2)
	chart.set_x_domain(0, max_x)
	
	if f.__x.size() > 0:
		for i in range(f.__x.size()):
			f.pop_front_point()

	for i in range(x.size()):
		f.add_point(x[i], y[i])

	chart.queue_redraw()

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
	if next_button.visible == false:
		next_button.visible = true
	_togle_chart()
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
	
	show_chart(rooms_x_values[chart_pos], rooms_y_values[chart_pos], false)
	next_button_pressed.emit(chart_pos)
