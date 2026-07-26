extends Area2D

signal throttle_changed(level: int, normalized: float)

const MIN_LEVEL := 2
const SEMITONES_PER_LEVEL := 2.0

@export var max_level: int = 7
@export var invert_frames: bool = true
@export var glow_when_active: Color = Color(1.3, 1.3, 1.3)
@export var brake_sound: AudioStream

@onready var tempIcon: Sprite2D = $visibleIcon
@onready var detailedIcon: Sprite2D = $detailedIcon

var _playback: AudioStreamPlaybackPolyphonic
var level: int = MIN_LEVEL
var active: bool = false
var hovered: bool = false


func _ready() -> void:
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = 8  # max simultaneous voices
	$AudioStreamPlayer2D.stream = poly
	$AudioStreamPlayer2D.play()
	_playback = $AudioStreamPlayer2D.get_stream_playback()

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

	#if active:
		#var cam = _get_camera()
		#cam.push_target(detailedIcon, cam.control_zoom, true)


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
	var new_level: int = clampi(value, MIN_LEVEL, max_level)
	if new_level == level:
		return
	level = new_level

	detailedIcon.frame = (max_level - level) if invert_frames else level
	tempIcon.frame = detailedIcon.frame

	if brake_sound:
		var steps := float(level - MIN_LEVEL)
		var pitch := pow(2.0, (steps * SEMITONES_PER_LEVEL) / 12.0)
		_playback.play_stream(brake_sound, 0.0, 0.0, pitch)

	throttle_changed.emit(level, float(level) / float(max_level))
