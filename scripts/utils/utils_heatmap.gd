extends Node

var heatmap_multimesh: MultiMeshInstance3D

const DIRECTIONS := [
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1)
	#Vector3i(1, 0, -1),
	#Vector3i(1, 0, 1),
	#Vector3i(-1, 0, 1),
	#Vector3i(-1, 0, -1),
]

const ENEMIES = "enemies"
const COINS = "coins"
const BANNERS = "banners"
const ENTRY_PORTALS = "entry_portals"
const EXIT_PORTALS = "exit_portals"
const COMBINED = "combined"
const RECHARGES = "recharges"
const PLAYER = "player"

const MAX_VALUE = {
	ENEMIES: 5.0,
	COINS: 5.0,
	BANNERS: 5.0,
	ENTRY_PORTALS: 5.0,
	EXIT_PORTALS: 5.0,
	PLAYER: 5.0
}

const MAX_DISTANCE = {
	ENEMIES: 5, 
	COINS: 5, 
	BANNERS: 5, 
	ENTRY_PORTALS: 5, 
	EXIT_PORTALS: 5, 
	PLAYER: 5
}

var heatmaps = {
	ENEMIES: [],
	COINS: [],
	BANNERS: [],
	COMBINED: [],
	ENTRY_PORTALS: [],
	EXIT_PORTALS: [],
	PLAYER: []
}

var decay_func_type = "linear"

var decay_func_types = {
	"linear": "Linear"
}

var curr_visible_heatmap = {
	ENEMIES: false,
	COINS: false,
	BANNERS: false,
	COMBINED: false,
	RECHARGES: false
}

func switch_decay_func(max_value: float, distance: int, max_distance: int) -> float:
	match decay_func_type:
		"linear":
			return max(0.0, max_value * (1.0 - float(distance) / float(max_distance)))
		_:
			print("Nenhuma função de decaimento válida!")
			return 0.0

func create_same_element_type_combined_heatmap(type_heatmaps):
	var combined_type_heat = {}
	for heat in type_heatmaps:
		for cell in heat.keys():
			if combined_type_heat.has(cell):
				combined_type_heat[cell] += heat[cell]
			else:
				combined_type_heat[cell] = heat[cell]
	return combined_type_heat

func create_heatmap_bfs(gridmap: GridMap, start_cell: Vector3i, element: String):
	var max_value = MAX_VALUE[element]
	var max_distance = MAX_DISTANCE[element]
	
	# Fila para o BFS
	var queue: Array[Vector3i] = [start_cell]
	var distances := { start_cell: 0 }
	
	# Define o mapa de influência com célula inicial
	var heatmap = { start_cell: max_value }
	
	# Loop da Busca em Largura
	while queue.size() > 0:
		# Remove a primeira célula da fila
		var current = queue.pop_front()
		# Guarda a distância da célula atual
		var current_dist = distances[current]
		
		# Verifica os vizinhos
		for direction in DIRECTIONS:
			var neighbor = current + direction
			
			# Se o vizinho já foi visitado, pula
			if heatmap.has(neighbor):
				continue
			
			# Captura ID do vizinho
			var neighbor_id = gridmap.get_cell_item(neighbor)
			
			# Verifica se o vizinho não é parede
			if neighbor_id != UGen.WALL_ID and neighbor_id != UGen.SOLID_ID:
				# Distância do vizinho é a distância atual + 1 tile
				var neighbor_dist = current_dist + 1
				# Registra distância do vizinho no dicionário de distâncias
				distances[neighbor] = neighbor_dist
				# Registra no heatmap o valor de influência na célula vizinha
				heatmap[neighbor] = switch_decay_func(max_value, neighbor_dist, max_distance)
				# Adiciona vizinho na fila
				queue.append(neighbor)
	
	return heatmap

