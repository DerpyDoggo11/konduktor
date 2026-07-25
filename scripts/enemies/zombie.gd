extends CharacterBody2D

enum Kind { BASIC, EXPLOSIVE, STRONG }

const STATS := {
	Kind.BASIC:     {"health": 20, "speed": 45.0,  "damage": 8,  "tint": Color(1.0, 0.55, 0.2)},
	Kind.EXPLOSIVE: {"health": 12, "speed": 95.0,  "damage": 4,  "tint": Color(0.55, 0.1, 0.12)},
	Kind.STRONG:    {"health": 70, "speed": 28.0,  "damage": 20, "tint": Color(0.3, 0.5, 1.0)},
}

@export var kind: int = Kind.BASIC
@export var acceleration: float = 400.0
@export var damage_interval: float = 0.8
@export var knockback_force: float = 260.0
@export var despawn_distance: float = 2500.0
@export var rotation_speed: float = 8.0
@export var sprite_angle_offset: float = 90.0
@export var door_preference: float = 1.5   # <1 makes doors more attractive than the player

@export var fuse_time: float = 0.7
@export var trigger_range: float = 45.0
@export var blast_radius: float = 110.0
@export var blast_damage: int = 34
@export var shake_amount: float = 14.0
@export var shake_time: float = 0.35

@onready var sprite: Sprite2D = $zombo
@onready var damage_area: Area2D = $DamageArea
@onready var healthbar: TextureProgressBar = $Healthbar

var max_health: int = 20
var health: int
var speed: float = 45.0
var damage: int = 8

var player: Node2D = null
var target: Node2D = null
var _touching: Array = []
var _damage_timer: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _fuse: float = -1.0
var _exploded: bool = false

func _ready() -> void:
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health
		healthbar.visible = false

func configure(new_kind: int, difficulty: float = 1.0) -> void:
	kind = new_kind
	var s: Dictionary = STATS[kind]
	max_health = int(round(s["health"] * difficulty))
	health = max_health
	speed = s["speed"] * lerpf(1.0, 1.35, clampf((difficulty - 1.0) / 3.0, 0.0, 1.0))
	damage = int(round(s["damage"] * difficulty))

	if sprite:
		sprite.modulate = s["tint"]
	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health

func _pick_target() -> Node2D:
	var best: Node2D = null
	var best_dist: float = INF

	if player and is_instance_valid(player):
		best = player
		best_dist = global_position.distance_to(player.global_position)

	for d in get_tree().get_nodes_in_group("door"):
		if not is_instance_valid(d) or d.is_broken:
			continue
		var dist: float = global_position.distance_to(d.global_position) * door_preference
		if dist < best_dist:
			best_dist = dist
			best = d

	return best

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	target = _pick_target()
	if target == null:
		return

	# Despawn is measured from the player, not the target, so a zombie
	# chewing on a door still cleans up once the train pulls away.
	if player and is_instance_valid(player):
		if global_position.distance_to(player.global_position) > despawn_distance:
			queue_free()
			return

	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()

	if _knockback.length() > 5.0:
		_knockback = _knockback.lerp(Vector2.ZERO, delta * 8.0)
		velocity = _knockback
	else:
		_knockback = Vector2.ZERO
		velocity = velocity.move_toward(to_target.normalized() * speed, acceleration * delta)

	if dist > 0.01:
		var want_angle: float = to_target.angle() + deg_to_rad(sprite_angle_offset)
		sprite.global_rotation = lerp_angle(
			sprite.global_rotation, want_angle, 1.0 - exp(-rotation_speed * delta)
		)

	move_and_slide()

	if kind == Kind.EXPLOSIVE:
		_tick_fuse(delta, dist)
		return

	_damage_timer -= delta
	if _damage_timer <= 0.0 and not _touching.is_empty():
		_damage_timer = damage_interval
		for body in _touching:
			if is_instance_valid(body) and body.has_method("take_damage"):
				body.take_damage(damage, global_position)

func _tick_fuse(delta: float, dist: float) -> void:
	if _fuse < 0.0:
		if dist <= trigger_range:
			_fuse = fuse_time
		return

	_fuse -= delta
	var blink: float = 1.0 - (_fuse / fuse_time)
	sprite.modulate = STATS[kind]["tint"].lerp(Color(2.0, 1.4, 0.6), absf(sin(blink * 24.0)))

	if _fuse <= 0.0:
		_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true

	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = blast_radius
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collide_with_bodies = true
	query.exclude = [get_rid()]

	for hit in space.intersect_shape(query, 16):
		var body = hit.get("collider")
		if body == null or body == self or not is_instance_valid(body):
			continue
		if not body.has_method("take_damage"):
			continue
		var falloff: float = 1.0 - clampf(
			global_position.distance_to(body.global_position) / blast_radius, 0.0, 1.0
		)
		body.take_damage(int(round(blast_damage * falloff)), global_position)

	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("shake"):
		cam.shake(shake_amount, shake_time)

	queue_free()

func take_damage(amount: float, hit_from = null) -> void:
	health -= int(amount)

	if healthbar:
		healthbar.value = health
		healthbar.visible = health < max_health

	if hit_from != null:
		var src: Vector2
		if hit_from is Vector2:
			src = hit_from
		elif hit_from is Node2D:
			src = (hit_from as Node2D).global_position
		else:
			src = global_position
		if src != global_position:
			_knockback = (global_position - src).normalized() * knockback_force

	if health <= 0:
		if kind == Kind.EXPLOSIVE:
			_explode()
		else:
			queue_free()

func _on_damage_area_body_entered(body: Node2D) -> void:
	if (body.is_in_group("player") or body.is_in_group("door")) and not _touching.has(body):
		_touching.append(body)
		_damage_timer = 0.0

func _on_damage_area_body_exited(body: Node2D) -> void:
	_touching.erase(body)
