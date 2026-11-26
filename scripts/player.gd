class_name Player extends CharacterBody2D

signal health_change(health_value: int)
signal coins_change(coins_value: int)
signal score_change(score_value: int)
signal powerup_state_change(state: Dictionary)
signal player_died

# --- Movimento ---
const BASE_SPEED := 115.0
const BOOSTED_SPEED := 175.0
const JUMP_VELOCITY := -315.0
const DOUBLE_JUMP_VELOCITY := -295.0
const DEFAULT_DASH_SPEED := 310.0
const FLOOR_SNAP_LENGTH := 4.0
const JUMP_CUT_MIN_VELOCITY := -120.0
const JUMP_CUT_MULTIPLIER := 0.65
const COYOTE_MAX := 0.11
const JUMP_BUFFER_MAX := 0.11
const PIT_LIMIT_Y := 275.0

# --- Combate ---
const DEFAULT_HEALTH := 5
const MAX_HEALTH := 5
const DEFAULT_ENEMY_DAMAGE := 1
const STOMP_MIN_VELOCITY_Y := -10.0
const STOMP_HEIGHT_MARGIN := 2.0
const KNOCKBACK_VELOCITY := Vector2(150.0, -170.0)
const DEATH_RELOAD_DELAY := 0.8

# --- Power-ups ---
const DOUBLE_JUMP_DURATION := 14.0
const SPEED_BOOST_DURATION := 10.0

# --- Pontuação ---
const TILE_SIZE_PX := 16.0
const POINTS_PER_TILE := 10
const POINTS_PER_COIN := 50
const POINTS_PER_STOMP := 100
const POINTS_HEAL := 50
const POINTS_TIMED_POWERUP := 75
const POINTS_SHIELD := 100

# --- Animações ---
const ANIMATION_IDLE := "idle"
const ANIMATION_JUMP := "jump"
const ANIMATION_WALK := "walk"
const ANIMATION_DASH := "dash"

# --- Cores de estado ---
const TINT_DEAD := Color(1.0, 0.3, 0.3, 0.8)
const TINT_INVULNERABLE := Color(1.0, 0.45, 0.45, 0.75)
const TINT_SHIELD := Color(0.65, 1.0, 0.75, 1.0)
const TINT_SPEED := Color(1.0, 0.88, 0.45, 1.0)
const TINT_DOUBLE_JUMP := Color(0.65, 0.92, 1.0, 1.0)
const TINT_NORMAL := Color.WHITE

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

# =========================================================
# Ciclo de vida
# =========================================================

func _ready() -> void:
	add_to_group("player")
	floor_snap_length = FLOOR_SNAP_LENGTH
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

	_track_distance()

	if not dash_timer.is_stopped():
		move_and_slide()
		return

	_apply_floor_state_and_gravity(delta)
	_handle_jump(delta)

	var direction := Input.get_axis("ui_left", "ui_right")
	_handle_horizontal(direction)

	_update_animations(direction)
	move_and_slide()
	_check_enemy_contact()

# =========================================================
# Movimento
# =========================================================

func _track_distance() -> void:
	var distance := global_position.x - start_x
	if distance > max_distance_px:
		max_distance_px = distance
		_emit_score()

func _apply_floor_state_and_gravity(delta: float) -> void:
	if is_on_floor():
		coyote_timer = COYOTE_MAX
		jump_count = 0
		can_air_dash = true
		stomp_combo = 0
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)
		velocity += get_gravity() * delta

