class_name Orange extends CharacterBody2D

@onready var animated: AnimatedSprite2D = $AnimatedSprite2D
@onready var sensors: Node2D = $Node2D
@onready var avoid_timer: Timer = $AvoidTimer
@onready var floor_ray: RayCast2D = $Node2D/FloorRay
@onready var wall_ray: RayCast2D = $Node2D/WallRay
@onready var hurtbox: Area2D = $Hurtbox
@onready var stompbox: Area2D = $StompBox
@onready var body_collision: CollisionShape2D = $CollisionShape2D

@export var damage: int = 1
const SPEED := 55.0
const DEFAULT_GRAVITY: float = 980.0
const STOMP_BOUNCE_VELOCITY := -250.0

var player: Player = null
var direction := -1.0
var turn_cooldown := 0.0
var is_defeated := false

func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player") as Player
	update_facing(int(direction))
	if stompbox and not stompbox.body_entered.is_connected(_on_stompbox_body_entered):
		stompbox.body_entered.connect(_on_stompbox_body_entered)
	if hurtbox and not hurtbox.body_entered.is_connected(_on_hurtbox_body_entered):
		hurtbox.body_entered.connect(_on_hurtbox_body_entered)

func _physics_process(delta: float) -> void:
	if is_defeated:
		return
	if global_position.y > 290.0:
		queue_free()
		return

	if turn_cooldown > 0.0:
		turn_cooldown -= delta

	if not is_on_floor():
		velocity.y += DEFAULT_GRAVITY * delta
		velocity.x = 0.0
		move_and_slide()
		update_animations(0.0)
		return

	floor_ray.force_raycast_update()
	wall_ray.force_raycast_update()

	var hit_wall := is_on_wall() or wall_ray.is_colliding()
	var at_ledge := not floor_ray.is_colliding()

	if (hit_wall or at_ledge) and turn_cooldown <= 0.0:
		direction *= -1.0
		update_facing(int(direction))
		avoid_timer.start()
		turn_cooldown = 0.35
	elif player != null and avoid_timer.is_stopped() and turn_cooldown <= 0.0:
		var diff := player.global_position - global_position
		if abs(diff.x) > 16.0 and abs(diff.x) < 110.0 and abs(diff.y) < 32.0:
			var desired_dir := signf(diff.x)
			if desired_dir != direction:
				direction = desired_dir
				update_facing(int(direction))
				turn_cooldown = 0.25

	velocity.x = direction * SPEED
	move_and_slide()

	for i in range(get_slide_collision_count()):
		var col_info := get_slide_collision(i)
		var col := col_info.get_collider()
		if col is Node and col.is_in_group("player"):
			if _is_head_stomp(col as Node2D):
				stomped_by(col as Node2D)
				return
			elif col.has_method("take_damage"):
				col.take_damage(damage)

	update_animations(direction)

func _is_head_stomp(body: Node2D) -> bool:
	if is_defeated or not body.is_in_group("player"):
		return false
	var vy: float = body.velocity.y if "velocity" in body else 0.0
	return vy >= -10.0 and body.global_position.y <= global_position.y - 2.0

func stomped_by(body: Node2D) -> void:
	if is_defeated:
		return
	is_defeated = true
	remove_from_group("enemies")
	velocity = Vector2.ZERO

	if body_collision:
		body_collision.set_deferred("disabled", true)
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	if stompbox:
		stompbox.set_deferred("monitoring", false)
		stompbox.set_deferred("monitorable", false)

	if "velocity" in body:
		body.velocity.y = STOMP_BOUNCE_VELOCITY
	if "jump_count" in body:
		body.jump_count = 1
	if body.has_method("on_enemy_stomped"):
		body.on_enemy_stomped()

	if animated and animated.sprite_frames:
		if animated.sprite_frames.has_animation("squished"):
			animated.play("squished")
		elif animated.sprite_frames.has_animation("hurt"):
			animated.play("hurt")

	await get_tree().create_timer(0.28).timeout
	queue_free()

func update_facing(dir: int) -> void:
	if dir != 0:
		sensors.scale.x = dir

func update_animations(dir: float) -> void:
	if is_defeated:
		return
	if not is_on_floor():
		animated.play("fall")
	elif dir != 0.0:
		animated.play("walking")
		animated.flip_h = dir < 0.0
	else:
		animated.play("idle")

func _on_stompbox_body_entered(body: Node2D) -> void:
	if is_defeated or not body.is_in_group("player"):
		return
	var vy: float = body.velocity.y if "velocity" in body else 0.0
	if vy >= -15.0 and body.global_position.y <= global_position.y + 1.0:
		stomped_by(body)

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if is_defeated or not body.is_in_group("player"):
		return
	if _is_head_stomp(body):
		stomped_by(body)
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
