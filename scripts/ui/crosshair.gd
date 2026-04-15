extends Control

func _draw() -> void:
	var center := size / 2.0
	var gap := 3.0
	var length := 8.0
	var color := Color(1, 1, 1, 0.8)
	var width := 2.0

	# Horizontal lines
	draw_line(Vector2(center.x - gap - length, center.y), Vector2(center.x - gap, center.y), color, width)
	draw_line(Vector2(center.x + gap, center.y), Vector2(center.x + gap + length, center.y), color, width)
	# Vertical lines
	draw_line(Vector2(center.x, center.y - gap - length), Vector2(center.x, center.y - gap), color, width)
	draw_line(Vector2(center.x, center.y + gap), Vector2(center.x, center.y + gap + length), color, width)
