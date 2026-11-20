class_name Forest extends Node2D
@onready var marker_2d: Marker2D = $Marker2D
@export var enemy_scene: PackedScene
@onready var hud: HUD = $HUD
@onready var player: Player = $Player


@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

# array de pontos de spawn de inimigos
var spawn_points: Array[Marker2D] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hud.hearts_template.visible = false
	player.health_change.connect(hud.update_hearts)
	
	hud.update_hearts(player.health)
	# Logica para spawn de inimigos em qualquer Mark2D presente no n
	for child in get_children():
		if child is Marker2D:
			spawn_points.append(child)
		
	audio_stream_player.play()
	spawn_enemies()
	pass # Replace with function body.


func spawn_enemies():
	if enemy_scene == null:
		return
	for spawn_point in spawn_points:
		var enemy_instance := enemy_scene.instantiate() as CharacterBody2D
		enemy_instance.global_position = spawn_point.global_position
	
		add_child(enemy_instance)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
