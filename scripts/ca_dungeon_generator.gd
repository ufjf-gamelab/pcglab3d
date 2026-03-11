extends Node

const ROOM_MIN_WIDTH = 6 * UGen.SCALE_FACTOR
const ROOM_MAX_WIDTH = 12 * UGen.SCALE_FACTOR
const ROOM_MIN_LENGTH = 6 * UGen.SCALE_FACTOR
const ROOM_MAX_LENGTH = 12 * UGen.SCALE_FACTOR

const P_WALL := 0.45
const GEN_CA := 5
const N_NEIGHBOR := 5

const MIN_TILES := 10

const CONNECT_SMALL_REGIONS = true

const BASE_2D_DIRECTIONS := [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1)
]

func generate_dungeon_ca(gridmap: GridMap, map_size: int = UGen.MAP_SIZE, room_count: int = UGen.ROOM_COUNT):
	print("Gerando Dungeon...")
	UGen.portal_links = {}
	UHeat.heatmaps["enemies"] = []
	UHeat.heatmaps["coins"] = []
	UHeat.heatmaps["banners"] = []
	UHeat.heatmaps["combined"] = []
	
	# Limpa as salas existentes	
	UGen.rooms.clear()
	
	# Limpa todo o GridMap
	gridmap.clear()
	
	# Preenche o mapa todo com paredes de solo
	UGen.fill_map_with_solids(gridmap, map_size)

	var occupied := {}

	var rooms_created := 0
	var attempts := 0

	while rooms_created < room_count and attempts < UGen.ATTEMPTS:

		var room_width = randi_range(ROOM_MIN_WIDTH, ROOM_MAX_WIDTH)
		var room_height = randi_range(ROOM_MIN_LENGTH, ROOM_MAX_LENGTH)

		var room_tiles = generate_ca_room(room_width, room_height)
		
		if len(room_tiles) < MIN_TILES:
			attempts += 1
			continue
		
		var regions = get_room_regions(room_tiles)
		if len(regions) > 1:
			print("Sala particionada detectada")
			regions.sort_custom(func(a,b): return a.size() > b.size())
			var main_region = regions[0]
			if CONNECT_SMALL_REGIONS:
				for i in range(1, len(regions)):
					connect_regions(main_region, regions[i], room_tiles)
			else:
				room_tiles = main_region
		
		var offset_x = randi_range(1, map_size - room_width - 1)
		var offset_y = randi_range(1, map_size - room_height - 1)

		if is_room_valid(room_tiles, offset_x, offset_y, occupied, map_size):

			var room = create_room(gridmap, room_tiles, offset_x, offset_y)
			
			UGen.rooms.append(room)

			for tile in room_tiles:
				occupied[Vector2i(tile.x + offset_x, tile.y + offset_y)] = true

			rooms_created += 1
		else:
			attempts += 1

	print("Salas criadas: ", rooms_created)
	
	# Cria paredes 'internas'
	UGen.add_room_walls(gridmap, map_size)

func generate_ca_room(width: int, height: int) -> Array[Vector2i]:
	var grid = []

	# Inicialização aleatória
	for x in range(width):
		grid.append([])
		for y in range(height):
			if randf() < P_WALL:
				grid[x].append(UGen.SOLID_ID) # parede
			else:
				grid[x].append(UGen.FLOOR_ID) # chão

	# Gerações de automatos celulares
	for i in range(GEN_CA):
		grid = cellular_gen(grid, width, height)

	var floor_tiles: Array[Vector2i] = []

	for x in range(width):
		for y in range(height):
			if grid[x][y] == UGen.FLOOR_ID:
				floor_tiles.append(Vector2i(x, y))

	return floor_tiles
	
func cellular_gen(grid, width, height):
	var new_grid = []

	for x in range(width):
		new_grid.append([])
		for y in range(height):
			var neighbors = count_wall_neighbors(grid, x, y, width, height)
			if neighbors >= N_NEIGHBOR:
				new_grid[x].append(UGen.SOLID_ID)
			else:
				new_grid[x].append(UGen.FLOOR_ID)

	return new_grid
	
func count_wall_neighbors(grid, x, y, width, height):
	var count = 0
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:

			if dx == 0 and dy == 0:
				continue

			var nx = x + dx
			var ny = y + dy
			
			# Considera fora do mapa como parede
			if nx < 0 or ny < 0 or nx >= width or ny >= height or grid[nx][ny] == 1:
				count += 1

	return count
		
func is_room_valid(room_tiles, offset_x, offset_y, occupied, map_size):
	for tile in room_tiles:
		var world_pos = Vector2i(tile.x + offset_x, tile.y + offset_y)
		
		if world_pos.x <= 0 or world_pos.y <= 0:
			return false
		elif world_pos.x >= map_size-1 or world_pos.y >= map_size-1:
			return false
			
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var neighbor_pos = world_pos + Vector2i(dx, dy)
				if occupied.has(neighbor_pos):
					return false

	return true

func create_room(gridmap: GridMap, room_tiles, offset_x, offset_y) -> Array[Vector3i]:
	var room : Array[Vector3i] = []
	for tile in room_tiles:
		var world_x = tile.x + offset_x
		var world_y = tile.y + offset_y
		var world_vector = Vector3i(world_x, 0, world_y)
		room.append(world_vector)
		gridmap.set_cell_item(world_vector, UGen.FLOOR_ID)
	return room

func spawn_dungeon_elements(gridmap: GridMap):
	UGen.spawn_dungeon_elements(gridmap)

func get_room_regions(room):
	var visited = []
	var regions = []

	for tile in room:
		if not visited.has(tile):
			var region = flood_fill(tile, room, visited)
			regions.append(region)

	return regions

func flood_fill(start, room, visited):
	var queue = [start]
	var region = []

	while queue.size() > 0:
		var current_tile = queue.pop_front()
		if visited.has(current_tile):
			continue
			
		visited.append(current_tile)
		region.append(current_tile)

		for dir in BASE_2D_DIRECTIONS:
			var neighbor_pos = current_tile + dir
			if room.has(neighbor_pos):
				queue.append(neighbor_pos)
	return region

func connect_regions(main_region, secondary_region, room_tiles):
	var best_main
	var best_sec
	var best_dist = INF

	for main_tile in main_region:
		for sec_tile in secondary_region:
			var d = main_tile.distance_to(sec_tile)

			if d < best_dist:
				best_dist = d
				best_main = main_tile
				best_sec = sec_tile

	create_corridor(best_main, best_sec, room_tiles)
	
func create_corridor(main_tile, sec_tile, room_tiles):
	var current = main_tile

	while current.x != sec_tile.x:
		current.x += sign(sec_tile.x - current.x)
		if not room_tiles.has(current):
			room_tiles.append(current)
		
	while current.y != sec_tile.y:
		current.y += sign(sec_tile.y - current.y)
		if not room_tiles.has(current):
			room_tiles.append(current)
