extends Area2D

@export_enum("Left:0", "Straight:1", "Right:2") var direction: int = 1
@export var glow_when_active: Color = Color(1.3, 1.3, 1.3)
@export var selected_color: Color = Color(1.6, 1.6, 0.9)
@export var unavailable_color: Color = Color(0.45, 0.45, 0.45)

@onready var tempIcon: Sprite2D = $visibleIcon
@onready var detailedIcon: Sprite2D = $detailedIcon

var panel: Node = null
var active: bool = false
var hovered: bool = false
var selected: bool = false
var available: bool = true
var _pushed: bool = false

func _ready() -> void:
	tempIcon.visible = true
	detailedIcon.visible = false
	_refresh()

func _get_camera() -> Camera2D:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("set_target"):
		return cam
	return null

func _push_cam() -> void:
	if _pushed:
		return
	var cam := _get_camera()
	if cam:
		cam.push_target(detailedIcon, cam.control_zoom, true)
		_pushed = true

func _pop_cam() -> void:
	if not _pushed:
		return
	_pushed = false
	var cam := _get_camera()
	if cam:
		cam.pop_target()

func _on_mouse_entered() -> void:
	if not active:
		return
	hovered = true
	_refresh()
	_push_cam()

func _on_mouse_exited() -> void:
	hovered = false
	_refresh()
	_pop_cam()

func set_active(value: bool) -> void:
	active = value
	if not active:
		hovered = false
		_pop_cam()
	_refresh()

func set_selected(value: bool) -> void:
	selected = value
	_refresh()

func set_available(value: bool) -> void:
	available = value
	_refresh()

func _refresh() -> void:
	detailedIcon.visible = active and hovered
	tempIcon.visible = not detailedIcon.visible

	var tint: Color
	if selected:
		tint = selected_color
	elif not available:
		tint = unavailable_color
	elif active:
		tint = glow_when_active
	else:
		tint = Color.WHITE

	detailedIcon.modulate = tint
	tempIcon.modulate = tint

func _on_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if not active or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT and panel:
		panel.select(direction)
		get_viewport().set_input_as_handled()
