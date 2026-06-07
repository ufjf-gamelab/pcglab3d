extends Node
class_name SpawnRecipe

# Critérios de seleção de tile
enum Selection { GREATEST, LOWEST }

# Tipos de spawn dos elementos
enum SpawnMode {
	FIXED_QUANTITY,
	UNTIL_NO_VALID_TILE
}
 
# Dados da receita
var element_key: String          # Chave no UHeat.heatmaps
var tile_id: int                 # ID do tile no GridMap
var positive_influence: bool     # Se o heatmap gerado é positivo ou negativo
var selection: Selection         # Critério de seleção do tile
var add_maps: Array              # Heatmaps somados na receita (Array[Dictionary])
var subtract_maps: Array         # Heatmaps subtraídos na receita (Array[Dictionary])
var self_repulsion: bool         # Se elementos deste mesmo tipo se repelem entre si
var spawn_mode: SpawnMode        # Número fixo de elementos ou com condição de parada
var tile_validator: Callable     # Função que valida o tile selecionado

func _init(
	p_element_key: String,
	p_tile_id: int,
	p_positive_influence: bool,
	p_selection: Selection,
	p_add_maps: Array,
	p_subtract_maps: Array,
	p_self_repulsion: bool = true,
	p_spawn_mode: SpawnMode = SpawnMode.FIXED_QUANTITY,
	p_tile_validator: Callable = Callable()
):
	element_key = p_element_key
	tile_id = p_tile_id
	positive_influence = p_positive_influence
	selection = p_selection
	add_maps = p_add_maps
	subtract_maps = p_subtract_maps
	self_repulsion = p_self_repulsion
	spawn_mode = p_spawn_mode
	tile_validator = p_tile_validator

func execute(gridmap: GridMap, quantity: int, available_spots: Array) -> Array:
	if UGen.SPAWN == UGen.Spawn.RANDOM:
		return _execute_fixed_quantity(
			gridmap,
			quantity,
			available_spots
		)
	
	match spawn_mode:
		SpawnMode.FIXED_QUANTITY:
			return _execute_fixed_quantity(gridmap, quantity, available_spots)
		SpawnMode.UNTIL_NO_VALID_TILE:
			return _execute_until_no_valid_tile(gridmap, available_spots)

	return []

func _execute_fixed_quantity(gridmap: GridMap, quantity: int, available_spots: Array) -> Array:
	var placed_heats := []
	var placed_positions := []

	for _n in range(quantity):
		if available_spots.is_empty():
			break

		var pos
		if UGen.SPAWN == UGen.Spawn.RANDOM:
			pos = available_spots.pop_front()
		else:
			pos = _pick_tile(available_spots, placed_heats)
			if pos == null:
				break
			available_spots.erase(pos)

		_place_element(gridmap, pos, placed_positions, placed_heats)

	_finalize_heatmap(placed_heats)

	return placed_positions

func _execute_until_no_valid_tile(gridmap: GridMap, available_spots: Array) -> Array:
	var placed_heats := []
	var placed_positions := []

	while true:
		if available_spots.is_empty():
			break

		var pos
		if UGen.SPAWN == UGen.Spawn.RANDOM:
			pos = available_spots.pop_front()
		else:
			pos = _pick_tile(available_spots, placed_heats)
			if pos == null:
				break
			available_spots.erase(pos)

		_place_element(gridmap, pos, placed_positions, placed_heats)

	_finalize_heatmap(placed_heats)

	return placed_positions

func _place_element(gridmap: GridMap, pos, placed_positions: Array, placed_heats: Array):
	gridmap.set_cell_item(pos, tile_id)
	placed_positions.append(pos)

	var heat = UHeat.create_heatmap_bfs(
		gridmap,
		pos,
		positive_influence,
		element_key
	)

	placed_heats.append(heat)

func _finalize_heatmap(placed_heats: Array):
	var combined = UHeat.create_same_element_type_combined_heatmap(placed_heats)
	UHeat.heatmaps[element_key].append(combined)

func _pick_tile(available_spots: Array, placed_heats: Array):
	# Monta heatmap base
	var working_heatmap := _build_working_heatmap(placed_heats)
 
	# Seleciona o tile de acordo com o critério da receita
	var candidates: Array
	match selection:
		Selection.GREATEST:
			candidates = UHeat.get_greatest_tiles(working_heatmap, available_spots)
		Selection.LOWEST:
			candidates = UHeat.get_lowest_tiles(working_heatmap, available_spots)

	# Caso exista uma função validadora, filtra tiles
	if tile_validator.is_valid():
		var filtered := []
		for tile in candidates:
			if tile_validator.call(tile, working_heatmap):
				filtered.append(tile)
		candidates = filtered

	if candidates.is_empty():
		return null

	candidates.shuffle()
	return candidates[0]
 
func _build_working_heatmap(placed_heats: Array) -> Dictionary:
	var working_heatmap := {}
 
	# Soma os mapas que atraem
	for hmap in add_maps:
		working_heatmap = UHeat.sum_heatmaps(working_heatmap, hmap)
 
	# Subtrai os mapas que repelem
	for hmap in subtract_maps:
		working_heatmap = UHeat.subtract_heatmaps(working_heatmap, hmap)
 
	# Elementos do mesmo tipo se afastam entre si
	if self_repulsion and placed_heats.size() > 0:
		var self_combined = UHeat.create_same_element_type_combined_heatmap(placed_heats)
		var self_repulsion_map := {}
		for key in self_combined:
			if selection == Selection.GREATEST:
				self_repulsion_map[key] = -abs(self_combined[key])
			else:
				self_repulsion_map[key] = abs(self_combined[key])
		working_heatmap = UHeat.sum_heatmaps(working_heatmap, self_repulsion_map)
 
	return working_heatmap
