extends SpellEffect

var beam_range: float = 15.0
var tick_rate: float = 0.1
var tick_timer: float = 0.0

@onready var raycast: RayCast3D = $RayCast3D

func _ready() -> void:
	beam_range = spell_data.get("range", 15.0)
	if raycast:
		raycast.target_position = Vector3(0, 0, -beam_range)
	_on_cast()

func _process(delta: float) -> void:
	tick_timer -= delta
	if tick_timer <= 0:
		tick_timer = tick_rate
		_beam_tick()

	# Update visual beam length
	_update_beam_visual()

func _beam_tick() -> void:
	if raycast and raycast.is_colliding():
		var collider := raycast.get_collider()
		if collider and collider.is_in_group("enemies"):
			_on_hit(collider)

func _update_beam_visual() -> void:
	var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
	if mesh == null:
		return

	var length := beam_range
	if raycast and raycast.is_colliding():
		length = global_position.distance_to(raycast.get_collision_point())

	mesh.scale = Vector3(0.1, 0.1, length)
	mesh.position = Vector3(0, 0, -length / 2.0)
