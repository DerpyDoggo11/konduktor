extends AnimatableBody2D

@export var slide_offset: Vector2 = Vector2(0, -40)
@export var slide_time: float = 0.6
@export var inverted: bool = false
@export var trans: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

signal state_changed(open: bool)

var is_open: bool = false
var _closed_pos: Vector2
var _tween: Tween = null
var _moving: bool = false

func _ready() -> void:
	sync_to_physics = false
	_closed_pos = position
	if inverted:
		is_open = true
		position = _closed_pos + slide_offset

func toggle() -> void:
	set_open(not is_open)

func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	state_changed.emit(is_open)

	if _tween and _tween.is_running():
		_tween.kill()

	var target: Vector2 = _closed_pos + (slide_offset if is_open else Vector2.ZERO)

	_moving = true
	
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.set_trans(trans).set_ease(ease_type)
	_tween.tween_property(self, "position", target, slide_time)
	_tween.tween_callback(func():
		position = target
		_moving = false
	)
