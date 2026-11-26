class_name Forest extends Node2D

# --- Tilemap ---
const TILE_SIZE := 16
const HALF_TILE := 8.0
const EMPTY_SOURCE_ID := -1
const AUTUMN_SOURCE_ID := 1
const DECO_GRASS_ID := 0
const DECO_FLOWERS_ID := 1
const DECO_HOUSE_ID := 2
const DECO_PLANTS_ID := 3
const DECO_FENCE_ID := 4

# Coordenadas no atlas do tileset de outono (chão).
const THIN_ROW_Y := 3
const THIN_SINGLE_X := 15
const THIN_LEFT_X := 9
const THIN_MID_X := 10
const THIN_RIGHT_X := 13
const THICK_LEFT_X := 3
const THICK_MID_X := 4
const THICK_RIGHT_X := 5
const THICK_TOP_Y := 1
const THICK_MID_Y := 5
const THICK_BOTTOM_Y := 6

# Coordenadas no atlas das decorações.
const BUSH_ATLAS := Vector2i(1, 5)
const HOUSE_ATLAS_X := [0, 8]
const TREE_ATLAS_X := [1, 9]
const TREE_ATLAS_Y := 1
const FENCE_ATLAS_Y := 2
const FENCE_LEFT_X := 0
const FENCE_MID_A_X := 1
const FENCE_MID_B_X := 2
const FENCE_RIGHT_X := 3
const FLOWER_VARIANTS := 4

# --- Geração procedural ---
const LOOKAHEAD_DISTANCE := 480.0
const MAX_BUFFER_DISTANCE := 960.0
const CLEANUP_BEHIND_DISTANCE := 540.0
const PROCEDURAL_INTERVAL := 2.0
const INITIAL_CHUNKS := 4
const INITIAL_NEXT_TILE_X := 98
const INITIAL_PLATFORM_Y := 10
const MIN_GAP_TILES := 3
const MAX_GAP_TILES := 5
const MAX_UPWARD_STEP := 2
const MIN_PLATFORM_Y := 5
const MAX_PLATFORM_Y := 10
const PLATFORM_SCAN_MIN_Y := 3
const PLATFORM_SCAN_MAX_Y := 13
const PATTERN_COUNT := 8
const DIFFICULTY_RAMP_TILES := 1400.0
const MAX_DIFFICULTY_BONUS := 0.2

# --- Spawns ---
const INITIAL_ITEM_COLUMNS: Array[int] = [7, 19, 27, 38, 46, 55, 65, 73, 82, 91]
const COLLECTIBLE_Y_OFFSET := 10.0
const ENEMY_Y_OFFSET := 15.0
const COIN_CHANCE := 0.72
const ITEM_CHANCE_PER_SLOT := 0.65
const ENEMY_BASE_CHANCE := 0.65
const DECO_CHANCE_PER_SLOT := 0.85
const DOUBLE_JUMP_DURATION := 14.0
const SPEED_BOOST_DURATION := 10.0

# --- Áudio ---
const MUSIC_VOLUME_DB := -12.0

@export var enemy_scene: PackedScene = preload("res://scenes/orange.tscn")
@export var collectible_scene: PackedScene = preload("res://scenes/collectible.tscn")

@onready var hud: HUD = $HUD
@onready var player: Player = $Player
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var pit_area: Area2D = $PitArea
@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var tile_map_layer_2: TileMapLayer = $TileMapLayer2

var rng := RandomNumberGenerator.new()
var spawn_points: Array[Marker2D] = []
var next_tile_x: int = INITIAL_NEXT_TILE_X
var last_platform_y: int = INITIAL_PLATFORM_Y
var procedural_timer: float = 0.0
var generated_chunks: Array[Dictionary] = []
var pattern_bag: Array[int] = []
var last_pattern_id: int = -1

# =========================================================
# Ciclo de vida
# =========================================================

func _ready() -> void:
	rng.randomize()
	hud.hearts_template.visible = false

	player.health_change.connect(hud.update_hearts)
	player.coins_change.connect(hud.update_coins)
	player.score_change.connect(hud.update_score)
	player.powerup_state_change.connect(hud.update_powerup_icons)
	player.player_died.connect(hud.show_game_over)

	hud.update_hearts(player.health)
	hud.update_coins(player.coins)

	if pit_area and not pit_area.body_entered.is_connected(_on_pit_area_body_entered):
		pit_area.body_entered.connect(_on_pit_area_body_entered)

	for child in get_children():
		if child is Marker2D:
			spawn_points.append(child)

	if audio_stream_player:
		audio_stream_player.volume_db = MUSIC_VOLUME_DB
		if not audio_stream_player.playing:
			audio_stream_player.play()

	spawn_enemies()
	spawn_initial_items_on_platforms()

	for i in range(INITIAL_CHUNKS):
		generate_next_procedural_chunk()

