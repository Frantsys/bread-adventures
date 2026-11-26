class_name PlayerConfig extends RefCounted
## Constantes de ajuste do jogador: movimento, combate, power-ups e pontuação.

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
