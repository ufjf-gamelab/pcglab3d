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

const MAP_SIZE = 50 * SCALE_FACTOR # Tamanho do mapa
const ROOM_COUNT = 8 # Número de salas

# Fator de escala
const SCALE_FACTOR = 1

var rooms = [] # Array[Array[Vector3i]]
var rooms_elements_pos = []

var portal_links: Dictionary = {}
var firstPortal: Vector3i
var lastPortal: Vector3i

var room_elements_quantity = {
	"enemies": 3,
	"coins": 3,
	"banners": 1
}

enum Spawn { RANDOM, SMART }

const SPAWN = Spawn.SMART

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
	# Inicia true para spawnar player na primeira sala
	var spawn_player = true
	for room in UGen.rooms:
		if SPAWN == Spawn.RANDOM:
			spawn_room_elements_random(gridmap, room.duplicate(), spawn_player)
		elif SPAWN == Spawn.SMART:
			spawn_room_elements_smart(gridmap, room.duplicate(), spawn_player)
		else:
			print("Tipo de spawn de elementos inválido.")
			return
		spawn_player = false
	# Linka os dois últimos portais
	UGen.portal_links[UGen.lastPortal] = UGen.firstPortal
	UGen.portal_links[UGen.firstPortal] = UGen.lastPortal

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
		
		return [portal1_pos, portal2_pos]
	else:
		print("Sem dois espaços livres para posicionar os portais.")
		return []

# Posiciona elementos na sala aleatoriamente
func spawn_room_elements_random(gridmap: GridMap, available_spots: Array[Vector3i], spawn_player: bool = false):
	var room_portals = _handle_room_portals_spawn(gridmap, available_spots)
	if room_portals.size() == 0:
		print("Posicionamento de elementos não pôde continuar devido à falta de espaços livres.")
		return
	
	# Embaralha os locais disponíveis
	available_spots.shuffle()
	
	var last_coin_heat
	var coins_heats = []
	var coin_pos
	var room_coins_pos = []
	for _n in range(room_elements_quantity["coins"]):
		# Posiciona a moeda no primeiro slot disponível
		if available_spots.size() > 0:
			coin_pos = available_spots.pop_front()
			room_coins_pos.append(coin_pos)
			gridmap.set_cell_item(coin_pos, UGen.COIN_ID)
			# Cria heatmap da moeda
			var heat = UHeat.create_heatmap_bfs(gridmap, coin_pos, true, "coins")
			# Adiciona na lista de heatmaps de moedas
			last_coin_heat = heat
			coins_heats.append(last_coin_heat)
	# Cria heatmap combinado de moedas da sala
	var combined_coins_heat = UHeat.create_same_element_type_combined_heatmap(coins_heats)
	UHeat.heatmaps["coins"].append(combined_coins_heat)
	
	var last_enemy_heat
	var enemies_heats = []
	var npc_pos
	var room_npc_pos = []
	for _n in range(room_elements_quantity["enemies"]):
		# Posiciona o NPC no próximo slot disponível
		if available_spots.size() > 0:
			npc_pos = available_spots.pop_front()
			room_npc_pos.append(npc_pos)
			gridmap.set_cell_item(npc_pos, UGen.NPC_ID)
			# Cria heatmap do inimigo
			var heat = UHeat.create_heatmap_bfs(gridmap, npc_pos, false, "enemies")
			# Adiciona na lista de heatmaps de inimigos
			last_enemy_heat = heat
			enemies_heats.append(last_enemy_heat)
	# Cria heatmap combinado de inimigos da sala			
	var combined_enemies_heat = UHeat.create_same_element_type_combined_heatmap(enemies_heats)
	UHeat.heatmaps["enemies"].append(combined_enemies_heat)
	
	var last_banner_heat
	var banners_heats = []
	var banner_pos
	var room_banners_pos = []
	for _n in range(room_elements_quantity["banners"]):
		# Posiciona o estandarte no próximo slot disponível
		if available_spots.size() > 0:
			banner_pos = available_spots.pop_front()
			room_banners_pos.append(banner_pos)
			gridmap.set_cell_item(banner_pos, UGen.BANNER_ID)
			# Cria heatmap do estandarte
			var heat = UHeat.create_heatmap_bfs(gridmap, banner_pos, true, "banners")
			# Adiciona na lista de heatmaps de estandartes
			last_banner_heat = heat
			banners_heats.append(last_banner_heat)
	# Cria heatmap combinado de banners da sala
	var combined_banners_heat = UHeat.create_same_element_type_combined_heatmap(banners_heats)
	UHeat.heatmaps["banners"].append(combined_banners_heat)

	# Salva posições dos elementos da sala
	var elements_pos = {
		"portal1_pos": room_portals[0],
		"portal2_pos": room_portals[1],
		"coin_pos": room_coins_pos,
		"npc_pos": room_npc_pos,
		"banner_pos": room_banners_pos
	}
	rooms_elements_pos.append(elements_pos)
	
	
	# Cria heatmap combinado de todos os elementos de uma sala
	var combined_heat = UHeat.create_combined_heatmap(combined_banners_heat, combined_enemies_heat, combined_coins_heat)
	UHeat.heatmaps["combined"].append(combined_heat) 

	# Posiciona o spawn do player se for nesta sala
	if spawn_player and available_spots.size() > 0:
		gridmap.set_cell_item(available_spots.pop_front(), UGen.PLAYER_SPAWN_ID)	

