class_name LevelConfig extends RefCounted
## Constantes de ajuste da fase: tamanhos, IDs do tileset, chances e limites da geração.

# --- Tilemap ---
const TILE_SIZE := 16
const HALF_TILE := 8.0
const EMPTY_SOURCE_ID := -1
const AUTUMN_SOURCE_ID := 1
const DECO_GRASS_ID := 0
const DECO_FLOWERS_ID := 1
const DECO_HOUSE_ID := 2
const DECO_PLANTS_ID := 3
const DECO_FENCE_ID := 4

# Coordenadas no atlas do tileset de outono (chão).
const THIN_ROW_Y := 3
const THIN_SINGLE_X := 15
const THIN_LEFT_X := 9
const THIN_MID_X := 10
const THIN_RIGHT_X := 13
const THICK_LEFT_X := 3
const THICK_MID_X := 4
const THICK_RIGHT_X := 5
const THICK_TOP_Y := 1
const THICK_MID_Y := 5
const THICK_BOTTOM_Y := 6

# Coordenadas no atlas das decorações.
const BUSH_ATLAS := Vector2i(1, 5)
const HOUSE_ATLAS_X := [0, 8]
const TREE_ATLAS_X := [1, 9]
const TREE_ATLAS_Y := 1
const FENCE_ATLAS_Y := 2
const FENCE_LEFT_X := 0
const FENCE_MID_A_X := 1
const FENCE_MID_B_X := 2
const FENCE_RIGHT_X := 3
const FLOWER_VARIANTS := 4

# --- Geração procedural ---
const LOOKAHEAD_DISTANCE := 480.0
const MAX_BUFFER_DISTANCE := 960.0
const CLEANUP_BEHIND_DISTANCE := 540.0
const PROCEDURAL_INTERVAL := 2.0
const INITIAL_CHUNKS := 4
const INITIAL_NEXT_TILE_X := 98
const INITIAL_PLATFORM_Y := 10
const MIN_GAP_TILES := 3
const MAX_GAP_TILES := 5
const MAX_UPWARD_STEP := 2
const MIN_PLATFORM_Y := 5
const MAX_PLATFORM_Y := 10
const PLATFORM_SCAN_MIN_Y := 3
const PLATFORM_SCAN_MAX_Y := 13
const PATTERN_COUNT := 8
const DIFFICULTY_RAMP_TILES := 1400.0
const MAX_DIFFICULTY_BONUS := 0.2

# --- Spawns ---
const INITIAL_ITEM_COLUMNS: Array[int] = [7, 19, 27, 38, 46, 55, 65, 73, 82, 91]
const COLLECTIBLE_Y_OFFSET := 10.0
const ENEMY_Y_OFFSET := 15.0
const COIN_CHANCE := 0.72
const ITEM_CHANCE_PER_SLOT := 0.65
const ENEMY_BASE_CHANCE := 0.65
const DECO_CHANCE_PER_SLOT := 0.85
const DOUBLE_JUMP_DURATION := 14.0
const SPEED_BOOST_DURATION := 10.0

# --- Áudio ---
const MUSIC_VOLUME_DB := -12.0
