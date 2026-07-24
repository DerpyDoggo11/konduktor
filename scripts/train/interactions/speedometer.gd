extends Area2D

@export var train_path: NodePath
@export var frame_count: int = 14
@export var invert_frames: bool = false
@export var needle_smoothing: float = 6.0

@onready var tempGauge: Sprite2D = $visibleSpeedometer
@onready var detailedGauge: Sprite2D = $detailedSpeedometer

var target_ratio: float = 0.0
var displayed_ratio: float = 0.0

var level: int = 0
var active: bool = false
var hovered: bool = false

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
		cam.push_target(detailedGauge, cam.control_zoom, true)
	
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
	detailedGauge.visible = active and hovered
	tempGauge.visible = not detailedGauge.visible

func _ready() -> void:
	_apply_frame()
	tempGauge.visible = true
	detailedGauge.visible = false
	detailedGauge.frame = 0

	var train := get_node_or_null(train_path)
	if train == null:
		train = get_parent()
	if train and train.has_signal("speed_changed"):
		train.speed_changed.connect(_on_speed_changed)

func _on_speed_changed(_speed_ms: float, normalized: float) -> void:
	target_ratio = normalized

func _process(delta: float) -> void:
	displayed_ratio = lerpf(
		displayed_ratio,
		target_ratio,
		1.0 - exp(-needle_smoothing * delta)
	)
	_apply_frame()

func _apply_frame() -> void:
	var idx: int = int(round(displayed_ratio * (frame_count - 1)))
	idx = clampi(idx, 0, frame_count - 1)
	detailedGauge.frame = (frame_count - 1 - idx) if invert_frames else idx
