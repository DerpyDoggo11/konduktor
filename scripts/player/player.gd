extends CharacterBody2D

@export var walk_speed: float = 150.0
@export var sprint_multiplier: float = 1.8


@export var acceleration: float = 1200.0
@export var friction: float = 1400.0

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var speed := walk_speed
	if Input.is_action_pressed("sprint"):
		speed *= sprint_multiplier

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
