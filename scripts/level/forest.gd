class_name Forest extends Node2D
## Cena da fase: liga o HUD ao jogador, toca a música e coordena a geração procedural.
## A lógica de geração fica em ChunkGenerator, ChunkPatterns, DecorationPlacer e EntitySpawner.

const C = preload("res://scripts/level/level_config.gd")

@export var enemy_scene: PackedScene = preload("res://scenes/orange.tscn")
@export var collectible_scene: PackedScene = preload("res://scenes/collectible.tscn")

@onready var hud: HUD = $HUD
@onready var player: Player = $Player
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var pit_area: Area2D = $PitArea
@onready var tile_map_layer: TileMapLayer = $TileMapLayer
@onready var tile_map_layer_2: TileMapLayer = $TileMapLayer2

var rng := RandomNumberGenerator.new()
var procedural_timer: float = 0.0
var spawner: EntitySpawner
var generator: ChunkGenerator

func _ready() -> void:
	rng.randomize()

	var tiles := LevelTiles.new(tile_map_layer, tile_map_layer_2)
	spawner = EntitySpawner.new(self, tiles, rng, enemy_scene, collectible_scene)
	generator = ChunkGenerator.new(rng, tiles, DecorationPlacer.new(tiles, rng), spawner)

	_connect_hud()
	_start_music()

	if pit_area and not pit_area.body_entered.is_connected(_on_pit_area_body_entered):
		pit_area.body_entered.connect(_on_pit_area_body_entered)

	_spawn_enemies_at_markers()
	spawner.spawn_initial_items()

	for i in range(C.INITIAL_CHUNKS):
		generator.generate_next()

func _process(delta: float) -> void:
	if player == null or player.is_dead:
		return

	procedural_timer += delta
	var dist_ahead := generator.frontier_world_x() - player.global_position.x

	if dist_ahead < C.LOOKAHEAD_DISTANCE or (procedural_timer >= C.PROCEDURAL_INTERVAL and dist_ahead < C.MAX_BUFFER_DISTANCE):
		procedural_timer = 0.0
		generator.generate_next()
		_cleanup_behind_player()

func _connect_hud() -> void:
	hud.hearts_template.visible = false
	player.health_change.connect(hud.update_hearts)
	player.coins_change.connect(hud.update_coins)
	player.score_change.connect(hud.update_score)
	player.powerup_state_change.connect(hud.update_powerup_icons)
	player.player_died.connect(hud.show_game_over)
	hud.update_hearts(player.health)
	hud.update_coins(player.coins)

func _start_music() -> void:
	if audio_stream_player:
		audio_stream_player.volume_db = C.MUSIC_VOLUME_DB
		if not audio_stream_player.playing:
			audio_stream_player.play()

## Inimigos fixos da parte feita à mão da fase (os Marker2D da cena).
func _spawn_enemies_at_markers() -> void:
	for child in get_children():
		if child is Marker2D:
			spawner.spawn_enemy_at(child.global_position)

func _cleanup_behind_player() -> void:
	var cutoff_x := player.global_position.x - C.CLEANUP_BEHIND_DISTANCE
	generator.cleanup_behind(cutoff_x)
	for child in get_children():
		if child is Node2D and child != player and (child.is_in_group("enemies") or child is Collectible):
			if child.global_position.x < cutoff_x:
				child.queue_free()

func _on_pit_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("fall_in_pit"):
		body.fall_in_pit()
