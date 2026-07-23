extends Camera2D

@export var default_target: Node2D
@export var follow_speed: float = 5.0

var target: Node2D

func _ready() -> void:
	target = default_target
	make_current()
	if target:
		global_position = target.global_position

func set_target(new_target: Node2D) -> void:
	target = new_target

func _physics_process(delta: float) -> void:
	if target == null:
		return
	global_position = global_position.lerp(
		target.global_position,
		1.0 - exp(-follow_speed * delta)
	)
