extends Node

const DIRECTIONS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIR_NAMES := {Vector2i(1, 0): "east", Vector2i(-1, 0): "west", Vector2i(0, 1): "south", Vector2i(0, -1): "north"}

var rng := RandomNumberGenerator.new()

var _floor_mat: StandardMaterial3D = null
var _wall_mat: StandardMaterial3D = null
var _ceiling_mat: StandardMaterial3D = null

func _ensure_materials() -> void:
	if _floor_mat:
		return
	_floor_mat = _make_triplanar_mat(
		"res://resources/textures/textures/ClaimedE.png",
		"res://resources/textures/textures/Claimed_nor2.png", 0.9)
	_wall_mat = _make_triplanar_mat(
		"res://resources/textures/textures/Claimedwall2C.png",
		"res://resources/textures/textures/Claimedwall2_nor3.png", 0.85)
	_ceiling_mat = _make_triplanar_mat(
		"res://resources/textures/textures/Rock_col.png",
		"res://resources/textures/textures/Rock_nor.png", 0.95)

func _make_triplanar_mat(albedo_path: String, normal_path: String, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var albedo := load(albedo_path) as Texture2D
	if albedo:
		mat.albedo_texture = albedo
	var normal_tex := load(normal_path) as Texture2D
	if normal_tex:
		mat.normal_enabled = true
		mat.normal_texture = normal_tex
		mat.normal_scale = 1.0
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.5, 0.5, 0.5) # tile every 2 world units
	mat.roughness = roughness
	return mat

func generate_layout(floor_number: int, floor_seed: int) -> Dictionary:
	rng.seed = floor_seed
	var target_rooms: int = Constants.get_rooms_for_floor(floor_number)

	# Room data: grid_pos -> {type, size, connections, grid_pos}
	var rooms: Dictionary = {}
	var connections: Array[Array] = [] # Array of [pos1, pos2]
	var open_doors: Array[Dictionary] = [] # {pos, direction}

	# Place start room
	var start_pos := Vector2i.ZERO
	rooms[start_pos] = _make_room_data(start_pos, "start")
	for dir in DIRECTIONS:
		open_doors.append({"pos": start_pos, "direction": dir})

	# Grow dungeon
	var attempts := 0
	while rooms.size() < target_rooms and attempts < 500:
		attempts += 1
		if open_doors.is_empty():
			break

		var door_idx := rng.randi_range(0, open_doors.size() - 1)
		var door: Dictionary = open_doors[door_idx]
		var new_pos: Vector2i = door.pos + door.direction

		if rooms.has(new_pos):
			open_doors.remove_at(door_idx)
			continue

		# Place room
		rooms[new_pos] = _make_room_data(new_pos, "empty")
		connections.append([door.pos, new_pos])
		open_doors.remove_at(door_idx)

		# Add new open doors from the new room (excluding the direction we came from)
		for dir in DIRECTIONS:
			if dir != -door.direction:
				var neighbor_pos: Vector2i = new_pos + dir
				if not rooms.has(neighbor_pos):
					open_doors.append({"pos": new_pos, "direction": dir})

	# Calculate graph distances from start
	var distances: Dictionary = _bfs_distances(start_pos, rooms, connections)

	# Place boss room at farthest point
	var boss_pos := start_pos
	var max_dist := 0
	for pos: Vector2i in distances:
		if distances[pos] > max_dist:
			max_dist = distances[pos]
			boss_pos = pos
	rooms[boss_pos].type = "boss"

	# Assign room types by distance
	var unassigned: Array[Vector2i] = []
	for pos: Vector2i in rooms:
		if rooms[pos].type == "empty" and pos != start_pos:
			unassigned.append(pos)

	# Sort by distance for assignment
	unassigned.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return distances.get(a, 0) < distances.get(b, 0))

	# Assign spell rooms in mid-range
	var spell_count := 0
	var mid_start := unassigned.size() / 3
	var mid_end := unassigned.size() * 2 / 3
	for i in range(mid_start, mini(mid_end + 1, unassigned.size())):
		if spell_count < Constants.MIN_SPELL_ROOMS:
			rooms[unassigned[i]].type = "spell"
			spell_count += 1

	# Assign enemy rooms scattered
	var enemy_count := 0
	for i in range(unassigned.size()):
		if rooms[unassigned[i]].type == "empty" and enemy_count < Constants.MIN_ENEMY_ROOMS:
			rooms[unassigned[i]].type = "enemy"
			enemy_count += 1

	# Fill remaining - alternate between enemy and empty
	for i in range(unassigned.size()):
		if rooms[unassigned[i]].type == "empty":
			if rng.randf() < 0.6:
				rooms[unassigned[i]].type = "enemy"
			# else stays empty

	# Store connections per room
	for conn: Array in connections:
		var p1: Vector2i = conn[0]
		var p2: Vector2i = conn[1]
		var dir: Vector2i = p2 - p1
		rooms[p1].connections.append(dir)
		rooms[p2].connections.append(-dir)

	return {
		"rooms": rooms,
		"connections": connections,
		"start_pos": start_pos,
		"boss_pos": boss_pos,
	}

