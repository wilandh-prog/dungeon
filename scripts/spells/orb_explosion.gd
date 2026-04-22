extends Node3D

const DURATION := 0.65

var element_color := Color.WHITE

func _ready() -> void:
	var core_color := Color.WHITE.lerp(element_color, 0.25)
	var edge_color := element_color.darkened(0.15)

	var mat: ShaderMaterial
	if $Sphere.material_override is ShaderMaterial:
		mat = ($Sphere.material_override as ShaderMaterial).duplicate()
		$Sphere.material_override = mat
		mat.set_shader_parameter("color_core", core_color)
		mat.set_shader_parameter("color_edge", edge_color)
		mat.set_shader_parameter("emission_strength", 22.0)

	var ring_mat: ShaderMaterial
	if $Ring.material_override is ShaderMaterial:
		ring_mat = ($Ring.material_override as ShaderMaterial).duplicate()
		$Ring.material_override = ring_mat
		ring_mat.set_shader_parameter("color", element_color)

	_setup_particles(core_color, element_color)
	_play(mat, ring_mat)

func _setup_particles(core_color: Color, color: Color) -> void:
	var burst_mesh := SphereMesh.new()
	burst_mesh.radius = 0.06
	burst_mesh.height = 0.12
	burst_mesh.radial_segments = 4
	burst_mesh.rings = 2
	var burst_draw_mat := StandardMaterial3D.new()
	burst_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	burst_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	burst_draw_mat.vertex_color_use_as_albedo = true
	burst_mesh.material = burst_draw_mat
	$Particles.draw_pass_1 = burst_mesh

	var burst_proc := ParticleProcessMaterial.new()
	burst_proc.direction = Vector3.ZERO
	burst_proc.spread = 180.0
	burst_proc.initial_velocity_min = 3.0
	burst_proc.initial_velocity_max = 9.0
	burst_proc.gravity = Vector3.ZERO
	burst_proc.radial_accel_min = 2.0
	burst_proc.radial_accel_max = 6.0
	burst_proc.damping_min = 5.0
	burst_proc.damping_max = 10.0
	burst_proc.scale_min = 0.6
	burst_proc.scale_max = 2.2
	var g1 := Gradient.new()
	g1.set_color(0, Color(core_color.r, core_color.g, core_color.b, 1.0))
	g1.set_color(1, Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 0.0))
	var gt1 := GradientTexture1D.new()
	gt1.gradient = g1
	burst_proc.color_ramp = gt1
	$Particles.process_material = burst_proc

	var ember_mesh := SphereMesh.new()
	ember_mesh.radius = 0.035
	ember_mesh.height = 0.07
	ember_mesh.radial_segments = 4
	ember_mesh.rings = 2
	var ember_draw_mat := StandardMaterial3D.new()
	ember_draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ember_draw_mat.vertex_color_use_as_albedo = true
	ember_mesh.material = ember_draw_mat
	$Embers.draw_pass_1 = ember_mesh

	var ember_proc := ParticleProcessMaterial.new()
	ember_proc.direction = Vector3(0, 1, 0)
	ember_proc.spread = 100.0
	ember_proc.initial_velocity_min = 4.0
	ember_proc.initial_velocity_max = 10.0
	ember_proc.gravity = Vector3(0, -5.0, 0)
	ember_proc.radial_accel_min = 0.0
	ember_proc.radial_accel_max = 2.0
	ember_proc.tangential_accel_min = -2.0
	ember_proc.tangential_accel_max = 2.0
	ember_proc.damping_min = 2.0
	ember_proc.damping_max = 6.0
	ember_proc.scale_min = 0.4
	ember_proc.scale_max = 1.2
	ember_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	ember_proc.emission_sphere_radius = 0.3
	var g2 := Gradient.new()
	g2.set_color(0, Color(color.r, color.g, color.b, 1.0))
	g2.set_color(1, Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.0))
	var gt2 := GradientTexture1D.new()
	gt2.gradient = g2
	ember_proc.color_ramp = gt2
	$Embers.process_material = ember_proc

func _play(mat: ShaderMaterial, ring_mat: ShaderMaterial) -> void:
	$Sphere.scale = Vector3.ONE * 0.05
	$Ring.scale = Vector3(0.05, 1.0, 0.05)

	$Particles.restart()
	$Embers.restart()

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property($Sphere, "scale", Vector3.ONE * 3.0, 0.2) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	if mat:
		tween.tween_method(func(v: float): mat.set_shader_parameter("expand_t", v), 0.0, 1.0, 0.2)
		tween.tween_method(func(v: float): mat.set_shader_parameter("dissolve_t", v), 0.0, 1.0, 0.35) \
			.set_delay(0.15)
		tween.tween_method(func(v: float): mat.set_shader_parameter("emission_strength", v), 22.0, 3.0, 0.5)

	tween.tween_property($Ring, "scale", Vector3(8.0, 1.0, 8.0), 0.45) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if ring_mat:
		tween.tween_method(func(v: float): ring_mat.set_shader_parameter("ring_progress", v), 0.0, 1.0, 0.45)

	await get_tree().create_timer(DURATION).timeout
	if is_instance_valid(self):
		queue_free()
