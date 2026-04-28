extends SpellEffect

var wall_range: float = 8.0
var wall_lifetime: float = 5.0
var tick_rate: float = 0.5
var tick_timer: float = 0.0
var wall_width: float = 8.0
var wall_height: float = 2.5
var spawn_distance: float = 5.0

func _apply_color(_color: Color) -> void:
	pass  # Ice wall keeps its own shader; ignore element color tint

func _ready() -> void:
	wall_range = spell_data.get("range", 8.0)
	damage = maxf(0.0, damage - 20.0)
	_on_cast()

	# Place wall at distance in front of caster (using camera aim direction)
	if caster:
		var camera: Camera3D = caster.camera
		var forward := -camera.global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		global_position = caster.global_position + forward * spawn_distance
		global_position.y = 0.0
		look_at(Vector3(caster.global_position.x, 0.0, caster.global_position.z), Vector3.UP)

	$Area3D.body_entered.connect(_on_area_body_entered)

func _process(delta: float) -> void:
	wall_lifetime -= delta
	tick_timer -= delta

	if wall_lifetime <= 0:
		_on_expire()
		return

	# Periodic damage to enemies touching the wall
	if tick_timer <= 0:
		tick_timer = tick_rate
		_wall_tick()

func _wall_tick() -> void:
	var bodies: Array[Node3D] = $Area3D.get_overlapping_bodies()
	for body: Node3D in bodies:
		if body.is_in_group("enemies"):
			_on_hit(body)

func _on_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies"):
		_on_hit(body)
