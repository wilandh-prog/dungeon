extends "res://scripts/enemies/enemy_base.gd"

const ProjectileScene = preload("res://scenes/enemies/enemy_projectile.tscn")
var preferred_range := 6.0

@onready var model: Node3D = $ArcherModel
var anim_player: AnimationPlayer = null
var current_anim := ""

func _ready() -> void:
	max_hp = 30.0
	move_speed = 2.5
	attack_damage = 6.0
	attack_range = 10.0
	attack_cooldown = 2.0
	super._ready()
	if model:
		anim_player = model.get_node_or_null("AnimationPlayer")
		if anim_player:
			print("Animations: ", anim_player.get_animation_list())
	_play_anim("idle")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_face_target()
	_update_animation()

func _face_target() -> void:
	if model and target and is_instance_valid(target):
		var dir := (target.global_position - global_position).normalized()
		dir.y = 0
		if dir.length() > 0.01:
			model.rotation.y = atan2(dir.x, dir.z)

func _update_animation() -> void:
	if state == "DEAD":
		return
	# Don't interrupt shoot animation while it's playing
	if current_anim == "shoot" and anim_player and anim_player.is_playing():
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var in_attack_range := false
	if target and is_instance_valid(target):
		in_attack_range = global_position.distance_to(target.global_position) <= attack_range
	if speed > 0.5:
		if target and is_instance_valid(target):
			var to_target := (target.global_position - global_position).normalized()
			var move_dir := Vector3(velocity.x, 0, velocity.z).normalized()
			if to_target.dot(move_dir) < -0.3:
				_play_anim("walk_back")
			else:
				_play_anim("walk")
		else:
			_play_anim("walk")
	elif in_attack_range:
		_play_anim("shoot")
	else:
		_play_anim("idle")

func _play_anim(anim_name: String) -> void:
	if anim_player == null or current_anim == anim_name:
		return
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
		current_anim = anim_name

func _chase(_delta: float) -> void:
	if target == null:
		return
	var dist := global_position.distance_to(target.global_position)
	if dist <= attack_range:
		state = "ATTACK"
	var dir := (target.global_position - global_position).normalized()
	dir.y = 0
	if dist > preferred_range + 2.0:
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	elif dist < preferred_range - 1.0:
		velocity.x = -dir.x * move_speed
		velocity.z = -dir.z * move_speed
	else:
		velocity.x = 0
		velocity.z = 0

func _attack(_delta: float) -> void:
	if target == null:
		return
	var dist := global_position.distance_to(target.global_position)
	var dir := (target.global_position - global_position).normalized()
	dir.y = 0
	if dist < preferred_range - 1.0:
		velocity.x = -dir.x * move_speed * 0.7
		velocity.z = -dir.z * move_speed * 0.7
	elif dist > attack_range * 1.5:
		state = "CHASE"
		return
	else:
		velocity.x = 0
		velocity.z = 0
	if attack_timer <= 0:
		_do_attack()
		attack_timer = attack_cooldown

func _do_attack() -> void:
	if target == null:
		return
	_play_anim("shoot")
	# Fire projectile after short delay for animation
	var timer := get_tree().create_timer(0.4)
	timer.timeout.connect(_fire_projectile)

func _fire_projectile() -> void:
	if target == null or not is_instance_valid(target) or state == "DEAD":
		return
	var projectile := ProjectileScene.instantiate()
	projectile.damage = attack_damage
	projectile.speed = 8.0
	var dir := (target.global_position - global_position).normalized()
	projectile.direction = dir
	projectile.global_position = global_position + Vector3(0, 1.0, 0) + dir * 0.5
	get_tree().current_scene.add_child(projectile)
	current_anim = ""  # Allow re-triggering shoot or switching to idle/walk
