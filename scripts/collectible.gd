class_name Collectible extends Area2D

enum ItemType { COIN, HEALTH, DOUBLE_JUMP, SPEED_BOOST, SHIELD }

@export var item_type: ItemType = ItemType.COIN
@export var amount: int = 1
@export var powerup_duration: float = 12.0

@onready var animated: AnimatedSprite2D = $AnimatedSprite2D
var start_y: float = 0.0
var time_acc: float = 0.0

func _ready() -> void:
	start_y = round(position.y)
	body_entered.connect(_on_body_entered)
	_setup_visual()

func _process(delta: float) -> void:
	time_acc += delta * 4.5
	position.y = round(start_y + sin(time_acc) * 2.0)

func _setup_visual() -> void:
	if not animated:
		return
	animated.scale = Vector2(1, 1)
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	match item_type:
		ItemType.COIN:
			animated.play("coin")
		ItemType.HEALTH:
			animated.play("health")
		ItemType.DOUBLE_JUMP:
			animated.play("double_jump")
		ItemType.SPEED_BOOST:
			animated.play("speed")
		ItemType.SHIELD:
			animated.play("shield")

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	match item_type:
		ItemType.COIN:
			if body.has_method("add_coins"):
				body.add_coins(amount)
		ItemType.HEALTH:
			if body.has_method("heal"):
				body.heal(amount)
		ItemType.DOUBLE_JUMP:
			if body.has_method("grant_double_jump"):
				body.grant_double_jump(powerup_duration)
		ItemType.SPEED_BOOST:
			if body.has_method("grant_speed_boost"):
				body.grant_speed_boost(powerup_duration)
		ItemType.SHIELD:
			if body.has_method("grant_shield"):
				body.grant_shield()

	queue_free()
