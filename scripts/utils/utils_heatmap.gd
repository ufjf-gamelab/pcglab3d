extends Node

var heatmap_multimesh: MultiMeshInstance3D

const DIRECTIONS := [
	Vector3i(1, 0, 0),
	Vector3i(1, 0, -1),
	Vector3i(1, 0, 1),
	Vector3i(-1, 0, 0),
	Vector3i(-1, 0, 1),
	Vector3i(-1, 0, -1),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1)
]

const START_CELL_ELEMENT_WEIGHT = {
	"enemies": -5,
	"coins": 5,
	"banners": 5,  
}

var heatmaps = {
	"enemies": [],
	"coins": [],
	"banners": [],
	"combined": []
}

var enemy_heatmap_visible := false
var coin_heatmap_visible := false
var banner_heatmap_visible := false
var combined_heatmap_visible := false

var decay_func_type = "linear"

var decay_func_types = {
	"linear": {
		"positive_influ_exibit": "B = A - 1",
		"negative_influ_exibit": "B = A + 1"
	}
}

func switch_decay_func(positive_influence, curr_heatmap_tile):
	match decay_func_type:
		"linear":
			return curr_heatmap_tile - 1 if positive_influence else curr_heatmap_tile + 1

func create_same_element_type_combined_heatmap(type_heatmaps):
	var combined_type_heat = {}
	for heat in type_heatmaps:
		for cell in heat.keys():
			if combined_type_heat.has(cell):
				combined_type_heat[cell] += heat[cell]
			else:
				combined_type_heat[cell] = heat[cell]
	return combined_type_heat

func create_heatmap_bfs(gridmap: GridMap, start_cell: Vector3i, positive_influence: bool, element: String):
	# Estruturas para o BFS
	var queue: Array[Vector3i] = [start_cell]
	
	# Define o mapa de influência com célula inicial
	var heatmap = { start_cell: START_CELL_ELEMENT_WEIGHT[element] }

	# Loop da Busca em Largura
	while queue.size() > 0:
		# Remove o primeiro da fila
		var current = queue.pop_front()
		
		# Verificar vizinhos
		for direction in DIRECTIONS:
			var neighbor = current + direction
			
			# Se já visitamos, pula
			if heatmap.has(neighbor):
				continue
			
			# Captura ID do vizinho
			var neighbor_id = gridmap.get_cell_item(neighbor)
			
			# Verifica se o vizinho não é parede
			if neighbor_id != UGen.WALL_ID and neighbor_id != UGen.SOLID_ID:
				# Adiciona vizinho no mapa de calor
				if heatmap[current] != 0:
					# Função de decaimento entra aqui (diferentes tipos)
					heatmap[neighbor] = heatmap[current] - 1 if positive_influence else heatmap[current] + 1
				else:
					heatmap[neighbor] = 0
				queue.append(neighbor)
				
	return heatmap

# Cria heatmap combinando elementos da sala
func create_combined_heatmap(banners_heat, enemies_heat, coins_heat):
	var combined_heat = {}
	
	for key in coins_heat.keys():
		combined_heat[key] = banners_heat[key] + enemies_heat[key] + coins_heat[key]	
				
	return combined_heat	

func show_heatmaps(gridmap: GridMap, element_heatmaps, cell_size := 1.0):
	var total_instances := 0
	var global_max := 0
	var global_min := 10000
	for heatmap in element_heatmaps:
		total_instances += heatmap.size()
		for value in heatmap.values():
			global_max = max(global_max, value)
			global_min = min(global_min, value)
		
	
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.instance_count = total_instances

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(cell_size, cell_size)
	
	mm.mesh = mesh
	heatmap_multimesh.multimesh = mm

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/heatmap.gdshader")
	heatmap_multimesh.material_override = mat	

	var i := 0
	for heatmap in element_heatmaps:
		for cell: Vector3i in heatmap.keys():
			var intensity
			if ((heatmap[cell]) == 0):
				# Zero fica no centro
				intensity = 0.5
			if ((heatmap[cell]) < 0):
				# Normaliza e comprime para a primeira metade (0 a 0.5)				
				intensity = 0.5 * (1 - (-heatmap[cell])/float(-global_min))
			elif ((heatmap[cell]) > 0):
				# Normaliza e comprime para a segunda metade (0.5 a 1)
				intensity = 0.5 + (0.5 * (heatmap[cell] / float(global_max)))
			
			var transform := Transform3D()
			transform.origin = gridmap.map_to_local(cell) + Vector3(0, 0.05, 0)

			mm.set_instance_transform(i, transform)
			mm.set_instance_custom_data(i, Color(intensity, 0.0, 0.0, 0.0))
			i += 1
	
	heatmap_multimesh.visible = true

