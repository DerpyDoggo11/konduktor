extends Area2D

@export var speed: float = 260.0
@export var lifetime: float = 0.42
@export var damage: int = 5
@export var reveal_delay: float = 0.06
@export var start_scale: float = 0.55
@export var end_scale: float = 1.6
@export var spread_deg: float = 9.0
@export var drift: float = 40.0 
@export_flags_2d_physics var wall_mask: int = 3

@onready var sprite: Sprite2D = $Sprite2D

var direction: Vector2 = Vector2.UP
var shooter: Node = null

var _age: float = 0.0
var _drift_dir: float = 1.0
var _dead: bool = false

func setup(from: Vector2, dir: Vector2, owner_node: Node) -> void:
	global_position = from
	direction = dir.normalized().rotated(deg_to_rad(randf_range(-spread_deg, spread_deg)))
	shooter = owner_node
	_drift_dir = 1.0 if randf() < 0.5 else -1.0
	sprite.rotation = direction.angle() + deg_to_rad(90)

func _ready() -> void:
	top_level = true
	visible = false
	monitoring = true
	sprite.scale = Vector2.ONE * start_scale
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _dead:
		return

	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	if not visible and _age >= reveal_delay:
		visible = true

	var t: float = _age / lifetime
	sprite.scale = Vector2.ONE * lerpf(start_scale, end_scale, t)
	sprite.modulate.a = 1.0 - (t * t) 

	var perpendicular: Vector2 = direction.orthogonal() * _drift_dir * drift * t
	var step: Vector2 = (direction * speed + perpendicular) * delta
	if step.length_squared() > 0.01:
		sprite.rotation = step.angle() + deg_to_rad(180)
		
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + step, wall_mask
	)
	query.collide_with_areas = false
	if shooter:
		query.exclude = [shooter]
	var hit := space.intersect_ray(query)

	if not hit.is_empty():
		global_position = hit["position"]
		_extinguish()
		return

	global_position += step

func _on_body_entered(body: Node) -> void:
	if _dead or body == shooter:
		return
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage, global_position)
		_extinguish()
	elif body is StaticBody2D or body is TileMapLayer or body is RigidBody2D:
		_extinguish()

func _extinguish() -> void:
	if _dead:
		return
	_dead = true
	monitoring = false
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.08)
	tween.tween_callback(queue_free)