func _make_room_data(grid_pos: Vector2i, type: String) -> Dictionary:
	var width: float = rng.randf_range(Constants.ROOM_MIN_SIZE, Constants.ROOM_MAX_SIZE)
	var depth: float = rng.randf_range(Constants.ROOM_MIN_SIZE, Constants.ROOM_MAX_SIZE)
	return {
		"grid_pos": grid_pos,
		"type": type,
		"width": width,
		"depth": depth,
		"height": Constants.ROOM_HEIGHT,
		"connections": [] as Array[Vector2i],
		"cleared": false,
	}

func _bfs_distances(start: Vector2i, rooms: Dictionary, connections: Array[Array]) -> Dictionary:
	var adj: Dictionary = {}
	for pos: Vector2i in rooms:
		adj[pos] = [] as Array[Vector2i]
	for conn: Array in connections:
		var p1: Vector2i = conn[0]
		var p2: Vector2i = conn[1]
		adj[p1].append(p2)
		adj[p2].append(p1)

	var dist: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for neighbor: Vector2i in adj[current]:
			if not dist.has(neighbor):
				dist[neighbor] = dist[current] + 1
				queue.append(neighbor)
	return dist

func build_room(room_data: Dictionary, _connections: Array[Array]) -> Node3D:
	var room := Node3D.new()
	room.name = "Room_%s_%d_%d" % [room_data.type, room_data.grid_pos.x, room_data.grid_pos.y]

	var room_script := preload("res://scripts/dungeon/room.gd")
	room.set_script(room_script)
	room.set("room_data", room_data)

	_ensure_materials()
	var w: float = room_data.width
	var d: float = room_data.depth
	var h: float = room_data.height
	var room_color: Color = Constants.ROOM_COLORS.get(room_data.type, Color(0.4, 0.4, 0.4))
	var wall_color := Color(0.35, 0.3, 0.3)
	var ceiling_color := Color(0.25, 0.25, 0.3)

	# Floor
	_add_box_mesh(room, Vector3(w, 0.2, d), Vector3(0, -0.1, 0), room_color, _floor_mat)

	# Ceiling
	_add_box_mesh(room, Vector3(w, 0.2, d), Vector3(0, h + 0.1, 0), ceiling_color, _ceiling_mat)

	# Walls with door cutouts
	var conns: Array = room_data.connections

	# North wall (Z-)
	if not conns.has(Vector2i(0, -1)):
		_add_box_mesh(room, Vector3(w, h, 0.2), Vector3(0, h / 2.0, -d / 2.0), wall_color, _wall_mat)
	else:
		_add_wall_with_door(room, w, h, Vector3(0, 0, -d / 2.0), true, wall_color, _wall_mat)

	# South wall (Z+)
	if not conns.has(Vector2i(0, 1)):
		_add_box_mesh(room, Vector3(w, h, 0.2), Vector3(0, h / 2.0, d / 2.0), wall_color, _wall_mat)
	else:
		_add_wall_with_door(room, w, h, Vector3(0, 0, d / 2.0), true, wall_color, _wall_mat)

	# West wall (X-)
	if not conns.has(Vector2i(-1, 0)):
		_add_box_mesh(room, Vector3(0.2, h, d), Vector3(-w / 2.0, h / 2.0, 0), wall_color, _wall_mat)
	else:
		_add_wall_with_door(room, d, h, Vector3(-w / 2.0, 0, 0), false, wall_color, _wall_mat)

	# East wall (X+)
	if not conns.has(Vector2i(1, 0)):
		_add_box_mesh(room, Vector3(0.2, h, d), Vector3(w / 2.0, h / 2.0, 0), wall_color, _wall_mat)
	else:
		_add_wall_with_door(room, d, h, Vector3(w / 2.0, 0, 0), false, wall_color, _wall_mat)

	# Add static body for collisions
	_add_room_collision(room, room_data)

	# Room-specific content will be populated by room.gd _ready
	# Add light to room
	var light := OmniLight3D.new()
	light.position = Vector3(0, h - 0.5, 0)
	light.omni_range = maxf(w, d)
	light.light_energy = 0.8
	light.light_color = Color(1.0, 0.9, 0.8)
	light.shadow_enabled = false
	room.add_child(light)

	# Add door triggers
	for conn_dir: Vector2i in conns:
		_add_door_trigger(room, room_data, conn_dir)

	return room

