class_name PlayerVisuals extends RefCounted
## Escolhe a animação e a cor do jogador a partir do estado dele.

const ANIMATION_IDLE := "idle"
const ANIMATION_JUMP := "jump"
const ANIMATION_WALK := "walk"
const ANIMATION_DASH := "dash"

const TINT_DEAD := Color(1.0, 0.3, 0.3, 0.8)
const TINT_INVULNERABLE := Color(1.0, 0.45, 0.45, 0.75)
const TINT_SHIELD := Color(0.65, 1.0, 0.75, 1.0)
const TINT_SPEED := Color(1.0, 0.88, 0.45, 1.0)
const TINT_DOUBLE_JUMP := Color(0.65, 0.92, 1.0, 1.0)
const TINT_NORMAL := Color.WHITE

static func update_animation(player: Player, sprite: AnimatedSprite2D, direction: float) -> void:
	if player.is_dashing:
		sprite.play(ANIMATION_DASH)
		return

	if direction != 0.0:
		sprite.flip_h = direction < 0.0

	if not player.is_on_floor():
		sprite.play(ANIMATION_JUMP)
	elif direction != 0.0:
		sprite.play(ANIMATION_WALK)
	else:
		sprite.play(ANIMATION_IDLE)

## A ordem define a prioridade: morte > invulnerável > escudo > velocidade > pulo duplo.
static func tint_for(player: Player) -> Color:
	if player.is_dead:
		return TINT_DEAD
	if player.invulnerable:
		return TINT_INVULNERABLE
	if player.has_shield:
		return TINT_SHIELD
	if player.has_speed_boost:
		return TINT_SPEED
	if player.has_double_jump:
		return TINT_DOUBLE_JUMP
	return TINT_NORMAL
