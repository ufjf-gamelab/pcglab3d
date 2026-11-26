extends CanvasLayer
class_name ExperimentScreen

signal running_changed(running: bool)
signal open_requested(run_info: Dictionary)

const EXPERIMENT = preload("res://lab/experiment/quantitative_experiment.gd")
const ROW = preload("res://ui/experiment_row.tscn")

const GENERATOR_NAMES = ["Salas geométricas", "Autômato celular"]
const PATH_NAMES = ["direto", "explorador"]
const SPAWN_NAMES = ["aleatório", "inteligente"]

@export var gridmap: GridMap
@export var rows_group: ButtonGroup

var running := false
var runs: Array[Dictionary] = []
var experiment = null
var selected := -1
var selected_room := 0

func _ready():
	visible = false
	%Folder.text = default_folder()
	%Run.pressed.connect(_on_run_pressed)
	%Cancel.pressed.connect(_on_cancel_pressed)
	%OpenFolder.pressed.connect(func(): open_folder(%Folder.text))
	%OpenOutput.pressed.connect(func(): open_folder(%OutputFolder.text))
	%OpenCsv.pressed.connect(func(): OS.shell_open(runs[selected].csv))
	%OpenEditor.pressed.connect(func(): open_requested.emit(runs[selected]))
	%PreviousRoom.pressed.connect(_change_room.bind(-1))
	%NextRoom.pressed.connect(_change_room.bind(1))
	for button: BaseButton in %Config.find_children("*", "BaseButton", true, false):
		button.toggled.connect(func(_on): _update_run_button())
	%SeedCount.value_changed.connect(func(_value): _update_run_button())
	_update_run_button()

func default_folder() -> String:
	var stamp := Time.get_datetime_string_from_system().replace("T", "_").replace(":", "").left(15)
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("pcglab3d/experimentos").path_join(stamp)

func open_folder(folder: String):
	DirAccess.make_dir_recursive_absolute(folder)
	OS.shell_open(folder)

func config() -> Dictionary:
	var seeds := []
	var rng := RandomNumberGenerator.new()
	if %FirstSeed.text.is_valid_int():
		rng.seed = int(%FirstSeed.text)
		seeds.append(int(%FirstSeed.text))
	else:
		rng.randomize()
	while seeds.size() < int(%SeedCount.value):
		seeds.append(rng.randi())

	var sizes := []
	for size in [[%Small, "pequeno", %SmallMin, %SmallMax], [%Medium, "medio", %MediumMin, %MediumMax], [%Large, "grande", %LargeMin, %LargeMax]]:
		if size[0].button_pressed:
			sizes.append({"name": size[0].text.to_lower(), "file_name": size[1], "min": int(size[2].value), "max": int(size[3].value)})

	return {
		"seeds": seeds,
		"generators": checked([%Geometric, %Cellular]),
		"sizes": sizes,
		"path_types": checked([%Straight, %Explorer]),
		"spawn_modes": checked([%RandomSpawn, %SmartSpawn]),
		"layers": checked([%LayerEnemies, %LayerCoins, %LayerBanners, %LayerPortals]).map(func(i): return UHeat.LAYERS[i]),
		"folder": %Folder.text,
	}

func checked(boxes: Array) -> Array:
	var values := []
	for i in boxes.size():
		if boxes[i].button_pressed:
			values.append(i)
	return values

func _update_run_button():
	var empty := false
	for boxes in [[%Geometric, %Cellular], [%Small, %Medium, %Large], [%Straight, %Explorer], [%RandomSpawn, %SmartSpawn], [%LayerEnemies, %LayerCoins, %LayerBanners, %LayerPortals]]:
		empty = empty or checked(boxes).is_empty()
	%Run.disabled = empty

func _on_run_pressed():
	var settings := config()
	runs = EXPERIMENT.build_runs(settings)
	for row in %Rows.get_children():
		row.free()

	%Config.visible = false
	%Results.visible = true
	%ProgressTitle.text = "Rodando experimento quantitativo"
	%Cancel.text = "Cancelar"
	%Cancel.disabled = false
	%Progress.max_value = runs.size()
	%Progress.value = 0
	%Counter.text = "0 / %d" % runs.size()
	%OutputFolder.text = settings.folder
	_select(-1)

	running = true
	running_changed.emit(true)
	experiment = EXPERIMENT.new()
	experiment.run_finished.connect(_on_run_finished)
	await experiment.run(gridmap, runs, settings.folder)

	for i in runs.size():
		if runs[i].done:
			var row: Button = ROW.instantiate()
			%Rows.add_child(row)
			row.button_group = rows_group
			row.setup([str(runs[i].seed), GENERATOR_NAMES[runs[i].generator], runs[i].size.name, PATH_NAMES[runs[i].path], SPAWN_NAMES[runs[i].spawn]])
			row.pressed.connect(_select.bind(i))
	%ProgressTitle.text = "Experimento cancelado" if experiment.cancelled else "Experimento concluído"
	%Cancel.text = "Voltar"
	%Cancel.disabled = false
	experiment = null
	running = false
	running_changed.emit(false)

func _on_cancel_pressed():
	if running:
		experiment.cancel()
		%Cancel.disabled = true
		return
	%Results.visible = false
	%Config.visible = true
	%Folder.text = default_folder()

func _on_run_finished(index: int):
	%Progress.value = index + 1
	%Counter.text = "%d / %d" % [index + 1, runs.size()]

func _select(index: int):
	selected = index
	selected_room = 0
	_show_selected()

func _change_room(step: int):
	selected_room = wrapi(selected_room + step, 0, runs[selected].rooms.size())
	_show_selected()

func _show_selected():
	var has_run := selected != -1
	%RunChart.visible = has_run
	%RunEmpty.visible = not has_run
	%RunRoom.get_parent().visible = has_run
	for button in [%OpenEditor, %OpenCsv]:
		button.disabled = not has_run
	if not has_run:
		return

	var run_info := runs[selected]
	var values: Array = run_info.rooms[selected_room]
	%RunRoom.text = "Sala %d de %d" % [selected_room + 1, run_info.rooms.size()]
	var top := 1.0
	for value in values:
		top = maxf(top, ceilf(absf(value) * 2) / 2)
	var bottom := -top if UHeat.is_bipolar(run_info.layers) else 0.0
	%RunChart.set_data(range(values.size()), values, bottom, top)
