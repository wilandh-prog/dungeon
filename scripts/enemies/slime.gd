extends "res://scripts/enemies/enemy_base.gd"

const HOP_INTERVAL   := 0.7
const HOP_FORCE      := 5.0
const TRAIL_INTERVAL := 0.35

var _mesh: MeshInstance3D
var _hop_timer   := 0.0
var _trail_timer := 0.0
var _trail_mat_base: StandardMaterial3D

func _ready() -> void:
	max_hp          = 20.0
	move_speed      = 2.0
	attack_damage   = 4.0
	attack_range    = 1.5
	attack_cooldown = 1.2
	super._ready()

	_hop_timer = randf() * HOP_INTERVAL  # stagger so groups don't hop in sync

	_mesh = $MeshInstance3D
	_apply_slime_shader()
	_init_trail_material()

func _apply_slime_shader() -> void:
	var shader := load("res://resources/shaders/slime_body.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_mesh.material_override = mat

func _init_trail_material() -> void:
	_trail_mat_base = StandardMaterial3D.new()
	_trail_mat_base.albedo_color = Color(0.08, 0.65, 0.1, 0.72)
	_trail_mat_base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat_base.roughness = 0.08
	_trail_mat_base.metallic_specular = 0.85
	_trail_mat_base.emission_enabled = true
	_trail_mat_base.emission = Color(0.04, 0.22, 0.04)
	_trail_mat_base.emission_energy_multiplier = 0.4

func _physics_process(delta: float) -> void:
	if state == "CHASE" and is_on_floor():
		_hop_timer -= delta
		if _hop_timer <= 0.0:
			_hop_timer = HOP_INTERVAL
			velocity.y = HOP_FORCE
			_play_hop_squash()

	super._physics_process(delta)

	if state == "CHASE" and is_on_floor() \
			and Vector2(velocity.x, velocity.z).length_squared() > 0.1:
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_trail_timer = TRAIL_INTERVAL
			_spawn_trail()

func _play_hop_squash() -> void:
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3(1.2,  0.75, 1.2),  0.07)
	tw.tween_property(_mesh, "scale", Vector3(0.88, 1.22, 0.88), 0.18)
	tw.tween_property(_mesh, "scale", Vector3(1.05, 0.95, 1.05), 0.12)
	tw.tween_property(_mesh, "scale", Vector3(1.0,  1.0,  1.0),  0.10)

func _spawn_trail() -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.26 + randf() * 0.12
	sphere.height = 0.1
	sphere.radial_segments = 10
	sphere.rings = 3
	mi.mesh = sphere
	mi.rotate_y(randf() * TAU)
	mi.scale = Vector3(1.0 + randf() * 0.4, 1.0, 1.0 + randf() * 0.4)

	var mat: StandardMaterial3D = _trail_mat_base.duplicate()
	mi.material_override = mat

	var floor_pos := Vector3(global_position.x, global_position.y + 0.05, global_position.z)
	get_tree().current_scene.add_child(mi)
	mi.global_position = floor_pos

	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_method(
		func(a: float) -> void: mat.albedo_color = Color(0.08, 0.65, 0.1, a),
		0.72, 0.0, 2.5
	)
	tw.tween_callback(mi.queue_free)

func _do_attack() -> void:
	if target and target.has_method("take_damage"):
		var dist := global_position.distance_to(target.global_position)
		if dist <= attack_range:
			target.take_damage(attack_damage)
			var tw := create_tween()
			tw.tween_property(_mesh, "scale", Vector3(1.35, 0.65, 1.35), 0.08)
			tw.tween_property(_mesh, "scale", Vector3(0.9,  1.1,  0.9),  0.10)
			tw.tween_property(_mesh, "scale", Vector3(1.0,  1.0,  1.0),  0.12)
