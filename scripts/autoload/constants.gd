extends Node

# Player
const PLAYER_MOVE_SPEED := 6.0
const PLAYER_JUMP_VELOCITY := 3.5
const PLAYER_MAX_HP := 200.0
const PLAYER_MAX_MANA := 150.0
const PLAYER_MANA_REGEN := 8.0 # per second
const PLAYER_MOUSE_SENSITIVITY := 0.002

# Dungeon
const ROOM_MIN_SIZE := 10.0
const ROOM_MAX_SIZE := 18.0
const ROOM_HEIGHT := 5.0
const DOOR_WIDTH := 2.0
const DOOR_HEIGHT := 3.0
const MIN_SPELL_ROOMS := 2
const MIN_ENEMY_ROOMS := 3
const ROOMS_PER_FLOOR := {1: 8, 2: 10} # 3+ defaults to 12
const DEFAULT_ROOMS_PER_FLOOR := 12

# Enemies
const ENEMY_SPAWN_MIN := 2
const ENEMY_SPAWN_MAX := 4
const ENEMY_DOOR_CLEARANCE := 2.0
const DIFFICULTY_SCALE_PER_FLOOR := 0.25

# Spells
const MAX_SPELL_SLOTS := 4
const BEAM_MANA_PER_SECOND := 15.0
const EMPOWERED_DAMAGE_MULT := 1.75
const EMPOWERED_MANA_MULT := 1.5
const AMPLIFY_DAMAGE_MULT := 2.0
const AMPLIFY_MANA_MULT := 2.0

# Fragment rarity weights (higher = more common)
const MODIFIER_WEIGHTS := {
	"NONE": 40,
	"PIERCE": 20,
	"SPLIT": 15,
	"CHAIN": 15,
	"AMPLIFY": 10,
}

# Room colors
const ROOM_COLORS := {
	"start": Color(0.2, 0.3, 0.6),
	"spell": Color(0.5, 0.2, 0.6),
	"enemy": Color(0.6, 0.2, 0.2),
	"boss": Color(0.4, 0.1, 0.1),
	"empty": Color(0.4, 0.4, 0.4),
}

# Cover objects per room type
const COVER_MIN := 2
const COVER_MAX := 4

# Gravity
const GRAVITY := 9.8

func get_rooms_for_floor(floor_number: int) -> int:
	if ROOMS_PER_FLOOR.has(floor_number):
		return ROOMS_PER_FLOOR[floor_number]
	return DEFAULT_ROOMS_PER_FLOOR
