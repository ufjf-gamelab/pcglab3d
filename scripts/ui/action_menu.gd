extends CanvasLayer
class_name ActionMenu

signal action_pressed(action: StringName)

@onready var panel: Control = $Panel

func _ready():
	# Isso daqui serve pra impedir que o usuário construe atrás da UI
	panel.add_to_group("blocking_ui")

	for button: Button in find_children("*", "Button", true, false):
		button.focus_mode = Control.FOCUS_NONE
		if button.has_meta("action"):
			var action: StringName = button.get_meta("action")
			button.pressed.connect(func(): action_pressed.emit(action))

func set_build_mode(enabled: bool):
	%Build.set_pressed_no_signal(enabled)
	%Build.text = "Construção: ligada" if enabled else "Construção: desligada"