# Cria heatmap combinando de N heatmaps
func create_combined_heatmap(maps_to_add: Array[Dictionary], maps_to_subtract: Array[Dictionary] = []) -> Dictionary:
	var combined: Dictionary = {}
	for heatmap in maps_to_add:
		combined = sum_heatmaps(combined, heatmap)
	for heatmap in maps_to_subtract:
		combined = subtract_heatmaps(combined, heatmap)
	return combined

func show_heatmaps(gridmap: GridMap, element_heatmaps, cell_size := 1.0, bipolar: bool = false):
	var total_instances := 0
	var extreme_values_heatmaps = []
	var extreme_values = {
		global_min = 10000,
		global_max = -10000
	}
	for i in range(element_heatmaps.size()):
		var heatmap = element_heatmaps[i]
		total_instances += heatmap.size()
		for value in heatmap.values():
			extreme_values.global_max = max(extreme_values.global_max, value)
			extreme_values.global_min = min(extreme_values.global_min, value)
		extreme_values_heatmaps.append(extreme_values.duplicate())
		extreme_values.global_min = 10000
		extreme_values.global_max = -10000
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.instance_count = total_instances

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(cell_size, cell_size)
	
	mm.mesh = mesh
	heatmap_multimesh.multimesh = mm

	var mat := ShaderMaterial.new()
	if bipolar:
		mat.shader = preload("res://shaders/heatmap_bipolar.gdshader")
	else:
		mat.shader = preload("res://shaders/heatmap_unipolar.gdshader")
	heatmap_multimesh.material_override = mat

	var j := 0
	for i in range(element_heatmaps.size()):
		var heatmap = element_heatmaps[i]
		var global_min = extreme_values_heatmaps[i]["global_min"]
		var global_max = extreme_values_heatmaps[i]["global_max"]
		for cell: Vector3i in heatmap.keys():
			var intensity
			# mapeia negativo->(0.0-0.5), zero->(0.5), positivo->(0.5-1.0)
			if bipolar:
				if is_zero_approx(heatmap[cell]):
					# Zero fica no centro
					intensity = 0.5
				if ((heatmap[cell]) < 0):
					# Normaliza e comprime para a primeira metade (0 a 0.5)
					intensity = 0.5 * (1 - (-heatmap[cell])/float(-global_min))
				elif ((heatmap[cell]) > 0):
					# Normaliza e comprime para a segunda metade (0.5 a 1)
					intensity = 0.5 + (0.5 * (heatmap[cell] / float(global_max)))
			# mapeia 0->0.0, max->1.0
			else:
				intensity = heatmap[cell] / float(global_max)
			
			var transform := Transform3D()
			transform.origin = gridmap.map_to_local(cell) + Vector3(0, 0.05, 0)

			mm.set_instance_transform(j, transform)
			mm.set_instance_custom_data(j, Color(intensity, 0.0, 0.0, 0.0))
			j += 1
	
	heatmap_multimesh.visible = true

func toggle_enemy_heatmaps(gridmap: GridMap, heatmap_panel: HeatmapInfoPanel):
	if curr_visible_heatmap[ENEMIES]:
		heatmap_multimesh.visible = false
		curr_visible_heatmap[ENEMIES] = false
		heatmap_panel.clear()
	else:
		deactivate_heatmaps()
		var enemies_heatmaps = heatmaps[ENEMIES]
		show_heatmaps(gridmap, enemies_heatmaps)
		curr_visible_heatmap[ENEMIES] = true
		heatmap_panel.show_heatmap_info(
			"Mapas de Influência de Inimigos", 
			{
				"Influência Máxima de um Inimigo": MAX_VALUE[ENEMIES],
				"Alcance Máximo da Influência de um Inimigo": MAX_DISTANCE[ENEMIES]
			}
		)

