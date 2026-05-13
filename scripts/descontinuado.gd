# DESCONTINUADO, CODIGO REMOVIDO DE MAIN.GD
# A IDEIA SERIA CRIAR CAMINHOS VERIFICANDO A DISTANCIA PARA O ESTANDARTE MAIS PROXIMO 
# E COMPARANDO COM O TEMPO DE LUZ AINDA RESTANTE PARA CRIAR UM PATH SEGURO

#const LIGHT_AWARE = false
#
#func _build_light_aware_global_path(gen_paths: Array, pathfinder) -> Array:
	#var safe_paths: Array = []
	#
	#var sim_life := max_life_time
	#var cell_time := 1.0 / 2.5 # speed = 2.5m/s ; cell_size = 1m
	#
	#for room_index in range(gen_paths.size()):
		#var room_path: Array[Vector2i] = gen_paths[room_index]
		#
		#var result: Dictionary = _walk_path(room_path, sim_life, cell_time, room_index, pathfinder, [], 0)
		#
		#safe_paths.append(result.path)
		#sim_life = result.life
	#
	#return safe_paths
#
#func _get_path_to_nearest_banner(pos: Vector2i, banners: Array[Vector2i], pathfinder):
	#var best_path = []
	#var best_cost = INF
#
	#for b in banners:
		#var path = pathfinder.find_path(pos, b)
		#var cost = path.size()
		#
		#if cost < best_cost:
			#best_cost = cost
			#best_path = path
	#
	#return best_path
#
#func _walk_path(room_path: Array[Vector2i], sim_light, cell_time, room_index: int, pathfinder, room_coins, deep: int) -> Dictionary:
	#var banners = _get_room_banners(room_index)
	#var new_room_path: Array[Vector2i] = []
	#
	#var room_coins_pos : Array[Vector2i]
	#if deep == 0:
		#room_coins_pos = []
		#for coin_pos in UGen.rooms_elements_pos[room_index].coin_pos:
			#room_coins_pos.append(Vector2i(coin_pos.x, coin_pos.z))
	#else:
		#room_coins_pos = room_coins
	#
	#for i in range(room_path.size()):
		#var current_pos = room_path[i]
		#var exit_portal = room_path[room_path.size()-1]
		#
		#if (room_coins_pos.has(current_pos)):
			#room_coins_pos.erase(current_pos)
		#
		#if (banners.has(current_pos)):
			#sim_light = max_life_time + cell_time
		#
		#new_room_path.append(current_pos)
		#
		#sim_light -= cell_time
		#
		#if sim_light <= 0:
			#print("Não foi possível completar o caminho! A luz acabou!")
			#break
		#
		## Se for o tile de saída, finaliza a execução da sala
		#if current_pos == exit_portal:
			#break
		#
		## Verifica a cada 5 tiles
		#if i % 5 == 0:
			#var path_to_nearest_banner = _get_path_to_nearest_banner(current_pos, banners, pathfinder)
			#
			#if path_to_nearest_banner != null:
				#var time_to_banner = path_to_nearest_banner.size() * cell_time
				#
				## Margem de segurança
				#if time_to_banner >= sim_light - 2.0:
					## Precisa ir até o estandarte
					#print("Desviando para o estandarte na sala ", room_index)
					#
					## Adiciona caminho até o estandarte
					#for tile in path_to_nearest_banner:
						#new_room_path.append(tile)
					#
					## Gasta o tempo da ida até o estandarte
					#sim_light -= time_to_banner
					#
					## Recarrega
					#sim_light = max_life_time
					#
					#var curr_pos = new_room_path[new_room_path.size()-1]
					#if PATH_TYPE == Pathfing.STRAIGHT:
						#var exit_path = pathfinder.find_path(curr_pos, exit_portal)
						#
						## Chama recursivamente a função para completar o caminho
						#var result = _walk_path(exit_path, sim_light, cell_time, room_index, pathfinder, room_coins_pos, deep+1)
						#
						#new_room_path += result.path
						#sim_light = result.life
						#break
					#elif PATH_TYPE == Pathfing.EXPLORER:
						#pass
						#var exit_path = pathfinder.find_explorer_path(curr_pos, room_coins_pos, exit_portal)
						## Chama recursivamente a função para completar o caminho
						#var result = _walk_path(exit_path, sim_light, cell_time, room_index, pathfinder, room_coins_pos, deep+1)
						#
						#new_room_path += result.path
						#sim_light = result.life
						#break
	#
	#return {
		#"path": new_room_path,
		#"life": sim_light
	#}
#
#func _get_room_banners(room_index: int) -> Array[Vector2i]:
	#var banners_pos: Array[Vector2i] = []
	#
	#var elements = UGen.rooms_elements_pos[room_index]
	#
	#for b in elements.banner_pos:
		#banners_pos.append(Vector2i(b.x, b.z))
	#
	#return banners_pos
#
#func _on_pathfinding_pressed():
	#var pathfinder = _pathfinder_init()
	#
	#paths = []
	#paths_influences = []
	#var influences = []
	#
	#for i in range((UGen.rooms).size()):
		#var path = _get_room_path(i, pathfinder)
		#
		#paths.append(path)
		#
		#if LIGHT_AWARE:
			#continue
		#
		#var influ = _get_path_influences(i, path)
		#if influ[1] == []:
			#print("Nenhum tipo de mapa de influência selecionado.")
			#return
		#paths_influences.append(influ[0])
		#influences.append(influ[1])
	#
	#if LIGHT_AWARE:
		#paths = _build_light_aware_global_path(paths, pathfinder)
		#for i in range(paths.size()):
			#var influ = _get_path_influences(i, paths[i])
			#if influ[1] == []:
				#print("Nenhum tipo de mapa de influência selecionado.")
				#return
			#paths_influences.append(influ[0])
			#influences.append(influ[1])
	#
	#_handle_chart(influences)
	#_visualize_path_by_room_index(0)
