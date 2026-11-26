class_name HUD extends CanvasLayer

const ICON_ACTIVE_COLOR := Color.WHITE
const ICON_INACTIVE_COLOR := Color(0.28, 0.28, 0.32, 0.35)
const COINS_FORMAT := "%02d"
const SCORE_FORMAT := "%05d"
const GAME_OVER_TEXT := "GAME OVER"

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
		coins_label.text = COINS_FORMAT % current_coins

func update_score(current_score: int) -> void:
	if score_label:
		score_label.text = SCORE_FORMAT % current_score

func update_powerup_icons(state: Dictionary) -> void:
	_set_icon_active(icon_double_jump, state.get("double_jump", false))
	_set_icon_active(icon_speed, state.get("speed", false))
	_set_icon_active(icon_shield, state.get("shield", false))

func _set_icon_active(icon: TextureRect, active: bool) -> void:
	if icon:
		icon.modulate = ICON_ACTIVE_COLOR if active else ICON_INACTIVE_COLOR

func show_game_over() -> void:
	if status_panel and status_label:
		status_label.text = GAME_OVER_TEXT
		status_panel.visible = true