func _add_wall_with_door(room: Node3D, wall_length: float, wall_height: float, base_pos: Vector3, is_z_wall: bool, color: Color, mat: StandardMaterial3D = null) -> void:
	var door_w := Constants.DOOR_WIDTH
	var door_h := Constants.DOOR_HEIGHT

	# Left section
	var left_width := (wall_length - door_w) / 2.0
	if left_width > 0.01:
		if is_z_wall:
			_add_box_mesh(room, Vector3(left_width, wall_height, 0.2),
				base_pos + Vector3(-wall_length / 2.0 + left_width / 2.0, wall_height / 2.0, 0), color, mat)
		else:
			_add_box_mesh(room, Vector3(0.2, wall_height, left_width),
				base_pos + Vector3(0, wall_height / 2.0, -wall_length / 2.0 + left_width / 2.0), color, mat)

	# Right section
	var right_width := (wall_length - door_w) / 2.0
	if right_width > 0.01:
		if is_z_wall:
			_add_box_mesh(room, Vector3(right_width, wall_height, 0.2),
				base_pos + Vector3(wall_length / 2.0 - right_width / 2.0, wall_height / 2.0, 0), color, mat)
		else:
			_add_box_mesh(room, Vector3(0.2, wall_height, right_width),
				base_pos + Vector3(0, wall_height / 2.0, wall_length / 2.0 - right_width / 2.0), color, mat)

	# Top section (above door)
	var top_height := wall_height - door_h
	if top_height > 0.01:
		if is_z_wall:
			_add_box_mesh(room, Vector3(door_w, top_height, 0.2),
				base_pos + Vector3(0, door_h + top_height / 2.0, 0), color, mat)
		else:
			_add_box_mesh(room, Vector3(0.2, top_height, door_w),
				base_pos + Vector3(0, door_h + top_height / 2.0, 0), color, mat)

