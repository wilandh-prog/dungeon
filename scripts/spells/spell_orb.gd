extends SpellEffect

var speed: float = 8.0
var max_range: float = 20.0
var aoe_radius: float = 3.0
var distance_traveled: float = 0.0
var direction: Vector3 = Vector3.FORWARD

func _ready() -> void:
	speed = spell_data.get("speed", 8.0)
	max_range = spell_data.get("range", 20.0)
	aoe_radius = spell_data.get("aoe_radius", 3.0)
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

	if distance_traveled >= max_range:
		_explode()

func _on_area_body_entered(body: Node3D) -> void:
	if body == caster:
		return
	if body.is_in_group("enemies"):
		_explode()

func _explode() -> void:
	# AoE damage at current position
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy: Node3D in enemies:
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist <= aoe_radius:
			_on_hit(enemy)

	# Visual: brief scale-up then remove
	var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh:
		var tween := create_tween()
		tween.tween_property(mesh, "scale", Vector3.ONE * aoe_radius, 0.15)
		tween.tween_callback(_on_expire)
	else:
		_on_expire()
