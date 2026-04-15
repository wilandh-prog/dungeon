extends Node3D

var room_data: Dictionary = {}
var is_cleared := false
var enemies_alive := 0
var doors_locked := false
var player_entered := false

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	if room_data.is_empty():
		return
	rng.seed = hash(room_data.grid_pos)
	_populate()

func _populate() -> void:
	match room_data.type:
		"enemy":
			_populate_enemy_room()
			_place_cover_objects()
		"spell":
			_populate_spell_room()
		"boss":
			_populate_boss_room()
			_place_cover_objects()
		"empty":
			_place_decorations()

func _populate_enemy_room() -> void:
	var count := rng.randi_range(Constants.ENEMY_SPAWN_MIN, Constants.ENEMY_SPAWN_MAX)
	for i in count:
		var pos := _get_valid_spawn_position()
		var enemy_type := _pick_enemy_type()
		var enemy: Node3D = _create_enemy(enemy_type)
		enemy.position = pos
		add_child(enemy)
		enemies_alive += 1

func _populate_spell_room() -> void:
	var count := rng.randi_range(1, 2)
	for i in count:
		var pos := _get_valid_spawn_position()
		var pickup := _create_fragment_pickup()
		pickup.position = pos
		add_child(pickup)

func _populate_boss_room() -> void:
	var boss := _create_enemy("paladin")
	boss.position = Vector3.ZERO
	add_child(boss)
	enemies_alive = 1

func _place_cover_objects() -> void:
	var count := rng.randi_range(Constants.COVER_MIN, Constants.COVER_MAX)
	var w: float = room_data.width
	var d: float = room_data.depth

	var cover_mat := StandardMaterial3D.new()
	var rock_albedo := load("res://resources/textures/textures/Rock_col.png") as Texture2D
	var rock_normal := load("res://resources/textures/textures/Rock_nor.png") as Texture2D
	if rock_albedo:
		cover_mat.albedo_texture = rock_albedo
	if rock_normal:
		cover_mat.normal_enabled = true
		cover_mat.normal_texture = rock_normal
	cover_mat.uv1_triplanar = true
	cover_mat.uv1_world_triplanar = true
	cover_mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	cover_mat.roughness = 0.9

	for i in count:
		var cover := MeshInstance3D.new()

		if rng.randf() < 0.5:
			# Box (crate)
			var box := BoxMesh.new()
			box.size = Vector3(1.0, 1.0, 1.0)
			cover.mesh = box
		else:
			# Cylinder (pillar)
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.4
			cyl.bottom_radius = 0.4
			cyl.height = 2.5
			cover.mesh = cyl

		cover.material_override = cover_mat
		# Pick a grid position that isn't blocking a doorway
		var gx := 0.0
		var gz := 0.0
		var placed := false
		for _attempt in 10:
			gx = rng.randi_range(-int(w / 4.0), int(w / 4.0)) * 2.0
			gz = rng.randi_range(-int(d / 4.0), int(d / 4.0)) * 2.0
			var too_close := false
			for conn: Vector2i in room_data.connections:
				var door_pos := Vector3.ZERO
				match conn:
					Vector2i(1, 0):  door_pos = Vector3(w / 2.0, 0, 0)
					Vector2i(-1, 0): door_pos = Vector3(-w / 2.0, 0, 0)
					Vector2i(0, 1):  door_pos = Vector3(0, 0, d / 2.0)
					Vector2i(0, -1): door_pos = Vector3(0, 0, -d / 2.0)
				if Vector3(gx, 0, gz).distance_to(door_pos) < Constants.ENEMY_DOOR_CLEARANCE:
					too_close = true
					break
			if not too_close:
				placed = true
				break
		if not placed:
			continue
		cover.position = Vector3(gx, cover.mesh.get_aabb().size.y / 2.0, gz)
		add_child(cover)

		# Add collision for cover
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.position = cover.position
		var col := CollisionShape3D.new()
		var col_box := BoxShape3D.new()
		col_box.size = cover.mesh.get_aabb().size
		col.shape = col_box
		body.add_child(col)
		add_child(body)

func _place_decorations() -> void:
	# Sparse decorative objects for empty rooms
	var count := rng.randi_range(0, 3)
	var w: float = room_data.width
	var d: float = room_data.depth

	for i in count:
		var deco := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(rng.randf_range(0.5, 1.5), rng.randf_range(0.3, 1.0), rng.randf_range(0.5, 1.5))
		deco.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.3, 0.25)
		deco.material_override = mat
		var gx := rng.randf_range(-w / 3.0, w / 3.0)
		var gz := rng.randf_range(-d / 3.0, d / 3.0)
		deco.position = Vector3(gx, box.size.y / 2.0, gz)
		add_child(deco)

func on_player_enter() -> void:
	if player_entered:
		return
	player_entered = true

	match room_data.type:
		"enemy":
			_activate_enemies()
			_lock_doors()
		"boss":
			_activate_enemies()
			_lock_doors()

	GameManager.on_room_cleared(room_data.type)

func _activate_enemies() -> void:
	for child in get_children():
		if child.has_method("activate"):
			child.activate()

func _lock_doors() -> void:
	doors_locked = true
	# In a full implementation, would enable door collision blockers

func _unlock_doors() -> void:
	doors_locked = false

func on_enemy_died() -> void:
	enemies_alive -= 1
	if enemies_alive <= 0:
		is_cleared = true
		_unlock_doors()
		room_data.cleared = true

func _get_valid_spawn_position() -> Vector3:
	var w: float = room_data.width
	var d: float = room_data.depth
	var clearance := Constants.ENEMY_DOOR_CLEARANCE

	for attempt in 20:
		var x := rng.randf_range(-w / 2.0 + 1.0, w / 2.0 - 1.0)
		var z := rng.randf_range(-d / 2.0 + 1.0, d / 2.0 - 1.0)
		var pos := Vector3(x, 0, z)

		# Check distance from doors
		var too_close := false
		for conn: Vector2i in room_data.connections:
			var door_pos := Vector3.ZERO
			match conn:
				Vector2i(1, 0):
					door_pos = Vector3(w / 2.0, 0, 0)
				Vector2i(-1, 0):
					door_pos = Vector3(-w / 2.0, 0, 0)
				Vector2i(0, 1):
					door_pos = Vector3(0, 0, d / 2.0)
				Vector2i(0, -1):
					door_pos = Vector3(0, 0, -d / 2.0)
			if pos.distance_to(door_pos) < clearance:
				too_close = true
				break

		if not too_close:
			return pos

	return Vector3(0, 0, 0)

func _pick_enemy_type() -> String:
	var roll := rng.randf()
	if roll < 0.45:
		return "slime"
	elif roll < 0.75:
		return "skeleton"
	return "warrior"

func _create_enemy(type: String) -> CharacterBody3D:
	match type:
		"slime":
			return preload("res://scenes/enemies/slime.tscn").instantiate()
		"skeleton":
			return preload("res://scenes/enemies/skeleton_enemy.tscn").instantiate()
		"warrior":
			return preload("res://scenes/enemies/melee_enemy.tscn").instantiate()
		"paladin":
			return preload("res://scenes/enemies/paladin_boss.tscn").instantiate()
	return preload("res://scenes/enemies/slime.tscn").instantiate()

func _create_fragment_pickup() -> Node3D:
	return preload("res://scenes/spells/fragment_pickup.tscn").instantiate()