func build_hallway(room_a_data: Dictionary, room_b_data: Dictionary, rooms_dict: Dictionary) -> Node3D:
	# Build a corridor connecting two adjacent rooms
	var pos_a: Vector2i = room_a_data.grid_pos
	var pos_b: Vector2i = room_b_data.grid_pos
	var dir: Vector2i = pos_b - pos_a # unit direction from A to B

	var hallway := Node3D.new()
	hallway.name = "Hallway_%d_%d_to_%d_%d" % [pos_a.x, pos_a.y, pos_b.x, pos_b.y]

	var world_a := Vector3(pos_a.x * 20.0, 0, pos_a.y * 20.0)
	var world_b := Vector3(pos_b.x * 20.0, 0, pos_b.y * 20.0)

	var wa: float = room_a_data.width
	var da: float = room_a_data.depth
	var wb: float = room_b_data.width
	var db: float = room_b_data.depth
	var h: float = Constants.ROOM_HEIGHT
	var door_w := Constants.DOOR_WIDTH
	var door_h := Constants.DOOR_HEIGHT

	var hall_color := Color(0.3, 0.28, 0.28)
	var floor_color := Color(0.35, 0.32, 0.3)

	# Calculate start and end points of the hallway in world space
	var start := Vector3.ZERO
	var end := Vector3.ZERO

	match dir:
		Vector2i(1, 0): # A east -> B west (X axis)
			start = world_a + Vector3(wa / 2.0, 0, 0)
			end = world_b + Vector3(-wb / 2.0, 0, 0)
		Vector2i(-1, 0): # A west -> B east
			start = world_a + Vector3(-wa / 2.0, 0, 0)
			end = world_b + Vector3(wb / 2.0, 0, 0)
		Vector2i(0, 1): # A south -> B north (Z axis)
			start = world_a + Vector3(0, 0, da / 2.0)
			end = world_b + Vector3(0, 0, -db / 2.0)
		Vector2i(0, -1): # A north -> B south
			start = world_a + Vector3(0, 0, -da / 2.0)
			end = world_b + Vector3(0, 0, db / 2.0)

	var center := (start + end) / 2.0
	hallway.position = center

	var length := start.distance_to(end)
	if length < 0.1:
		return hallway # Rooms are touching, no hallway needed

	var is_x_axis := dir.x != 0

	_ensure_materials()

	# Floor (mesh + collision)
	if is_x_axis:
		_add_box_mesh(hallway, Vector3(length, 0.2, door_w), Vector3(0, -0.1, 0), floor_color, _floor_mat)
	else:
		_add_box_mesh(hallway, Vector3(door_w, 0.2, length), Vector3(0, -0.1, 0), floor_color, _floor_mat)

	# Ceiling
	if is_x_axis:
		_add_box_mesh(hallway, Vector3(length, 0.2, door_w), Vector3(0, door_h + 0.1, 0), hall_color, _ceiling_mat)
	else:
		_add_box_mesh(hallway, Vector3(door_w, 0.2, length), Vector3(0, door_h + 0.1, 0), hall_color, _ceiling_mat)

	# Walls (two side walls)
	if is_x_axis:
		# Walls along Z sides
		_add_box_mesh(hallway, Vector3(length, door_h, 0.2), Vector3(0, door_h / 2.0, -door_w / 2.0), hall_color, _wall_mat)
		_add_box_mesh(hallway, Vector3(length, door_h, 0.2), Vector3(0, door_h / 2.0, door_w / 2.0), hall_color, _wall_mat)
	else:
		# Walls along X sides
		_add_box_mesh(hallway, Vector3(0.2, door_h, length), Vector3(-door_w / 2.0, door_h / 2.0, 0), hall_color, _wall_mat)
		_add_box_mesh(hallway, Vector3(0.2, door_h, length), Vector3(door_w / 2.0, door_h / 2.0, 0), hall_color, _wall_mat)

	# Collision
	var static_body := StaticBody3D.new()
	static_body.collision_layer = 1
	static_body.collision_mask = 0

	# Floor collision
	if is_x_axis:
		_add_wall_collision(static_body, Vector3(length, 0.2, door_w), Vector3(0, -0.1, 0))
	else:
		_add_wall_collision(static_body, Vector3(door_w, 0.2, length), Vector3(0, -0.1, 0))

	# Ceiling collision
	if is_x_axis:
		_add_wall_collision(static_body, Vector3(length, 0.2, door_w), Vector3(0, door_h + 0.1, 0))
	else:
		_add_wall_collision(static_body, Vector3(door_w, 0.2, length), Vector3(0, door_h + 0.1, 0))

	# Wall collisions
	if is_x_axis:
		_add_wall_collision(static_body, Vector3(length, door_h, 0.2), Vector3(0, door_h / 2.0, -door_w / 2.0))
		_add_wall_collision(static_body, Vector3(length, door_h, 0.2), Vector3(0, door_h / 2.0, door_w / 2.0))
	else:
		_add_wall_collision(static_body, Vector3(0.2, door_h, length), Vector3(-door_w / 2.0, door_h / 2.0, 0))
		_add_wall_collision(static_body, Vector3(0.2, door_h, length), Vector3(door_w / 2.0, door_h / 2.0, 0))

	hallway.add_child(static_body)

	# Small light in hallway
	var light := OmniLight3D.new()
	light.position = Vector3(0, door_h - 0.3, 0)
	light.omni_range = length
	light.light_energy = 0.4
	light.light_color = Color(1.0, 0.9, 0.8)
	light.shadow_enabled = false
	hallway.add_child(light)

	return hallway

func _add_box_mesh(parent: Node3D, size: Vector3, pos: Vector3, color: Color, mat: StandardMaterial3D = null) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = pos

	if mat:
		mesh_instance.material_override = mat
	else:
		var plain_mat := StandardMaterial3D.new()
		plain_mat.albedo_color = color
		mesh_instance.material_override = plain_mat

	parent.add_child(mesh_instance)
	return mesh_instance

