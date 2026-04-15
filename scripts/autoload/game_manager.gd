extends Node

signal floor_started(floor_number: int)
signal floor_completed(floor_number: int)
signal player_died
signal run_started
signal run_ended(stats: Dictionary)
signal room_cleared(room_type: String)
signal enemy_killed
signal fragment_collected

enum GameState { MENU, PLAYING, PAUSED, CRAFTING, DEAD }

var current_state: GameState = GameState.MENU
var current_floor: int = 1
var floor_seed: int = 0

# Run stats
var stats := {
	"rooms_cleared": 0,
	"spells_crafted": 0,
	"enemies_killed": 0,
	"fragments_collected": 0,
	"floors_completed": 0,
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_run() -> void:
	current_floor = 1
	floor_seed = randi()
	_reset_stats()
	current_state = GameState.PLAYING
	run_started.emit()
	floor_started.emit(current_floor)

func complete_floor() -> void:
	stats.floors_completed += 1
	floor_completed.emit(current_floor)
	current_floor += 1
	floor_seed = randi()
	floor_started.emit(current_floor)

func on_player_died() -> void:
	current_state = GameState.DEAD
	player_died.emit()

func on_enemy_killed() -> void:
	stats.enemies_killed += 1
	enemy_killed.emit()

func on_room_cleared(room_type: String) -> void:
	stats.rooms_cleared += 1
	room_cleared.emit(room_type)

func on_fragment_collected() -> void:
	stats.fragments_collected += 1
	fragment_collected.emit()

func on_spell_crafted() -> void:
	stats.spells_crafted += 1

func set_paused(paused: bool) -> void:
	if current_state == GameState.DEAD:
		return
	if paused:
		current_state = GameState.PAUSED
	else:
		current_state = GameState.PLAYING
	get_tree().paused = paused

func set_crafting(crafting: bool) -> void:
	if crafting:
		current_state = GameState.CRAFTING
	else:
		current_state = GameState.PLAYING
	get_tree().paused = crafting

func get_difficulty_multiplier() -> float:
	return 1.0 + Constants.DIFFICULTY_SCALE_PER_FLOOR * current_floor

func get_stats() -> Dictionary:
	return stats.duplicate()

func _reset_stats() -> void:
	stats = {
		"rooms_cleared": 0,
		"spells_crafted": 0,
		"enemies_killed": 0,
		"fragments_collected": 0,
		"floors_completed": 0,
	}
