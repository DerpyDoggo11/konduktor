class_name TrackSegment
extends Path2D

enum Dir { LEFT, STRAIGHT, RIGHT }

@export var exits: Array[NodePath] = []
@export var straight_tolerance_deg: float = 25.0

var _by_dir: Dictionary = {}

func _ready() -> void:
	classify_exits()

func classify_exits() -> void:
	_by_dir.clear()
	if curve == null or curve.point_count < 2:
		return

	var arrive: float = heading_at_end()
	var best_straight: float = INF

	for p in exits:
		var seg := get_node_or_null(p) as TrackSegment
		if seg == null or seg.curve == null or seg.curve.point_count < 2:
			continue

		var turn: float = angle_difference(arrive, seg.heading_at_start())
		var turn_abs: float = absf(turn)

		if turn_abs <= deg_to_rad(straight_tolerance_deg):
			if turn_abs < best_straight:
				best_straight = turn_abs
				_by_dir[Dir.STRAIGHT] = seg
		elif turn < 0.0:
			_by_dir[Dir.LEFT] = seg
		else:
			_by_dir[Dir.RIGHT] = seg

func get_exit(dir: int) -> TrackSegment:
	if _by_dir.has(dir):
		return _by_dir[dir]
	return _by_dir.get(Dir.STRAIGHT, null)

func has_exit(dir: int) -> bool:
	return _by_dir.has(dir)

func heading_at_start() -> float:
	return _heading_at(0.0)

func heading_at_end() -> float:
	return _heading_at(curve.get_baked_length())

func _heading_at(d: float) -> float:
	var length: float = curve.get_baked_length()
	var a: float = clampf(d - 4.0, 0.0, length)
	var b: float = clampf(d + 4.0, 0.0, length)
	var p_a: Vector2 = to_global(curve.sample_baked(a))
	var p_b: Vector2 = to_global(curve.sample_baked(b))
	return (p_b - p_a).angle()
