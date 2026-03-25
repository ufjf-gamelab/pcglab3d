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

var portal_links: Dictionary = {}
var firstPortal: Vector3i
var lastPortal: Vector3i

var room_elements_quantity = {
	"enemies": 1,
	"coins": 1,
	"banners": 1
}

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
		spawn_room_elements(gridmap, room.duplicate(), spawn_player)
		spawn_player = false
	# Linka os dois últimos portais
	UGen.portal_links[UGen.lastPortal] = UGen.firstPortal
	UGen.portal_links[UGen.firstPortal] = UGen.lastPortal

# Posiciona elementos na sala
func spawn_room_elements(gridmap: GridMap, available_spots: Array[Vector3i], spawn_player: bool = false):
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
	
	# Embaralha os locais disponíveis
	available_spots.shuffle()
	
	var last_coin_heat
	var coins_heats = []
	for _n in range(room_elements_quantity["coins"]):
		# Posiciona a moeda no primeiro slot disponível
		if available_spots.size() > 0:
			var coin_pos = available_spots.pop_front()
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
	for _n in range(room_elements_quantity["enemies"]):
		# Posiciona o NPC no próximo slot disponível
		if available_spots.size() > 0:
			var npc_pos = available_spots.pop_front()
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
	for _n in range(room_elements_quantity["banners"]):
		# Posiciona o estandarte no próximo slot disponível
		if available_spots.size() > 0:
			var banner_pos = available_spots.pop_front()
			gridmap.set_cell_item(banner_pos, UGen.BANNER_ID)
			# Cria heatmap do estandarte
			var heat = UHeat.create_heatmap_bfs(gridmap, banner_pos, true, "banners")
			# Adiciona na lista de heatmaps de estandartes
			last_banner_heat = heat
			banners_heats.append(last_banner_heat)
	# Cria heatmap combinado de banners da sala			
	var combined_banners_heat = UHeat.create_same_element_type_combined_heatmap(banners_heats)
	UHeat.heatmaps["banners"].append(combined_banners_heat)
	
	# Cria heatmap combinado de todos os elementos de uma sala
	var combined_heat = UHeat.create_combined_heatmap(combined_banners_heat, combined_enemies_heat, combined_coins_heat)
	UHeat.heatmaps["combined"].append(combined_heat) 

	# Posiciona o spawn do player se for nesta sala
	if spawn_player and available_spots.size() > 0:
		gridmap.set_cell_item(available_spots.pop_front(), UGen.PLAYER_SPAWN_ID)	