func _process(delta: float) -> void:
	if player == null or player.is_dead:
		return

	procedural_timer += delta
	var frontier_world_x := tile_map_layer.position.x + float(next_tile_x * TILE_SIZE)
	var dist_ahead := frontier_world_x - player.global_position.x

	if dist_ahead < LOOKAHEAD_DISTANCE or (procedural_timer >= PROCEDURAL_INTERVAL and dist_ahead < MAX_BUFFER_DISTANCE):
		procedural_timer = 0.0
		generate_next_procedural_chunk()
		cleanup_old_entities()

# =========================================================
# Helpers de tilemap
# =========================================================

func _tile_to_world(tx: int, ty: int, y_offset: float) -> Vector2:
	return Vector2(
		tile_map_layer.position.x + float(tx * TILE_SIZE) + HALF_TILE,
		tile_map_layer.position.y + float(ty * TILE_SIZE) - y_offset
	)

func _has_solid_cell(cell: Vector2i) -> bool:
	return tile_map_layer != null and tile_map_layer.get_cell_source_id(cell) != EMPTY_SOURCE_ID

func _is_area_clear_of_ground(x_min: int, x_max: int, y_min: int, y_max: int) -> bool:
	for x in range(x_min, x_max + 1):
		for y in range(y_min, y_max + 1):
			if _has_solid_cell(Vector2i(x, y)):
				return false
	return true

func _is_space_above_clear(tx: int, y_top: int) -> bool:
	return _is_area_clear_of_ground(tx, tx, y_top - 2, y_top - 1)

func _find_highest_platform_tile_at_x(tx: int) -> int:
	if tile_map_layer == null:
		return -1
	for y in range(PLATFORM_SCAN_MIN_Y, PLATFORM_SCAN_MAX_Y + 1):
		if _has_solid_cell(Vector2i(tx, y)) and _is_space_above_clear(tx, y):
			return y
	return -1

func _set_deco(cell: Vector2i, source_id: int, atlas: Vector2i, deco_list: Array[Vector2i]) -> void:
	tile_map_layer_2.set_cell(cell, source_id, atlas, 0)
	deco_list.append(cell)

# =========================================================
# Spawns
# =========================================================

func spawn_enemies() -> void:
	if enemy_scene == null:
		return
	for spawn_point in spawn_points:
		_spawn_enemy_at(spawn_point.global_position)

func _spawn_enemy_at(pos: Vector2) -> void:
	var enemy_instance := enemy_scene.instantiate() as CharacterBody2D
	enemy_instance.global_position = pos
	add_child(enemy_instance)

func spawn_initial_items_on_platforms() -> void:
	for tx in INITIAL_ITEM_COLUMNS:
		var top_y := _find_highest_platform_tile_at_x(tx)
		if top_y != -1:
			_spawn_collectible_above_tile(tx, top_y, true)

func _spawn_collectible_above_tile(tx: int, y_top: int, allow_coin: bool) -> void:
	if collectible_scene == null or tile_map_layer == null:
		return
	if not _has_solid_cell(Vector2i(tx, y_top)) or not _is_space_above_clear(tx, y_top):
		return

	var item := collectible_scene.instantiate() as Collectible
	item.global_position = _tile_to_world(tx, y_top, COLLECTIBLE_Y_OFFSET)
	item.amount = 1
	item.powerup_duration = 0.0

	if allow_coin and rng.randf() < COIN_CHANCE:
		item.item_type = Collectible.ItemType.COIN
	else:
		match rng.randi_range(0, 3):
			0:
				item.item_type = Collectible.ItemType.DOUBLE_JUMP
				item.powerup_duration = DOUBLE_JUMP_DURATION
			1:
				item.item_type = Collectible.ItemType.SPEED_BOOST
				item.powerup_duration = SPEED_BOOST_DURATION
			2:
				item.item_type = Collectible.ItemType.SHIELD
			_:
				item.item_type = Collectible.ItemType.HEALTH

	add_child(item)

# =========================================================
# Geração procedural
# =========================================================

