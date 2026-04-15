extends Area3D

var fragment: SpellFragment = null
var bob_time: float = 0.0

func _ready() -> void:
	collision_layer = 16 # layer 5 - pickups
	collision_mask = 2 # player
	body_entered.connect(_on_body_entered)

	if fragment == null:
		# Generate random fragment if none assigned
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		fragment = SpellFragment.create_random(rng)

	# Set color to match element
	var mesh: MeshInstance3D = $MeshInstance3D
	if mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = fragment.icon_color
		mat.emission_enabled = true
		mat.emission = fragment.icon_color
		mat.emission_energy_multiplier = 4.0
		mesh.material_override = mat

	# Add point light so it glows in the room
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.0, 0)
	light.omni_range = 4.0
	light.light_energy = 1.5
	light.light_color = fragment.icon_color
	light.shadow_enabled = false
	add_child(light)

func _process(delta: float) -> void:
	# Bobbing animation
	bob_time += delta * 2.0
	position.y += sin(bob_time) * 0.3 * delta
	rotate_y(delta * 1.5)

func _on_body_entered(body: Node3D) -> void:
	if body.has_node("PlayerInventory"):
		var inventory: Node = body.get_node("PlayerInventory")
		inventory.add_fragment(fragment)
		queue_free()
