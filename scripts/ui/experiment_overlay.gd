extends CanvasLayer
class_name ExperimentOverlay

signal cancel_pressed

@onready var title_label: Label = %Title
@onready var detail_label: Label = %Detail
@onready var progress_bar: ProgressBar = %Progress
@onready var action_button: Button = %ActionButton

var _running := false

func _ready():
	visible = false
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.pressed.connect(_on_action_button_pressed)

func start():
	_running = true
	visible = true
	title_label.text = "Rodando experimento quantitativo"
	detail_label.text = "Preparando..."
	progress_bar.value = 0
	action_button.text = "Cancelar"
	action_button.disabled = false

func update_progress(current: int, total: int, description: String):
	progress_bar.max_value = total
	progress_bar.value = current
	detail_label.text = "%s  (%d/%d)" % [description, current, total]

func finish(cancelled: bool, output_folder: String):
	_running = false
	if cancelled:
		title_label.text = "Experimento cancelado"
		detail_label.text = "Os CSVs das execuções já concluídas ficaram em:\n%s" % output_folder
	else:
		title_label.text = "Experimento concluído"
		detail_label.text = "CSVs salvos em:\n%s" % output_folder
	action_button.text = "Fechar"
	action_button.disabled = false

func _on_action_button_pressed():
	if _running:
		action_button.disabled = true
		detail_label.text = "Cancelando após a execução atual..."
		cancel_pressed.emit()
	else:
		visible = false
