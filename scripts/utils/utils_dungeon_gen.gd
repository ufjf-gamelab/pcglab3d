extends Node

# IDs Array de Structures
const WALL_ID = 0
const SOLID_ID = 1
const FLOOR_ID = 2
const COIN_ID = 3
const NPC_ID = 4
const PORTAL_ID = 5
const PLAYER_SPAWN_ID = 6
const BANNER_ID = 7

const ATTEMPTS = 200 # Número de tentativas de geração de salas

const MAP_SIZE = 40 * SCALE_FACTOR # Tamanho do mapa
const ROOM_COUNT = 8 # Número de salas

# Fator de escala
const SCALE_FACTOR = 1

var rooms = [] # Array[Array[Vector3i]]
var rooms_elements_pos = []

var portal_links: Dictionary = {}
var firstPortal: Vector3i
var lastPortal: Vector3i

var ENEMIES_RATE = UHeat.MAX_DISTANCE[UHeat.ENEMIES] * UHeat.MAX_DISTANCE[UHeat.ENEMIES]
var COINS_RATE = UHeat.MAX_DISTANCE[UHeat.COINS] * UHeat.MAX_DISTANCE[UHeat.COINS]
var BANNERS_RATE = UHeat.MAX_DISTANCE[UHeat.BANNERS] * UHeat.MAX_DISTANCE[UHeat.BANNERS]

# 1 elemento a mais a cada N tiles
var rate_element_tiles = {
	UHeat.ENEMIES: ENEMIES_RATE,
	UHeat.COINS: COINS_RATE,
	UHeat.BANNERS: BANNERS_RATE
}

# Quantidade de elementos em cada sala
var rooms_elements_quantity = {}

var room_coins_heatmap = {}
var room_banners_heatmap = {}
var room_enemies_heatmap = {}

var room_entry_portals_heatmap = {}
var room_exit_portals_heatmap = {}

enum Spawn { RANDOM, SMART }

var SPAWN: Spawn = Spawn.RANDOM

func update_elements_pos(gridmap: GridMap):
	clear_elements_pos()
	
	for i in range(rooms.size()):
		var room = rooms[i]
		var elements_pos = rooms_elements_pos[i]
		
		for pos in room:
			match gridmap.get_cell_item(pos):
				NPC_ID:
					elements_pos["npc_pos"].append(pos)
				COIN_ID:
					elements_pos["coin_pos"].append(pos)
				BANNER_ID:
					elements_pos["banner_pos"].append(pos)

func clear_elements_pos():
	for room in rooms_elements_pos:
		room["coin_pos"].clear()
		room["banner_pos"].clear()
		room["npc_pos"].clear()

# Preenche o espaço todo do mapa com paredes sólidas
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
			if id == UGen.SOLID_ID:
				if is_touching_floor(grid, x, z):
					grid.set_cell_item(pos, UGen.WALL_ID)

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
			if (neighbor_id == UGen.FLOOR_ID or neighbor_id == UGen.COIN_ID or neighbor_id == UGen.PORTAL_ID 
			or neighbor_id == UGen.NPC_ID or neighbor_id == UGen.PLAYER_SPAWN_ID or neighbor_id == UGen.BANNER_ID):
				return true
				
	return false

# Posiciona elementos na dungeon
func spawn_dungeon_elements(gridmap: GridMap):
	rooms_elements_quantity.clear()
	
	# Inicia true para spawnar player na primeira sala
	var spawn_player = true
	
	for i in range(UGen.rooms.size()):
		spawn_room_elements(gridmap, UGen.rooms[i].duplicate(), i, spawn_player)
		spawn_player = false
		
	# Linka os dois últimos portais
	UGen.portal_links[UGen.lastPortal] = UGen.firstPortal
	UGen.portal_links[UGen.firstPortal] = UGen.lastPortal

