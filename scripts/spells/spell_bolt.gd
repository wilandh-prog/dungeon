extends SpellEffect

var speed: float = 20.0
var max_range: float = 30.0
var distance_traveled: float = 0.0
var direction: Vector3 = Vector3.FORWARD
var hit_targets: Array[Node3D] = []

func _ready() -> void:
	speed = spell_data.get("speed", 20.0)
	max_range = spell_data.get("range", 30.0)
	# Direction set in first process frame when global transform is valid
	_on_cast()

	$Area3D.body_entered.connect(_on_area_body_entered)

var _direction_set := false

func _process(delta: float) -> void:
	if not _direction_set:
		direction = -global_transform.basis.z
		_direction_set = true
	var move := direction * speed * delta
	global_position += move
	distance_traveled += move.length()

	# Split modifier
	if has_split and not split_done and distance_traveled > 3.0:
		_do_split()

	if distance_traveled >= max_range:
		_on_expire()

func _on_area_body_entered(body: Node3D) -> void:
	if body == caster:
		return
	if body.is_in_group("enemies"):
		if hit_targets.has(body):
			return
		hit_targets.append(body)
		_on_hit(body)
		if not has_pierce:
			_on_expire()

func _do_split() -> void:
	split_done = true
	var angles := [-0.3, 0.3] # ~17 degrees
	for angle in angles:
		var split_bolt := preload("res://scenes/spells/spell_bolt.tscn").instantiate()
		split_bolt.initialize(spell_data, caster)
		split_bolt.has_split = false # Don't chain-split
		split_bolt.split_done = true
		split_bolt.global_position = global_position
		split_bolt.global_rotation = global_rotation
		split_bolt.rotate_y(angle)
		split_bolt.damage = damage * 0.6
		get_tree().current_scene.add_child(split_bolt)
