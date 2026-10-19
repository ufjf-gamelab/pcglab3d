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
	
	if title.contains("Combinado"):
		parts.append("Somatório de Influências Positivas e Negativas")
	else:
		var decay_type = UHeat.decay_func_types[UHeat.decay_func_type]
		parts.append("Função de Decaimento %s" % decay_type)
		
	for key in influences.keys():
		parts.append("%s: %s" % [key, influences[key]])
		
	return "\n".join(parts)
