extends SpellEffect

var beam_range: float = 15.0
var tick_rate: float = 0.1
var tick_timer: float = 0.0
var beam_mesh_v: MeshInstance3D = null
var wand_tip: Node3D = null

@onready var raycast: RayCast3D = $RayCast3D

func _ready() -> void:
	beam_range = spell_data.get("range", 15.0)
	if raycast:
		raycast.target_position = Vector3(0, 0, -beam_range)
	_on_cast()
	var primary_mesh := get_node_or_null("BeamMesh") as MeshInstance3D
	if primary_mesh:
		beam_mesh_v = primary_mesh.duplicate() as MeshInstance3D
		beam_mesh_v.name = "BeamMeshV"
		beam_mesh_v.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		add_child(beam_mesh_v)

func _apply_color(color: Color) -> void:
	var mesh := get_node_or_null("BeamMesh")
	if mesh and mesh.material_override is ShaderMaterial:
		var beam_mat := (mesh.material_override as ShaderMaterial).duplicate()
		mesh.material_override = beam_mat
		beam_mat.set_shader_parameter("beam_color", Color(color.r, color.g, color.b, 1.0))

func _process(delta: float) -> void:
	if wand_tip and is_instance_valid(wand_tip) and is_instance_valid(caster):
		global_transform.basis = caster.camera.global_transform.basis
		global_position = wand_tip.global_position

	tick_timer -= delta
	if tick_timer <= 0:
		tick_timer = tick_rate
		_beam_tick()
	_update_beam_visual()

func _beam_tick() -> void:
	if raycast and raycast.is_colliding():
		var collider := raycast.get_collider()
		if collider and collider.is_in_group("enemies"):
			_on_hit(collider)

func _update_beam_visual() -> void:
	var mesh: MeshInstance3D = get_node_or_null("BeamMesh")
	if mesh == null:
		return

	var length := beam_range
	if raycast and raycast.is_colliding():
		length = global_position.distance_to(raycast.get_collision_point())

	mesh.scale = Vector3(1.0, 1.0, length)
	mesh.position = Vector3(0, 0, -length / 2.0)
	if beam_mesh_v:
		beam_mesh_v.scale = Vector3(1.0, 1.0, length)
		beam_mesh_v.position = Vector3(0, 0, -length / 2.0)
