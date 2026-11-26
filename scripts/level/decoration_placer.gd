class_name DecorationPlacer extends RefCounted
## Coloca casas, cercas, árvores, arbustos e flores sobre as plataformas.

const C = preload("res://scripts/level/level_config.gd")

var tiles: LevelTiles
var rng: RandomNumberGenerator

func _init(level_tiles: LevelTiles, random: RandomNumberGenerator) -> void:
	tiles = level_tiles
	rng = random

## Escolhe um estilo de decoração; se o prop principal não couber, usa decorações pequenas.
func decorate_segment(x_start: int, x_end: int, y_top: int, deco_list: Array[Vector2i]) -> void:
	var width := x_end - x_start + 1
	if tiles.deco == null or width < 4:
		return

	var placed_main_prop := false
	match rng.randi_range(0, 3):
		0:
			if width >= 9:
				placed_main_prop = _try_place_house(x_start, x_end, y_top, deco_list)
		1:
			if width >= 5:
				placed_main_prop = _try_place_fence(x_start, x_end, y_top, deco_list)
		2:
			if width >= 5:
				placed_main_prop = _try_place_tree(x_start, x_end, y_top, deco_list)
	if not placed_main_prop:
		_place_small_decos(x_start, x_end, y_top, deco_list)

## Verifica se um prop de (2*half_w+1) tiles cabe no topo do segmento com height tiles livres acima.
func _can_place_prop_at(center_x: int, y_top: int, x_start: int, x_end: int, half_w: int, height: int) -> bool:
	if center_x - half_w < x_start + 1 or center_x + half_w > x_end - 1:
		return false
	for tx in range(center_x - half_w, center_x + half_w + 1):
		if not tiles.has_solid_cell(Vector2i(tx, y_top)):
			return false
	return tiles.is_area_clear(center_x - half_w - 1, center_x + half_w + 1, y_top - height, y_top - 1)

func _random_flower_atlas() -> Vector2i:
	return Vector2i(rng.randi_range(0, C.FLOWER_VARIANTS - 1), 0)

func _try_place_house(x_start: int, x_end: int, y_top: int, deco_list: Array[Vector2i]) -> bool:
	var house_cx := x_start + (x_end - x_start + 1) / 2
	if not _can_place_prop_at(house_cx, y_top, x_start, x_end, 3, 6):
		return false
	var house_ax: int = C.HOUSE_ATLAS_X[0] if rng.randf() < 0.5 else C.HOUSE_ATLAS_X[1]
	tiles.set_deco(Vector2i(house_cx, y_top - 3), C.DECO_HOUSE_ID, Vector2i(house_ax, 0), deco_list)
	var bush_x := x_start + 1
	if abs(bush_x - house_cx) >= 4 and tiles.is_space_above_clear(bush_x, y_top):
		tiles.set_deco(Vector2i(bush_x, y_top - 1), C.DECO_GRASS_ID, C.BUSH_ATLAS, deco_list)
	return true

func _try_place_fence(x_start: int, x_end: int, y_top: int, deco_list: Array[Vector2i]) -> bool:
	var f_start := x_start + 1
	var f_end := mini(x_start + rng.randi_range(3, 4), x_end - 1)
	if not tiles.is_area_clear(f_start, f_end, y_top - 2, y_top - 1):
		return false
	for fx in range(f_start, f_end + 1):
		var ax := C.FENCE_LEFT_X if fx == f_start else (C.FENCE_RIGHT_X if fx == f_end else (C.FENCE_MID_A_X if (fx - f_start) % 2 == 1 else C.FENCE_MID_B_X))
		tiles.set_deco(Vector2i(fx, y_top - 1), C.DECO_FENCE_ID, Vector2i(ax, C.FENCE_ATLAS_Y), deco_list)
	return true

func _try_place_tree(x_start: int, x_end: int, y_top: int, deco_list: Array[Vector2i]) -> bool:
	var tree_cx := x_start + (x_end - x_start + 1) / 2
	if not _can_place_prop_at(tree_cx, y_top, x_start, x_end, 1, 4):
		return false
	var tree_ax: int = C.TREE_ATLAS_X[0] if rng.randf() < 0.5 else C.TREE_ATLAS_X[1]
	tiles.set_deco(Vector2i(tree_cx, y_top - 2), C.DECO_GRASS_ID, Vector2i(tree_ax, C.TREE_ATLAS_Y), deco_list)
	if x_end - 1 > tree_cx + 1 and tiles.is_space_above_clear(x_end - 1, y_top):
		tiles.set_deco(Vector2i(x_end - 1, y_top - 1), C.DECO_FLOWERS_ID, _random_flower_atlas(), deco_list)
	return true

func _place_small_decos(x_start: int, x_end: int, y_top: int, deco_list: Array[Vector2i]) -> void:
	var slot := 0
	for x in range(x_start + 1, x_end, 2):
		if tiles.is_space_above_clear(x, y_top) and rng.randf() < C.DECO_CHANCE_PER_SLOT:
			var dcell := Vector2i(x, y_top - 1)
			if slot % 2 == 0:
				tiles.set_deco(dcell, C.DECO_GRASS_ID, C.BUSH_ATLAS, deco_list)
			else:
				tiles.set_deco(dcell, C.DECO_FLOWERS_ID, _random_flower_atlas(), deco_list)
		slot += 1
