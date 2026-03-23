extends PanelContainer
class_name HeatmapInfoPanel

@onready var title_label: Label = $VBoxContainer/Title
@onready var subtitle_label: Label = $VBoxContainer/Subtitle

func _ready():
	visible = false

func show_heatmap_info(title: String, influences: Dictionary):
	title_label.text = title
	subtitle_label.text = format_influences(influences, title)
	visible = true

func clear():
	visible = false

func format_influences(influences: Dictionary, title: String) -> String:
	var parts := []

	for key in influences.keys():
		parts.append("%s: %s" % [key, influences[key]])
	
	var positive_decay_func = UHeat.decay_func_types[UHeat.decay_func_type]["positive_influ_exibit"]
	var negative_decay_func = UHeat.decay_func_types[UHeat.decay_func_type]["negative_influ_exibit"]
	
	if title.contains("Inimigo"):
		parts.append("Função de Decaimento: %s" % negative_decay_func)
	elif title.contains("Moeda") or title.contains("Estandarte"):
		parts.append("Função de Decaimento: %s" % positive_decay_func)
	else:
		parts.append("Influência Positiva em B + Influência Negativa em B")
		
	return "\n ".join(parts)
