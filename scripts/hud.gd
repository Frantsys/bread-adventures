class_name HUD extends CanvasLayer

@onready var hearts_container: HBoxContainer = $TopBar/LeftPanel/VBox/HeartsContainer
@onready var hearts_template: Control = $TopBar/LeftPanel/VBox/HeartsContainer/HeartsTemplate
@onready var coins_label: Label = $TopBar/LeftPanel/VBox/CoinsRow/CoinsLabel
@onready var powerup_icons: HBoxContainer = $TopBar/RightPanel/VBox/PowerupIcons
@onready var icon_double_jump: TextureRect = $TopBar/RightPanel/VBox/PowerupIcons/IconDoubleJump
@onready var icon_speed: TextureRect = $TopBar/RightPanel/VBox/PowerupIcons/IconSpeed
@onready var icon_shield: TextureRect = $TopBar/RightPanel/VBox/PowerupIcons/IconShield
@onready var score_label: Label = $TopBar/RightPanel/VBox/ScoreLabel
@onready var status_panel: PanelContainer = $StatusPanel
@onready var status_label: Label = $StatusPanel/StatusLabel

func _ready() -> void:
	if status_panel:
		status_panel.visible = false
	update_powerup_icons({})

func update_hearts(current_health: int) -> void:
	for child in hearts_container.get_children():
		if child != hearts_template:
			child.queue_free()

	for i in range(current_health):
		var new_heart := hearts_template.duplicate()
		new_heart.visible = true
		hearts_container.add_child(new_heart)

func update_coins(current_coins: int) -> void:
	if coins_label:
		coins_label.text = "%02d" % current_coins

func update_score(current_score: int) -> void:
	if score_label:
		score_label.text = "%05d" % current_score

func update_powerup_icons(state: Dictionary) -> void:
	if icon_double_jump:
		var dj_active: bool = bool(state.get("double_jump", false))
		icon_double_jump.modulate = Color(1, 1, 1, 1) if dj_active else Color(0.28, 0.28, 0.32, 0.35)
	if icon_speed:
		var sp_active: bool = bool(state.get("speed", false))
		icon_speed.modulate = Color(1, 1, 1, 1) if sp_active else Color(0.28, 0.28, 0.32, 0.35)
	if icon_shield:
		var sh_active: bool = bool(state.get("shield", false))
		icon_shield.modulate = Color(1, 1, 1, 1) if sh_active else Color(0.28, 0.28, 0.32, 0.35)

func show_game_over() -> void:
	if status_panel and status_label:
		status_label.text = "GAME OVER"
		status_panel.visible = true
