class_name Forest extends Node2D

@export var enemy_scene: PackedScene = preload("res://scenes/orange.tscn")
@export var collectible_scene: PackedScene = preload("res://scenes/collectible.tscn")

@onready var hud: HUD = $HUD
@onready var player: Player = $Player
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var pit_area: Area2D = $PitArea
@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var tile_map_layer_2: TileMapLayer = $TileMapLayer2

const TILE_SIZE := 16
const AUTUMN_SOURCE_ID := 1
const DECO_GRASS_ID := 0
const DECO_FLOWERS_ID := 1
const DECO_HOUSE_ID := 2
const DECO_PLANTS_ID := 3
const DECO_FENCE_ID := 4
const LOOKAHEAD_DISTANCE := 480.0
const MAX_BUFFER_DISTANCE := 960.0
const CLEANUP_BEHIND_DISTANCE := 540.0
const PROCEDURAL_INTERVAL := 2.0

const MIN_GAP_TILES := 3
const MAX_GAP_TILES := 5
const MAX_UPWARD_STEP := 2

var rng := RandomNumberGenerator.new()
var spawn_points: Array[Marker2D] = []
var next_tile_x: int = 98
var last_platform_y: int = 10
var procedural_timer: float = 0.0
var generated_chunks: Array[Dictionary] = []
var pattern_bag: Array[int] = []
var last_pattern_id: int = -1

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
		audio_stream_player.volume_db = -12.0
		if not audio_stream_player.playing:
			audio_stream_player.play()

	spawn_enemies()
	spawn_initial_items_on_platforms()

	for i in range(4):
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

func spawn_enemies() -> void:
	if enemy_scene == null:
		return
	for spawn_point in spawn_points:
		var enemy_instance := enemy_scene.instantiate() as CharacterBody2D
		enemy_instance.global_position = spawn_point.global_position
		add_child(enemy_instance)

func _has_solid_cell(cell: Vector2i) -> bool:
	return tile_map_layer != null and tile_map_layer.get_cell_source_id(cell) != -1

func _is_area_clear_of_ground(x_min: int, x_max: int, y_min: int, y_max: int) -> bool:
	for x in range(x_min, x_max + 1):
		for y in range(y_min, y_max + 1):
			if _has_solid_cell(Vector2i(x, y)):
				return false
	return true

func _find_highest_platform_tile_at_x(tx: int) -> int:
	if tile_map_layer == null:
		return -1
	for y in range(3, 14):
		var c := Vector2i(tx, y)
		if _has_solid_cell(c):
			if not _has_solid_cell(Vector2i(tx, y - 1)) and not _has_solid_cell(Vector2i(tx, y - 2)):
				return y
	return -1

func _spawn_collectible_above_tile(tx: int, y_top: int, allow_coin: bool) -> void:
	if collectible_scene == null or tile_map_layer == null:
		return
	if not _has_solid_cell(Vector2i(tx, y_top)):
		return
	if not _is_area_clear_of_ground(tx, tx, y_top - 2, y_top - 1):
		return

	var wx := tile_map_layer.position.x + float(tx * TILE_SIZE) + 8.0
	var wy := tile_map_layer.position.y + float(y_top * TILE_SIZE) - 10.0

	var item := collectible_scene.instantiate() as Collectible
	item.global_position = Vector2(wx, wy)

	var roll := rng.randf()
	if allow_coin and roll < 0.72:
		item.item_type = Collectible.ItemType.COIN
		item.amount = 1
		item.powerup_duration = 0.0
	else:
		var p_roll := rng.randi_range(0, 3)
		match p_roll:
			0:
				item.item_type = Collectible.ItemType.DOUBLE_JUMP
				item.amount = 1
				item.powerup_duration = 14.0
			1:
				item.item_type = Collectible.ItemType.SPEED_BOOST
				item.amount = 1
				item.powerup_duration = 10.0
			2:
				item.item_type = Collectible.ItemType.SHIELD
				item.amount = 1
				item.powerup_duration = 0.0
			_:
				item.item_type = Collectible.ItemType.HEALTH
				item.amount = 1
				item.powerup_duration = 0.0

	add_child(item)

func spawn_initial_items_on_platforms() -> void:
	var initial_cols: Array[int] = [7, 19, 27, 38, 46, 55, 65, 73, 82, 91]
	for tx in initial_cols:
		var top_y := _find_highest_platform_tile_at_x(tx)
		if top_y != -1:
			_spawn_collectible_above_tile(tx, top_y, true)

