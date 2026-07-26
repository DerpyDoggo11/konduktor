extends Area2D

signal brake_changed(level: int, normalized: float)

@export var max_level: int = 7
@export var invert_frames: bool = true
@export var glow_when_active: Color = Color(1.3, 1.3, 1.3)

@onready var tempIcon: Sprite2D = $visibleIcon
@onready var detailedIcon: Sprite2D = $detailedIcon

@export var brake_sound: AudioStream

var _playback: AudioStreamPlaybackPolyphonic

func _ready() -> void:
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = 8
	$AudioStreamPlayer2D.stream = poly
	$AudioStreamPlayer2D.play()
	_playback = $AudioStreamPlayer2D.get_stream_playback()
	tempIcon.visible = true
	detailedIcon.visible = false
	_apply_frames()

var level: int = 7
var active: bool = false
var hovered: bool = false
var _pushed: bool = false

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
	#_push_cam()

func _on_mouse_exited() -> void:
	hovered = false
	_refresh()
	#_pop_cam()

func set_active(value: bool) -> void:
	active = value
	if not active:
		hovered = false
		_pop_cam()
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
			_set_level(level - 1)
		MOUSE_BUTTON_RIGHT:
			_set_level(level + 1)
		MOUSE_BUTTON_WHEEL_UP:
			_set_level(level - 1)
		MOUSE_BUTTON_WHEEL_DOWN:
			_set_level(level + 1)

func _set_level(value: int) -> void:
	var new_level: int = clampi(value, 0, max_level)
	if new_level == level:
		return
	level = new_level
	_apply_frames()
	_playback.play_stream(brake_sound, 0.0, 0.0, pow(2.0, -level * 2.0 / 30.0))
	brake_changed.emit(level, float(level) / float(max_level))


func _apply_frames() -> void:
	detailedIcon.frame = (max_level - level) if invert_frames else level
	tempIcon.frame = detailedIcon.frame
