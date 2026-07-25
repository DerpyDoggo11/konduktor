extends Area2D

enum Mode { SUPPLY, DEPOSIT }

@export var mode: Mode = Mode.SUPPLY
@export var transfer_rate: float = 40.0
@export var frame_count: int = 8
@export var invert_frames: bool = false
@export var infinite: bool = false
@export var max_fuel: float = 300.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt: Control = $Control

var fuel: float
var player_in_range: Node = null
var _target: Node = null

func _ready() -> void:
	fuel = max_fuel
	sprite.hframes = frame_count
	sprite.vframes = 1
	prompt.visible = false
	set_process(false)
	_apply_frame(1.0 if infinite else fuel / max_fuel)

	if mode == Mode.DEPOSIT:
		await get_tree().process_frame
		_target = get_tree().get_first_node_in_group("train")
		if _target and _target.has_signal("fuel_changed"):
			_target.fuel_changed.connect(func(_f, n): _apply_frame(n))
			_apply_frame(_target.fuel / _target.max_fuel)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	player_in_range = body
	prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body != player_in_range:
		return
	player_in_range = null
	prompt.visible = false
	set_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range == null:
		return
	if event.is_action_pressed("interact"):
		set_process(true)
	elif event.is_action_released("interact"):
		set_process(false)

func _process(delta: float) -> void:
	if player_in_range == null:
		set_process(false)
		return

	var amount: float = transfer_rate * delta

	if mode == Mode.SUPPLY:
		var space: float = player_in_range.max_fuel - player_in_range.fuel
		var give: float = minf(amount, space)
		if not infinite:
			give = minf(give, fuel)
		if give <= 0.0:
			return
		player_in_range.add_fuel(give)
		if not infinite:
			fuel -= give
			_apply_frame(fuel / max_fuel)
	else:
		if _target == null:
			return
		var available: float = player_in_range.consume_fuel(amount)
		if available <= 0.0:
			return
		var accepted: float = _target.add_fuel(available)
		# Tank was full — give the remainder back.
		if accepted < available:
			player_in_range.add_fuel(available - accepted)

func _apply_frame(normalized: float) -> void:
	var idx: int = int(round(clampf(normalized, 0.0, 1.0) * (frame_count - 1)))
	sprite.frame = (frame_count - 1 - idx) if invert_frames else idx
