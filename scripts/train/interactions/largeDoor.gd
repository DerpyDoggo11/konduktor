extends AnimatableBody2D

signal state_changed(open: bool)
signal broke()
signal repaired()

@export var slide_offset: Vector2 = Vector2(0, -40)
@export var slide_time: float = 0.6
@export var inverted: bool = false
@export var trans: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

@export var max_health: int = 500
@export var repair_per_hit: int = 25

@onready var sprite_intact: Sprite2D = $Door
@onready var sprite_broken: Sprite2D = get_node_or_null("Door2")
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var repair_shape: CollisionShape2D = get_node_or_null("RepairShape")
@onready var healthbar: TextureProgressBar = get_node_or_null("Healthbar")

var is_open: bool = false
var is_broken: bool = false
var health: int

var _closed_pos: Vector2
var _tween: Tween = null
var _moving: bool = false

func _ready() -> void:
	add_to_group("door")
	sync_to_physics = false
	_closed_pos = position
	health = max_health

	if healthbar:
		healthbar.max_value = max_health
		healthbar.value = health
		healthbar.visible = false

	_refresh_sprites()

	if inverted:
		is_open = true
		position = _closed_pos + slide_offset

func _refresh_sprites() -> void:
	if sprite_intact:
		sprite_intact.visible = not is_broken
	if sprite_broken:
		sprite_broken.visible = is_broken
		
func _physics_process(_delta: float) -> void:
	if _moving:
		return

	var rest: Vector2 = _closed_pos + (slide_offset if is_open else Vector2.ZERO)
	if position != rest:
		position = rest


func toggle() -> void:
	set_open(not is_open)

func set_open(open: bool) -> void:
	if open == is_open or is_broken:
		return
	is_open = open
	state_changed.emit(is_open)
	
	if open == true:
		$AudioStreamPlayer2D.play()
	else:
		$AudioStreamPlayer2D2.play() # REVERSE

	if _tween and _tween.is_running():
		_tween.kill()

	var target: Vector2 = _closed_pos + (slide_offset if is_open else Vector2.ZERO)
	_moving = true

	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.set_trans(trans).set_ease(ease_type)
	_tween.tween_property(self, "position", target, slide_time)
	_tween.tween_callback(func():
		position = target
		_moving = false
	)


func take_damage(amount: float, _hit_from = null) -> void:
	if is_broken:
		return
	health = maxi(0, health - int(amount))
	_refresh_health()
	if health <= 0:
		_break()

func repair(amount: int = -1) -> bool:
	if health >= max_health:
		return false

	var heal: int = repair_per_hit if amount < 0 else amount
	health = mini(max_health, health + heal)
	_refresh_health()

	if is_broken and health > 0:
		is_broken = false
		_refresh_sprites()
		shape.set_deferred("disabled", false)
		repaired.emit()
	return true

func needs_repair() -> bool:
	return health < max_health

func _break() -> void:
	if is_broken:
		return
	is_broken = true
	_refresh_sprites()
	shape.set_deferred("disabled", true)
	broke.emit()

func _refresh_health() -> void:
	if healthbar == null:
		return
	healthbar.value = health
	healthbar.visible = health < max_health
