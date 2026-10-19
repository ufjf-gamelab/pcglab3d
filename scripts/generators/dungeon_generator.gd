extends Node

const BORDER_MARGIN = 1 # Borda mínima do tile de chão

var ROOM_MIN_WIDTH = 8 * UGen.SCALE_FACTOR
var ROOM_MAX_WIDTH = 10 * UGen.SCALE_FACTOR
var ROOM_MIN_LENGTH = 8 * UGen.SCALE_FACTOR
var ROOM_MAX_LENGTH = 10 * UGen.SCALE_FACTOR

var rect_rooms := [] # Array[Array[Rect2i]]

# Gera N salas da dungeon
func generate_dungeon(gridmap: GridMap, map_size: int = UGen.MAP_SIZE, room_count: int = UGen.ROOM_COUNT):
	print("Gerando Dungeon...")
	UGen.portal_links = {}
	
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
	var w = randi_range(ROOM_MIN_WIDTH, ROOM_MAX_WIDTH)
	var h = randi_range(ROOM_MIN_LENGTH, ROOM_MAX_LENGTH)
	var x = randi_range(BORDER_MARGIN, map_size - w - BORDER_MARGIN)
	var y = randi_range(BORDER_MARGIN, map_size - h - BORDER_MARGIN)
	
	return [Rect2i(x, y, w, h)]

# Cria sala em cruz
func create_cross_room(map_size: int) -> Array[Rect2i]:
	var length = randi_range(ROOM_MIN_LENGTH * UGen.SCALE_FACTOR, ROOM_MAX_LENGTH * UGen.SCALE_FACTOR)
	var thickness = randi_range(max(3, int(length * 0.33)), int(length * 0.5))

	var cx = randi_range(int(length * 0.5) + BORDER_MARGIN, map_size - int(length * 0.5) - BORDER_MARGIN)
	var cy = randi_range(int(length * 0.5) + BORDER_MARGIN, map_size - int(length * 0.5) - BORDER_MARGIN)

	var rect_h = Rect2i(cx - int(length * 0.5), cy - int(thickness * 0.5), length, thickness)
	var rect_v = Rect2i(cx - int(thickness * 0.5), cy - int(length * 0.5), thickness, length)

	return [rect_h, rect_v]

# Cria sala em T
func create_t_room(map_size: int) -> Array[Rect2i]:
	var total_w = randi_range(ROOM_MIN_WIDTH * UGen.SCALE_FACTOR, ROOM_MAX_WIDTH * UGen.SCALE_FACTOR)
	var total_h = randi_range(ROOM_MIN_LENGTH * UGen.SCALE_FACTOR, ROOM_MAX_LENGTH * UGen.SCALE_FACTOR)

	var top_h = randi_range(max(3, int(total_h * 0.33)), int(total_h * 0.5))
	var stem_h = total_h - top_h

	var stem_w = randi_range(max(3, int(total_w * 0.33)), int(total_w * 0.5))

	var x = randi_range(BORDER_MARGIN, map_size - total_w - BORDER_MARGIN)
	var y = randi_range(BORDER_MARGIN, map_size - total_h - BORDER_MARGIN)

	var rect_top = Rect2i(x, y, total_w, top_h)
	var rect_stem = Rect2i(x + int(total_w * 0.5) - int(stem_w * 0.5), y + top_h, stem_w, stem_h)

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

func set_room_size(min_size: int, max_size: int):
	ROOM_MIN_WIDTH  = min_size;  
	ROOM_MAX_WIDTH  = max_size
	ROOM_MIN_LENGTH = min_size;  
	ROOM_MAX_LENGTH = max_size
