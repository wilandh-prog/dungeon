extends SpellEffect

var aoe_radius: float = 5.0
var expand_speed: float = 15.0
var current_radius: float = 0.0
var hit_targets: Array[Node3D] = []

func _ready() -> void:
	aoe_radius = spell_data.get("aoe_radius", 5.0)
	_on_cast()

func _on_cast() -> void:
	# Immediately deal damage to all enemies in radius
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy: Node3D in enemies:
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist <= aoe_radius:
			_on_hit(enemy)
			hit_targets.append(enemy)

func _process(delta: float) -> void:
	# Visual expansion
	current_radius += expand_speed * delta
	var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh:
		var s := current_radius / aoe_radius
		mesh.scale = Vector3(s, s, s) * aoe_radius

	if current_radius >= aoe_radius:
		_on_expire()