func _clamp_reachable_y(prev_y: int, candidate_y: int) -> int:
	var min_allowed_y := maxi(prev_y - MAX_UPWARD_STEP, MIN_PLATFORM_Y)
	return clampi(candidate_y, min_allowed_y, MAX_PLATFORM_Y)

func _random_gap(extra: int = 0) -> int:
	return rng.randi_range(MIN_GAP_TILES + extra, MAX_GAP_TILES + extra)

func _draw_next_pattern() -> int:
	if pattern_bag.is_empty():
		pattern_bag.assign(range(PATTERN_COUNT))
		pattern_bag.shuffle()
		# Evita repetir o mesmo padrão na virada do saco.
		if pattern_bag[0] == last_pattern_id and pattern_bag.size() > 1:
			var swap_val := pattern_bag[0]
			pattern_bag[0] = pattern_bag[1]
			pattern_bag[1] = swap_val
	last_pattern_id = pattern_bag.pop_front()
	return last_pattern_id

func _segment(x_start: int, width: int, y_top: int, depth: int, allow_enemy: bool, diff: float, force_powerup: bool = false) -> Dictionary:
	return {
		"x_start": x_start,
		"x_end": x_start + width - 1,
		"y_top": y_top,
		"depth": depth,
		"allow_enemy": allow_enemy,
		"diff": diff,
		"force_powerup": force_powerup,
	}

func generate_next_procedural_chunk() -> void:
	if tile_map_layer == null:
		return

	var pattern_id := _draw_next_pattern()
	var ground_list: Array[Vector2i] = []
	var deco_list: Array[Vector2i] = []
	var segments: Array[Dictionary] = []

	var cursor_x := next_tile_x + _random_gap()
	var cur_y := _clamp_reachable_y(last_platform_y, last_platform_y + rng.randi_range(-1, 1))
	var diff := clampf(float(cursor_x) / DIFFICULTY_RAMP_TILES, 0.0, MAX_DIFFICULTY_BONUS)

	match pattern_id:
		0: # Plataforma longa
			var w := rng.randi_range(8, 10)
			segments.append(_segment(cursor_x, w, cur_y, 3, true, diff))
			cursor_x += w - 1
		1: # Duas plataformas subindo
			segments.append(_segment(cursor_x, 5, cur_y, 2, false, 0.0))
			cursor_x += 5 + _random_gap()
			cur_y = _clamp_reachable_y(cur_y, cur_y - 1)
			segments.append(_segment(cursor_x, 6, cur_y, 2, true, diff))
			cursor_x += 5
		2: # Base + plataforma alta com power-up
			var base_y := _clamp_reachable_y(cur_y, cur_y + 1)
			segments.append(_segment(cursor_x, 6, base_y, 3, true, diff))
			cursor_x += 6 + _random_gap()
			var high_y := _clamp_reachable_y(base_y, base_y - 2)
			segments.append(_segment(cursor_x, 5, high_y, 1, false, 0.0, true))
			cursor_x += 4
			cur_y = high_y
		3: # Escada de 3 degraus
			var step_y := _clamp_reachable_y(cur_y, cur_y + 1)
			for s in range(3):
				var depth := 2 if s == 0 else 1
				segments.append(_segment(cursor_x, 5, step_y, depth, s == 2, diff))
				if s < 2:
					cursor_x += 5 + _random_gap()
					step_y = _clamp_reachable_y(step_y, step_y - rng.randi_range(1, 2))
				else:
					cursor_x += 4
			cur_y = step_y
		4: # Alta fina seguida de descida larga
			var high_y := _clamp_reachable_y(cur_y, cur_y - 1)
			segments.append(_segment(cursor_x, 5, high_y, 1, false, 0.0))
			cursor_x += 5 + _random_gap(1)
			var low_y := _clamp_reachable_y(high_y, high_y + 2)
			segments.append(_segment(cursor_x, 8, low_y, 3, true, diff))
			cursor_x += 7
			cur_y = low_y
		5: # Duas finas, a segunda com power-up
			segments.append(_segment(cursor_x, 5, cur_y, 1, false, 0.0))
			cursor_x += 5 + _random_gap()
			var next_y := _clamp_reachable_y(cur_y, cur_y + rng.randi_range(-1, 1))
			segments.append(_segment(cursor_x, 6, next_y, 1, false, 0.0, true))
			cursor_x += 5
			cur_y = next_y
		6: # Duas médias com variação de altura
			segments.append(_segment(cursor_x, 6, cur_y, 2, true, diff))
			cursor_x += 6 + _random_gap()
			var right_y := _clamp_reachable_y(cur_y, cur_y + rng.randi_range(-1, 2))
			segments.append(_segment(cursor_x, 6, right_y, 2, false, 0.0))
			cursor_x += 5
			cur_y = right_y
		_: # Corrida reta
			segments.append(_segment(cursor_x, 10, cur_y, 3, true, diff))
			cursor_x += 9

	for seg in segments:
		_paint_ground_only(seg["x_start"], seg["x_end"], seg["y_top"], seg["depth"], ground_list)

	for seg in segments:
		_populate_segment_props_and_entities(
			seg["x_start"],
			seg["x_end"],
			seg["y_top"],
			deco_list,
			seg["allow_enemy"],
			seg["diff"],
			seg["force_powerup"]
		)

	generated_chunks.append({
		"end_world_x": tile_map_layer.position.x + float((cursor_x + 1) * TILE_SIZE),
		"ground_cells": ground_list,
		"deco_cells": deco_list
	})

	next_tile_x = cursor_x
	last_platform_y = cur_y

