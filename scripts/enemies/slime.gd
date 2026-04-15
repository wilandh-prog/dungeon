extends "res://scripts/enemies/enemy_base.gd"

func _ready() -> void:
	max_hp = 20.0
	move_speed = 2.0
	attack_damage = 4.0
	attack_range = 1.5
	attack_cooldown = 1.2
	super._ready()

func _do_attack() -> void:
	# Melee attack
	if target and target.has_method("take_damage"):
		var dist := global_position.distance_to(target.global_position)
		if dist <= attack_range:
			target.take_damage(attack_damage)
			# Simple bounce animation
			var tween := create_tween()
			tween.tween_property(self, "scale", Vector3(1.3, 0.7, 1.3), 0.1)
			tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
