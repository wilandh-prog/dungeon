extends Control

func _ready() -> void:
	SdkManager.game_loading_stop()
	$VBox/PlayButton.pressed.connect(_on_play)
	$VBox/HowToPlayButton.pressed.connect(_on_how_to_play)
	$VBox/CreditsButton.pressed.connect(_on_credits)
	$HowToPlayPanel/VBox/BackButton.pressed.connect(_on_back)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_play() -> void:
	GameManager.start_run()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_how_to_play() -> void:
	$HowToPlayPanel.visible = true

func _on_credits() -> void:
	pass # Will show credits panel

func _on_back() -> void:
	$HowToPlayPanel.visible = false