func _paint_ground_only(x_start: int, x_end: int, y_top: int, depth: int, ground_list: Array[Vector2i]) -> void:
	for x in range(x_start, x_end + 1):
		var is_left := (x == x_start)
		var is_right := (x == x_end)
		if depth == 1:
			var ax := THIN_SINGLE_X if (is_left and is_right) else (THIN_LEFT_X if is_left else (THIN_RIGHT_X if is_right else THIN_MID_X))
			var cell := Vector2i(x, y_top)
			tile_map_layer.set_cell(cell, AUTUMN_SOURCE_ID, Vector2i(ax, THIN_ROW_Y), 0)
			ground_list.append(cell)
		else:
			var ax := THICK_LEFT_X if is_left else (THICK_RIGHT_X if is_right else THICK_MID_X)
			for d in range(depth):
				var ay := THICK_TOP_Y if d == 0 else (THICK_BOTTOM_Y if d == depth - 1 else THICK_MID_Y)
				var cell := Vector2i(x, y_top + d)
				tile_map_layer.set_cell(cell, AUTUMN_SOURCE_ID, Vector2i(ax, ay), 0)
				ground_list.append(cell)

# =========================================================
# Decoração e entidades
# =========================================================

# Verifica se um prop de (2*half_w+1) tiles cabe no topo do segmento com height tiles livres acima.
func _can_place_prop_at(center_x: int, y_top: int, x_start: int, x_end: int, half_w: int, height: int) -> bool:
	if center_x - half_w < x_start + 1 or center_x + half_w > x_end - 1:
		return false
	for tx in range(center_x - half_w, center_x + half_w + 1):
		if not _has_solid_cell(Vector2i(tx, y_top)):
			return false
	return _is_area_clear_of_ground(center_x - half_w - 1, center_x + half_w + 1, y_top - height, y_top - 1)

func _can_place_tree_at(center_x: int, y_top: int, x_start: int, x_end: int) -> bool:
	return _can_place_prop_at(center_x, y_top, x_start, x_end, 1, 4)

func _can_place_house_at(center_x: int, y_top: int, x_start: int, x_end: int) -> bool:
	return _can_place_prop_at(center_x, y_top, x_start, x_end, 3, 6)

func _random_flower_atlas() -> Vector2i:
	return Vector2i(rng.randi_range(0, FLOWER_VARIANTS - 1), 0)

func _try_place_house(x_start: int, x_end: int, y_top: int, deco_list: Array[Vector2i]) -> bool:
	var house_cx := x_start + (x_end - x_start + 1) / 2
	if not _can_place_house_at(house_cx, y_top, x_start, x_end):
		return false
	var house_ax: int = HOUSE_ATLAS_X[0] if rng.randf() < 0.5 else HOUSE_ATLAS_X[1]
	_set_deco(Vector2i(house_cx, y_top - 3), DECO_HOUSE_ID, Vector2i(house_ax, 0), deco_list)
	var bush_x := x_start + 1
	if abs(bush_x - house_cx) >= 4 and _is_space_above_clear(bush_x, y_top):
		_set_deco(Vector2i(bush_x, y_top - 1), DECO_GRASS_ID, BUSH_ATLAS, deco_list)
	return true

