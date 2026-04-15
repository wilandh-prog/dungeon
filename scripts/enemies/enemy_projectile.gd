extends Area3D

var damage: float = 10.0
var speed: float = 8.0
var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 5.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 3 # hits player (2) and environment (1)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
