extends CanvasLayer
class_name ActionMenu

signal action_pressed(action: StringName)
signal tool_pressed(tool: int)
signal structure_pressed(index: int)

func _ready():
	# Isso daqui serve pra impedir que o usuário construe atrás da UI
	for panel in $Root.get_children():
		panel.add_to_group("blocking_ui")

	for button: BaseButton in find_children("*", "BaseButton", true, false):
		button.focus_mode = Control.FOCUS_NONE
		if button.has_meta("action"):
			var action: StringName = button.get_meta("action")
			button.pressed.connect(func(): action_pressed.emit(action))
		if button.has_meta("tool"):
			var button_tool: int = button.get_meta("tool")
			button.pressed.connect(func(): tool_pressed.emit(button_tool))
		if button.has_meta("structure"):
			var structure: int = button.get_meta("structure")
			button.pressed.connect(func(): structure_pressed.emit(structure))

	set_tool(0)

func get_selected_generator() -> int:
	return %GeneratorSelect.get_selected_id()

func get_spawn_mode() -> int:
	return %SpawnSelect.get_selected_id()

func get_seed() -> int:
	return int(%Seed.text)

func set_seed(value: int):
	%Seed.text = str(value)

func set_tool(tool: int):
	press_button_with("tool", tool)

func set_structure(index: int):
	press_button_with("structure", index)

func set_heatmap(action: StringName):
	press_button_with("action", action)

func set_cell(cell: Vector3i, room: int):
	%Cell.text = "(%d, %d)" % [cell.x, cell.z]
	%Room.text = "fora das salas" if room == -1 else str(room + 1)

func show_room_info(number: int, info: Dictionary):
	%RoomInfo.visible = true
	%RoomName.text = "Sala %d" % number
	%RoomTiles.text = str(info.tiles)
	%RoomEnemies.text = str(info.enemies)
	%RoomCoins.text = str(info.coins)
	%RoomCampfires.text = str(info.campfires)
	%RoomFrom.text = room_list(info.arrives_from)
	%RoomTo.text = room_list(info.leads_to)

func hide_room_info():
	%RoomInfo.visible = false

func room_list(rooms: Array) -> String:
	if rooms.is_empty():
		return "-"
	return ", ".join(rooms.map(func(room): return "Sala %d" % room))

func press_button_with(meta: StringName, value):
	for button: BaseButton in find_children("*", "BaseButton", true, false):
		if button.toggle_mode and button.has_meta(meta) and button.get_meta(meta) == value:
			button.button_pressed = true
