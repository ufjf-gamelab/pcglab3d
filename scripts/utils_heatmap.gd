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

var enemy_heatmap_visible := false
var coin_heatmap_visible := false
var banner_heatmap_visible := false
var combined_heatmap_visible := false

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
				heatmap[neighbor] = heatmap[current] - 1 if positive_influence else heatmap[current] + 1
				if heatmap[current] != 0:
					heatmap[neighbor] = heatmap[current] - 1 if positive_influence else heatmap[current] + 1
				else:
					heatmap[neighbor] = 0
				queue.append(neighbor)
				
	return heatmap

# Cria heatmap combinando elementos da sala
func create_combined_heatmap(last_banner_heat, last_enemy_heat, last_coin_heat):
	var combined_heat = {}

	for key in last_coin_heat.keys():
		combined_heat[key] = last_banner_heat[key] + last_enemy_heat[key] + last_coin_heat[key]	
				
	return combined_heat	

func show_heatmaps(gridmap: GridMap, heatmaps, cell_size := 1.0):
	var total_instances := 0
	var global_max := 0
	var global_min := 10000
	for heatmap in heatmaps:
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
	for heatmap in heatmaps:
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

func toggle_enemy_heatmaps(gridmap: GridMap):
	if enemy_heatmap_visible:
		heatmap_multimesh.visible = false
		enemy_heatmap_visible = false
	else:
		var enemies_heatmaps = UGen.heatmaps["enemies"]
		show_heatmaps(gridmap, enemies_heatmaps)
		enemy_heatmap_visible = true
		
func toggle_coin_heatmaps(gridmap: GridMap):
	if coin_heatmap_visible:
		heatmap_multimesh.visible = false
		coin_heatmap_visible = false
	else:
		var coins_heatmaps = UGen.heatmaps["coins"]
		show_heatmaps(gridmap, coins_heatmaps)
		coin_heatmap_visible = true
		
func toggle_banner_heatmaps(gridmap: GridMap):
	if banner_heatmap_visible:
		heatmap_multimesh.visible = false
		banner_heatmap_visible = false
	else:
		var banners_heatmaps = UGen.heatmaps["banners"]
		show_heatmaps(gridmap, banners_heatmaps)
		banner_heatmap_visible = true

func toggle_combined_heatmaps(gridmap: GridMap):
	if combined_heatmap_visible:
		heatmap_multimesh.visible = false
		combined_heatmap_visible = false
	else:
		var combined_heatmaps = UGen.heatmaps["combined"]
		# Criar nova funcao para exibir cores sem necessidade de passar influencia?
		show_heatmaps(gridmap, combined_heatmaps) 
		combined_heatmap_visible = true
