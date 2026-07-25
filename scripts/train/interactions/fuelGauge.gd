extends Area2D

@export var frame_count: int = 15
@export var invert_frames: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt: Control = $Control

var _train: Node = null
var player_in_range: Node = null

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
		player_in_range = body
		_refresh_prompt()

func _on_body_exited(body: Node) -> void:
	if body == player_in_range:
		player_in_range = null
		prompt.visible = false

func _process(_delta: float) -> void:
	_refresh_prompt()

func _refresh_prompt() -> void:
	prompt.visible = player_in_range != null and player_in_range.is_carrying()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if player_in_range == null or not player_in_range.is_carrying() or _train == null:
		return

	var canister = player_in_range.carried
	if canister == null or not canister.has_method("consume"):
		return

	_train.add_fuel(canister.consume())
	get_viewport().set_input_as_handled()

func _apply_frame(normalized: float) -> void:
	var idx: int = clampi(int(round(clampf(normalized, 0.0, 1.0) * (frame_count - 1))), 0, frame_count - 1)
	sprite.frame = (frame_count - 1 - idx) if invert_frames else idx