# Posiciona elementos na sala
func spawn_room_elements(gridmap: GridMap, available_spots: Array[Vector3i], room_index: int, spawn_player: bool = false):
	room_coins_heatmap = {}
	room_banners_heatmap = {}
	room_enemies_heatmap = {}
	room_entry_portals_heatmap = {}
	room_exit_portals_heatmap = {}
	
	var room_portals = _handle_room_portals_spawn(gridmap, available_spots)
	if room_portals.size() == 0:
		print("Posicionamento de elementos não pôde continuar devido à falta de espaços livres.")
		return
	# Captura o heatmap do portal de entrada recém criado
	room_entry_portals_heatmap = UHeat.heatmaps[UHeat.ENTRY_PORTALS].back()
	# Captura o heatmap do portal de saída recém criado
	room_exit_portals_heatmap = UHeat.heatmaps[UHeat.EXIT_PORTALS].back()
	
	# Caulcula a quantidade de elementos da sala
	_calculate_elements_quantity(room_index, available_spots.size())
	var room_elements_quantity = rooms_elements_quantity[room_index]
	
	# Embaralha os locais disponíveis
	available_spots.shuffle()
	
	# Moedas: longe da entrada, espalhadas entre si
	var coins_recipe = SpawnRecipe.new(
		UHeat.COINS, UGen.COIN_ID,                             
		SpawnRecipe.Selection.GREATEST,      
		[],                                
		[room_entry_portals_heatmap, room_exit_portals_heatmap],      
		true,                              
		SpawnRecipe.SpawnMode.FIXED_QUANTITY
	)
	
	var room_coins_pos = coins_recipe.execute(gridmap, room_elements_quantity[UHeat.COINS], available_spots)
	room_coins_heatmap = UHeat.heatmaps[UHeat.COINS].back()
 
	# Inimigos: longe da entrada, próximos às moedas, espalhados entre si
	var enemies_recipe = SpawnRecipe.new(
		UHeat.ENEMIES, UGen.NPC_ID,                           
		SpawnRecipe.Selection.GREATEST,    
		[room_coins_heatmap],             
		[room_entry_portals_heatmap, room_exit_portals_heatmap],      
		true,                              
		SpawnRecipe.SpawnMode.FIXED_QUANTITY
	)

	var room_enemies_pos = enemies_recipe.execute(gridmap, room_elements_quantity[UHeat.ENEMIES], available_spots)
	room_enemies_heatmap = UHeat.heatmaps[UHeat.ENEMIES].back()
 
	# Estandartes: longe de ambos os portais, espalhados entre si
	var room_portals_heatmap = UHeat.sum_heatmaps(room_entry_portals_heatmap, room_exit_portals_heatmap)
	var banners_recipe = SpawnRecipe.new(
		UHeat.BANNERS, UGen.BANNER_ID,                                            
		SpawnRecipe.Selection.GREATEST,                   
		[],                                             
		[room_portals_heatmap],                          
		true,                                            
		SpawnRecipe.SpawnMode.UNTIL_NO_VALID_TILE,       
		func(tile, heatmap):                             
			return (is_zero_approx(heatmap[tile]) and
				UHeat.has_neighbor_below_zero(tile, heatmap))
	)

	var room_banners_pos = banners_recipe.execute(gridmap, room_elements_quantity[UHeat.BANNERS], available_spots)
	room_banners_heatmap = UHeat.heatmaps[UHeat.BANNERS].back()
	
	# Salva posições dos elementos da sala
	var elements_pos = {
		"portal1_pos": room_portals[0],
		"portal2_pos": room_portals[1],
		"coin_pos": room_coins_pos,
		"npc_pos": room_enemies_pos,
		"banner_pos": room_banners_pos
	}
	rooms_elements_pos.append(elements_pos)
	
	# Cria heatmap combinado de todos os elementos da sala
	var combined_heat = UHeat.create_combined_heatmap([room_coins_heatmap], [room_enemies_heatmap])
	UHeat.heatmaps["combined"].append(combined_heat) 

	# Posiciona o spawn do player se for nesta sala 
	if spawn_player and available_spots.size() > 0:
		var player_recipe = SpawnRecipe.new(
			UHeat.PLAYER, UGen.PLAYER_SPAWN_ID,
			SpawnRecipe.Selection.BALANCED,
			[],
			[room_entry_portals_heatmap, room_exit_portals_heatmap, room_enemies_heatmap],
			false,
			SpawnRecipe.SpawnMode.FIXED_QUANTITY
		)
		player_recipe.execute(gridmap, 1, available_spots)

# Posiciona portais em uma sala
func _handle_room_portals_spawn(gridmap: GridMap, available_spots: Array[Vector3i]) -> Array[Vector3i]:
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
		gridmap.set_cell_item(portal1_pos, UGen.PORTAL_ID)
		gridmap.set_cell_item(portal2_pos, UGen.PORTAL_ID)
		
		var curr_portal_keys = UGen.portal_links.keys()
		if len(curr_portal_keys) == 0:
			UGen.firstPortal = portal1_pos
			UGen.lastPortal = portal2_pos
			UGen.portal_links[portal1_pos] = null
			UGen.portal_links[portal2_pos] = null
		else:
			UGen.portal_links[UGen.lastPortal] = portal1_pos
			UGen.portal_links[portal1_pos] = UGen.lastPortal
			UGen.lastPortal = portal2_pos
		
		# Remove as posições usadas pelos portais
		available_spots.erase(portal1_pos)
		available_spots.erase(portal2_pos)
		
		# Cria heatmap do portal de entrada (portal1)
		var portal1_heat = UHeat.create_heatmap_bfs(gridmap, portal1_pos, UHeat.ENTRY_PORTALS)
		UHeat.heatmaps[UHeat.ENTRY_PORTALS].append(portal1_heat)
		
		# Cria heatmap do portal de saída (portal2)
		var portal2_heat = UHeat.create_heatmap_bfs(gridmap, portal2_pos, UHeat.EXIT_PORTALS)
		UHeat.heatmaps[UHeat.EXIT_PORTALS].append(portal2_heat)
		
		return [portal1_pos, portal2_pos]
	else:
		print("Sem dois espaços livres para posicionar os portais.")
		return []

# Calcula a quantidade de elementos em cada sala
func _calculate_elements_quantity(room_index: int, tile_count: int):
	rooms_elements_quantity[room_index] = {
		UHeat.ENEMIES: max(1, tile_count / rate_element_tiles[UHeat.ENEMIES]),
		UHeat.COINS:   max(1, tile_count / rate_element_tiles[UHeat.COINS]),
		UHeat.BANNERS: max(1, tile_count / rate_element_tiles[UHeat.BANNERS])
	}
	#print("Sala %d | Tiles: %d | Inimigos: %d | Moedas: %d | Estandartes: %d" % [
		#room_index, tile_count,
		#rooms_elements_quantity[room_index][UHeat.ENEMIES],
		#rooms_elements_quantity[room_index][UHeat.COINS],
		#rooms_elements_quantity[room_index][UHeat.BANNERS]
	#])
