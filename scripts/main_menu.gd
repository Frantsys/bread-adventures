class_name MainMenu extends Control

@export var game_scene_path: String = "res://scenes/forest.tscn"

@onready var play_button: Button = $CenterPanel/VBox/PlayButton
@onready var preview_penguin: AnimatedSprite2D = $PreviewPenguin

func _ready() -> void:
	if preview_penguin and preview_penguin.sprite_frames:
		preview_penguin.play("idle")
	if play_button:
		play_button.grab_focus()
		if not play_button.pressed.is_connected(_on_play_pressed):
			play_button.pressed.connect(_on_play_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_play_pressed()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(game_scene_path)
