extends Control
class_name LineChart
# Baseado quase completamente no addon EasyCharts

@export var x_label := "Tile"
@export var y_label := "Influência"
@export var line_color := Color("#36a2eb")
@export var grid_color := Color(1, 1, 1, 0.08)
@export var axis_color := Color(1, 1, 1, 0.35)
@export var text_color := Color(1, 1, 1, 0.75)
@export var font_size := 13

const PAD_LEFT := 56.0
const PAD_RIGHT := 14.0
const PAD_TOP := 10.0
const PAD_BOTTOM := 40.0
const Y_TICKS := 4

var _xs: Array = []
var _ys: Array = []
var _y_min := 0.0
var _y_max := 1.0
var _x_max := 1.0
var _hover := -1

func _ready():
	mouse_exited.connect(func(): _set_hover(-1))

func set_data(xs: Array, ys: Array, y_min: float, y_max: float):
	_xs = xs
	_ys = ys
	_y_min = y_min
	_y_max = y_max if y_max > y_min else y_min + 1.0
	_x_max = max(1.0, float(xs.back())) if not xs.is_empty() else 1.0
	_hover = -1
	queue_redraw()

func _plot_rect() -> Rect2:
	return Rect2(PAD_LEFT, PAD_TOP, size.x - PAD_LEFT - PAD_RIGHT, size.y - PAD_TOP - PAD_BOTTOM)

func _to_screen(x: float, y: float) -> Vector2:
	var r := _plot_rect()
	var px := r.position.x + x / _x_max * r.size.x
	var py := r.end.y - (y - _y_min) / (_y_max - _y_min) * r.size.y
	return Vector2(px, py)

func _draw():
	var font := get_theme_default_font()
	var r := _plot_rect()

	for i in range(Y_TICKS + 1):
		var value := lerpf(_y_min, _y_max, float(i) / Y_TICKS)
		var y := _to_screen(0, value).y
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), grid_color)
		var text := _format(value)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(r.position.x - w - 8, y + font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

	var step := maxi(1, ceili(_x_max / 10.0))
	var tile := 0
	while tile <= _x_max:
		var x := _to_screen(tile, 0).x
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), grid_color)
		var text := str(tile)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(x - w / 2, r.end.y + font_size + 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
		tile += step

	draw_line(r.position, Vector2(r.position.x, r.end.y), axis_color)
	draw_line(Vector2(r.position.x, r.end.y), r.end, axis_color)
	if _y_min < 0.0 and _y_max > 0.0:
		var zero_y := _to_screen(0, 0).y
		draw_line(Vector2(r.position.x, zero_y), Vector2(r.end.x, zero_y), axis_color, 1.5)

	var xl_w := font.get_string_size(x_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(r.get_center().x - xl_w / 2, size.y - 4), x_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	draw_set_transform(Vector2(14, r.get_center().y), -PI / 2)
	var yl_w := font.get_string_size(y_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(-yl_w / 2, 0), y_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	draw_set_transform(Vector2.ZERO)

	if _xs.is_empty():
		return

	var points := PackedVector2Array()
	for i in range(_xs.size()):
		points.append(_to_screen(_xs[i], _ys[i]))
	if points.size() > 1:
		draw_polyline(points, line_color, 2.0, true)
	for p in points:
		draw_circle(p, 3.0, line_color)

	if _hover >= 0:
		var p := points[_hover]
		draw_line(Vector2(p.x, r.position.y), Vector2(p.x, r.end.y), axis_color)
		draw_circle(p, 5.5, Color.WHITE)
		draw_circle(p, 4.0, line_color)
		var label := "tile %d: %s" % [int(_xs[_hover]), _format(_ys[_hover])]
		var ls := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var box := Rect2(p + Vector2(8, -ls.y - 14), ls + Vector2(12, 8))
		if box.end.x > size.x:
			box.position.x = p.x - box.size.x - 8
		if box.position.y < 0:
			box.position.y = p.y + 8
		draw_rect(box, Color(0, 0, 0, 0.8))
		draw_string(font, box.position + Vector2(6, ls.y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _gui_input(event):
	if event is InputEventMouseMotion and not _xs.is_empty():
		var best := -1
		var best_dist := INF
		for i in range(_xs.size()):
			var d := absf(_to_screen(_xs[i], _ys[i]).x - event.position.x)
			if d < best_dist:
				best_dist = d
				best = i
		_set_hover(best if _plot_rect().grow(8).has_point(event.position) else -1)

func _set_hover(index: int):
	if index != _hover:
		_hover = index
		queue_redraw()

func _format(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return String.num(value, 2)
