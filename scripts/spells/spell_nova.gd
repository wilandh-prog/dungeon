extends SpellEffect

const EXPLOSION_SCENE := preload("res://scenes/spells/orb_explosion.tscn")

var aoe_radius: float = 5.0

func _ready() -> void:
	aoe_radius = spell_data.get("aoe_radius", 5.0)
	var mesh := get_node_or_null("MeshInstance3D")
	if mesh:
		mesh.visible = false
	_on_cast()

func _on_cast() -> void:
	call_deferred("_do_nova")

func _do_nova() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy: Node3D in enemies:
		if global_position.distance_to(enemy.global_position) <= aoe_radius:
			_on_hit(enemy)

	var expl: Node3D = EXPLOSION_SCENE.instantiate()
	expl.set("element_color", spell_data.get("color", Color.WHITE))
	get_tree().current_scene.add_child(expl)
	expl.global_position = global_position
	expl.scale = Vector3.ONE * (aoe_radius / 3.0)

	_on_expire()
