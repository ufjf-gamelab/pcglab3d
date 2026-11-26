extends CanvasLayer
class_name ActionMenu

signal action_pressed(action: StringName)
signal tool_pressed(tool: int)
signal structure_pressed(index: int)

@export var unipolar_scale: Texture2D
@export var bipolar_scale: Texture2D

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
	show_heatmap_details(action)

func show_heatmap_details(action: StringName):
	var enemy := ["Inimigo", UHeat.MAX_VALUE[UHeat.ENEMIES], UHeat.MAX_DISTANCE[UHeat.ENEMIES]]
	var coin := ["Moeda", UHeat.MAX_VALUE[UHeat.COINS], UHeat.MAX_DISTANCE[UHeat.COINS]]
	var campfire := ["Fogueira", UHeat.MAX_VALUE[UHeat.BANNERS], UHeat.MAX_DISTANCE[UHeat.BANNERS]]
	var portal := ["Portal", UHeat.MAX_VALUE[UHeat.ENTRY_PORTALS], UHeat.MAX_DISTANCE[UHeat.ENTRY_PORTALS]]
	var decay := "Decaimento %s" % UHeat.decay_func_types[UHeat.decay_func_type].to_lower()

	var elements := []
	%ScaleBar.texture = unipolar_scale
	%ScaleMin.text = "0"
	%ScaleMax.text = "máx."
	%Decay.text = decay
	match action:
		&"show_enemies_heatmaps":
			elements = [enemy]
		&"show_coins_heatmaps":
			elements = [coin]
		&"show_banners_heatmaps":
			elements = [campfire]
		&"show_recharges_heatmaps":
			elements = [portal, campfire]
		&"show_combined_heatmaps":
			elements = [["Inimigo", -enemy[1], enemy[2]], coin]
			%ScaleBar.texture = bipolar_scale
			%ScaleMin.text = "mín."
			%Decay.text = "Soma das influências positivas e negativas"
		_:
			%HeatmapDetails.visible = false
			return

	for row in 3:
		var shown: bool = row < elements.size()
		var name_label: Label = get_node("%%Element%d" % (row + 1))
		var max_label: Label = get_node("%%Element%dMax" % (row + 1))
		var range_label: Label = get_node("%%Element%dRange" % (row + 1))
		name_label.visible = shown
		max_label.visible = shown
		range_label.visible = shown
		if shown:
			name_label.text = elements[row][0]
			max_label.text = ("%.1f" % elements[row][1]).replace(".", ",")
			range_label.text = str(elements[row][2])

	%HeatmapName.text = find_button_with("action", action).text
	%HeatmapDetails.visible = true

func set_palette_visible(value: bool):
	$Root/Palette.visible = value

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
	var button := find_button_with(meta, value)
	if button:
		button.button_pressed = true

func find_button_with(meta: StringName, value) -> BaseButton:
	for button: BaseButton in find_children("*", "BaseButton", true, false):
		if button.toggle_mode and button.has_meta(meta) and button.get_meta(meta) == value:
			return button
	return null
