extends "res://scripts/enemies/enemy_base.gd"

@onready var model: Node3D = $IdleModel
var anim_player: AnimationPlayer = null
var current_anim := ""
var idle_anim := ""
var walk_anim := ""
var attack_anim := ""

# Boss mechanics
var phase := 1
var attack_pattern := 0
var charge_speed := 9.0
var is_charging := false
var charge_timer := 0.0

func _ready() -> void:
	max_hp = 150.0
	move_speed = 2.5
	attack_damage = 15.0
	attack_range = 2.5
	attack_cooldown = 2.0
	detection_range = 20.0
	super._ready()
	phase = GameManager.current_floor
	if model:
		anim_player = _find_anim_player(model)
		if anim_player:
			_load_extra_animations()
			_resolve_animation_names()
			_set_loop_modes()
			_strip_root_motion(walk_anim)
			_strip_root_motion(attack_anim)
	_play_anim(idle_anim)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result = _find_anim_player(child)
		if result:
			return result
	return null

func _load_extra_animations() -> void:
	var extras := {
		"walk_lib": "res://resources/enemypaladin/Walking (1).fbx",
		"attack_lib": "res://resources/enemypaladin/Sword And Shield Slash.fbx"
	}
	for lib_name in extras:
		var packed = load(extras[lib_name])
		if not packed:
			push_warning("[PaladinBoss] Could not load: " + extras[lib_name])
			continue
		var inst = packed.instantiate()
		var ap = _find_anim_player(inst)
		if ap:
			var lib_list = ap.get_animation_library_list()
			if lib_list.size() > 0:
				var lib = ap.get_animation_library(lib_list[0]).duplicate(true)
				if lib and not anim_player.has_animation_library(lib_name):
					anim_player.add_animation_library(lib_name, lib)
		inst.queue_free()

func _resolve_animation_names() -> void:
	if anim_player.has_animation_library(""):
		var lib := anim_player.get_animation_library("")
		for a in lib.get_animation_list():
			if a != "RESET" and a != "Take 001":
				idle_anim = a
				break
	if anim_player.has_animation_library("walk_lib"):
		var lib := anim_player.get_animation_library("walk_lib")
		for a in lib.get_animation_list():
			if a != "RESET" and a != "Take 001":
				walk_anim = "walk_lib/" + a
				break
	if anim_player.has_animation_library("attack_lib"):
		var lib := anim_player.get_animation_library("attack_lib")
		for a in lib.get_animation_list():
			if a != "RESET" and a != "Take 001":
				attack_anim = "attack_lib/" + a
				break

func _set_loop_modes() -> void:
	for anim_name in [idle_anim, walk_anim]:
		if anim_name != "" and anim_player.has_animation(anim_name):
			anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR

func _strip_root_motion(anim_name: String) -> void:
	if anim_name == "" or not anim_player.has_animation(anim_name):
		return
	var parts := anim_name.split("/", true, 1)
	var lib_name := parts[0] if parts.size() > 1 else ""
	var short_name := parts[-1]
	var anim := anim_player.get_animation(anim_name).duplicate()
	anim_player.get_animation_library(lib_name).remove_animation(short_name)
	anim_player.get_animation_library(lib_name).add_animation(short_name, anim)

	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var path_lower := str(anim.track_get_path(i)).to_lower()
		var is_root := "hip" in path_lower or "root" in path_lower or "pelvis" in path_lower \
				or ":" not in str(anim.track_get_path(i))
		if not is_root:
			continue
		for j in anim.track_get_key_count(i):
			var pos: Vector3 = anim.track_get_key_value(i, j)
			anim.track_set_key_value(i, j, Vector3(0.0, pos.y, 0.0))

func _physics_process(delta: float) -> void:
	if is_charging:
		_process_charge(delta)
		move_and_slide()
		return
	super._physics_process(delta)
	_face_target()
	_update_animation()

func _face_target() -> void:
	if model == null or target == null or not is_instance_valid(target):
		return
	var dir := (target.global_position - global_position).normalized()
	dir.y = 0
	if dir.length() > 0.01:
		model.rotation.y = atan2(dir.x, dir.z)

func _update_animation() -> void:
	if state == "DEAD":
		return
	if current_anim == attack_anim and attack_anim != "" and anim_player and anim_player.is_playing():
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if is_charging and walk_anim != "":
		_play_anim(walk_anim)
	elif speed > 0.5 and walk_anim != "":
		_play_anim(walk_anim)
	elif state == "ATTACK" and attack_anim != "":
		_play_anim(attack_anim)
	elif idle_anim != "":
		_play_anim(idle_anim)

func _play_anim(anim_name: String) -> void:
	if anim_player == null or anim_name == "" or current_anim == anim_name:
		return
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
		current_anim = anim_name

func _do_attack() -> void:
	# Cycle: slash, charge, slash on floor 1; adds extra slashes on higher floors
	attack_pattern = (attack_pattern + 1) % (2 + phase - 1)
	match attack_pattern:
		0:
			_slash_attack()
		1:
			_charge_attack()
		_:
			_slash_attack()

func _slash_attack() -> void:
	if attack_anim != "":
		_play_anim(attack_anim)
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(_deal_slash_damage)

func _deal_slash_damage() -> void:
	if target == null or not is_instance_valid(target) or state == "DEAD":
		return
	var dist := global_position.distance_to(target.global_position)
	if dist <= attack_range * 1.5:
		target.take_damage(attack_damage)
	current_anim = ""

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
	if target and target.has_method("take_damage"):
		var dist := global_position.distance_to(target.global_position)
		if dist <= 2.0:
			target.take_damage(attack_damage * 1.5)
			is_charging = false
			velocity.x = 0
			velocity.z = 0
