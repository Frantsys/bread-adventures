class_name Player extends CharacterBody2D

signal health_change(health_value: int)
signal coins_change(coins_value: int)
signal score_change(score_value: int)
signal powerup_state_change(state: Dictionary)
signal player_died

@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown: Timer = $DashCooldown
@onready var invuln_timer: Timer = $InvulnTimer
@onready var double_jump_timer: Timer = $DoubleJumpTimer
@onready var speed_boost_timer: Timer = $SpeedBoostTimer
@onready var contact_area: Area2D = $ContactArea
@onready var animated: AnimatedSprite2D = %AnimatedSprite2D
@onready var sfx_jump: AudioStreamPlayer = $SfxJump
@onready var sfx_coin: AudioStreamPlayer = $SfxCoin
@onready var sfx_powerup: AudioStreamPlayer = $SfxPowerup
@onready var sfx_hurt: AudioStreamPlayer = $SfxHurt

const BASE_SPEED := 115.0
const BOOSTED_SPEED := 175.0
const JUMP_VELOCITY := -315.0
const DOUBLE_JUMP_VELOCITY := -295.0
const ANIMATION_IDLE := "idle"
const ANIMATION_JUMP := "jump"
const ANIMATION_WALK := "walk"
const ANIMATION_DASH := "dash"
const DEFAULT_HEALTH := 5
const MAX_HEALTH := 5
const DEFAULT_DASH_SPEED := 310.0
const PIT_LIMIT_Y := 275.0
const COYOTE_MAX := 0.11
const JUMP_BUFFER_MAX := 0.11

var is_dashing := false
var can_air_dash := true
var is_dead := false
var invulnerable := false
var jump_count := 0
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var stomp_combo := 0
var start_x := 0.0
var max_distance_px := 0.0

var has_double_jump := false
var has_speed_boost := false
var has_shield := false

var coins := 0:
	set(value):
		coins = max(value, 0)
		coins_change.emit(coins)
		_emit_score()

var bonus_score := 0:
	set(value):
		bonus_score = max(value, 0)
		_emit_score()

var health := DEFAULT_HEALTH:
	set(value):
		health = clamp(value, 0, MAX_HEALTH)
		health_change.emit(health)
		if health <= 0 and not is_dead:
			die()

func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 4.0
	start_x = global_position.x
	health_change.emit(health)
	coins_change.emit(coins)
	_emit_score()
	_refresh_powerup_hud()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if global_position.y > PIT_LIMIT_Y:
		fall_in_pit()
		return

	if global_position.x - start_x > max_distance_px:
		max_distance_px = global_position.x - start_x
		_emit_score()

	if not dash_timer.is_stopped():
		move_and_slide()
		return

	if is_on_floor():
		coyote_timer = COYOTE_MAX
		jump_count = 0
		can_air_dash = true
		stomp_combo = 0
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_MAX
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	var max_jumps := 2 if has_double_jump else 1
	var current_speed := BOOSTED_SPEED if has_speed_boost else BASE_SPEED

	if jump_buffer_timer > 0.0:
		if coyote_timer > 0.0:
			velocity.y = JUMP_VELOCITY
			jump_count = 1
			coyote_timer = 0.0
			jump_buffer_timer = 0.0
			_play_sfx(sfx_jump)
		elif jump_count < max_jumps:
			velocity.y = DOUBLE_JUMP_VELOCITY
			jump_count += 1
			jump_buffer_timer = 0.0
			_play_sfx(sfx_jump)

	if Input.is_action_just_released("ui_accept") and velocity.y < -120.0:
		velocity.y *= 0.65

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		if Input.is_action_just_pressed("dash") and dash_cooldown.is_stopped() and (is_on_floor() or can_air_dash):
			if not is_on_floor():
				can_air_dash = false
			dash_timer.start()
			is_dashing = true
			velocity.x = direction * DEFAULT_DASH_SPEED
			velocity.y = 0.0
		else:
			velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)

	_update_animations(direction)
	move_and_slide()
	_check_enemy_contact()

func _emit_score() -> void:
	var dist_pts := int(max_distance_px / 16.0) * 10
	var total := dist_pts + (coins * 50) + bonus_score
	score_change.emit(total)

func _check_enemy_contact() -> void:
	if is_dead or invulnerable or not dash_timer.is_stopped():
		return

	if contact_area:
		for body in contact_area.get_overlapping_bodies():
			if body != self and body.is_in_group("enemies"):
				if _try_stomp_enemy(body):
					return
				_apply_enemy_hit(body)
				return

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is Node and collider.is_in_group("enemies"):
			if _try_stomp_enemy(collider):
				return
			_apply_enemy_hit(collider)
			return

