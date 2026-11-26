class_name EntitySpawner extends RefCounted
## Cria inimigos e coletáveis na fase.

const C = preload("res://scripts/level/level_config.gd")

var parent: Node
var tiles: LevelTiles
var rng: RandomNumberGenerator
var enemy_scene: PackedScene
var collectible_scene: PackedScene

func _init(parent_node: Node, level_tiles: LevelTiles, random: RandomNumberGenerator, enemy: PackedScene, collectible: PackedScene) -> void:
	parent = parent_node
	tiles = level_tiles
	rng = random
	enemy_scene = enemy
	collectible_scene = collectible

func spawn_enemy_at(pos: Vector2) -> void:
	if enemy_scene == null:
		return
	var enemy_instance := enemy_scene.instantiate() as CharacterBody2D
	enemy_instance.global_position = pos
	parent.add_child(enemy_instance)

func spawn_initial_items() -> void:
	for tx in C.INITIAL_ITEM_COLUMNS:
		var top_y := tiles.find_highest_platform_tile_at_x(tx)
		if top_y != -1:
			spawn_collectible_above_tile(tx, top_y, true)

func spawn_collectible_above_tile(tx: int, y_top: int, allow_coin: bool) -> void:
	if collectible_scene == null or tiles.ground == null:
		return
	if not tiles.has_solid_cell(Vector2i(tx, y_top)) or not tiles.is_space_above_clear(tx, y_top):
		return

	var item := collectible_scene.instantiate() as Collectible
	item.global_position = tiles.tile_to_world(tx, y_top, C.COLLECTIBLE_Y_OFFSET)
	item.amount = 1
	item.powerup_duration = 0.0

	if allow_coin and rng.randf() < C.COIN_CHANCE:
		item.item_type = Collectible.ItemType.COIN
	else:
		match rng.randi_range(0, 3):
			0:
				item.item_type = Collectible.ItemType.DOUBLE_JUMP
				item.powerup_duration = C.DOUBLE_JUMP_DURATION
			1:
				item.item_type = Collectible.ItemType.SPEED_BOOST
				item.powerup_duration = C.SPEED_BOOST_DURATION
			2:
				item.item_type = Collectible.ItemType.SHIELD
			_:
				item.item_type = Collectible.ItemType.HEALTH

	parent.add_child(item)

## Itens e inimigo de um segmento recém-gerado.
func populate_segment(x_start: int, x_end: int, y_top: int, allow_enemy: bool, diff_bonus: float, force_powerup: bool) -> void:
	var width := x_end - x_start + 1

	if force_powerup:
		spawn_collectible_above_tile(x_start + width / 2, y_top, false)
	else:
		for tx in range(x_start + 1, x_end, 2):
			if rng.randf() < C.ITEM_CHANCE_PER_SLOT:
				spawn_collectible_above_tile(tx, y_top, true)

	if allow_enemy and enemy_scene != null and width >= 5 and rng.randf() < (C.ENEMY_BASE_CHANCE + diff_bonus):
		var enemy_tx := rng.randi_range(x_start + 1, x_end - 1)
		if tiles.is_area_clear(enemy_tx - 1, enemy_tx + 1, y_top - 3, y_top - 1):
			spawn_enemy_at(tiles.tile_to_world(enemy_tx, y_top, C.ENEMY_Y_OFFSET))
