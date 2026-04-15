extends "res://scripts/enemies/enemy_base.gd"

var phase := 1
var charge_speed := 8.0
var is_charging := false
var charge_timer := 0.0
var slam_cooldown := 3.0
var slam_timer := 0.0
var attack_pattern := 0 # Alternates between slam and charge

func _ready() -> void:
	max_hp = 150.0
	move_speed = 2.0
	attack_damage = 10.0
	attack_range = 3.0
	attack_cooldown = 2.5
	super._ready()
	# Extra patterns on higher floors
	phase = GameManager.current_floor

func _physics_process(delta: float) -> void:
	if is_charging:
		_process_charge(delta)
		move_and_slide()
		return
	super._physics_process(delta)

func _do_attack() -> void:
	attack_pattern = (attack_pattern + 1) % (2 + phase - 1)

	match attack_pattern:
		0:
			_slam_attack()
		1:
			_charge_attack()
		_:
			_slam_attack() # Extra slams on higher floors

func _slam_attack() -> void:
	# Melee slam - AoE damage around boss
	if target and target.has_method("take_damage"):
		var dist := global_position.distance_to(target.global_position)
		if dist <= attack_range * 1.5:
			target.take_damage(attack_damage)
	# Visual: scale pulse
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.2, 0.8, 1.2), 0.15)
	tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.15)

func _charge_attack() -> void:
	if target == null:
		return
	is_charging = true
	charge_timer = 1.0
	var dir := (target.global_position - global_position).normalized()
	dir.y = 0
	velocity.x = dir.x * charge_speed
	velocity.z = dir.z * charge_speed

func _process_charge(delta: float) -> void:
	charge_timer -= delta
	if charge_timer <= 0:
		is_charging = false
		velocity.x = 0
		velocity.z = 0
		return

	# Check if hit player during charge
	if target and target.has_method("take_damage"):
		var dist := global_position.distance_to(target.global_position)
		if dist <= 2.0:
			target.take_damage(attack_damage * 1.5)
			is_charging = false
			velocity.x = 0
			velocity.z = 0
