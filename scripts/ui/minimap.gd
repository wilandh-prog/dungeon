extends Control

var rooms: Dictionary = {} # grid_pos -> room_data
var connections: Array[Array] = []
var player_room: Vector2i = Vector2i.ZERO
var visited_rooms: Dictionary = {} # grid_pos -> true

const CELL_SIZE := 12.0
const CELL_GAP := 2.0
const CELL_STEP := CELL_SIZE + CELL_GAP

const TYPE_COLORS := {
	"start": Color(0.3, 0.4, 0.8),
	"spell": Color(0.6, 0.3, 0.8),
	"enemy": Color(0.8, 0.3, 0.3),
	"boss": Color(0.9, 0.15, 0.15),
	"empty": Color(0.5, 0.5, 0.5),
}

func update_data(p_rooms: Dictionary, p_connections: Array[Array]) -> void:
	rooms = p_rooms
	connections = p_connections
	visited_rooms.clear()
	queue_redraw()

func set_player_room(grid_pos: Vector2i) -> void:
	player_room = grid_pos
	visited_rooms[grid_pos] = true
	queue_redraw()

func _draw() -> void:
	if rooms.is_empty():
		return

	# Draw background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))

	var center := size / 2.0
	# Offset so player room is centered
	var offset := center - Vector2(player_room.x * CELL_STEP, player_room.y * CELL_STEP)

	# Draw connections (hallways)
	for conn: Array in connections:
		var p1: Vector2i = conn[0]
		var p2: Vector2i = conn[1]
		if not visited_rooms.has(p1) and not visited_rooms.has(p2):
			continue
		var from := Vector2(p1.x * CELL_STEP, p1.y * CELL_STEP) + offset + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
		var to := Vector2(p2.x * CELL_STEP, p2.y * CELL_STEP) + offset + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
		draw_line(from, to, Color(0.5, 0.5, 0.5, 0.6), 2.0)

	# Draw rooms
	for grid_pos: Vector2i in rooms:
		var room_data: Dictionary = rooms[grid_pos]
		var pos := Vector2(grid_pos.x * CELL_STEP, grid_pos.y * CELL_STEP) + offset
		var rect := Rect2(pos, Vector2(CELL_SIZE, CELL_SIZE))

		if visited_rooms.has(grid_pos):
			# Visited room - show type color
			var color: Color = TYPE_COLORS.get(room_data.type, Color(0.4, 0.4, 0.4))
			draw_rect(rect, color)

			# Cleared indicator
			if room_data.get("cleared", false):
				draw_rect(rect.grow(-2), Color(1, 1, 1, 0.15))
		else:
			# Unvisited - show as dark outline if adjacent to visited
			var is_adjacent := false
			for visited_pos: Vector2i in visited_rooms:
				if absi(grid_pos.x - visited_pos.x) + absi(grid_pos.y - visited_pos.y) == 1:
					is_adjacent = true
					break
			if is_adjacent:
				draw_rect(rect, Color(0.3, 0.3, 0.3, 0.4))

	# Draw player indicator
	var player_pos := Vector2(player_room.x * CELL_STEP, player_room.y * CELL_STEP) + offset
	var player_center := player_pos + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	draw_circle(player_center, 3.0, Color.WHITE)
