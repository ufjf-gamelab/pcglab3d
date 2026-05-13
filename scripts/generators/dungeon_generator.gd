extends Node

const BORDER_MARGIN = 1 # Borda mínima do tile de chão

# Sala retangular
const RECT_MIN_WIDTH = 6 * UGen.SCALE_FACTOR
const RECT_MAX_WIDTH = 12 * UGen.SCALE_FACTOR
const RECT_MIN_HEIGHT = 6 * UGen.SCALE_FACTOR
const RECT_MAX_HEIGHT = 12 * UGen.SCALE_FACTOR

# Sala em cruz
const CROSS_MIN_LENGTH = 10 * UGen.SCALE_FACTOR
const CROSS_MAX_LENGTH = 14 * UGen.SCALE_FACTOR
const CROSS_MIN_THICKNESS = 4 * UGen.SCALE_FACTOR
const CROSS_MAX_THICKNESS = 6 * UGen.SCALE_FACTOR

# Sala em T
const T_TOP_RECT_MIN_WIDTH = 10 * UGen.SCALE_FACTOR
const T_TOP_RECT_MAX_WIDTH = 14 * UGen.SCALE_FACTOR
const T_TOP_RECT_MIN_HEIGHT = 4 * UGen.SCALE_FACTOR
const T_TOP_RECT_MAX_HEIGHT = 6 * UGen.SCALE_FACTOR
const T_CENTRAL_RECT_MIN_WIDTH = 4 * UGen.SCALE_FACTOR
const T_CENTRAL_RECT_MAX_WIDTH = 6 * UGen.SCALE_FACTOR
const T_CENTRAL_RECT_MIN_HEIGHT = 6 * UGen.SCALE_FACTOR
const T_CENTRAL_RECT_MAX_HEIGHT = 10 * UGen.SCALE_FACTOR

var rect_rooms := [] # Array[Array[Rect2i]]

# Gera N salas da dungeon
func generate_dungeon(gridmap: GridMap, map_size: int = UGen.MAP_SIZE, room_count: int = UGen.ROOM_COUNT):
	print("Gerando Dungeon...")
	UGen.portal_links = {}
	UHeat.heatmaps["enemies"] = []
	UHeat.heatmaps["coins"] = []
	UHeat.heatmaps["banners"] = []
	UHeat.heatmaps["combined"] = []
	
	# Limpa lista de salas	
	rect_rooms.clear()
	
	# Limpa as salas existentes e seus elementos
	UGen.rooms.clear()
	UGen.rooms_elements_pos.clear()
	
	# Limpa todo o GridMap
	gridmap.clear()
	
	# Preenche o mapa todo com paredes de solo
	UGen.fill_map_with_solids(gridmap, map_size)
	
	# Lista para guardar as partes de salas já criadas
	var existing_rects: Array[Rect2i] = []
	
	var rooms_created = 0
	var attempts = 0
	
	# Tenta criar as N salas
	while rooms_created < room_count and attempts < UGen.ATTEMPTS:
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
			create_shape(gridmap, candidate_shape)
			
			# Adiciona sala no array de salas
			rect_rooms.append(candidate_shape)
			
			# Adiciona retângulos da sala no array de retângulos existentes
			existing_rects.append_array(candidate_shape)
			rooms_created += 1
		else:
			attempts += 1
			
	if rooms_created < room_count:
		print("Aviso: ", rooms_created, " salas foram criadas em ", UGen.ATTEMPTS, " tentativas.")
	else:
		print("Todas as ", room_count, " salas foram criadas.")

	# Cria paredes 'internas'
	UGen.add_room_walls(gridmap, map_size)
	
# Cria sala retangular
func create_rect_room(map_size: int) -> Array[Rect2i]:
	var w = randi_range(RECT_MIN_WIDTH, RECT_MAX_WIDTH)
	var h = randi_range(RECT_MIN_HEIGHT, RECT_MAX_HEIGHT)
	var x = randi_range(BORDER_MARGIN, map_size - w - BORDER_MARGIN)
	var y = randi_range(BORDER_MARGIN, map_size - h - BORDER_MARGIN)
	
	return [Rect2i(x, y, w, h)]

# Cria sala em cruz
func create_cross_room(map_size: int) -> Array[Rect2i]:
	# Define largura e comprimento
	var length = randi_range(CROSS_MIN_LENGTH, CROSS_MAX_LENGTH)
	var thickness = randi_range(CROSS_MIN_THICKNESS, CROSS_MAX_THICKNESS)
	
	# Ponto central
	var cx = randi_range(int(CROSS_MAX_LENGTH/2.0), map_size - int(CROSS_MAX_LENGTH/2.0))
	var cy = randi_range(int(CROSS_MAX_LENGTH/2.0), map_size - int(CROSS_MAX_LENGTH/2.0))
	
	# Retângulo horizontal
	var rect_h = Rect2i(cx - int(length/2.0), cy - int(thickness/2.0), length, thickness)
	
	# Retângulo vertical
	var rect_v = Rect2i(cx - int(thickness/2.0), cy - int(length/2.0), thickness, length)
	
	return [rect_h, rect_v]

# Cria sala em T
func create_t_room(map_size: int) -> Array[Rect2i]:
	var top_w = randi_range(T_TOP_RECT_MIN_WIDTH, T_TOP_RECT_MAX_WIDTH) # Largura do retangulo superior
	var top_h = randi_range(T_TOP_RECT_MIN_HEIGHT, T_TOP_RECT_MAX_HEIGHT)   # Altura do retangulo superior
	var central_w = randi_range(T_CENTRAL_RECT_MIN_WIDTH, T_CENTRAL_RECT_MAX_WIDTH)  # Largura do retangulo central
	var central_h = randi_range(T_CENTRAL_RECT_MIN_HEIGHT, T_CENTRAL_RECT_MAX_HEIGHT) # Altura do retangulo central
	
	# Ponto superior esquerdo do retangulo superior
	var tx = randi_range(BORDER_MARGIN, map_size - top_w - BORDER_MARGIN)
	var ty = randi_range(BORDER_MARGIN, map_size - (top_h + central_h) - BORDER_MARGIN)
	
	var rect_top = Rect2i(tx, ty, top_w, top_h)
	
	# Ponto do meio do retangulo superior
	var central_x = tx + int(top_w / 2.0) - int(central_w / 2.0)
	var central_y = ty + int(top_h / 2.0)
	
	var rect_central = Rect2i(central_x, central_y, central_w, central_h)
	
	return [rect_top, rect_central]

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
			if part.grow(1).intersects(other):
				return false
	return true

func spawn_dungeon_elements(gridmap: GridMap):
	dungeon_room_rects_to_tiles()
	UGen.spawn_dungeon_elements(gridmap)

# Cria sala no GridMap
func create_shape(grid: GridMap, shape: Array[Rect2i]):
	for rect in shape:
		# Preenche com chão
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				grid.set_cell_item(Vector3i(x, 0, z), UGen.FLOOR_ID)

func dungeon_room_rects_to_tiles():
	for room in rect_rooms:
		UGen.rooms.append(room_rects_to_tiles(room))

func room_rects_to_tiles(shape: Array[Rect2i]):
	var available_spots: Array[Vector3i] = []
	
	# Coleta todos os blocos de chão disponíveis na forma da sala
	for rect in shape:
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				var pos = Vector3i(x, 0, z)
				# Evita duplicatas
				if not pos in available_spots:
					available_spots.append(pos)
					
	return available_spots
