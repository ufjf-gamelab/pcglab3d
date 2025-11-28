extends Node

# IDs Array de Structures
const WALL_ID = 0
const SOLID_ID = 1
const FLOOR_ID = 2
const COIN_ID = 3
const NPC_ID = 4
const PORTAL_ID = 5

const BORDER_MARGIN = 1 # Borda mínima do tile de chão
const ATTEMPTS = 1000 # Número de tentativas de geração de salas

# Gera N salas da dungeon
func generate_dungeon(target_grid_map: GridMap, map_size: int = 40, room_count: int = 8):
	print("Gerando Dungeon...")
	
	# Limpa todo o GridMap
	target_grid_map.clear()
	
	# Preenche o mapa todo com paredes de solo
	fill_map_with_solids(target_grid_map, map_size)
	
	# Lista para guardar as partes de salas já criadas
	var existing_rects: Array[Rect2i] = []
	
	var rooms_created = 0
	var attempts = 0
	
	# Tenta criar as N salas
	while rooms_created < room_count and attempts < ATTEMPTS:
		# Escolhe aleatoriamente um tipo de sala
		var room_type = randi() % 3
		var candidate_shape: Array[Rect2i] = []
		
		match room_type:
			0: candidate_shape = create_rect_room(map_size)
			1: candidate_shape = create_cross_room(map_size)
			2: candidate_shape = create_t_room(map_size)
		
		# Verifica 'colisão' entre salas e limites do mapa
		if is_shape_valid(candidate_shape, existing_rects, map_size):
			# Cria a sala
			create_shape(target_grid_map, candidate_shape)
			
			# Adiciona Moeda e NPC nesta sala recém criada
			spawn_room_objects(target_grid_map, candidate_shape)
			
			# Adiciona sala no Array de salas existentes
			existing_rects.append_array(candidate_shape)
			rooms_created += 1
		else:
			attempts += 1
			
	if rooms_created < room_count:
		print("Aviso: ", rooms_created, " salas foram criadas em ", ATTEMPTS, " tentativas.")
	else:
		print("Todas as ", room_count, " foram criadas.")

	# Cria paredes 'internas'
	add_room_walls(target_grid_map, map_size)

# Cria sala retangular
func create_rect_room(map_size: int) -> Array[Rect2i]:
	var w = randi_range(6, 12)
	var h = randi_range(6, 12)
	var x = randi_range(BORDER_MARGIN, map_size - w - BORDER_MARGIN)
	var y = randi_range(BORDER_MARGIN, map_size - h - BORDER_MARGIN)
	
	return [Rect2i(x, y, w, h)]

# Cria sala em cruz
func create_cross_room(map_size: int) -> Array[Rect2i]:
	# Define largura e comprimento
	var long_side = randi_range(10, 14)
	var thickness = randi_range(4, 6)
	
	# Ponto central
	var cx = randi_range(6, map_size - 6)
	var cy = randi_range(6, map_size - 6)
	
	# Retângulo horizontal
	var rect_h = Rect2i(cx - int(long_side/2.0), cy - int(thickness/2.0), long_side, thickness)
	
	# Retângulo vertical
	var rect_v = Rect2i(cx - int(thickness/2.0), cy - int(long_side/2.0), thickness, long_side)
	
	return [rect_h, rect_v]

# Cria sala em T
func create_t_room(map_size: int) -> Array[Rect2i]:
	var top_w = randi_range(10, 14) # Largura do retangulo superior
	var top_h = randi_range(4, 6)   # Altura do retangulo superior
	var stem_w = randi_range(4, 6)  # Largura do retangulo central
	var stem_h = randi_range(6, 10) # Altura do retangulo central
	
	# Ponto superior esquerdo do retangulo superior
	var tx = randi_range(4, map_size - top_w - 4)
	var ty = randi_range(4, map_size - (top_h + stem_h) - 4)
	
	var rect_top = Rect2i(tx, ty, top_w, top_h)
	
	# Ponto do meio do retangulo superior
	var stem_x = tx + int(top_w / 2.0) - int(stem_w / 2.0)
	var stem_y = ty + int(top_h / 2.0)
	
	var rect_stem = Rect2i(stem_x, stem_y, stem_w, stem_h)
	
	return [rect_top, rect_stem]

