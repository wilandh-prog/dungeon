extends Control

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	$PanelContainer/VBox/ContinueButton.pressed.connect(_on_continue)
	GameManager.floor_completed.connect(_on_floor_completed)

func _on_floor_completed(floor_number: int) -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

	var stats: Dictionary = GameManager.get_stats()
	$PanelContainer/VBox/Title.text = "FLOOR %d COMPLETE!" % floor_number
	$PanelContainer/VBox/StatsLabel.text = "Enemies Killed: %d\nSpells Crafted: %d\nFragments: %d" % [
		stats.enemies_killed, stats.spells_crafted, stats.fragments_collected
	]

func _on_continue() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
