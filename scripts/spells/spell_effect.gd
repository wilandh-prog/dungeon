class_name SpellEffect
extends Node3D

var spell_data: Dictionary = {}
var caster: CharacterBody3D = null
var damage: float = 0.0
var lifetime: float = 5.0
var has_chain := false
var has_split := false
var has_pierce := false
var chain_range := 5.0
var split_done := false

func initialize(data: Dictionary, p_caster: CharacterBody3D) -> void:
	spell_data = data
	caster = p_caster
	damage = data.get("damage", 20.0)

	var mods: Array = data.get("modifiers", [])
	has_chain = mods.has("CHAIN")
	has_split = mods.has("SPLIT")
	has_pierce = mods.has("PIERCE")

	# Set color
	_apply_color(data.get("color", Color.WHITE))

func _apply_color(color: Color) -> void:
	for child in get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 2.0
			child.material_override = mat
		if child is GPUParticles3D and child.process_material:
			child.process_material.color = color

func _on_cast() -> void:
	pass

func _on_hit(target: Node3D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)

	# Chain modifier
	if has_chain:
		_chain_to_nearby(target)

	# Hybrid bonuses
	_apply_hybrid_bonus(target)

func _on_expire() -> void:
	queue_free()

func _chain_to_nearby(hit_target: Node3D) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var closest: Node3D = null
	var closest_dist := chain_range

	for enemy: Node3D in enemies:
		if enemy == hit_target:
			continue
		var dist: float = hit_target.global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy

	if closest and closest.has_method("take_damage"):
		closest.take_damage(damage * 0.5)
		# Visual: brief line effect (simplified)

func _apply_hybrid_bonus(target: Node3D) -> void:
	var bonus: String = spell_data.get("hybrid_bonus", "")
	match bonus:
		"aoe_on_hit":
			_aoe_damage_at(target.global_position, 2.0, damage * 0.3)
		"bonus_vs_cc":
			# Extra damage to slowed/stunned enemies
			if target.has_method("take_damage"):
				target.take_damage(damage * 0.3)

func _aoe_damage_at(pos: Vector3, radius: float, dmg: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy: Node3D in enemies:
		if enemy.global_position.distance_to(pos) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(dmg)