func _try_stomp_enemy(enemy: Node) -> bool:
	if enemy is Node2D and velocity.y >= -10.0 and global_position.y <= enemy.global_position.y - 2.0:
		if enemy.has_method("stomped_by"):
			enemy.stomped_by(self)
			return true
	return false

func on_enemy_stomped() -> void:
	_play_sfx(sfx_jump)
	can_air_dash = true
	stomp_combo += 1
	coins += stomp_combo
	bonus_score += 100 * stomp_combo

func _apply_enemy_hit(enemy: Node) -> void:
	var push_dir := signf(global_position.x - enemy.global_position.x)
	if push_dir == 0.0:
		push_dir = -1.0
	velocity.x = push_dir * 150.0
	velocity.y = -170.0

	if has_shield:
		has_shield = false
		invulnerable = true
		invuln_timer.start()
		_play_sfx(sfx_powerup)
		_refresh_powerup_hud()
		_update_visual_tint()
		return

	var dmg := 1
	if "damage" in enemy:
		dmg = enemy.damage
	take_damage(dmg)

func _update_animations(direction: float) -> void:
	if is_dashing:
		animated.play(ANIMATION_DASH)
		return

	if direction != 0.0:
		animated.flip_h = direction < 0.0

	if not is_on_floor():
		animated.play(ANIMATION_JUMP)
	elif direction != 0.0:
		animated.play(ANIMATION_WALK)
	else:
		animated.play(ANIMATION_IDLE)

func _update_visual_tint() -> void:
	if is_dead:
		modulate = Color(1.0, 0.3, 0.3, 0.8)
	elif invulnerable:
		modulate = Color(1.0, 0.45, 0.45, 0.75)
	elif has_shield:
		modulate = Color(0.65, 1.0, 0.75, 1.0)
	elif has_speed_boost:
		modulate = Color(1.0, 0.88, 0.45, 1.0)
	elif has_double_jump:
		modulate = Color(0.65, 0.92, 1.0, 1.0)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)

func _refresh_powerup_hud() -> void:
	powerup_state_change.emit({
		"shield": has_shield,
		"double_jump": has_double_jump and not double_jump_timer.is_stopped(),
		"speed": has_speed_boost and not speed_boost_timer.is_stopped(),
	})

func take_damage(amount: int = 1) -> void:
	if is_dead or invulnerable:
		return
	_play_sfx(sfx_hurt)
	invulnerable = true
	invuln_timer.start()
	_update_visual_tint()
	health -= amount

func heal(amount: int = 1) -> void:
	if is_dead:
		return
	_play_sfx(sfx_powerup)
	health += amount
	bonus_score += 50

func add_coins(amount: int = 1) -> void:
	if is_dead:
		return
	_play_sfx(sfx_coin)
	coins += amount

func grant_double_jump(duration: float = 14.0) -> void:
	if is_dead:
		return
	_play_sfx(sfx_powerup)
	double_jump_timer.wait_time = duration
	double_jump_timer.start()
	has_double_jump = true
	bonus_score += 75
	_update_visual_tint()
	_refresh_powerup_hud()

func grant_speed_boost(duration: float = 10.0) -> void:
	if is_dead:
		return
	_play_sfx(sfx_powerup)
	speed_boost_timer.wait_time = duration
	speed_boost_timer.start()
	has_speed_boost = true
	bonus_score += 75
	_update_visual_tint()
	_refresh_powerup_hud()

func grant_shield() -> void:
	if is_dead:
		return
	_play_sfx(sfx_powerup)
	has_shield = true
	bonus_score += 100
	_update_visual_tint()
	_refresh_powerup_hud()

func fall_in_pit() -> void:
	if is_dead:
		return
	_play_sfx(sfx_hurt)
	health = 0

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	_update_visual_tint()
	player_died.emit()
	await get_tree().create_timer(0.8).timeout
	if is_inside_tree():
		get_tree().reload_current_scene()

func _play_sfx(player_audio: AudioStreamPlayer) -> void:
	if player_audio and player_audio.stream:
		player_audio.play()

func _on_dash_timer_timeout() -> void:
	velocity.x = 0.0
	is_dashing = false
	dash_cooldown.start()

func _on_invuln_timer_timeout() -> void:
	invulnerable = false
	_update_visual_tint()

func _on_double_jump_timer_timeout() -> void:
	has_double_jump = false
	_update_visual_tint()
	_refresh_powerup_hud()

func _on_speed_boost_timer_timeout() -> void:
	has_speed_boost = false
	_update_visual_tint()
	_refresh_powerup_hud()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == self or is_dead:
		return
	if body.is_in_group("enemies"):
		_check_enemy_contact()
