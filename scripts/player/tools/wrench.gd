extends Node2D

@export var damage: int = 18
@export var swing_arc_deg: float = 130.0
@export var swing_time: float = 0.22
@export var recover_time: float = 0.18
@export var cooldown: float = 0.15
@export_flags_2d_physics var wall_mask: int = 1

@onready var wrench_sprite: Sprite2D = $Wrench
@onready var hit_area: Area2D = $Area2D

var firing: bool = false
var _swinging: bool = false
var _cooldown: float = 0.0
var _hit_this_swing: Array = []
var _rest_rotation: float = 0.0

func _ready() -> void:
	_rest_rotation = wrench_sprite.rotation
	hit_area.monitoring = false

func set_firing(value: bool) -> void:
	firing = value

func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if firing and not _swinging and _cooldown <= 0.0:
		_swing()

func _swing() -> void:
	_swinging = true
	_hit_this_swing.clear()

	var half: float = deg_to_rad(swing_arc_deg) * 0.5
	_set_swing_angle(_rest_rotation - half)
	hit_area.monitoring = true

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_swing_angle, _rest_rotation - half, _rest_rotation + half, swing_time)
	tween.tween_callback(func(): hit_area.monitoring = false)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_swing_angle, _rest_rotation + half, _rest_rotation, recover_time)
	tween.tween_callback(func():
		_swinging = false
		_cooldown = cooldown
	)

func _set_swing_angle(angle: float) -> void:
	wrench_sprite.rotation = angle
	hit_area.rotation = angle
	if not hit_area.monitoring:
		return
	for body in hit_area.get_overlapping_bodies():
		_try_hit(body)

func _try_hit(body: Node) -> void:
	if _hit_this_swing.has(body) or not is_instance_valid(body):
		return
	if not body.is_in_group("enemy") or not body.has_method("take_damage"):
		return
	if not _has_los(body):
		return
	_hit_this_swing.append(body)
	body.take_damage(damage, global_position)

func _has_los(target: Node2D) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, target.global_position, wall_mask
	)
	query.collide_with_areas = false
	return space.intersect_ray(query).is_empty()