func toggle_coin_heatmaps(gridmap: GridMap, heatmap_panel: HeatmapInfoPanel):
	if curr_visible_heatmap[COINS]:
		heatmap_multimesh.visible = false
		curr_visible_heatmap[COINS] = false
		heatmap_panel.clear()
	else:
		deactivate_heatmaps()
		var coins_heatmaps = heatmaps[COINS]
		show_heatmaps(gridmap, coins_heatmaps)
		curr_visible_heatmap[COINS] = true
		heatmap_panel.show_heatmap_info(
			"Mapas de Influência de Moedas", 
			{
				"Influência Máxima de uma Moeda": MAX_VALUE[COINS],
				"Alcance Máximo da Influência de uma Moeda": MAX_DISTANCE[COINS]
			}
		)

func toggle_banner_heatmaps(gridmap: GridMap, heatmap_panel: HeatmapInfoPanel):
	if curr_visible_heatmap[BANNERS]:
		heatmap_multimesh.visible = false
		curr_visible_heatmap[BANNERS] = false
		heatmap_panel.clear()
	else:
		deactivate_heatmaps()
		var banners_heatmaps = heatmaps[BANNERS]
		show_heatmaps(gridmap, banners_heatmaps)
		curr_visible_heatmap[BANNERS] = true
		heatmap_panel.show_heatmap_info(
			"Mapas de Influência de Estandartes", 
			{
				"Influência Máxima de um Estandarte": MAX_VALUE[BANNERS],
				"Alcance Máximo da Influência de um Estandarte": MAX_DISTANCE[BANNERS]
			}
		)

func toggle_recharge_heatmaps(gridmap: GridMap, heatmap_panel: HeatmapInfoPanel):
	if curr_visible_heatmap[RECHARGES]:
		heatmap_multimesh.visible = false
		curr_visible_heatmap[RECHARGES] = false
		heatmap_panel.clear()
	else:
		deactivate_heatmaps()
		
		var recharge_heatmaps = []
		
		for i in range(heatmaps[BANNERS].size()):
			recharge_heatmaps.append(
				UHeat.create_combined_heatmap([heatmaps[ENTRY_PORTALS][i], heatmaps[EXIT_PORTALS][i], heatmaps[BANNERS][i]], [])
			)
			
		UHeat.heatmaps[RECHARGES] = recharge_heatmaps
		
		show_heatmaps(gridmap, recharge_heatmaps)
		curr_visible_heatmap[RECHARGES] = true
		heatmap_panel.show_heatmap_info(
			"Mapas de Influência de Recargas de Energia",
			{
				"Influência Máxima do Portal de Entrada": MAX_VALUE[ENTRY_PORTALS],
				"Alcance Máximo da Influência do Portal de Entrada": MAX_DISTANCE[ENTRY_PORTALS],
				
				"Influência Máxima do Portal de Saída": MAX_VALUE[EXIT_PORTALS],
				"Alcance Máximo da Influência do Portal de Saída": MAX_DISTANCE[EXIT_PORTALS],
				
				"Influência Máxima de um Estandarte": MAX_VALUE[BANNERS],
				"Alcance Máximo da Influência de um Estandarte": MAX_DISTANCE[BANNERS]
			}
		)

func toggle_combined_heatmaps(gridmap: GridMap, heatmap_panel: HeatmapInfoPanel):
	if curr_visible_heatmap[COMBINED]:
		heatmap_multimesh.visible = false
		curr_visible_heatmap[COMBINED] = false
		heatmap_panel.clear()
	else:
		deactivate_heatmaps()
		var combined_heatmaps = heatmaps[COMBINED]
		show_heatmaps(gridmap, combined_heatmaps, 1, true) 
		curr_visible_heatmap[COMBINED] = true
		heatmap_panel.show_heatmap_info(
			"Mapas de Influência Combinados", 
			{
				"Influência Máxima de um Inimigo": -MAX_VALUE[ENEMIES],
				"Alcance Máximo da Influência de um Inimigo": MAX_DISTANCE[BANNERS],
				"Influência Máxima de uma Moeda": MAX_VALUE[COINS],
				"Alcance Máximo da Influência de uma Moeda": MAX_DISTANCE[BANNERS]
			}
		)

