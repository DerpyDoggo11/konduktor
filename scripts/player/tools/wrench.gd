extends Node2D

@export var damage: int = 30
@export var swing_arc_deg: float = 60.0
@export var swing_time: float = 0.10
@export var recover_time: float = 0.16
@export var cooldown: float = 0.08

@export var arc_variance_deg: float = 25.0
@export var aim_variance_deg: float = 12.0
@export var time_variance: float = 0.25
@export var damage_variance: float = 0.5
@export var overshoot: float = 0.12

@onready var wrench_sprite: Sprite2D = $Wrench
@onready var hit_area: Area2D = $Area2D

var firing: bool = false
var ownerPlayer: Node = null

var _swinging: bool = false
var _cooldown: float = 0.0
var _hit_this_swing: Array = []
var _rest_rotation: float = 0.0
var _swing_sign: float = 1.0

func _ready() -> void:
	_rest_rotation = rotation
	hit_area.monitoring = false
	ownerPlayer = _find_owner()

func _find_owner() -> Node:
	var n: Node = self
	while n:
		if n.has_method("consume_fuel"):
			return n
		n = n.get_parent()
	return null

func set_firing(value: bool) -> void:
	firing = value

func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if firing and not _swinging and _cooldown <= 0.0:
		_swing()
	if hit_area.monitoring:
		for body in hit_area.get_overlapping_bodies():
			_try_hit(body)

func _set_swing_angle(angle: float) -> void:
	rotation = angle

func _swing() -> void:
	_swinging = true
	_hit_this_swing.clear()

	if randf() < 0.65:
		_swing_sign = -_swing_sign
	else:
		_swing_sign = 1.0 if randf() < 0.5 else -1.0

	var arc: float = deg_to_rad(swing_arc_deg + randf_range(-arc_variance_deg, arc_variance_deg))
	var aim: float = _rest_rotation + deg_to_rad(randf_range(-aim_variance_deg, aim_variance_deg))
	var half: float = arc * 0.5

	var start_a: float = aim - half * _swing_sign
	var end_a: float = aim + half * _swing_sign
	var past: float = end_a + (arc * overshoot * _swing_sign)

	var st: float = swing_time * randf_range(1.0 - time_variance, 1.0 + time_variance)
	var rt: float = recover_time * randf_range(1.0 - time_variance, 1.0 + time_variance)

	_set_swing_angle(start_a)
	hit_area.set_deferred("monitoring", true)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_swing_angle, start_a, past, st)
	tween.tween_callback(func(): hit_area.monitoring = false)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_swing_angle, past, _rest_rotation, rt)
	tween.tween_callback(func():
		_swinging = false
		_cooldown = cooldown * randf_range(0.8, 1.3)
	)

func _try_hit(body: Node) -> void:
	if _hit_this_swing.has(body) or not is_instance_valid(body):
		return

	if body.is_in_group("door") and body.has_method("repair"):
		if body.needs_repair():
			_hit_this_swing.append(body)
			body.repair()
		return

	if not body.is_in_group("enemy") or not body.has_method("take_damage"):
		return
	if not _has_los(body):
		return

	_hit_this_swing.append(body)
	var dmg: int = int(round(damage * randf_range(1.0 - damage_variance, 1.0 + damage_variance)))
	body.take_damage(dmg, global_position)

func _has_los(target: Node2D) -> bool:
	var from: Vector2 = ownerPlayer.global_position if ownerPlayer else global_position
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, target.global_position)
	query.collide_with_areas = false

	var skip: Array = [target.get_rid()]
	if ownerPlayer:
		skip.append(ownerPlayer.get_rid())
	query.exclude = skip

	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	return not (hit.get("collider") is RigidBody2D)
