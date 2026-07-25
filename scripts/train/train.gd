extends Node2D

signal speed_changed(speed_ms: float, normalized: float)
signal rpm_changed(rpm: float)
signal segment_changed(segment: TrackSegment)
signal dead_end_reached()

signal junction_approaching(good_dirs: Array, bad_dirs: Array)
signal junction_cleared()

signal fuel_changed(fuel: float, normalized: float)

@export var junction_warn_px: float = 1200.0

var _warned: bool = false

# engine
@export var idle_rpm: float = 300.0
@export var max_rpm: float = 1800.0
@export var rpm_spool_rate: float = 400.0
@export var max_tractive_force: float = 220000.0
@export var mass: float = 180000.0
@export var max_speed_ms: float = 10.0

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

@onready var throttle: Area2D = $FrontTrainCart/Throttle
@onready var brake: Area2D = $FrontTrainCart/brake
@onready var speedometer: Area2D = $FrontTrainCart/speedometer
@onready var map: Area2D = $FrontTrainCart/map
@onready var switchPanel: Node2D = $FrontTrainCart/SwitchPanel


@export var max_fuel: float = 500.0
@export var idle_burn: float = 0.4
@export var full_burn: float = 6.0

var fuel: float
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
var _back_riders: Array = []

@export var coupling_px: float = 220.0
@export var back_cart_path: NodePath

@onready var back_cart: Node2D = get_node_or_null(back_cart_path)

var _history: Array = []

func _ready() -> void:
	add_to_group("train")
	add_to_group("train_marker")
	
	fuel = max_fuel
	
	throttle.throttle_changed.connect(_on_throttle_changed)
	brake.brake_changed.connect(_on_brake_changed)

	throttle.set_active(false)
	brake.set_active(false)
	speedometer.set_active(false)
	#map.set_active(false)
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
		_history = [segment]
		segment_changed.emit(segment)

	if back_cart:
		coupling_px = global_position.distance_to(back_cart.global_position)
		back_cart.top_level = true

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
	
	var burn: float = lerpf(idle_burn, full_burn, throttle_normalized) * delta
	var used: float = minf(burn, fuel)
	fuel -= used
	fuel_changed.emit(fuel, fuel / max_fuel)

	var has_fuel: bool = used >= burn * 0.99
	if not has_fuel:
		rpm = move_toward(rpm, 0.0, rpm_spool_rate * delta)
		
	var rpm_fraction: float = inverse_lerp(idle_rpm, max_rpm, rpm)
	var speed_falloff: float = 1.0 / (1.0 + speed_ms * 0.06)
	var tractive: float = max_tractive_force * rpm_fraction * speed_falloff
	if not has_fuel:
		tractive = 0.0
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
	
func add_fuel(amount: float) -> float:
	var space: float = max_fuel - fuel
	var taken: float = minf(amount, space)
	fuel += taken
	fuel_changed.emit(fuel, fuel / max_fuel)
	return taken
	
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
		_history.append(segment)
		if _history.size() > 8:
			_history.pop_front()
		length = segment.curve.get_baked_length()
		_blocked = false
		segment_changed.emit(segment)
	
	var remaining: float = segment.curve.get_baked_length() - dist_px
	var has_choice: bool = (
		segment.has_exit(TrackSegment.Dir.LEFT)
		or segment.has_exit(TrackSegment.Dir.RIGHT)
	)
	
	if has_choice and remaining <= junction_warn_px:
		if not _warned:
			_warned = true
			var good: Array = []
			var bad: Array = []
			for d in [TrackSegment.Dir.LEFT, TrackSegment.Dir.STRAIGHT, TrackSegment.Dir.RIGHT]:
				if not segment.has_exit(d):
					continue
				var next: TrackSegment = segment.get_exit(d)
				if next != null and not next.all_exits().is_empty():
					good.append(d)
				else:
					bad.append(d)
			junction_approaching.emit(good, bad)
	elif _warned:
		_warned = false
		junction_cleared.emit()
		
	_snap()
	_update_back_cart(delta)
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
		
		
@export var heading_sample_px: float = 24.0
@export var rotation_smoothing: float = 12.0

