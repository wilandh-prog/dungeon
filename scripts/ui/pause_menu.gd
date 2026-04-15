extends Control

func _ready() -> void:
	visible = false
	$PanelContainer/VBox/ResumeButton.pressed.connect(_on_resume)
	$PanelContainer/VBox/RestartButton.pressed.connect(_on_restart)
	$PanelContainer/VBox/QuitButton.pressed.connect(_on_quit)
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameManager.current_state == GameManager.GameState.CRAFTING:
			return
		if visible:
			_on_resume()
		elif GameManager.current_state == GameManager.GameState.PLAYING:
			_show_pause()
		get_viewport().set_input_as_handled()

func _show_pause() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.set_paused(true)

func _on_resume() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.set_paused(false)

func _on_restart() -> void:
	GameManager.set_paused(false)
	GameManager.start_run()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_quit() -> void:
	GameManager.set_paused(false)
	GameManager.current_state = GameManager.GameState.MENU
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
