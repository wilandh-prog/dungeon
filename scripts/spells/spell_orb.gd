extends SpellEffect

const EXPLOSION_SCENE := preload("res://scenes/spells/orb_explosion.tscn")
const MIN_TRAVEL := 2.5

var speed: float = 8.0
var max_range: float = 20.0
var aoe_radius: float = 3.0
var distance_traveled: float = 0.0
var direction: Vector3 = Vector3.FORWARD
var _exploded := false

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
	if body is StaticBody3D:
		_explode()
		return
	if distance_traveled < MIN_TRAVEL:
		return
	if body.is_in_group("enemies"):
		_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	set_process(false)
	$Area3D.monitoring = false

	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy: Node3D in enemies:
		if global_position.distance_to(enemy.global_position) <= aoe_radius:
			_on_hit(enemy)

	var expl: Node3D = EXPLOSION_SCENE.instantiate()
	expl.set("element_color", spell_data.get("color", Color.WHITE))
	get_tree().current_scene.add_child(expl)
	expl.global_position = global_position

	_on_expire()
