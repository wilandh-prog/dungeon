extends CharacterBody3D

signal died(enemy: CharacterBody3D)

@export var max_hp: float = 50.0
@export var move_speed: float = 3.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5
@export var detection_range: float = 15.0

var hp: float
var state: String = "IDLE" # IDLE, CHASE, ATTACK, DEAD
var target: CharacterBody3D = null
var attack_timer: float = 0.0
var gravity: float = Constants.GRAVITY
var room_node: Node3D = null

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

func _ready() -> void:
	hp = max_hp * GameManager.get_difficulty_multiplier()
	attack_damage *= GameManager.get_difficulty_multiplier()
	add_to_group("enemies")
	# Find parent room
	var parent := get_parent()
	if parent and parent.has_method("on_enemy_died"):
		room_node = parent

func activate() -> void:
	state = "CHASE"
	_find_player()
	# Move out of the room node so room visibility culling doesn't hide this enemy
	# while it's actively chasing. room_node reference is kept for on_enemy_died().
	var room := get_parent()
	var container := room.get_parent() if is_instance_valid(room) else null
	if container:
		reparent(container, true)

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0] as CharacterBody3D
	else:
		# Find by scene tree
		var game := get_tree().current_scene
		if game:
			var player_node := game.get_node_or_null("Player")
			if player_node:
				target = player_node

func _physics_process(delta: float) -> void:
	if state == "DEAD":
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if target == null or not is_instance_valid(target):
		_find_player()
		if target == null:
			return

	attack_timer -= delta

	match state:
		"IDLE":
			pass
		"CHASE":
			_chase(delta)
		"ATTACK":
			_attack(delta)

	move_and_slide()

func _chase(_delta: float) -> void:
	if target == null:
		return

	var dist := global_position.distance_to(target.global_position)
	if dist <= attack_range:
		state = "ATTACK"
		velocity.x = 0
		velocity.z = 0
		return

	# Direct movement toward player (no navmesh needed)
	var dir := (target.global_position - global_position).normalized()
	dir.y = 0
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

func _attack(_delta: float) -> void:
	if target == null:
		return

	var dist := global_position.distance_to(target.global_position)
	if dist > attack_range * 1.5:
		state = "CHASE"
		return

	if attack_timer <= 0:
		_do_attack()
		attack_timer = attack_cooldown

func _do_attack() -> void:
	# Override in subclasses
	if target and target.has_method("take_damage"):
		var dist := global_position.distance_to(target.global_position)
		if dist <= attack_range:
			target.take_damage(attack_damage)

func take_damage(amount: float) -> void:
	if state == "DEAD":
		return
	hp -= amount
	_on_hit()
	if hp <= 0:
		_die()

func _on_hit() -> void:
	# Flash effect - brief color change
	pass

func _die() -> void:
	state = "DEAD"
	GameManager.on_enemy_killed()
	_drop_fragment()
	if room_node and room_node.has_method("on_enemy_died"):
		room_node.on_enemy_died()
	died.emit(self)
	# Simple death: just remove after brief delay
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.3)
	tween.tween_callback(queue_free)

func _drop_fragment() -> void:
	if randf() < 0.7: # 70% drop chance
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var fragment := SpellFragment.create_random(rng)
		var pickup := preload("res://scenes/spells/fragment_pickup.tscn").instantiate()
		pickup.fragment = fragment
		pickup.global_position = global_position + Vector3(0, 0.5, 0)
		get_tree().current_scene.add_child(pickup)
