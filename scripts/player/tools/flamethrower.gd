extends Node2D

@export var flameColliderMaxLength: float = 90.0
@export var flameColliderWidth: float = 30.0
@export var flameGrowSpeed: float = 4.0
@export var flameDamage: int = 5
@export var flameDamageInterval: float = 0.1
@export var fuelPerSecond: float = 9.0
@export var frameCount: int = 13
@export var invertFrames: bool = false
@export var particleAngleOffset: float = 270.0
@export_flags_2d_physics var wall_mask: int = 1

@export var particleSpeed: float = 300.0 
@export var wallMargin: float = 6.0

var _reach: float = 0.0

var firing: bool = false
var flameIntensity: float = 0.0
var flameDamageTimer: float = 0.0
var bodiesInFlames: Array = []
var ownerPlayer: Node = null
var _shape: RectangleShape2D


@onready var sprite: Sprite2D = $Sprite2D
@onready var nozzle: Marker2D = $nozzle
@onready var flameCollider: CollisionShape2D = $Flames/CollisionShape2D
@onready var flameArea: Area2D = $Flames
@onready var flameParticles: CPUParticles2D = $Flames/FlameParticles

func _ready() -> void:
	sprite.hframes = frameCount
	sprite.vframes = 1

	_shape = flameCollider.shape.duplicate()
	flameCollider.shape = _shape

	flameArea.monitoring = false
	flameParticles.emitting = false
	_apply_flame_intensity(0.0)

	ownerPlayer = _find_owner()
	if ownerPlayer and ownerPlayer.has_signal("fuel_changed"):
		ownerPlayer.fuel_changed.connect(_on_fuel_changed)
		_on_fuel_changed(ownerPlayer.fuel, ownerPlayer.fuel / ownerPlayer.max_fuel)

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
	var wants: bool = firing
	if wants and ownerPlayer:
		var needed: float = fuelPerSecond * delta
		if ownerPlayer.consume_fuel(needed) < needed * 0.99:
			wants = false

	var intensityTarget: float = 1.0 if wants else 0.0
	flameIntensity = move_toward(flameIntensity, intensityTarget, delta * flameGrowSpeed)
	_reach = _wall_distance()
	_apply_flame_intensity(flameIntensity)

	flameParticles.emitting = wants
	flameArea.monitoring = flameIntensity > 0.05

	if flameIntensity > 0.05:
		var flame_deg: float = (rad_to_deg(global_rotation) * -1) + particleAngleOffset
		flameParticles.angle_min = flame_deg
		flameParticles.angle_max = flame_deg

		flameDamageTimer -= delta
		if flameDamageTimer <= 0.0:
			flameDamageTimer = flameDamageInterval
			_burn()
	else:
		flameDamageTimer = 0.0

func _apply_flame_intensity(t: float) -> void:
	var length: float = minf(flameColliderMaxLength * t, _reach)
	_shape.size = Vector2(flameColliderWidth, maxf(length, 0.1))
	flameCollider.position = nozzle.position + Vector2(0, -length * 0.5)
	flameParticles.lifetime = maxf(0.05, length / maxf(particleSpeed, 1.0))
	
func _burn() -> void:
	for body in bodiesInFlames:
		if not is_instance_valid(body):
			continue
		if body == ownerPlayer or not body.has_method("take_damage"):
			continue
		if hasLineOfSightTo(body):
			body.take_damage(flameDamage, global_position)

func hasLineOfSightTo(target: Node2D) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		nozzle.global_position, target.global_position, wall_mask
	)
	query.collide_with_areas = false
	query.exclude = [self, ownerPlayer]
	return space.intersect_ray(query).is_empty()

func _on_fuel_changed(_fuel: float, normalized: float) -> void:
	var idx: int = clampi(int(round((1.0 - normalized) * (frameCount - 1))), 0, frameCount - 1)
	sprite.frame = (frameCount - 1 - idx) if invertFrames else idx


func _forward() -> Vector2:
	return Vector2(0, -1).rotated(global_rotation)

func _wall_distance() -> float:
	var from: Vector2 = nozzle.global_position
	var to: Vector2 = from + _forward() * flameColliderMaxLength
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, wall_mask)
	query.collide_with_areas = false
	query.exclude = [self, ownerPlayer]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return flameColliderMaxLength
	return maxf(0.0, from.distance_to(hit["position"]) - wallMargin)
	
func _on_flames_body_entered(body: Node2D) -> void:
	if body != ownerPlayer and not bodiesInFlames.has(body):
		bodiesInFlames.append(body)

func _on_flames_body_exited(body: Node2D) -> void:
	bodiesInFlames.erase(body)