func _clamp_reachable_y(prev_y: int, candidate_y: int) -> int:
	var min_allowed_y := maxi(prev_y - MAX_UPWARD_STEP, 5)
	return clampi(candidate_y, min_allowed_y, 10)

func _draw_next_pattern() -> int:
	if pattern_bag.is_empty():
		pattern_bag = [0, 1, 2, 3, 4, 5, 6, 7]
		for i in range(pattern_bag.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp := pattern_bag[i]
			pattern_bag[i] = pattern_bag[j]
			pattern_bag[j] = tmp
		if pattern_bag[0] == last_pattern_id and pattern_bag.size() > 1:
			var swap_val := pattern_bag[0]
			pattern_bag[0] = pattern_bag[1]
			pattern_bag[1] = swap_val
	last_pattern_id = pattern_bag.pop_front()
	return last_pattern_id

func generate_next_procedural_chunk() -> void:
	if tile_map_layer == null:
		return

	var pattern_id := _draw_next_pattern()
	var ground_list: Array[Vector2i] = []
	var deco_list: Array[Vector2i] = []
	var segments: Array[Dictionary] = []

	var gap := rng.randi_range(MIN_GAP_TILES, MAX_GAP_TILES)
	var cursor_x := next_tile_x + gap
	var cur_y := _clamp_reachable_y(last_platform_y, last_platform_y + rng.randi_range(-1, 1))
	var difficulty_bonus := clampf(float(cursor_x) / 1400.0, 0.0, 0.2)

	match pattern_id:
		0:
			var w := rng.randi_range(8, 10)
			segments.append({"x_start": cursor_x, "x_end": cursor_x + w - 1, "y_top": cur_y, "depth": 3, "allow_enemy": true, "diff": difficulty_bonus, "force_powerup": false})
			cursor_x += w - 1
		1:
			var w1 := 5
			segments.append({"x_start": cursor_x, "x_end": cursor_x + w1 - 1, "y_top": cur_y, "depth": 2, "allow_enemy": false, "diff": 0.0, "force_powerup": false})
			cursor_x += w1 + rng.randi_range(MIN_GAP_TILES, MAX_GAP_TILES)
			cur_y = _clamp_reachable_y(cur_y, cur_y - 1)
			var w2 := 6
			segments.append({"x_start": cursor_x, "x_end": cursor_x + w2 - 1, "y_top": cur_y, "depth": 2, "allow_enemy": true, "diff": difficulty_bonus, "force_powerup": false})
			cursor_x += w2 - 1
		2:
			var base_y := _clamp_reachable_y(cur_y, cur_y + 1)
			var w1 := 6
			segments.append({"x_start": cursor_x, "x_end": cursor_x + w1 - 1, "y_top": base_y, "depth": 3, "allow_enemy": true, "diff": difficulty_bonus, "force_powerup": false})
			cursor_x += w1 + rng.randi_range(MIN_GAP_TILES, MAX_GAP_TILES)
			var high_y := _clamp_reachable_y(base_y, base_y - 2)
			var w2 := 5
			segments.append({"x_start": cursor_x, "x_end": cursor_x + w2 - 1, "y_top": high_y, "depth": 1, "allow_enemy": false, "diff": 0.0, "force_powerup": true})
			cursor_x += w2 - 1
			cur_y = high_y
		3:
			var step_y := _clamp_reachable_y(cur_y, cur_y + 1)
			for s in range(3):
				var sw := 5
				var d := 2 if s == 0 else 1
				segments.append({"x_start": cursor_x, "x_end": cursor_x + sw - 1, "y_top": step_y, "depth": d, "allow_enemy": s == 2, "diff": difficulty_bonus, "force_powerup": false})
				if s < 2:
					cursor_x += sw + rng.randi_range(MIN_GAP_TILES, MAX_GAP_TILES)
					step_y = _clamp_reachable_y(step_y, step_y - rng.randi_range(1, 2))
				else:
					cursor_x += sw - 1
			cur_y = step_y
		4:
			var high_y := _clamp_reachable_y(cur_y, cur_y - 1)
			segments.append({"x_start": cursor_x, "x_end": cursor_x + 4, "y_top": high_y, "depth": 1, "allow_enemy": false, "diff": 0.0, "force_powerup": false})
			cursor_x += 5 + rng.randi_range(MIN_GAP_TILES + 1, MAX_GAP_TILES + 1)
			var low_y := _clamp_reachable_y(high_y, high_y + 2)
			segments.append({"x_start": cursor_x, "x_end": cursor_x + 7, "y_top": low_y, "depth": 3, "allow_enemy": true, "diff": difficulty_bonus, "force_powerup": false})
			cursor_x += 7
			cur_y = low_y
		5:
			segments.append({"x_start": cursor_x, "x_end": cursor_x + 4, "y_top": cur_y, "depth": 1, "allow_enemy": false, "diff": 0.0, "force_powerup": false})
			cursor_x += 5 + rng.randi_range(MIN_GAP_TILES, MAX_GAP_TILES)
			var next_y := _clamp_reachable_y(cur_y, cur_y + rng.randi_range(-1, 1))
			segments.append({"x_start": cursor_x, "x_end": cursor_x + 5, "y_top": next_y, "depth": 1, "allow_enemy": false, "diff": 0.0, "force_powerup": true})
			cursor_x += 5
			cur_y = next_y
		6:
			var left_w := 6
			segments.append({"x_start": cursor_x, "x_end": cursor_x + left_w - 1, "y_top": cur_y, "depth": 2, "allow_enemy": true, "diff": difficulty_bonus, "force_powerup": false})
			cursor_x += left_w + rng.randi_range(MIN_GAP_TILES, MAX_GAP_TILES)
			var right_y := _clamp_reachable_y(cur_y, cur_y + rng.randi_range(-1, 2))
			segments.append({"x_start": cursor_x, "x_end": cursor_x + 5, "y_top": right_y, "depth": 2, "allow_enemy": false, "diff": 0.0, "force_powerup": false})
			cursor_x += 5
			cur_y = right_y
		_:
			var run_w := 10
			segments.append({"x_start": cursor_x, "x_end": cursor_x + run_w - 1, "y_top": cur_y, "depth": 3, "allow_enemy": true, "diff": difficulty_bonus, "force_powerup": false})
			cursor_x += run_w - 1

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
			var ax := 15 if (is_left and is_right) else (9 if is_left else (13 if is_right else 10))
			var cell := Vector2i(x, y_top)
			tile_map_layer.set_cell(cell, AUTUMN_SOURCE_ID, Vector2i(ax, 3), 0)
			ground_list.append(cell)
		else:
			for d in range(depth):
				var y := y_top + d
				var ax := 3 if is_left else (5 if is_right else 4)
				var ay := 1 if d == 0 else (6 if d == depth - 1 else 5)
				var cell := Vector2i(x, y)
				tile_map_layer.set_cell(cell, AUTUMN_SOURCE_ID, Vector2i(ax, ay), 0)
				ground_list.append(cell)

func _can_place_tree_at(center_x: int, y_top: int, x_start: int, x_end: int) -> bool:
	if center_x - 1 < x_start + 1 or center_x + 1 > x_end - 1:
		return false
	for tx in range(center_x - 1, center_x + 2):
		if not _has_solid_cell(Vector2i(tx, y_top)):
			return false
	return _is_area_clear_of_ground(center_x - 2, center_x + 2, y_top - 4, y_top - 1)

func _can_place_house_at(center_x: int, y_top: int, x_start: int, x_end: int) -> bool:
	if center_x - 3 < x_start + 1 or center_x + 3 > x_end - 1:
		return false
	for tx in range(center_x - 3, center_x + 4):
		if not _has_solid_cell(Vector2i(tx, y_top)):
			return false
	return _is_area_clear_of_ground(center_x - 4, center_x + 4, y_top - 6, y_top - 1)

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

		if deco_style == 0 and width >= 9:
			var house_cx := x_start + width / 2
			if _can_place_house_at(house_cx, y_top, x_start, x_end):
				var house_cell := Vector2i(house_cx, y_top - 3)
				var house_ax := 0 if rng.randf() < 0.5 else 8
				tile_map_layer_2.set_cell(house_cell, DECO_HOUSE_ID, Vector2i(house_ax, 0), 0)
				deco_list.append(house_cell)
				placed_main_prop = true
				var bush_x := x_start + 1
				if abs(bush_x - house_cx) >= 4 and _is_area_clear_of_ground(bush_x, bush_x, y_top - 2, y_top - 1):
					var bcell := Vector2i(bush_x, y_top - 1)
					tile_map_layer_2.set_cell(bcell, DECO_GRASS_ID, Vector2i(1, 5), 0)
					deco_list.append(bcell)

		if not placed_main_prop and deco_style == 1 and width >= 5:
			var f_start := x_start + 1
			var f_end := mini(x_start + rng.randi_range(3, 4), x_end - 1)
			if _is_area_clear_of_ground(f_start, f_end, y_top - 2, y_top - 1):
				for fx in range(f_start, f_end + 1):
					var ax := 0 if fx == f_start else (3 if fx == f_end else (1 if (fx - f_start) % 2 == 1 else 2))
					var fcell := Vector2i(fx, y_top - 1)
					tile_map_layer_2.set_cell(fcell, DECO_FENCE_ID, Vector2i(ax, 2), 0)
					deco_list.append(fcell)
				placed_main_prop = true

		if not placed_main_prop and deco_style == 2 and width >= 5:
			var tree_cx := x_start + width / 2
			if _can_place_tree_at(tree_cx, y_top, x_start, x_end):
				var tree_cell := Vector2i(tree_cx, y_top - 2)
				var tree_ax := 1 if rng.randf() < 0.5 else 9
				tile_map_layer_2.set_cell(tree_cell, DECO_GRASS_ID, Vector2i(tree_ax, 1), 0)
				deco_list.append(tree_cell)
				placed_main_prop = true
				if x_end - 1 > tree_cx + 1 and _is_area_clear_of_ground(x_end - 1, x_end - 1, y_top - 2, y_top - 1):
					var fcell := Vector2i(x_end - 1, y_top - 1)
					tile_map_layer_2.set_cell(fcell, DECO_FLOWERS_ID, Vector2i(rng.randi_range(0, 3), 0), 0)
					deco_list.append(fcell)

		if not placed_main_prop:
			var slot := 0
			for x in range(x_start + 1, x_end, 2):
				if _is_area_clear_of_ground(x, x, y_top - 2, y_top - 1) and rng.randf() < 0.85:
					var dcell := Vector2i(x, y_top - 1)
					if slot % 2 == 0:
						tile_map_layer_2.set_cell(dcell, DECO_GRASS_ID, Vector2i(1, 5), 0)
					else:
						tile_map_layer_2.set_cell(dcell, DECO_FLOWERS_ID, Vector2i(rng.randi_range(0, 3), 0), 0)
					deco_list.append(dcell)
				slot += 1

	if force_powerup:
		var mid_tx := x_start + width / 2
		_spawn_collectible_above_tile(mid_tx, y_top, false)
	else:
		for tx in range(x_start + 1, x_end, 2):
			if rng.randf() < 0.65:
				_spawn_collectible_above_tile(tx, y_top, true)

	if allow_enemy and enemy_scene != null and width >= 5 and rng.randf() < (0.65 + diff_bonus):
		var enemy_tx := rng.randi_range(x_start + 1, x_end - 1)
		if _is_area_clear_of_ground(enemy_tx - 1, enemy_tx + 1, y_top - 3, y_top - 1):
			var enemy_wx := tile_map_layer.position.x + float(enemy_tx * TILE_SIZE) + 8.0
			var enemy_wy := tile_map_layer.position.y + float(y_top * TILE_SIZE) - 15.0
			var enemy_instance := enemy_scene.instantiate() as CharacterBody2D
			enemy_instance.global_position = Vector2(enemy_wx, enemy_wy)
			add_child(enemy_instance)

func cleanup_old_entities() -> void:
	if player == null:
		return
	var cutoff_x := player.global_position.x - CLEANUP_BEHIND_DISTANCE
	while generated_chunks.size() > 0:
		var oldest: Dictionary = generated_chunks[0]
		if float(oldest["end_world_x"]) < cutoff_x:
			for cell in oldest.get("ground_cells", []):
				tile_map_layer.set_cell(cell, -1)
			if tile_map_layer_2 != null:
				for dcell in oldest.get("deco_cells", []):
					tile_map_layer_2.set_cell(dcell, -1)
			generated_chunks.pop_front()
		else:
			break

	for child in get_children():
		if child is Node2D and child != player and (child.is_in_group("enemies") or child is Collectible):
			if child.global_position.x < cutoff_x:
				child.queue_free()

func _on_pit_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("fall_in_pit"):
		body.fall_in_pit()
