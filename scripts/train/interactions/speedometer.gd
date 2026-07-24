extends Area2D

@export var train_path: NodePath
@export var frame_count: int = 14
@export var invert_frames: bool = false
@export var needle_smoothing: float = 6.0

@onready var gauge: Sprite2D = $Sprite2D

var target_ratio: float = 0.0
var displayed_ratio: float = 0.0

var level: int = 0
var active: bool = false
var hovered: bool = false

func _on_mouse_entered() -> void:
	hovered = true
	_refresh()
	
func _on_mouse_exited() -> void:
	hovered = false
	_refresh()
	
func set_active(value: bool) -> void:
	active = value
	if not active:
		hovered = false
	_refresh()
	
func _refresh() -> void:
	gauge.visible = active and hovered

func _ready() -> void:
	_apply_frame()
	
	gauge.visible = false
	gauge.frame = 0

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
	gauge.frame = (frame_count - 1 - idx) if invert_frames else idx
