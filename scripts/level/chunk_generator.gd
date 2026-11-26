class_name ChunkGenerator extends RefCounted
## Gera a fase infinita em trechos ("chunks") à frente do jogador e apaga os que ficaram para trás.

const C = preload("res://scripts/level/level_config.gd")

var rng: RandomNumberGenerator
var tiles: LevelTiles
var patterns: ChunkPatterns
var decorations: DecorationPlacer
var spawner: EntitySpawner

var next_tile_x: int = C.INITIAL_NEXT_TILE_X
var last_platform_y: int = C.INITIAL_PLATFORM_Y
var generated_chunks: Array[Dictionary] = []
var pattern_bag: Array[int] = []
var last_pattern_id: int = -1

func _init(random: RandomNumberGenerator, level_tiles: LevelTiles, decoration_placer: DecorationPlacer, entity_spawner: EntitySpawner) -> void:
	rng = random
	tiles = level_tiles
	patterns = ChunkPatterns.new(random)
	decorations = decoration_placer
	spawner = entity_spawner

## Posição X (mundo) onde termina o último trecho gerado.
func frontier_world_x() -> float:
	return tiles.column_world_x(next_tile_x)

## "Saco" de padrões: todos saem uma vez antes de repetir, em ordem aleatória.
func _draw_next_pattern() -> int:
	if pattern_bag.is_empty():
		pattern_bag.assign(range(C.PATTERN_COUNT))
		pattern_bag.shuffle()
		# Evita repetir o mesmo padrão na virada do saco.
		if pattern_bag[0] == last_pattern_id and pattern_bag.size() > 1:
			var swap_val := pattern_bag[0]
			pattern_bag[0] = pattern_bag[1]
			pattern_bag[1] = swap_val
	last_pattern_id = pattern_bag.pop_front()
	return last_pattern_id

func generate_next() -> void:
	if tiles.ground == null:
		return

	var pattern_id := _draw_next_pattern()
	var ground_list: Array[Vector2i] = []
	var deco_list: Array[Vector2i] = []

	var cursor_x := next_tile_x + patterns.random_gap()
	var cur_y := patterns.clamp_reachable_y(last_platform_y, last_platform_y + rng.randi_range(-1, 1))
	var diff := clampf(float(cursor_x) / C.DIFFICULTY_RAMP_TILES, 0.0, C.MAX_DIFFICULTY_BONUS)

	var result := patterns.build(pattern_id, cursor_x, cur_y, diff)
	var segments: Array[Dictionary] = result["segments"]

	# Primeiro pinta todo o chão, depois decora: assim as checagens de espaço livre veem o trecho inteiro.
	for seg in segments:
		tiles.paint_ground(seg["x_start"], seg["x_end"], seg["y_top"], seg["depth"], ground_list)

	for seg in segments:
		decorations.decorate_segment(seg["x_start"], seg["x_end"], seg["y_top"], deco_list)
		spawner.populate_segment(seg["x_start"], seg["x_end"], seg["y_top"], seg["allow_enemy"], seg["diff"], seg["force_powerup"])

	next_tile_x = result["end_x"]
	last_platform_y = result["end_y"]

	generated_chunks.append({
		"end_world_x": tiles.column_world_x(next_tile_x + 1),
		"ground_cells": ground_list,
		"deco_cells": deco_list,
	})

func cleanup_behind(cutoff_x: float) -> void:
	while not generated_chunks.is_empty() and float(generated_chunks[0]["end_world_x"]) < cutoff_x:
		var oldest: Dictionary = generated_chunks.pop_front()
		tiles.clear_cells(oldest.get("ground_cells", []), oldest.get("deco_cells", []))