func deactivate_heatmaps():
	heatmap_multimesh.visible = false
	curr_visible_heatmap[ENEMIES] = false
	curr_visible_heatmap[COINS] = false
	curr_visible_heatmap[BANNERS] = false
	curr_visible_heatmap[COMBINED] = false
	curr_visible_heatmap[RECHARGES] = false

func clear_heatmaps():
	heatmaps[ENEMIES] = []
	heatmaps[COINS] = []
	heatmaps[BANNERS] = []
	heatmaps[COMBINED] = []
	heatmaps[ENTRY_PORTALS] = []
	heatmaps[EXIT_PORTALS] = []
	heatmaps[RECHARGES] = []

func recalculate_heatmaps(gridmap: GridMap, heatmap_panel: HeatmapInfoPanel):
	deactivate_heatmaps()
	clear_heatmaps()
	heatmap_panel.clear()
	
	var room_enemies_heatmaps
	var room_coins_heatmaps
	var room_banners_heatmaps
	
	for i in range(UGen.rooms.size()):
		var elements_pos = UGen.rooms_elements_pos[i]
		
		# Recria heatmaps de portais (portais nao mudam de posicao)
		var portal1_heat = create_heatmap_bfs(gridmap, elements_pos["portal1_pos"], ENTRY_PORTALS)
		heatmaps[ENTRY_PORTALS].append(portal1_heat)
		var portal2_heat = create_heatmap_bfs(gridmap, elements_pos["portal2_pos"], EXIT_PORTALS)
		heatmaps[EXIT_PORTALS].append(portal2_heat)
		
		room_enemies_heatmaps = []
		room_coins_heatmaps = []
		room_banners_heatmaps = []
		
		for element_type in elements_pos.keys():
			match element_type:
				"npc_pos":
					for pos in elements_pos["npc_pos"]:
						var heat = create_heatmap_bfs(gridmap, pos, ENEMIES)
						room_enemies_heatmaps.append(heat)
				"coin_pos":
					for pos in elements_pos["coin_pos"]:
						var heat = create_heatmap_bfs(gridmap, pos, COINS)
						room_coins_heatmaps.append(heat)
				"banner_pos":
					for pos in elements_pos["banner_pos"]:
						var heat = create_heatmap_bfs(gridmap, pos, BANNERS)
						room_banners_heatmaps.append(heat)
		
		# Cria heatmap combinado de moedas da sala
		var combined_coins_heat = create_same_element_type_combined_heatmap(room_coins_heatmaps)
		UHeat.heatmaps[COINS].append(combined_coins_heat)
		# Cria heatmap combinado de inimigos da sala
		var combined_enemies_heat = create_same_element_type_combined_heatmap(room_enemies_heatmaps)
		UHeat.heatmaps[ENEMIES].append(combined_enemies_heat)
		# Cria heatmap combinado de banners da sala
		var combined_banners_heat = create_same_element_type_combined_heatmap(room_banners_heatmaps)
		UHeat.heatmaps[BANNERS].append(combined_banners_heat)
		# Cria heatmap combinado de todos os elementos de uma sala
		var combined_heat = UHeat.create_combined_heatmap([combined_coins_heat], [combined_enemies_heat])
		UHeat.heatmaps[COMBINED].append(combined_heat) 

func sum_heatmaps(a: Dictionary, b: Dictionary) -> Dictionary:
	var result = a.duplicate()
	for key in b.keys():
		if result.has(key):
			result[key] += b[key]
		else:
			result[key] = b[key]
	return result

func subtract_heatmaps(a: Dictionary, b: Dictionary) -> Dictionary:
	var result = a.duplicate()
	for key in b.keys():
		if result.has(key):
			result[key] -= b[key]
		else:
			result[key] = -b[key]
	return result

# Verifica se o tile tem vizinhos com valor X em um heatmap
func has_neighbor_with_value(tile: Vector3i, heatmap: Dictionary, neighbor_value: float) -> bool:
	for dir in UHeat.DIRECTIONS:
		var neighbor = tile + dir
		if heatmap.has(neighbor) and is_equal_approx(heatmap[neighbor], neighbor_value):
			return true
	return false

