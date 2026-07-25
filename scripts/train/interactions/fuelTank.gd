extends Area2D

@export var frame_count: int = 15
@export var invert_frames: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt: Control = $Control

var _train: Node = null

func _ready() -> void:
	sprite.hframes = frame_count
	sprite.vframes = 1
	prompt.visible = false

	await get_tree().process_frame
	_train = get_tree().get_first_node_in_group("train")
	if _train and _train.has_signal("fuel_changed"):
		_train.fuel_changed.connect(func(_f, n): _apply_frame(n))
		_apply_frame(_train.fuel / _train.max_fuel)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		prompt.visible = false

func _apply_frame(normalized: float) -> void:
	var idx: int = clampi(int(round(clampf(normalized, 0.0, 1.0) * (frame_count - 1))), 0, frame_count - 1)
	sprite.frame = (frame_count - 1 - idx) if invert_frames else idx
