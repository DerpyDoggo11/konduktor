extends Camera2D

@export var default_target: Node2D
@export var follow_speed: float = 10.0
@export var zoom_speed: float = 4.0
@export var mouse_lead: float = 0.35

@export var walk_zoom: Vector2 = Vector2(4, 4)
@export var seated_zoom: Vector2 = Vector2(4, 4)
@export var control_zoom: Vector2 = Vector2(4, 4) 
@export var map_zoom: Vector2 = Vector2(0.5, 0.5)

var target: Node2D
var target_zoom: Vector2
var focus_mouse: bool = false

var _prev_target: Node2D = null
var _prev_zoom: Vector2
var _prev_focus: bool = false

var _shake_amount: float = 0.0
var _shake_decay: float = 0.0

	
func _ready() -> void:
	process_physics_priority = 100
	process_priority = 100
	target = default_target
	target_zoom = walk_zoom
	zoom = walk_zoom
	make_current()
	if target:
		global_position = target.global_position

func carry(move: Vector2) -> void:
	global_position += move
	if _prev_target == null and target == null:
		return
		
func set_target(new_target: Node2D, new_zoom: Vector2 = Vector2.ZERO, focus: bool = false) -> void:
	_prev_target = null
	target = new_target
	target_zoom = new_zoom if new_zoom != Vector2.ZERO else walk_zoom
	focus_mouse = focus

func push_target(new_target: Node2D, new_zoom: Vector2 = Vector2.ZERO, focus: bool = false) -> void:
	var prev_t := target
	var prev_z := target_zoom
	var prev_f := focus_mouse
	set_target(new_target, new_zoom, focus)
	_prev_target = prev_t
	_prev_zoom = prev_z
	_prev_focus = prev_f

func pop_target() -> void:
	if _prev_target == null:
		return
	target = _prev_target
	target_zoom = _prev_zoom
	focus_mouse = _prev_focus
	_prev_target = null

func _physics_process(delta: float) -> void:
	zoom = zoom.lerp(target_zoom, 1.0 - exp(-zoom_speed * delta))

	if target == null:
		return

	var desired := target.global_position
	if focus_mouse:
		var screen_offset := get_viewport().get_mouse_position() - get_viewport_rect().size * 0.5
		desired += (screen_offset / zoom) * mouse_lead

	global_position = global_position.lerp(desired, 1.0 - exp(-follow_speed * delta))
	
	if _shake_amount > 0.0:
		_shake_amount = maxf(0.0, _shake_amount - _shake_decay * delta)
		offset = Vector2(
			randf_range(-_shake_amount, _shake_amount),
			randf_range(-_shake_amount, _shake_amount)
		)
	else:
		offset = Vector2.ZERO
		
func shake(amount: float, duration: float) -> void:
	_shake_amount = maxf(_shake_amount, amount)
	_shake_decay = amount / maxf(duration, 0.01)