# Verifica se o formato/posição é válido
func is_shape_valid(new_shape: Array[Rect2i], existing_shapes: Array[Rect2i], map_size: int) -> bool:
	for part in new_shape:
		# Verifica se está nos limites do mapa
		if part.position.x < BORDER_MARGIN or part.position.y < BORDER_MARGIN:
			return false
		if part.end.x > map_size - BORDER_MARGIN or part.end.y > map_size - BORDER_MARGIN:
			return false
			
		# Verifica colisão com outras salas
		for other in existing_shapes:
			# Garante pelo menos 2 blocos de parede entre o chão de salas diferentes
			if part.grow(2).intersects(other):
				return false
	return true

# Cria sala no GridMap
func create_shape(grid: GridMap, shape: Array[Rect2i]):
	for rect in shape:
		# Preenche com chão
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				grid.set_cell_item(Vector3i(x, 0, z), FLOOR_ID)

func fill_map_with_solids(grid: GridMap, size: int):
	for x in range(size):
		for z in range(size):
			grid.set_cell_item(Vector3i(x, 0, z), SOLID_ID)

# Adiciona paredes internas
func add_room_walls(grid: GridMap, size: int):
	for x in range(size):
		for z in range(size):
			var pos = Vector3i(x, 0, z)
			var id = grid.get_cell_item(pos)
			
			# Se é um bloco preto e tem chão em volta, vira parede
			if id == SOLID_ID:
				if is_touching_floor(grid, x, z):
					grid.set_cell_item(pos, WALL_ID)

# Verifica se tem chão na vizinhança
func is_touching_floor(grid: GridMap, x: int, z: int) -> bool:
	# Percorre de x-1 até x+1 e z-1 até z+1
	for offset_x in [-1, 0, 1]:
		for offset_z in [-1, 0, 1]:
			
			# Pula a checagem do próprio bloco central (0,0)
			if offset_x == 0 and offset_z == 0:
				continue
			
			var neighbor_pos = Vector3i(x + offset_x, 0, z + offset_z)
			var neighbor_id = grid.get_cell_item(neighbor_pos)
			
			# Se algum vizinho for chão, retorna verdadeiro
			if neighbor_id == FLOOR_ID or neighbor_id == COIN_ID or neighbor_id == PORTAL_ID or neighbor_id == NPC_ID:
				return true
				
	return false
	
# Posiciona 1 Moeda e 1 NPC em posições aleatórias dentro da sala
func spawn_room_objects(grid: GridMap, shape: Array[Rect2i]):
	var available_spots: Array[Vector3i] = []
	
	# Coleta todos os blocos de chão disponíveis na forma da sala
	for rect in shape:
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				var pos = Vector3i(x, 0, z)
				# Evita duplicatas
				if not pos in available_spots:
					available_spots.append(pos)
	
	var portal1_pos = Vector3i()
	var portal2_pos = Vector3i()
	var max_dist_sq = -1.0
	
	# Compara todos os pontos com todos os pontos para achar a maior distância
	if available_spots.size() >= 2:
		for i in range(available_spots.size()):
			for j in range(i + 1, available_spots.size()):
				var p1 = available_spots[i]
				var p2 = available_spots[j]
				var dist = Vector3(p1).distance_squared_to(Vector3(p2))
				
				if dist > max_dist_sq:
					max_dist_sq = dist
					portal1_pos = p1
					portal2_pos = p2
		
		# Posiciona os portais
		grid.set_cell_item(portal1_pos, PORTAL_ID)
		grid.set_cell_item(portal2_pos, PORTAL_ID)
		
		# Remove as posições usadas pelos portais
		available_spots.erase(portal1_pos)
		available_spots.erase(portal2_pos)
	
	# Embaralha os locais disponíveis
	available_spots.shuffle()
	
	# Posiciona a moeda no primeiro slot disponível
	if available_spots.size() > 0:
		grid.set_cell_item(available_spots.pop_front(), COIN_ID)
		
	# Posiciona o NPC no próximo slot disponível
	if available_spots.size() > 0:
		grid.set_cell_item(available_spots.pop_front(), NPC_ID)
