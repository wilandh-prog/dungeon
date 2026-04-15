class_name EnemyStateMachine
extends Node

# Simple state machine helper for enemies
# Not strictly needed since enemy_base.gd handles states directly,
# but available for more complex enemy behaviors

var current_state: String = "IDLE"
var states: Dictionary = {}
var owner_node: CharacterBody3D

func _ready() -> void:
	owner_node = get_parent() as CharacterBody3D

func add_state(state_name: String, enter: Callable = Callable(), process: Callable = Callable(), exit: Callable = Callable()) -> void:
	states[state_name] = {
		"enter": enter,
		"process": process,
		"exit": exit,
	}

func transition_to(new_state: String) -> void:
	if states.has(current_state) and states[current_state].exit.is_valid():
		states[current_state].exit.call()
	current_state = new_state
	if states.has(current_state) and states[current_state].enter.is_valid():
		states[current_state].enter.call()

func process_state(delta: float) -> void:
	if states.has(current_state) and states[current_state].process.is_valid():
		states[current_state].process.call(delta)