# Verifica se o tile tem algum vizinho com valor negativo
func has_neighbor_below_zero(tile: Vector3i, heatmap: Dictionary) -> bool:
	for dir in UHeat.DIRECTIONS:
		var neighbor = tile + dir
		if heatmap.has(neighbor) and heatmap[neighbor] < 0 and not is_zero_approx(heatmap[neighbor]):
			return true
	return false

# Retorna tiles com um valor X e com pelo menos um vizinhos com valor Y em um heatmap 
func filter_tiles_by_value_and_neighbor_value(heatmap: Dictionary, available_spots: Array[Vector3i], tile_value: float, neighbor_value: float) -> Array[Vector3i]:
	var selected: Array[Vector3i] = []
	for tile in available_spots:
		if not heatmap.has(tile):
			continue
		if is_equal_approx(heatmap[tile], tile_value) and has_neighbor_with_value(tile, heatmap, neighbor_value):
			selected.append(tile)
	return selected

# Retorna lista de posicoes com menores valores de influencia
func get_lowest_tiles(heatmap: Dictionary, available_spots: Array[Vector3i]) -> Array[Vector3i]:
	var lowest = 10000
	var lowest_pos: Array[Vector3i] = []
	for tile in available_spots:
		if not heatmap.has(tile):
			continue
		
		var value = heatmap[tile]
		if value < lowest:
			lowest_pos.clear()
			lowest_pos.append(tile)
			lowest = value
		elif is_equal_approx(value, lowest):
			lowest_pos.append(tile)
	return lowest_pos

# Retorna lista de posicoes com maiores valores de influencia
func get_greatest_tiles(heatmap: Dictionary, available_spots: Array[Vector3i]) -> Array[Vector3i]:
	var greatest = -INF
	var greatest_pos: Array[Vector3i] = []
	for tile in available_spots:
		if not heatmap.has(tile):
			continue

		var value = heatmap[tile]
		if value > greatest:
			greatest_pos.clear()
			greatest_pos.append(tile)
			greatest = value
		elif is_equal_approx(value, greatest):
			greatest_pos.append(tile)
	return greatest_pos

# Retorna lista de posicoes com menores valores de influencia em módulo
func get_balanced_tiles(heatmap: Dictionary, available_spots: Array[Vector3i]) -> Array[Vector3i]:
	var closest_value = INF
	var selected_tiles: Array[Vector3i] = []
	
	for tile in available_spots:
		if not heatmap.has(tile):
			continue
		
		var val = abs(heatmap[tile])
		if val < closest_value:
			selected_tiles.clear()
			selected_tiles.append(tile)
			closest_value = val
		elif is_equal_approx(val, closest_value):
			selected_tiles.append(tile)
	
	return selected_tiles

# Retorna lista de posicoes cujo valor seja exatamente igual a target_value
func get_tiles_with_exact_value(heatmap: Dictionary, available_spots: Array[Vector3i], target_value: float) -> Array[Vector3i]:
	var selected_tiles: Array[Vector3i] = []
	
	for tile in available_spots:
		if not heatmap.has(tile):
			continue
		
		var value = heatmap[tile]
		
		if is_equal_approx(value, target_value):
			selected_tiles.append(tile)
	
	return selected_tiles

# Retorna lista posicoes cujo valor esteja dentro do intervalo fechado [min_value, max_value]
func get_tiles_in_range(heatmap: Dictionary, available_spots: Array[Vector3i], min_value: float, max_value: float) -> Array[Vector3i]:
	var selected_tiles: Array[Vector3i] = []
	
	for tile in available_spots:
		if not heatmap.has(tile):
			continue
		
		var value = heatmap[tile]
		
		if value >= min_value and value <= max_value:
			selected_tiles.append(tile)
	
	return selected_tiles