func _try_place_fence(x_start: int, x_end: int, y_top: int, deco_list: Array[Vector2i]) -> bool:
	var f_start := x_start + 1
	var f_end := mini(x_start + rng.randi_range(3, 4), x_end - 1)
	if not _is_area_clear_of_ground(f_start, f_end, y_top - 2, y_top - 1):
		return false
	for fx in range(f_start, f_end + 1):
		var ax := FENCE_LEFT_X if fx == f_start else (FENCE_RIGHT_X if fx == f_end else (FENCE_MID_A_X if (fx - f_start) % 2 == 1 else FENCE_MID_B_X))
		_set_deco(Vector2i(fx, y_top - 1), DECO_FENCE_ID, Vector2i(ax, FENCE_ATLAS_Y), deco_list)
	return true

func _try_place_tree(x_start: int, x_end: int, y_top: int, deco_list: Array[Vector2i]) -> bool:
	var tree_cx := x_start + (x_end - x_start + 1) / 2
	if not _can_place_tree_at(tree_cx, y_top, x_start, x_end):
		return false
	var tree_ax: int = TREE_ATLAS_X[0] if rng.randf() < 0.5 else TREE_ATLAS_X[1]
	_set_deco(Vector2i(tree_cx, y_top - 2), DECO_GRASS_ID, Vector2i(tree_ax, TREE_ATLAS_Y), deco_list)
	if x_end - 1 > tree_cx + 1 and _is_space_above_clear(x_end - 1, y_top):
		_set_deco(Vector2i(x_end - 1, y_top - 1), DECO_FLOWERS_ID, _random_flower_atlas(), deco_list)
	return true

func _place_small_decos(x_start: int, x_end: int, y_top: int, deco_list: Array[Vector2i]) -> void:
	var slot := 0
	for x in range(x_start + 1, x_end, 2):
		if _is_space_above_clear(x, y_top) and rng.randf() < DECO_CHANCE_PER_SLOT:
			var dcell := Vector2i(x, y_top - 1)
			if slot % 2 == 0:
				_set_deco(dcell, DECO_GRASS_ID, BUSH_ATLAS, deco_list)
			else:
				_set_deco(dcell, DECO_FLOWERS_ID, _random_flower_atlas(), deco_list)
		slot += 1

func _populate_segment_props_and_entities(
	x_start: int,
	x_end: int,
	y_top: int,
	deco_list: Array[Vector2i],
	allow_enemy: bool,
	diff_bonus: float,
	force_powerup: bool
) -> void:
	var width := x_end - x_start + 1

	if tile_map_layer_2 != null and width >= 4:
		var deco_style := rng.randi_range(0, 3)
		var placed_main_prop := false
		match deco_style:
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

	if force_powerup:
		_spawn_collectible_above_tile(x_start + width / 2, y_top, false)
	else:
		for tx in range(x_start + 1, x_end, 2):
			if rng.randf() < ITEM_CHANCE_PER_SLOT:
				_spawn_collectible_above_tile(tx, y_top, true)

	if allow_enemy and enemy_scene != null and width >= 5 and rng.randf() < (ENEMY_BASE_CHANCE + diff_bonus):
		var enemy_tx := rng.randi_range(x_start + 1, x_end - 1)
		if _is_area_clear_of_ground(enemy_tx - 1, enemy_tx + 1, y_top - 3, y_top - 1):
			_spawn_enemy_at(_tile_to_world(enemy_tx, y_top, ENEMY_Y_OFFSET))

# =========================================================
# Limpeza
# =========================================================

func cleanup_old_entities() -> void:
	if player == null:
		return
	var cutoff_x := player.global_position.x - CLEANUP_BEHIND_DISTANCE
	while not generated_chunks.is_empty() and float(generated_chunks[0]["end_world_x"]) < cutoff_x:
		var oldest: Dictionary = generated_chunks.pop_front()
		for cell in oldest.get("ground_cells", []):
			tile_map_layer.set_cell(cell, EMPTY_SOURCE_ID)
		if tile_map_layer_2 != null:
			for dcell in oldest.get("deco_cells", []):
				tile_map_layer_2.set_cell(dcell, EMPTY_SOURCE_ID)

	for child in get_children():
		if child is Node2D and child != player and (child.is_in_group("enemies") or child is Collectible):
			if child.global_position.x < cutoff_x:
				child.queue_free()

func _on_pit_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("fall_in_pit"):
		body.fall_in_pit()