# Retorna lista de posicoes com menores valores de influencia
func _get_lowest_tiles(heatmap: Dictionary) -> Array[Vector3i]:
	var lowest = 10000
	var lowest_pos : Array[Vector3i] = []
	for key in heatmap.keys():
		var value = heatmap[key]
		if value < lowest:
			lowest_pos.clear()
			lowest_pos.append(key)
			lowest = value
		elif value == lowest:
			lowest_pos.append(key)
	return lowest_pos
	
# Retorna lista de posicoes com maiores valores de influencia
func _get_greatest_tiles(heatmap: Dictionary) -> Array[Vector3i]:
	var greatest = -10000
	var greatest_pos : Array[Vector3i] = []
	for key in heatmap.keys():
		var value = heatmap[key]
		if value > greatest:
			greatest_pos.clear()
			greatest_pos.append(key)
			greatest = value
		elif value == greatest:
			greatest_pos.append(key)
	return greatest_pos

func _handle_room_coins_spawn(gridmap: GridMap, available_spots: Array[Vector3i]):
	var last_coin_heat
	var coins_heats = []
	var coin_pos
	var room_coins_pos = []
	for _n in range(room_elements_quantity["coins"]):
		# Posiciona a moeda no primeiro slot disponível
		if available_spots.size() > 0:
			if coins_heats.size() == 0:
				coin_pos = available_spots.pop_front()
			else:
				var partial_combined_coins_heat = UHeat.create_same_element_type_combined_heatmap(coins_heats)
				var lowest_tiles = _get_lowest_tiles(partial_combined_coins_heat)
				lowest_tiles.shuffle()
				coin_pos = lowest_tiles.pop_front()
				available_spots.erase(coin_pos)
				
			room_coins_pos.append(coin_pos)
			gridmap.set_cell_item(coin_pos, UGen.COIN_ID)
			# Cria heatmap da moeda
			var heat = UHeat.create_heatmap_bfs(gridmap, coin_pos, true, "coins")
			# Adiciona na lista de heatmaps de moedas
			last_coin_heat = heat
			coins_heats.append(last_coin_heat)
	# Cria heatmap combinado de moedas da sala
	var final_combined_coins_heat = UHeat.create_same_element_type_combined_heatmap(coins_heats)
	UHeat.heatmaps["coins"].append(final_combined_coins_heat)
	
	return room_coins_pos

