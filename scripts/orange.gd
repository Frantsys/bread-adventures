class_name Orange extends CharacterBody2D

# --- Movimento ---
const SPEED := 55.0
const DEFAULT_GRAVITY: float = 980.0
const DESPAWN_Y := 290.0
const TURN_COOLDOWN_OBSTACLE := 0.35
const TURN_COOLDOWN_CHASE := 0.25

# --- Perseguição ao jogador ---
const CHASE_MIN_DISTANCE_X := 16.0
const CHASE_MAX_DISTANCE_X := 110.0
const CHASE_MAX_DISTANCE_Y := 32.0

# --- Pisão ---
const STOMP_BOUNCE_VELOCITY := -250.0
const STOMP_MIN_VELOCITY_Y := -10.0
const STOMP_HEIGHT_MARGIN := 2.0
# A StompBox é mais tolerante que a checagem por colisão.
const STOMPBOX_MIN_VELOCITY_Y := -15.0
const STOMPBOX_HEIGHT_MARGIN := -1.0
const DEFEAT_DESPAWN_DELAY := 0.28

# --- Animações ---
const ANIMATION_IDLE := "idle"
const ANIMATION_WALK := "walking"
const ANIMATION_FALL := "fall"
const ANIMATION_SQUISHED := "squished"
const ANIMATION_HURT := "hurt"

@export var damage: int = 1

@onready var animated: AnimatedSprite2D = $AnimatedSprite2D
@onready var sensors: Node2D = $Node2D
@onready var avoid_timer: Timer = $AvoidTimer
@onready var floor_ray: RayCast2D = $Node2D/FloorRay
@onready var wall_ray: RayCast2D = $Node2D/WallRay
@onready var hurtbox: Area2D = $Hurtbox
@onready var stompbox: Area2D = $StompBox
@onready var body_collision: CollisionShape2D = $CollisionShape2D

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
	if global_position.y > DESPAWN_Y:
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

	_update_direction()

	velocity.x = direction * SPEED
	move_and_slide()

	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i).get_collider()
		if col is Node and col.is_in_group("player"):
			if _is_head_stomp(col as Node2D):
				stomped_by(col as Node2D)
				return
			elif col.has_method("take_damage"):
				col.take_damage(damage)

	update_animations(direction)

func _update_direction() -> void:
	floor_ray.force_raycast_update()
	wall_ray.force_raycast_update()

	var hit_wall := is_on_wall() or wall_ray.is_colliding()
	var at_ledge := not floor_ray.is_colliding()

	if (hit_wall or at_ledge) and turn_cooldown <= 0.0:
		_set_direction(-direction, TURN_COOLDOWN_OBSTACLE)
		avoid_timer.start()
	elif player != null and avoid_timer.is_stopped() and turn_cooldown <= 0.0:
		var diff := player.global_position - global_position
		var in_range: bool = abs(diff.x) > CHASE_MIN_DISTANCE_X and abs(diff.x) < CHASE_MAX_DISTANCE_X and abs(diff.y) < CHASE_MAX_DISTANCE_Y
		var desired_dir := signf(diff.x)
		if in_range and desired_dir != direction:
			_set_direction(desired_dir, TURN_COOLDOWN_CHASE)

func _set_direction(new_dir: float, cooldown: float) -> void:
	direction = new_dir
	update_facing(int(direction))
	turn_cooldown = cooldown

func _is_stomp(body: Node2D, min_velocity_y: float, height_margin: float) -> bool:
	if is_defeated or not body.is_in_group("player"):
		return false
	var vy: float = body.velocity.y if "velocity" in body else 0.0
	return vy >= min_velocity_y and body.global_position.y <= global_position.y - height_margin

func _is_head_stomp(body: Node2D) -> bool:
	return _is_stomp(body, STOMP_MIN_VELOCITY_Y, STOMP_HEIGHT_MARGIN)

func stomped_by(body: Node2D) -> void:
	if is_defeated:
		return
	is_defeated = true
	remove_from_group("enemies")
	velocity = Vector2.ZERO

	if body_collision:
		body_collision.set_deferred("disabled", true)
	for area in [hurtbox, stompbox]:
		if area:
			area.set_deferred("monitoring", false)
			area.set_deferred("monitorable", false)

	if "velocity" in body:
		body.velocity.y = STOMP_BOUNCE_VELOCITY
	if "jump_count" in body:
		body.jump_count = 1
	if body.has_method("on_enemy_stomped"):
		body.on_enemy_stomped()

	if animated and animated.sprite_frames:
		if animated.sprite_frames.has_animation(ANIMATION_SQUISHED):
			animated.play(ANIMATION_SQUISHED)
		elif animated.sprite_frames.has_animation(ANIMATION_HURT):
			animated.play(ANIMATION_HURT)

	await get_tree().create_timer(DEFEAT_DESPAWN_DELAY).timeout
	queue_free()

func update_facing(dir: int) -> void:
	if dir != 0:
		sensors.scale.x = dir

func update_animations(dir: float) -> void:
	if is_defeated:
		return
	if not is_on_floor():
		animated.play(ANIMATION_FALL)
	elif dir != 0.0:
		animated.play(ANIMATION_WALK)
		animated.flip_h = dir < 0.0
	else:
		animated.play(ANIMATION_IDLE)

func _on_stompbox_body_entered(body: Node2D) -> void:
	if _is_stomp(body, STOMPBOX_MIN_VELOCITY_Y, STOMPBOX_HEIGHT_MARGIN):
		stomped_by(body)

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if is_defeated or not body.is_in_group("player"):
		return
	if _is_head_stomp(body):
		stomped_by(body)
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
