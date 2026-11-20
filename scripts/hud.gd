class_name HUD extends CanvasLayer

@onready var hearts_container: HBoxContainer = $HeartsContainer
@onready var hearts_template: Control = $HeartsContainer/HeartsTemplate


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func update_hearts(current_health: int) -> void:
	# Remove os corações antigos, preservando apenas o molde invisível
	for child in hearts_container.get_children():
		if child != hearts_template:
			child.queue_free()
	
	# Cria um novo coração para cada ponto de vida
	for i in range(current_health):
		var new_heart := hearts_template.duplicate()
		new_heart.visible = true
		hearts_container.add_child(new_heart)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
