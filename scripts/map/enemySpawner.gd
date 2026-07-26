extends Node2D

@export var zombie_scene: PackedScene
@export var spawn_interval: float = 3.0
@export var min_spawn_interval: float = 2
@export var max_alive: int = 100
@export var min_distance: float = 500.0
@export var max_distance: float = 1400.0
@export var enabled: bool = true

@export var ramp_seconds: float = 60.0
@export var max_difficulty: float = 3.5

var _points: Array = []
var _timer: float = 0.0
var _alive: Array = []
var _elapsed: float = 0.0

func _ready() -> void:
	for c in get_children():
		if c is Marker2D:
			_points.append(c)
	if _points.is_empty():
		push_warning("enemy spawner: no Marker2D children")

func difficulty() -> float:
	return lerpf(1.0, max_difficulty, clampf(_elapsed / ramp_seconds, 0.0, 1.0))

func _pick_kind() -> int:
	var t: float = clampf(_elapsed / ramp_seconds, 0.0, 1.0)
	var roll: float = randf()
	var explosive_chance: float = lerpf(0.0, 0.3, clampf((t - 0.15) / 0.5, 0.0, 1.0))
	var strong_chance: float = lerpf(0.0, 0.28, clampf((t - 0.35) / 0.5, 0.0, 1.0))

	if roll < explosive_chance:
		return 1 
	if roll < explosive_chance + strong_chance:
		return 2
	return 0

func _physics_process(delta: float) -> void:
	if not enabled or zombie_scene == null or _points.is_empty():
		return

	_elapsed += delta

	_alive = _alive.filter(func(z): return is_instance_valid(z))
	if _alive.size() >= max_alive:
		return

	_timer -= delta
	if _timer > 0.0:
		return

	var t: float = clampf(_elapsed / ramp_seconds, 0.0, 1.0)
	_timer = lerpf(spawn_interval, min_spawn_interval, t)

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var candidates: Array = []
	for p in _points:
		var d: float = p.global_position.distance_to(player.global_position)
		if d >= min_distance and d <= max_distance:
			candidates.append(p)

	if candidates.is_empty():
		return

	var point: Marker2D = candidates.pick_random()
	var zombie = zombie_scene.instantiate()
	get_parent().add_child(zombie)
	zombie.global_position = point.global_position
	zombie.configure(_pick_kind(), difficulty())
	_alive.append(zombie)