func _add_room_collision(room: Node3D, room_data: Dictionary) -> void:
	var static_body := StaticBody3D.new()
	static_body.collision_layer = 1
	static_body.collision_mask = 0

	var w: float = room_data.width
	var d: float = room_data.depth
	var h: float = room_data.height
	var conns: Array = room_data.connections

	# Floor collision
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(w, 0.2, d)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0, -0.1, 0)
	static_body.add_child(floor_shape)

	# Ceiling collision
	var ceiling_shape := CollisionShape3D.new()
	var ceiling_box := BoxShape3D.new()
	ceiling_box.size = Vector3(w, 0.2, d)
	ceiling_shape.shape = ceiling_box
	ceiling_shape.position = Vector3(0, h + 0.1, 0)
	static_body.add_child(ceiling_shape)

	# Wall collisions (full walls only - doors have gaps)
	if not conns.has(Vector2i(0, -1)):
		_add_wall_collision(static_body, Vector3(w, h, 0.2), Vector3(0, h / 2.0, -d / 2.0))
	else:
		_add_door_wall_collision(static_body, w, h, Vector3(0, 0, -d / 2.0), true)

	if not conns.has(Vector2i(0, 1)):
		_add_wall_collision(static_body, Vector3(w, h, 0.2), Vector3(0, h / 2.0, d / 2.0))
	else:
		_add_door_wall_collision(static_body, w, h, Vector3(0, 0, d / 2.0), true)

	if not conns.has(Vector2i(-1, 0)):
		_add_wall_collision(static_body, Vector3(0.2, h, d), Vector3(-w / 2.0, h / 2.0, 0))
	else:
		_add_door_wall_collision(static_body, d, h, Vector3(-w / 2.0, 0, 0), false)

	if not conns.has(Vector2i(1, 0)):
		_add_wall_collision(static_body, Vector3(0.2, h, d), Vector3(w / 2.0, h / 2.0, 0))
	else:
		_add_door_wall_collision(static_body, d, h, Vector3(w / 2.0, 0, 0), false)

	room.add_child(static_body)

func _add_wall_collision(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	body.add_child(shape)

func _add_door_wall_collision(body: StaticBody3D, wall_length: float, wall_height: float, base_pos: Vector3, is_z_wall: bool) -> void:
	var door_w := Constants.DOOR_WIDTH
	var door_h := Constants.DOOR_HEIGHT

	var side_width := (wall_length - door_w) / 2.0

	if side_width > 0.01:
		if is_z_wall:
			_add_wall_collision(body, Vector3(side_width, wall_height, 0.2),
				base_pos + Vector3(-wall_length / 2.0 + side_width / 2.0, wall_height / 2.0, 0))
			_add_wall_collision(body, Vector3(side_width, wall_height, 0.2),
				base_pos + Vector3(wall_length / 2.0 - side_width / 2.0, wall_height / 2.0, 0))
		else:
			_add_wall_collision(body, Vector3(0.2, wall_height, side_width),
				base_pos + Vector3(0, wall_height / 2.0, -wall_length / 2.0 + side_width / 2.0))
			_add_wall_collision(body, Vector3(0.2, wall_height, side_width),
				base_pos + Vector3(0, wall_height / 2.0, wall_length / 2.0 - side_width / 2.0))

	var top_height := wall_height - door_h
	if top_height > 0.01:
		if is_z_wall:
			_add_wall_collision(body, Vector3(door_w, top_height, 0.2),
				base_pos + Vector3(0, door_h + top_height / 2.0, 0))
		else:
			_add_wall_collision(body, Vector3(0.2, top_height, door_w),
				base_pos + Vector3(0, door_h + top_height / 2.0, 0))

func _add_door_trigger(room: Node3D, room_data: Dictionary, dir: Vector2i) -> void:
	var area := Area3D.new()
	area.collision_layer = 64 # layer 6 - triggers
	area.collision_mask = 2 # player

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(Constants.DOOR_WIDTH, Constants.DOOR_HEIGHT, 1.0)
	shape.shape = box

	var w: float = room_data.width
	var d: float = room_data.depth
	var door_pos := Vector3.ZERO

	match dir:
		Vector2i(1, 0): # East
			door_pos = Vector3(w / 2.0, Constants.DOOR_HEIGHT / 2.0, 0)
			box.size = Vector3(1.0, Constants.DOOR_HEIGHT, Constants.DOOR_WIDTH)
		Vector2i(-1, 0): # West
			door_pos = Vector3(-w / 2.0, Constants.DOOR_HEIGHT / 2.0, 0)
			box.size = Vector3(1.0, Constants.DOOR_HEIGHT, Constants.DOOR_WIDTH)
		Vector2i(0, 1): # South
			door_pos = Vector3(0, Constants.DOOR_HEIGHT / 2.0, d / 2.0)
		Vector2i(0, -1): # North
			door_pos = Vector3(0, Constants.DOOR_HEIGHT / 2.0, -d / 2.0)

	area.position = door_pos
	shape.position = Vector3.ZERO
	area.add_child(shape)
	room.add_child(area)
