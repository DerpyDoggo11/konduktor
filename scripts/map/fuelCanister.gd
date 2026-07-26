extends Area2D

@export var fuel_amount: float = 250.0
@export var frame_count: int = 1
@export var invert_frames: bool = true
@export var follow_speed: float = 22.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt: Control = $Control
@onready var shape: CollisionShape2D = $CollisionShape2D

var carrier: Node2D = null
var player_in_range: Node = null

func _ready() -> void:
	add_to_group("fuel_canister")
	top_level = true
	sprite.hframes = frame_count
	sprite.vframes = 1
	_apply_frame(1.0)
	prompt.visible = false
	set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return

	if carrier != null:
		for area in get_overlapping_areas():
			if area.has_method("_refresh_prompt"):
				return
		_drop()
		get_viewport().set_input_as_handled()
	elif player_in_range != null and not player_in_range.is_carrying():
		_pick_up(player_in_range)
		get_viewport().set_input_as_handled()

func _pick_up(player: Node2D) -> void:
	if not player.pick_up(self):
		return
	carrier = player
	prompt.visible = false
	player_in_range = null
	shape.set_deferred("disabled", true)
	global_position = player.carry_point.global_position
	global_rotation = player.global_rotation
	set_physics_process(true)

func _drop() -> void:
	if carrier:
		carrier.release()
	carrier = null
	shape.set_deferred("disabled", false)
	set_physics_process(false)

func consume() -> float:
	if carrier:
		carrier.release()
	queue_free()
	return fuel_amount

func _physics_process(delta: float) -> void:
	if carrier == null or not is_instance_valid(carrier):
		_drop()
		return
	var w: float = 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(carrier.carry_point.global_position, w)
	global_rotation = lerp_angle(global_rotation, carrier.global_rotation, w)

func _apply_frame(normalized: float) -> void:
	var idx: int = clampi(int(round(clampf(normalized, 0.0, 1.0) * (frame_count - 1))), 0, frame_count - 1)
	sprite.frame = (frame_count - 1 - idx) if invert_frames else idx

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and carrier == null:
		player_in_range = body
		prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body == player_in_range:
		player_in_range = null
		prompt.visible = false
