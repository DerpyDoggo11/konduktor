extends Area2D

signal throttle_changed(level: int, normalized: float)

@export var max_level: int = 7
@export var invert_frames: bool = true

@export var glow_when_active: Color = Color(1.3, 1.3, 1.3)

@onready var tempIcon: Sprite2D = $visibleIcon
@onready var detailedIcon: Sprite2D = $detailedIcon

var level: int = 0
var active: bool = false
var hovered: bool = false

func _ready() -> void:
	tempIcon.visible = true
	detailedIcon.visible = false
	detailedIcon.frame = 7
	tempIcon.frame = 7

func _get_camera() -> Camera2D:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("set_target"):
		return cam
	return null

func _on_mouse_entered() -> void:
	hovered = true
	_refresh()
	
	if active:
		var cam = _get_camera()
		cam.push_target(detailedIcon, cam.control_zoom, true)
	
func _on_mouse_exited() -> void:
	hovered = false
	_refresh()
	
	if active:
		var cam = _get_camera()
		cam.pop_target()
	
func set_active(value: bool) -> void:
	active = value
	if not active:
		hovered = false
	_refresh()

func _refresh() -> void:
	detailedIcon.visible = active and hovered
	tempIcon.visible = not detailedIcon.visible
	detailedIcon.modulate = glow_when_active if active else Color.WHITE

func _on_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:

	if not active or not (event is InputEventMouseButton) or not event.pressed:
		return
		
	
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_set_level(level + 1)
		MOUSE_BUTTON_RIGHT:
			_set_level(level - 1)
		MOUSE_BUTTON_WHEEL_UP:
			_set_level(level + 1)
		MOUSE_BUTTON_WHEEL_DOWN:
			_set_level(level - 1)
			
func _set_level(value: int) -> void:
	var new_level: int = clampi(value, 0, max_level)
	if new_level == level:
		return
	level = new_level
	
	detailedIcon.frame = (max_level - level) if invert_frames else level
	tempIcon.frame = detailedIcon.frame
	throttle_changed.emit(level, float(level) / float(max_level))
