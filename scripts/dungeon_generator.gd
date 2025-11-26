extends Node

# IDs Array de Structures
const WALL_ID = 0
const SOLID_ID = 1
const FLOOR_ID = 2

# Gera N salas da dungeon
func generate_dungeon(target_grid_map: GridMap, map_size: int = 40, room_count: int = 5):
	print("Gerando Dungeon...")
	
	# Limpa todo o GridMap
	target_grid_map.clear()
	
	# Preenche o mapa todo com paredes de solo
	fill_map_with_soil_wall(target_grid_map, map_size)
	
	# Lista para guardar o retângulo das salas inseridas
	var existing_rooms: Array[Rect2i] = []
	
	var rooms_created = 0
	var attempts = 0
	var max_attempts = 100 
	
	# Tenta criar as N salas
	while rooms_created < room_count and attempts < max_attempts:
		var w = randi_range(6, 12)
		var h = randi_range(6, 12)
		var x = randi_range(2, map_size - w - 2)
		var y = randi_range(2, map_size - h - 2)
		
		var new_room_rect = Rect2i(x, y, w, h)
		
		#  Verifica 'colisão' entre salas
		var has_collision = false
		for other_room in existing_rooms:
			# Verifica se as salas têm pelo menos uma parede de solo entre si
			if new_room_rect.grow(1).intersects(other_room):
				has_collision = true
				break
		
		if has_collision:
			attempts += 1
			continue 
		
		# Cria a sala
		create_room(target_grid_map, new_room_rect)
		
		# Adiciona sala no Array de salas existentes
		existing_rooms.append(new_room_rect)
		rooms_created += 1
	
	if rooms_created < room_count:
		print("Aviso: ", rooms_created, " salas foram criadas em ", max_attempts, " tentativas.")
	else:
		print("Todas as ", room_count, " foram criadas.")

# Preenche o mapa com paredes de solo
func fill_map_with_soil_wall(grid: GridMap, size: int):
	for x in range(size):
		for z in range(size):
			grid.set_cell_item(Vector3i(x, 0, z), SOLID_ID)

# Cria sala no GridMap
func create_room(grid: GridMap, rect: Rect2i):
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			var pos = Vector3i(x, 0, z)
			
			var is_left = (x == rect.position.x)
			var is_right = (x == rect.end.x - 1)
			var is_top = (z == rect.position.y)
			var is_bottom = (z == rect.end.y - 1)
			
			if is_left or is_right or is_top or is_bottom:
				grid.set_cell_item(pos, WALL_ID)
			else:
				grid.set_cell_item(pos, FLOOR_ID)
