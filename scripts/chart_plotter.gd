extends Control

@onready var chart: Chart = $VBoxContainer/Chart
@onready var next_button: Button = $VBoxContainer/HBoxContainer/Next

signal close_button_pressed

var f: Function

var cp: ChartProperties
var x: Array
var y: Array
var rooms_x_values: Array
var rooms_y_values: Array
var chart_pos

func _togle_chart():
	if visible == true:
		visible = false
	else:
		visible = true

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
	cp.y_scale = 10
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

	visible = false

func show_charts(x_values, y_values):
	_togle_chart()
	rooms_x_values = x_values
	rooms_y_values = y_values

	show_chart(rooms_x_values[chart_pos], rooms_y_values[chart_pos], false)

func get_max_abs_from_array(y) -> int:
	var y_max = 0
	for i in range(y.size()):
		if (abs(y[i]) > y_max):
			y_max = abs(y[i])
	return y_max
	
func show_chart(x_val, y_val, external_call: bool):
	if external_call:
		_togle_chart()
		next_button.visible = false

	x = x_val
	y = y_val
	
	print(chart.y_domain)
	var max_y := get_max_abs_from_array(y)
	chart.set_y_domain(-max_y-1, max_y+1)
	print(chart.y_domain, "\n")
	
	chart.y_
	
	chart.y_labels_function = func(value):
		if value == int(value):
			return str(value)
		return ""
	
	if f.__x.size() > 0:
		for i in range(f.__x.size()):
			f.pop_front_point()

	for i in range(x.size()):
		f.add_point(x[i], y[i])

	chart.queue_redraw()

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
