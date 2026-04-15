extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var dungeon_container: Node3D = $DungeonContainer
@onready var hud_layer: CanvasLayer = $HUD
@onready var ui_layer: CanvasLayer = $UILayer

var dungeon_generator: Node = null
var current_rooms: Dictionary = {} # grid_pos -> room_node
var current_player_room: Vector2i = Vector2i.ZERO
var current_layout: Dictionary = {}
var floor_complete_triggered := false

var hud: Control = null
var spell_crafting: Control = null
var pause_menu: Control = null
var death_screen: Control = null
var floor_complete: Control = null

func _ready() -> void:
	SdkManager.gameplay_start()
	player.add_to_group("player")

	# Give player a starter spell (Arcane Bolt)
	var starter_frags: Array = [SpellFragment.create("ARCANE", "BOLT", "NONE")]
	var starter_spell: Dictionary = SpellDatabase.compute_spell(starter_frags)
	player.get_node("PlayerInventory").equip_spell(0, starter_spell)

	# Setup UI
	hud = preload("res://scenes/ui/hud.tscn").instantiate()
	hud_layer.add_child(hud)
	hud.setup(player)

	spell_crafting = preload("res://scenes/ui/spell_crafting.tscn").instantiate()
	ui_layer.add_child(spell_crafting)

	pause_menu = preload("res://scenes/ui/pause_menu.tscn").instantiate()
	ui_layer.add_child(pause_menu)

	death_screen = preload("res://scenes/ui/death_screen.tscn").instantiate()
	ui_layer.add_child(death_screen)

	floor_complete = preload("res://scenes/ui/floor_complete.tscn").instantiate()
	ui_layer.add_child(floor_complete)

	# Setup dungeon
	dungeon_generator = preload("res://scripts/dungeon/dungeon_generator.gd").new()
	add_child(dungeon_generator)
	_generate_floor()

	GameManager.floor_started.connect(_on_floor_started)
	player.died.connect(_on_player_died)

func _generate_floor() -> void:
	# Clear old dungeon
	for child in dungeon_container.get_children():
		child.queue_free()
	current_rooms.clear()

	# Generate new layout
	current_layout = dungeon_generator.generate_layout(
		GameManager.current_floor,
		GameManager.floor_seed
	)

	# Build rooms
	for grid_pos: Vector2i in current_layout.rooms:
		var room_data: Dictionary = current_layout.rooms[grid_pos]
		var room_node: Node3D = dungeon_generator.build_room(room_data, current_layout.connections)
		dungeon_container.add_child(room_node)
		room_node.position = Vector3(grid_pos.x * 20.0, 0, grid_pos.y * 20.0)
		current_rooms[grid_pos] = room_node

	# Build hallways between connected rooms
	for conn: Array in current_layout.connections:
		var pos_a: Vector2i = conn[0]
		var pos_b: Vector2i = conn[1]
		var room_a_data: Dictionary = current_layout.rooms[pos_a]
		var room_b_data: Dictionary = current_layout.rooms[pos_b]
		var hallway: Node3D = dungeon_generator.build_hallway(room_a_data, room_b_data, current_layout.rooms)
		dungeon_container.add_child(hallway)

	# Place player in start room
	var start_pos: Vector2i = current_layout.start_pos
	player.global_position = Vector3(start_pos.x * 20.0, 1.0, start_pos.y * 20.0)
	current_player_room = start_pos
	_update_room_visibility(start_pos)

	# Setup minimap
	if hud:
		hud.setup_minimap(current_layout.rooms, current_layout.connections)
		hud.update_minimap_player(start_pos)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_crafting"):
		if GameManager.current_state == GameManager.GameState.PLAYING:
			spell_crafting.open(player.get_node("PlayerInventory"))
		elif GameManager.current_state == GameManager.GameState.CRAFTING:
			spell_crafting.close()

	# Debug: F1 = teleport to boss room
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		if current_layout and not current_layout.is_empty():
			var boss_pos: Vector2i = current_layout.boss_pos
			player.global_position = Vector3(boss_pos.x * 20.0, 1.0, boss_pos.y * 20.0)
			current_player_room = boss_pos
			_update_room_visibility(boss_pos)
			_on_enter_room(boss_pos)

func _process(_delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_check_player_room()
	_check_boss_cleared()

func _check_player_room() -> void:
	var px: float = player.global_position.x
	var pz: float = player.global_position.z
	var grid_pos := Vector2i(roundi(px / 20.0), roundi(pz / 20.0))

	if grid_pos != current_player_room and current_rooms.has(grid_pos):
		current_player_room = grid_pos
		_update_room_visibility(grid_pos)
		_on_enter_room(grid_pos)
		if hud:
			hud.update_minimap_player(grid_pos)

func _check_boss_cleared() -> void:
	if floor_complete_triggered:
		return
	if not current_layout.is_empty():
		var boss_pos: Vector2i = current_layout.boss_pos
		if current_rooms.has(boss_pos):
			var boss_room: Node3D = current_rooms[boss_pos]
			if boss_room.get("is_cleared") and boss_room.is_cleared:
				floor_complete_triggered = true
				_on_floor_complete()

func _on_floor_complete() -> void:
	SdkManager.happy_time()
	# Show interstitial ad between floors
	SdkManager.show_midgame_ad()
	await SdkManager.ad_finished
	GameManager.complete_floor()

func _update_room_visibility(center: Vector2i) -> void:
	for pos: Vector2i in current_rooms:
		var room: Node3D = current_rooms[pos]
		var dist := absi(pos.x - center.x) + absi(pos.y - center.y)
		if dist <= 1:
			room.visible = true
			room.process_mode = Node.PROCESS_MODE_INHERIT
		else:
			room.visible = false
			room.process_mode = Node.PROCESS_MODE_DISABLED

func _on_enter_room(grid_pos: Vector2i) -> void:
	var room: Node3D = current_rooms[grid_pos]
	if room.has_method("on_player_enter"):
		room.on_player_enter()

func _on_floor_started(floor_number: int) -> void:
	floor_complete_triggered = false
	if floor_number > 1:
		_generate_floor()

func _on_player_died() -> void:
	SdkManager.gameplay_stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
