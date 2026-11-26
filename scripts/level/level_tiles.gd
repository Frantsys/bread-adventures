class_name LevelTiles extends RefCounted
## Acesso aos dois TileMapLayers da fase: consultas de chão, conversão de coordenadas e pintura.

const C = preload("res://scripts/level/level_config.gd")

var ground: TileMapLayer
var deco: TileMapLayer

func _init(ground_layer: TileMapLayer, deco_layer: TileMapLayer) -> void:
	ground = ground_layer
	deco = deco_layer

func tile_to_world(tx: int, ty: int, y_offset: float) -> Vector2:
	return Vector2(
		ground.position.x + float(tx * C.TILE_SIZE) + C.HALF_TILE,
		ground.position.y + float(ty * C.TILE_SIZE) - y_offset
	)

func column_world_x(tx: int) -> float:
	return ground.position.x + float(tx * C.TILE_SIZE)

func has_solid_cell(cell: Vector2i) -> bool:
	return ground != null and ground.get_cell_source_id(cell) != C.EMPTY_SOURCE_ID

func is_area_clear(x_min: int, x_max: int, y_min: int, y_max: int) -> bool:
	for x in range(x_min, x_max + 1):
		for y in range(y_min, y_max + 1):
			if has_solid_cell(Vector2i(x, y)):
				return false
	return true

## Duas células livres acima do topo (espaço para um item ou decoração pequena).
func is_space_above_clear(tx: int, y_top: int) -> bool:
	return is_area_clear(tx, tx, y_top - 2, y_top - 1)

func find_highest_platform_tile_at_x(tx: int) -> int:
	if ground == null:
		return -1
	for y in range(C.PLATFORM_SCAN_MIN_Y, C.PLATFORM_SCAN_MAX_Y + 1):
		if has_solid_cell(Vector2i(tx, y)) and is_space_above_clear(tx, y):
			return y
	return -1

## Pinta uma plataforma. depth 1 = plataforma fina; maior = bloco com topo, meio e base.
func paint_ground(x_start: int, x_end: int, y_top: int, depth: int, ground_list: Array[Vector2i]) -> void:
	for x in range(x_start, x_end + 1):
		var is_left := (x == x_start)
		var is_right := (x == x_end)
		if depth == 1:
			var ax := C.THIN_SINGLE_X if (is_left and is_right) else (C.THIN_LEFT_X if is_left else (C.THIN_RIGHT_X if is_right else C.THIN_MID_X))
			_set_ground(Vector2i(x, y_top), Vector2i(ax, C.THIN_ROW_Y), ground_list)
		else:
			var ax := C.THICK_LEFT_X if is_left else (C.THICK_RIGHT_X if is_right else C.THICK_MID_X)
			for d in range(depth):
				var ay := C.THICK_TOP_Y if d == 0 else (C.THICK_BOTTOM_Y if d == depth - 1 else C.THICK_MID_Y)
				_set_ground(Vector2i(x, y_top + d), Vector2i(ax, ay), ground_list)

func _set_ground(cell: Vector2i, atlas: Vector2i, ground_list: Array[Vector2i]) -> void:
	ground.set_cell(cell, C.AUTUMN_SOURCE_ID, atlas, 0)
	ground_list.append(cell)

func set_deco(cell: Vector2i, source_id: int, atlas: Vector2i, deco_list: Array[Vector2i]) -> void:
	deco.set_cell(cell, source_id, atlas, 0)
	deco_list.append(cell)

func clear_cells(ground_cells: Array, deco_cells: Array) -> void:
	for cell in ground_cells:
		ground.set_cell(cell, C.EMPTY_SOURCE_ID)
	if deco != null:
		for cell in deco_cells:
			deco.set_cell(cell, C.EMPTY_SOURCE_ID)
