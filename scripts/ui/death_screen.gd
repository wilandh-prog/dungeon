extends Control

@onready var stats_label: Label = $PanelContainer/VBox/StatsLabel
@onready var revive_button: Button = $PanelContainer/VBox/ReviveButton
@onready var restart_button: Button = $PanelContainer/VBox/RestartButton
@onready var quit_button: Button = $PanelContainer/VBox/QuitButton

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	revive_button.pressed.connect(_on_revive)
	restart_button.pressed.connect(_on_restart)
	quit_button.pressed.connect(_on_quit)
	GameManager.player_died.connect(_on_player_died)

func _on_player_died() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

	var stats: Dictionary = GameManager.get_stats()
	stats_label.text = "Floor: %d\n" % GameManager.current_floor
	stats_label.text += "Rooms Cleared: %d\n" % stats.rooms_cleared
	stats_label.text += "Enemies Killed: %d\n" % stats.enemies_killed
	stats_label.text += "Spells Crafted: %d\n" % stats.spells_crafted
	stats_label.text += "Fragments Collected: %d\n" % stats.fragments_collected
	stats_label.text += "Spells Discovered: %d/%d" % [SpellDatabase.get_discovery_count(), SpellDatabase.total_possible_combos]

func _on_revive() -> void:
	# Rewarded ad for revive
	SdkManager.show_rewarded_ad(func():
		visible = false
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		GameManager.current_state = GameManager.GameState.PLAYING
		# Heal player
		var player := get_tree().current_scene.get_node_or_null("Player")
		if player and player.has_method("heal"):
			player.heal(player.max_hp * 0.5)
	)

func _on_restart() -> void:
	get_tree().paused = false
	GameManager.start_run()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_quit() -> void:
	get_tree().paused = false
	GameManager.current_state = GameManager.GameState.MENU
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