func toggle_enemy_heatmaps(gridmap: GridMap, heatmap_panel: HeatmapInfoPanel):
	if enemy_heatmap_visible:
		heatmap_multimesh.visible = false
		enemy_heatmap_visible = false
		heatmap_panel.clear()
	else:
		var enemies_heatmaps = heatmaps["enemies"]
		show_heatmaps(gridmap, enemies_heatmaps)
		enemy_heatmap_visible = true
		heatmap_panel.show_heatmap_info("Mapas de Influência de Inimigos", {"Influência de um Inimigo": START_CELL_ELEMENT_WEIGHT["enemies"]})

		
func toggle_coin_heatmaps(gridmap: GridMap, heatmap_panel: HeatmapInfoPanel):
	if coin_heatmap_visible:
		heatmap_multimesh.visible = false
		coin_heatmap_visible = false
		heatmap_panel.clear()
	else:
		var coins_heatmaps = heatmaps["coins"]
		show_heatmaps(gridmap, coins_heatmaps)
		coin_heatmap_visible = true
		heatmap_panel.show_heatmap_info("Mapas de Influência de Moedas", {"Influência de uma Moeda": START_CELL_ELEMENT_WEIGHT["coins"]})

		
func toggle_banner_heatmaps(gridmap: GridMap, heatmap_panel: HeatmapInfoPanel):
	if banner_heatmap_visible:
		heatmap_multimesh.visible = false
		banner_heatmap_visible = false
		heatmap_panel.clear()
	else:
		var banners_heatmaps = heatmaps["banners"]
		show_heatmaps(gridmap, banners_heatmaps)
		banner_heatmap_visible = true
		heatmap_panel.show_heatmap_info("Mapas de Influência de Estandartes", {"Influência de um Estandarte": START_CELL_ELEMENT_WEIGHT["banners"]})


func toggle_combined_heatmaps(gridmap: GridMap, heatmap_panel: HeatmapInfoPanel):
	if combined_heatmap_visible:
		heatmap_multimesh.visible = false
		combined_heatmap_visible = false
		heatmap_panel.clear()
	else:
		var combined_heatmaps = heatmaps["combined"]
		show_heatmaps(gridmap, combined_heatmaps) 
		combined_heatmap_visible = true
		heatmap_panel.show_heatmap_info("Mapas de Influência Combinados", 
		{
			"Influência de um Inimigo": START_CELL_ELEMENT_WEIGHT["enemies"],
			"Influência de uma Moeda": START_CELL_ELEMENT_WEIGHT["coins"],
			"Influência de um Estandarte": START_CELL_ELEMENT_WEIGHT["banners"]
		})


func recalculate_heatmaps(gridmap: GridMap, heatmap_panel: HeatmapInfoPanel):
	heatmaps["enemies"] = []
	heatmaps["coins"] = []
	heatmaps["banners"] = []
	heatmaps["combined"] = []
	
	heatmap_multimesh.visible = false
	combined_heatmap_visible = false
	banner_heatmap_visible = false
	coin_heatmap_visible = false
	enemy_heatmap_visible = false
	heatmap_panel.clear()
	
	var room_enemies_heatmaps
	var room_coins_heatmaps
	var room_banners_heatmaps
	for room in UGen.rooms:
		room_enemies_heatmaps = []
		room_coins_heatmaps = []
		room_banners_heatmaps = []
		for pos in room:
			match gridmap.get_cell_item(pos):
				UGen.NPC_ID:
					var heat = create_heatmap_bfs(gridmap, pos, false, "enemies")
					room_enemies_heatmaps.append(heat)
				UGen.COIN_ID:
					var heat = create_heatmap_bfs(gridmap, pos, true, "coins")
					room_coins_heatmaps.append(heat)
				UGen.BANNER_ID:
					var heat = create_heatmap_bfs(gridmap, pos, true, "banners")
					room_banners_heatmaps.append(heat)
		# Cria heatmap combinado de moedas da sala
		var combined_coins_heat = create_same_element_type_combined_heatmap(room_coins_heatmaps)
		UHeat.heatmaps["coins"].append(combined_coins_heat)
		# Cria heatmap combinado de inimigos da sala
		var combined_enemies_heat = create_same_element_type_combined_heatmap(room_enemies_heatmaps)
		UHeat.heatmaps["enemies"].append(combined_enemies_heat)
		# Cria heatmap combinado de banners da sala
		var combined_banners_heat = create_same_element_type_combined_heatmap(room_banners_heatmaps)
		UHeat.heatmaps["banners"].append(combined_banners_heat)
		# Cria heatmap combinado de todos os elementos de uma sala
		var combined_heat = UHeat.create_combined_heatmap(combined_banners_heat, combined_enemies_heat, combined_coins_heat)
		UHeat.heatmaps["combined"].append(combined_heat) 
