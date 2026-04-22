extends SpellEffect

const EXPLOSION_SCENE := preload("res://scenes/spells/orb_explosion.tscn")
const BOLT_SCENE := preload("res://scenes/spells/spell_bolt.tscn")

var speed: float = 20.0
var max_range: float = 30.0
var distance_traveled: float = 0.0
var direction: Vector3 = Vector3.FORWARD
var hit_targets: Array[Node3D] = []
var _done := false

func _ready() -> void:
	speed = spell_data.get("speed", 20.0)
	max_range = spell_data.get("range", 30.0)
	_on_cast()

	$Area3D.body_entered.connect(_on_area_body_entered)

var _direction_set := false

func _apply_color(color: Color) -> void:
	var bolt_mesh := get_node_or_null("BoltMesh")
	if bolt_mesh and bolt_mesh.material_override is ShaderMaterial:
		var bolt_mat := (bolt_mesh.material_override as ShaderMaterial).duplicate()
		bolt_mesh.material_override = bolt_mat
		bolt_mat.set_shader_parameter("bolt_color", Color(color.r, color.g, color.b, 1.0))

	var core := get_node_or_null("CoreGlow")
	if core and core.material_override is ShaderMaterial:
		var core_mat := (core.material_override as ShaderMaterial).duplicate()
		core.material_override = core_mat
		var core_color := Color.WHITE.lerp(color, 0.3)
		core_mat.set_shader_parameter("color_core", core_color)
		core_mat.set_shader_parameter("color_edge", color)

func _process(delta: float) -> void:
	if not _direction_set:
		direction = -global_transform.basis.z
		_direction_set = true
	var move := direction * speed * delta
	global_position += move
	distance_traveled += move.length()

	if has_split and not split_done and distance_traveled > 3.0:
		_do_split()

	if distance_traveled >= max_range:
		_expire_with_impact()

func _on_area_body_entered(body: Node3D) -> void:
	if body == caster:
		return
	if body is StaticBody3D:
		_expire_with_impact()
		return
	if body.is_in_group("enemies"):
		if hit_targets.has(body):
			return
		hit_targets.append(body)
		_on_hit(body)
		if has_pierce:
			_spawn_impact()
		else:
			_expire_with_impact()

func _spawn_impact() -> void:
	var expl: Node3D = EXPLOSION_SCENE.instantiate()
	expl.set("element_color", spell_data.get("color", Color.WHITE))
	get_tree().current_scene.add_child(expl)
	expl.global_position = global_position
	expl.scale = Vector3.ONE * 0.4

func _expire_with_impact() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	$Area3D.monitoring = false
	_spawn_impact()
	_on_expire()

func _do_split() -> void:
	split_done = true
	var angles := [-0.3, 0.3]
	for angle in angles:
		var split_bolt: Node3D = BOLT_SCENE.instantiate()
		split_bolt.initialize(spell_data, caster)
		split_bolt.has_split = false
		split_bolt.split_done = true
		split_bolt.global_position = global_position
		split_bolt.global_rotation = global_rotation
		split_bolt.rotate_y(angle)
		split_bolt.damage = damage * 0.6
		get_tree().current_scene.add_child(split_bolt)