# Posiciona elementos na sala de acordo com heatmaps parciais
func spawn_room_elements_smart(gridmap: GridMap, available_spots: Array[Vector3i], spawn_player: bool = false):
	var room_portals = _handle_room_portals_spawn(gridmap, available_spots)
	if room_portals.size() == 0:
		print("Posicionamento de elementos não pôde continuar devido à falta de espaços livres.")
		return
	
	# Embaralha os locais disponíveis
	available_spots.shuffle()
	
	var room_coins_pos = _handle_room_coins_spawn(gridmap, available_spots)
	var room_coins_heatmap = UHeat.heatmaps["coins"][UHeat.heatmaps["coins"].size()-1]
	
	var last_banner_heat
	var banners_heats = []
	var banner_pos
	var room_banners_pos = []
	for _n in range(room_elements_quantity["banners"]):
		# Posiciona o estandarte no próximo slot disponível
		if available_spots.size() > 0:
			if banners_heats.size() == 0:
				var lowest_tiles = _get_lowest_tiles(room_coins_heatmap)
				lowest_tiles.shuffle()
				banner_pos = lowest_tiles.pop_front()
				available_spots.erase(banner_pos)
			else:
				var partial_combined_banners_heat = UHeat.create_same_element_type_combined_heatmap(banners_heats)
				var partial_combined_heat = UHeat.create_combined_heatmap(partial_combined_banners_heat, {}, room_coins_heatmap)
				var lowest_tiles = _get_lowest_tiles(partial_combined_heat)
				lowest_tiles.shuffle()
				banner_pos = lowest_tiles.pop_front()
				available_spots.erase(banner_pos)
				banner_pos = available_spots.pop_front()
				
			room_banners_pos.append(banner_pos)
			gridmap.set_cell_item(banner_pos, UGen.BANNER_ID)
			# Cria heatmap do estandarte
			var heat = UHeat.create_heatmap_bfs(gridmap, banner_pos, true, "banners")
			# Adiciona na lista de heatmaps de estandartes
			last_banner_heat = heat
			banners_heats.append(last_banner_heat)
	# Cria heatmap combinado de banners da sala			
	var combined_banners_heat = UHeat.create_same_element_type_combined_heatmap(banners_heats)
	UHeat.heatmaps["banners"].append(combined_banners_heat)
	
	var last_enemy_heat
	var enemies_heats = []
	var npc_pos
	var room_npc_pos = []
	for _n in range(room_elements_quantity["enemies"]):
		# Posiciona o NPC no próximo slot disponível
		if available_spots.size() > 0:
			if enemies_heats.size() == 0:
				var greatest_tiles = _get_greatest_tiles(room_coins_heatmap)
				greatest_tiles.shuffle()
				npc_pos = greatest_tiles.pop_front()
				available_spots.erase(npc_pos)
			else:
				npc_pos = available_spots.pop_front()
				
			room_npc_pos.append(npc_pos)
			gridmap.set_cell_item(npc_pos, UGen.NPC_ID)
			# Cria heatmap do inimigo
			var heat = UHeat.create_heatmap_bfs(gridmap, npc_pos, false, "enemies")
			# Adiciona na lista de heatmaps de inimigos
			last_enemy_heat = heat
			enemies_heats.append(last_enemy_heat)
	# Cria heatmap combinado de inimigos da sala			
	var combined_enemies_heat = UHeat.create_same_element_type_combined_heatmap(enemies_heats)
	UHeat.heatmaps["enemies"].append(combined_enemies_heat)

	# Salva posições dos elementos da sala
	var elements_pos = {
		"portal1_pos": room_portals[0],
		"portal2_pos": room_portals[1],
		"coin_pos": room_coins_pos,
		"npc_pos": room_npc_pos,
		"banner_pos": room_banners_pos
	}
	rooms_elements_pos.append(elements_pos)
	
	# Cria heatmap combinado de todos os elementos de uma sala
	var combined_heat = UHeat.create_combined_heatmap(combined_banners_heat, combined_enemies_heat, room_coins_heatmap)
	UHeat.heatmaps["combined"].append(combined_heat) 

	# Posiciona o spawn do player se for nesta sala
	if spawn_player and available_spots.size() > 0:
		gridmap.set_cell_item(available_spots.pop_front(), UGen.PLAYER_SPAWN_ID)	
