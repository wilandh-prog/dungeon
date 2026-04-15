extends CharacterBody3D

signal hp_changed(current: float, max_hp: float)
signal mana_changed(current: float, max_mana: float)
signal died

@onready var camera: Camera3D = $Camera3D
@onready var spell_caster: Node3D = $Camera3D/SpellCaster
@onready var raycast: RayCast3D = $Camera3D/SpellCaster/RayCast3D

var hp: float = Constants.PLAYER_MAX_HP
var max_hp: float = Constants.PLAYER_MAX_HP
var mana: float = Constants.PLAYER_MAX_MANA
var max_mana: float = Constants.PLAYER_MAX_MANA

var mouse_sensitivity: float = Constants.PLAYER_MOUSE_SENSITIVITY
var gravity: float = Constants.GRAVITY

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -PI / 2.0, PI / 2.0)

	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = Constants.PLAYER_JUMP_VELOCITY

	# Movement
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * Constants.PLAYER_MOVE_SPEED
		velocity.z = direction.z * Constants.PLAYER_MOVE_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, Constants.PLAYER_MOVE_SPEED)
		velocity.z = move_toward(velocity.z, 0, Constants.PLAYER_MOVE_SPEED)

	move_and_slide()

	# Mana regen
	if mana < max_mana:
		mana = minf(mana + Constants.PLAYER_MANA_REGEN * delta, max_mana)
		mana_changed.emit(mana, max_mana)

func take_damage(amount: float) -> void:
	hp -= amount
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		hp = 0
		died.emit()
		GameManager.on_player_died()

func heal(amount: float) -> void:
	hp = minf(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)

func use_mana(amount: float) -> bool:
	if mana >= amount:
		mana -= amount
		mana_changed.emit(mana, max_mana)
		return true
	return false

func has_mana(amount: float) -> bool:
	return mana >= amount
