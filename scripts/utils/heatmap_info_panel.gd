extends PanelContainer
class_name HeatmapInfoPanel

@onready var title_label: Label = $VBoxContainer/Title
@onready var subtitle_label: Label = $VBoxContainer/Subtitle

func _ready():
	visible = false

func show_heatmap_info(title: String, influences: Dictionary):
	title_label.text = title
	subtitle_label.text = _format_influences(influences)
	visible = true

func clear():
	visible = false

func _format_influences(influences: Dictionary) -> String:
	var parts := []

	for key in influences.keys():
		parts.append("%s: %s" % [key, influences[key]])

	return "\n ".join(parts)