func _handle_jump(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_MAX
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	var max_jumps := 2 if has_double_jump else 1

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

	# Pulo variável: soltar o botão cedo corta a subida.
	if Input.is_action_just_released("ui_accept") and velocity.y < JUMP_CUT_MIN_VELOCITY:
		velocity.y *= JUMP_CUT_MULTIPLIER

func _handle_horizontal(direction: float) -> void:
	var current_speed := BOOSTED_SPEED if has_speed_boost else BASE_SPEED
	if direction == 0.0:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		return

	if Input.is_action_just_pressed("dash") and dash_cooldown.is_stopped() and (is_on_floor() or can_air_dash):
		if not is_on_floor():
			can_air_dash = false
		dash_timer.start()
		is_dashing = true
		velocity.x = direction * DEFAULT_DASH_SPEED
		velocity.y = 0.0
	else:
		velocity.x = direction * current_speed

# =========================================================
# Pontuação
# =========================================================

func _emit_score() -> void:
	var dist_pts := int(max_distance_px / TILE_SIZE_PX) * POINTS_PER_TILE
	var total := dist_pts + (coins * POINTS_PER_COIN) + bonus_score
	score_change.emit(total)

# =========================================================
# Combate
# =========================================================

func _check_enemy_contact() -> void:
	if is_dead or invulnerable or not dash_timer.is_stopped():
		return

	if contact_area:
		for body in contact_area.get_overlapping_bodies():
			if body != self and body.is_in_group("enemies"):
				_resolve_enemy_contact(body)
				return

	for i in range(get_slide_collision_count()):
		var collider := get_slide_collision(i).get_collider()
		if collider is Node and collider.is_in_group("enemies"):
			_resolve_enemy_contact(collider)
			return

func _resolve_enemy_contact(enemy: Node) -> void:
	if not _try_stomp_enemy(enemy):
		_apply_enemy_hit(enemy)

func _try_stomp_enemy(enemy: Node) -> bool:
	if enemy is Node2D and velocity.y >= STOMP_MIN_VELOCITY_Y and global_position.y <= enemy.global_position.y - STOMP_HEIGHT_MARGIN:
		if enemy.has_method("stomped_by"):
			enemy.stomped_by(self)
			return true
	return false

func on_enemy_stomped() -> void:
	_play_sfx(sfx_jump)
	can_air_dash = true
	stomp_combo += 1
	coins += stomp_combo
	bonus_score += POINTS_PER_STOMP * stomp_combo

func _apply_enemy_hit(enemy: Node) -> void:
	var push_dir := signf(global_position.x - enemy.global_position.x)
	if push_dir == 0.0:
		push_dir = -1.0
	velocity = Vector2(push_dir * KNOCKBACK_VELOCITY.x, KNOCKBACK_VELOCITY.y)

	if has_shield:
		has_shield = false
		invulnerable = true
		invuln_timer.start()
		_play_sfx(sfx_powerup)
		_refresh_powerup_hud()
		_update_visual_tint()
		return

	var dmg := DEFAULT_ENEMY_DAMAGE
	if "damage" in enemy:
		dmg = enemy.damage
	take_damage(dmg)

func take_damage(amount: int = 1) -> void:
	if is_dead or invulnerable:
		return
	_play_sfx(sfx_hurt)
	invulnerable = true
	invuln_timer.start()
	_update_visual_tint()
	health -= amount

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
	await get_tree().create_timer(DEATH_RELOAD_DELAY).timeout
	if is_inside_tree():
		get_tree().reload_current_scene()

# =========================================================
# Itens e power-ups
# =========================================================

func heal(amount: int = 1) -> void:
	if is_dead:
		return
	_play_sfx(sfx_powerup)
	health += amount
	bonus_score += POINTS_HEAL

func add_coins(amount: int = 1) -> void:
	if is_dead:
		return
	_play_sfx(sfx_coin)
	coins += amount

func grant_double_jump(duration: float = DOUBLE_JUMP_DURATION) -> void:
	if is_dead:
		return
	_start_timed_powerup(double_jump_timer, duration)
	has_double_jump = true
	_after_powerup(POINTS_TIMED_POWERUP)

func grant_speed_boost(duration: float = SPEED_BOOST_DURATION) -> void:
	if is_dead:
		return
	_start_timed_powerup(speed_boost_timer, duration)
	has_speed_boost = true
	_after_powerup(POINTS_TIMED_POWERUP)

func grant_shield() -> void:
	if is_dead:
		return
	_play_sfx(sfx_powerup)
	has_shield = true
	_after_powerup(POINTS_SHIELD)

func _start_timed_powerup(timer: Timer, duration: float) -> void:
	_play_sfx(sfx_powerup)
	timer.wait_time = duration
	timer.start()

func _after_powerup(points: int) -> void:
	bonus_score += points
	_update_visual_tint()
	_refresh_powerup_hud()

# =========================================================
# Visual / áudio
# =========================================================

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
		modulate = TINT_DEAD
	elif invulnerable:
		modulate = TINT_INVULNERABLE
	elif has_shield:
		modulate = TINT_SHIELD
	elif has_speed_boost:
		modulate = TINT_SPEED
	elif has_double_jump:
		modulate = TINT_DOUBLE_JUMP
	else:
		modulate = TINT_NORMAL

func _refresh_powerup_hud() -> void:
	powerup_state_change.emit({
		"shield": has_shield,
		"double_jump": has_double_jump and not double_jump_timer.is_stopped(),
		"speed": has_speed_boost and not speed_boost_timer.is_stopped(),
	})

func _play_sfx(player_audio: AudioStreamPlayer) -> void:
	if player_audio and player_audio.stream:
		player_audio.play()

# =========================================================
# Sinais
# =========================================================

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
