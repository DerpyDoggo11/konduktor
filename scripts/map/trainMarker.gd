extends Node2D

signal segment_changed(segment: TrackSegment)
signal dead_end_reached()

@export var start_segment: NodePath
@export var pixels_per_meter: float = 16.0
@export var align_to_track: bool = true

var segment: TrackSegment = null
var dist_px: float = 0.0
var speed_ms: float = 0.0
var switch_panel: Node = null
var _blocked: bool = false

func _ready() -> void:
	add_to_group("train_marker")

	segment = get_node_or_null(start_segment) as TrackSegment

	var train := get_tree().get_first_node_in_group("train")
	if train and train.has_signal("speed_changed"):
		train.speed_changed.connect(_on_speed_changed)

	switch_panel = get_tree().get_first_node_in_group("switch_panel")

	_snap()
	if segment:
		segment_changed.emit(segment)

func _on_speed_changed(speed: float, _n: float) -> void:
	speed_ms = speed

func _physics_process(delta: float) -> void:
	if segment == null or segment.curve == null:
		return

	dist_px += speed_ms * pixels_per_meter * delta

	var length: float = segment.curve.get_baked_length()
	while dist_px >= length:
		var dir: int = TrackSegment.Dir.STRAIGHT
		if switch_panel:
			dir = switch_panel.selected

		var next := segment.get_exit(dir)
		if next == null or next.curve == null:
			dist_px = length
			if not _blocked:
				_blocked = true
				dead_end_reached.emit()
			break

		dist_px -= length
		segment = next
		length = segment.curve.get_baked_length()
		_blocked = false
		segment_changed.emit(segment)

	_snap()

func _snap() -> void:
	if segment == null or segment.curve == null:
		return
	var curve := segment.curve
	var d: float = clampf(dist_px, 0.0, curve.get_baked_length())
	global_position = segment.to_global(curve.sample_baked(d))

	if align_to_track:
		var ahead: float = minf(d + 4.0, curve.get_baked_length())
		var behind: float = maxf(d - 4.0, 0.0)
		var p_a: Vector2 = segment.to_global(curve.sample_baked(ahead))
		var p_b: Vector2 = segment.to_global(curve.sample_baked(behind))
		if p_a.distance_squared_to(p_b) > 0.01:
			global_rotation = (p_a - p_b).angle() + deg_to_rad(90)
