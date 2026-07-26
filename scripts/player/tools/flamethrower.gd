extends Node2D

@export var flame_scene: PackedScene
@export var emit_rate: float = 28.0
@export var fuelPerSecond: float = 9.0
@export var frameCount: int = 23
@export var invertFrames: bool = false
@export var spool_up: float = 6.0

var firing: bool = false : set = set_firing
var intensity: float = 0.0
var ownerPlayer: Node = null

@onready var fire_sfx: AudioStreamPlayer2D = $AudioStreamPlayer2D

var _emit_accum: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var nozzle: Marker2D = $nozzle

func _ready() -> void:
	sprite.hframes = frameCount
	sprite.vframes = 1

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
	if value == firing:
		return
	firing = value
	if firing:
		fire_sfx.play()
	else:
		fire_sfx.stop()

func _forward() -> Vector2:
	return Vector2(0, -1).rotated(global_rotation)

func _physics_process(delta: float) -> void:
	var wants: bool = firing
	if wants and ownerPlayer:
		var needed: float = fuelPerSecond * delta
		if ownerPlayer.consume_fuel(needed) < needed * 0.99:
			wants = false

	if wants and not fire_sfx.playing:
		fire_sfx.play()
	elif not wants and fire_sfx.playing:
		fire_sfx.stop()


	intensity = move_toward(intensity, 1.0 if wants else 0.0, delta * spool_up)

	if not wants or flame_scene == null:
		_emit_accum = 0.0
		return

	_emit_accum += emit_rate * intensity * delta
	while _emit_accum >= 1.0:
		_emit_accum -= 1.0
		_spawn_flame()

@export_flags_2d_physics var wall_mask: int = 3
@export var muzzle_check_inset: float = 10.0

func _spawn_flame() -> void:
	var origin: Vector2 = nozzle.global_position

	if ownerPlayer:
		var from: Vector2 = ownerPlayer.global_position + _forward() * muzzle_check_inset
		if _blocked_to(from, origin):
			return

	var flame = flame_scene.instantiate()
	get_tree().current_scene.add_child(flame)
	flame.setup(origin, _forward(), ownerPlayer)

@export var block_margin: float = 4.0
func _blocked_to(from: Vector2, to: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, wall_mask)
	query.collide_with_areas = false
	if ownerPlayer:
		query.exclude = [ownerPlayer]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	return from.distance_to(hit["position"]) < from.distance_to(to) - block_margin

func _on_fuel_changed(_fuel: float, normalized: float) -> void:
	var idx: int = clampi(int(round((1.0 - normalized) * (frameCount - 1))), 0, frameCount - 1)
	sprite.frame = (frameCount - 1 - idx) if invertFrames else idx