func _snap(delta: float = 0.0) -> void:
	if segment == null or segment.curve == null:
		return
	var curve := segment.curve
	var length: float = curve.get_baked_length()
	var d: float = clampf(dist_px, 0.0, length)
	global_position = segment.to_global(curve.sample_baked(d))

	if not align_to_track:
		return

	var ahead: float = minf(d + heading_sample_px, length)
	var behind: float = maxf(d - heading_sample_px, 0.0)
	var p_a: Vector2 = segment.to_global(curve.sample_baked(ahead))
	var p_b: Vector2 = segment.to_global(curve.sample_baked(behind))
	if p_a.distance_squared_to(p_b) <= 0.01:
		return

	var want: float = (p_a - p_b).angle() + deg_to_rad(90)
	if delta <= 0.0 or rotation_smoothing <= 0.0:
		global_rotation = want
	else:
		global_rotation = lerp_angle(global_rotation, want, 1.0 - exp(-rotation_smoothing * delta))

func _carry_bodies(list: Array, move: Vector2, turn: float, pivot: Vector2) -> void:
	if move == Vector2.ZERO and is_zero_approx(turn):
		return
	for body in list:
		if not is_instance_valid(body):
			continue
		if body.get("seated") == true:
			continue
		var offset: Vector2 = body.global_position - pivot
		body.global_position = pivot + offset.rotated(turn) + move

func _carry_riders(move: Vector2, turn: float, pivot: Vector2) -> void:
	_carry_bodies(_riders, move, turn, pivot)

	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("carry"):
		cam.carry(move)

func _on_ride_entered(body: Node) -> void:
	if body.is_in_group("player") and not _riders.has(body):
		_riders.append(body)

func _on_ride_exited(body: Node) -> void:
	_riders.erase(body)

func _update_back_cart(delta: float) -> void:
	if back_cart == null or segment == null:
		return
		
	var prev_pos: Vector2 = back_cart.global_position
	var prev_rot: float = back_cart.global_rotation

	var back: float = coupling_px
	var idx: int = _history.size() - 1
	var d: float = dist_px

	while back > d and idx > 0:
		back -= d
		idx -= 1
		d = _history[idx].curve.get_baked_length()

	var seg: TrackSegment = _history[idx]
	var seg_len: float = seg.curve.get_baked_length()
	var at: float = d - back

	if at < 0.0 and idx == 0:
		var p0: Vector2 = seg.to_global(seg.curve.sample_baked(0.0))
		var p1: Vector2 = seg.to_global(seg.curve.sample_baked(minf(heading_sample_px, seg_len)))
		var dir_v: Vector2 = (p1 - p0).normalized()
		back_cart.global_position = p0 - dir_v * absf(at)
		back_cart.global_rotation = dir_v.angle() + deg_to_rad(90)
		_carry_bodies(_back_riders,
			back_cart.global_position - prev_pos,
			back_cart.global_rotation - prev_rot,
			prev_pos)
		return

	at = clampf(at, 0.0, seg_len)
	back_cart.global_position = seg.to_global(seg.curve.sample_baked(at))

	var length: float = seg.curve.get_baked_length()
	var ahead: float = minf(at + heading_sample_px, length)
	var behind: float = maxf(at - heading_sample_px, 0.0)
	var p_a: Vector2 = seg.to_global(seg.curve.sample_baked(ahead))
	var p_b: Vector2 = seg.to_global(seg.curve.sample_baked(behind))

	if p_a.distance_squared_to(p_b) > 0.01:
		var want: float = (p_a - p_b).angle() + deg_to_rad(90)
		if delta <= 0.0 or rotation_smoothing <= 0.0:
			back_cart.global_rotation = want
		else:
			back_cart.global_rotation = lerp_angle(
				back_cart.global_rotation, want, 1.0 - exp(-rotation_smoothing * delta)
			)

	_carry_bodies(_back_riders,
		back_cart.global_position - prev_pos,
		back_cart.global_rotation - prev_rot,
		prev_pos)

func _on_back_ride_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _back_riders.has(body):
		_back_riders.append(body)


func _on_back_ride_area_body_exited(body: Node2D) -> void:
	_back_riders.erase(body)
