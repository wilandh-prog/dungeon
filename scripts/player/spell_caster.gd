extends Node3D

@onready var player: CharacterBody3D = get_parent().get_parent()
@onready var inventory: Node = null
@onready var raycast: RayCast3D = $RayCast3D
@onready var wand: Node3D = get_parent().get_node("Wand")
@onready var wand_tip: Marker3D = get_parent().get_node("Wand/TipPoint")
@onready var melee_area: Area3D = get_parent().get_node("MeleeArea")

var is_casting_beam := false
var beam_spell: Dictionary = {}
var beam_visual: Node3D = null

var melee_cooldown := 0.5
var melee_timer := 0.0
var melee_damage := 15.0
var is_swinging := false

const SpellBoltScene = preload("res://scenes/spells/spell_bolt.tscn")
const SpellNovaScene = preload("res://scenes/spells/spell_nova.tscn")
const SpellBeamScene = preload("res://scenes/spells/spell_beam.tscn")
const SpellOrbScene = preload("res://scenes/spells/spell_orb.tscn")
const SpellWallScene = preload("res://scenes/spells/spell_wall.tscn")

func _ready() -> void:
	inventory = player.get_node("PlayerInventory")

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		if is_casting_beam:
			_stop_beam()
		return

	melee_timer -= delta

	# Spell cycling
	if Input.is_action_just_pressed("spell_next"):
		inventory.cycle_spell(1)
		_update_wand_color()
	elif Input.is_action_just_pressed("spell_prev"):
		inventory.cycle_spell(-1)
		_update_wand_color()

	# Casting
	if Input.is_action_just_pressed("cast_spell"):
		_try_cast()
	elif Input.is_action_just_released("cast_spell"):
		if is_casting_beam:
			_stop_beam()

	# Beam continuous drain
	if is_casting_beam:
		if not player.use_mana(beam_spell.mana_cost * delta):
			_stop_beam()

func _try_cast() -> void:
	var spell: Dictionary = inventory.get_active_spell()

	if spell.is_empty():
		_melee_attack()
		return

	if spell.get("is_beam", false):
		# Beam only needs a fraction of mana_cost to start (drained per-frame after)
		if not player.has_mana(spell.mana_cost * 0.1):
			_melee_attack()
			return
		_start_beam(spell)
	else:
		if not player.use_mana(spell.mana_cost):
			_melee_attack()
			return
		_cast_spell(spell)
		_wand_cast_anim()

func _cast_spell(spell: Dictionary) -> void:
	var scene: PackedScene
	match spell.shape:
		"BOLT":
			scene = SpellBoltScene
		"NOVA":
			scene = SpellNovaScene
		"ORB":
			scene = SpellOrbScene
		"WALL":
			scene = SpellWallScene
		_:
			scene = SpellBoltScene

	var instance := scene.instantiate()
	instance.initialize(spell, player)
	get_tree().current_scene.add_child(instance)

	if spell.shape == "NOVA":
		instance.global_position = player.global_position
	else:
		var camera: Camera3D = player.camera
		instance.global_position = wand_tip.global_position
		instance.global_transform.basis = camera.global_transform.basis

func _start_beam(spell: Dictionary) -> void:
	if is_casting_beam:
		return
	if not player.has_mana(spell.mana_cost * 0.1):
		return

	is_casting_beam = true
	beam_spell = spell

	var instance := SpellBeamScene.instantiate()
	instance.initialize(spell, player)
	add_child(instance)
	beam_visual = instance

func _stop_beam() -> void:
	is_casting_beam = false
	beam_spell = {}
	if beam_visual and is_instance_valid(beam_visual):
		beam_visual.queue_free()
	beam_visual = null

func _melee_attack() -> void:
	if melee_timer > 0:
		return
	melee_timer = melee_cooldown
	_wand_swing_anim()

	# Damage enemies in melee range
	var bodies := melee_area.get_overlapping_bodies()
	for body: Node3D in bodies:
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(melee_damage)

func _wand_swing_anim() -> void:
	if wand == null:
		return
	var tween := create_tween()
	tween.tween_property(wand, "rotation_degrees", Vector3(-60, 0, 0), 0.1)
	tween.tween_property(wand, "rotation_degrees", Vector3(0, 0, 0), 0.2)

func _wand_cast_anim() -> void:
	if wand == null:
		return
	var tween := create_tween()
	tween.tween_property(wand, "rotation_degrees", Vector3(15, 0, 0), 0.08)
	tween.tween_property(wand, "rotation_degrees", Vector3(0, 0, 0), 0.15)

func _update_wand_color() -> void:
	var spell: Dictionary = inventory.get_active_spell()
	var tip_mesh: MeshInstance3D = wand.get_node_or_null("Tip")
	if tip_mesh == null:
		return
	var color := Color(0.6, 0.8, 1.0)
	if not spell.is_empty():
		color = spell.get("color", color)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	tip_mesh.material_override = mat
