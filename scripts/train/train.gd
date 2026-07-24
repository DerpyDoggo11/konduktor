extends Node2D

signal speed_changed(speed_ms: float, normalized: float)
signal rpm_changed(rpm: float)
signal segment_changed(segment: TrackSegment)
signal dead_end_reached()

# engine
@export var idle_rpm: float = 300.0
@export var max_rpm: float = 1800.0
@export var rpm_spool_rate: float = 400.0
@export var max_tractive_force: float = 220000.0
@export var mass: float = 180000.0
@export var max_speed_ms: float = 20.0

# resistance
@export var rolling_a: float = 2000.0
@export var rolling_b: float = 300.0
@export var drag_c: float = 45.0

# braking
@export var brake_force: float = 900000.0
@export var brake_cuts_power: bool = true

# track
@export var start_segment_path: NodePath = ^"/root/Main/map/Track/seg_a"
@export var pixels_per_meter: float = 16.0
@export var align_to_track: bool = true
@export var ride_area_path: NodePath

@onready var throttle: Area2D = $Throttle
@onready var brake: Area2D = $brake
@onready var speedometer: Area2D = $speedometer
@onready var map: Area2D = $map
@onready var switchPanel: Node2D = $SwitchPanel

var throttle_level: int = 0
var throttle_normalized: float = 0.0
var brake_level: int = 0
var brake_normalized: float = 0.0

var rpm: float = 0.0
var speed_ms: float = 0.0
var distance_m: float = 0.0

var segment: TrackSegment = null
var dist_px: float = 0.0
var _blocked: bool = false
var _riders: Array = []

func _ready() -> void:
	add_to_group("train")
	add_to_group("train_marker")

	throttle.throttle_changed.connect(_on_throttle_changed)
	brake.brake_changed.connect(_on_brake_changed)

	throttle.set_active(false)
	brake.set_active(false)
	speedometer.set_active(false)
	map.set_active(false)
	switchPanel.set_active(false)

	rpm = idle_rpm

	var ride := get_node_or_null(ride_area_path) as Area2D
	if ride:
		ride.body_entered.connect(_on_ride_entered)
		ride.body_exited.connect(_on_ride_exited)

	await get_tree().process_frame
	segment = get_node_or_null(start_segment_path) as TrackSegment
	if segment == null:
		push_error("start segment not found at %s" % start_segment_path)
	_snap()
	if segment:
		segment_changed.emit(segment)

func _on_throttle_changed(level: int, normalized: float) -> void:
	throttle_level = level
	throttle_normalized = normalized

func _on_brake_changed(level: int, normalized: float) -> void:
	brake_level = level
	brake_normalized = normalized

func _physics_process(delta: float) -> void:
	_update_physics(delta)
	_advance_track(delta)

func _update_physics(delta: float) -> void:
	var target_rpm: float = lerpf(idle_rpm, max_rpm, throttle_normalized)
	rpm = move_toward(rpm, target_rpm, rpm_spool_rate * delta)

	var rpm_fraction: float = inverse_lerp(idle_rpm, max_rpm, rpm)
	var speed_falloff: float = 1.0 / (1.0 + speed_ms * 0.06)
	var tractive: float = max_tractive_force * rpm_fraction * speed_falloff
	if brake_cuts_power and brake_normalized > 0.0:
		tractive *= 1.0 - brake_normalized

	var resistance: float = rolling_a + rolling_b * speed_ms + drag_c * speed_ms * speed_ms
	if speed_ms <= 0.01:
		resistance = 0.0

	var braking: float = brake_force * brake_normalized
	var max_stopping: float = (speed_ms * mass) / delta
	braking = minf(braking, max_stopping)

	var net_force: float = tractive - resistance - braking
	var accel: float = net_force / mass

	speed_ms = maxf(0.0, speed_ms + accel * delta)
	distance_m += speed_ms * delta

	speed_changed.emit(speed_ms, clampf(speed_ms / max_speed_ms, 0.0, 1.0))
	rpm_changed.emit(rpm)

func _advance_track(delta: float) -> void:
	if segment == null or segment.curve == null:
		return

	var prev_pos: Vector2 = global_position
	var prev_rot: float = global_rotation

	dist_px += speed_ms * pixels_per_meter * delta

	var length: float = segment.curve.get_baked_length()
	while dist_px >= length:
		var dir: int = switchPanel.selected

		var next := segment.get_exit(dir)
		if next == null or next.curve == null:
			dist_px = length
			if not _blocked:
				_blocked = true
				_crash()
			break

		dist_px -= length
		segment = next
		length = segment.curve.get_baked_length()
		_blocked = false
		segment_changed.emit(segment)

	_snap()
	_carry_riders(global_position - prev_pos, global_rotation - prev_rot, prev_pos)

@export var crash_speed_ms: float = 3.0

func _crash() -> void:
	dead_end_reached.emit()

	if speed_ms < crash_speed_ms:
		speed_ms = 0.0
		throttle_normalized = 0.0
		return

	speed_ms = 0.0
	throttle_normalized = 0.0
	set_physics_process(false)

	var gameOver := get_tree().get_first_node_in_group("gameOver")
	if gameOver:
		gameOver.show_game_over("Stay on track, your train hit a barrier")
		
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

func _carry_riders(move: Vector2, turn: float, pivot: Vector2) -> void:
	if move == Vector2.ZERO and is_zero_approx(turn):
		return
	for body in _riders:
		if not is_instance_valid(body):
			continue
		if body.get("seated") == true:
			continue
		var offset: Vector2 = body.global_position - pivot
		body.global_position = pivot + offset.rotated(turn) + move

func _on_ride_entered(body: Node) -> void:
	if body.is_in_group("player") and not _riders.has(body):
		_riders.append(body)

func _on_ride_exited(body: Node) -> void:
	_riders.erase(body)
