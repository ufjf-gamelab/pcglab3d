extends Node

var astar: AStarGrid2D
var gridmap: GridMap

func _init(curr_gridmap: GridMap):
	astar = AStarGrid2D.new()
	gridmap = curr_gridmap

# Configura grid
func setup_grid(region_size: Vector2i, cell_size: Vector2i):
	# Região e Tamanho da célula
	astar.region = Rect2i(Vector2i.ZERO, region_size)
	astar.cell_size = cell_size
	
	# Heurística e Diagonal
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	
	# Atualiza o grid de acordo com as definições passadas
	astar.update()
	
	# Define limites nao navegaveis do grid
	_set_solid_cells(gridmap.get_used_cells_by_item(UGen.WALL_ID))
	_set_solid_cells(gridmap.get_used_cells_by_item(UGen.SOLID_ID))

# Define pontos sólidos do grid
func _set_solid_cells(solid_cells: Array[Vector3i]):
	for cell in solid_cells:
		astar.set_point_solid(Vector2i(cell.x, cell.z))

# Retorna o caminho entre dois pontos do grid
func find_path(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	if not astar.is_in_boundsv(start) or not astar.is_in_boundsv(end):
		print("Tile de início ou fim fora da região")
		return []
	
	return astar.get_id_path(start, end)
