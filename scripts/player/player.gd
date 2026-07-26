extends CharacterBody2D

signal fuel_changed(fuel: float, normalized: float)
signal inventory_changed(frame: int)

@export var walk_speed: float = 150.0
@export var sprint_multiplier: float = 1.1
@export var acceleration: float = 1200.0
@export var friction: float = 1800.0
@export var rotation_speed: float = 10.0
@export var item_scenes: Array[PackedScene] = []

@export var fuel_frame_count: int = 9
@export var invert_fuel_frames: bool = true
@export var invuln_time: float = 0.4

@export var hit_flash_color: Color = Color(2.0, 0.4, 0.4)
@export var hit_flash_time: float = 0.18
@export var knockback_force: float = 320.0
@export var knockback_decay: float = 9.0

@export var carry_speed_multiplier: float = 0.55
@export var carry_rotation_speed: float = 14.0

@onready var hand: Node2D = $Hand
@onready var body_sprite: Sprite2D = $Player1
@onready var carry_point: Node2D = $CarryPoint

var seated: bool = false
var seat_anchor: Node2D = null
var equipped_slot: int = 0
var equipped_item: Node2D = null
var carried: Node2D = null

var _train: Node = null
var _invuln: float = 0.0
var _dead: bool = false
var _knockback: Vector2 = Vector2.ZERO
var _flash_tween: Tween = null

var fuel: float:
	get:
		return _train.fuel if _train else 0.0

var max_fuel: float:
	get:
		return _train.max_fuel if _train else 1.0

func _ready() -> void:
	add_to_group("player")
	body_sprite.hframes = fuel_frame_count
	body_sprite.vframes = 1

	await get_tree().process_frame
	_train = get_tree().get_first_node_in_group("train")
	if _train == null:
		return
	_train.fuel_changed.connect(_on_train_fuel_changed)
	_on_train_fuel_changed(_train.fuel, _train.fuel / _train.max_fuel)

func _on_train_fuel_changed(f: float, normalized: float) -> void:
	_apply_fuel_frame(normalized)
	fuel_changed.emit(f, normalized)

func _apply_fuel_frame(normalized: float) -> void:
	var idx: int = clampi(int(round(normalized * (fuel_frame_count - 1))), 0, fuel_frame_count - 1)
	body_sprite.frame = (fuel_frame_count - 1 - idx) if invert_fuel_frames else idx

func consume_fuel(amount: float) -> float:
	if _train == null:
		return 0.0
	return _train.consume_fuel(amount)

func add_fuel(amount: float) -> void:
	if _train:
		_train.add_fuel(amount)

func take_damage(amount: float, hit_from = null) -> void:
	if _dead or _invuln > 0.0 or _train == null:
		return
	_invuln = invuln_time
	_train.consume_fuel(amount)
	$AudioStreamPlayer2D2.play()

	_flash()

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

func _flash() -> void:
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	body_sprite.modulate = hit_flash_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(body_sprite, "modulate", Color.WHITE, hit_flash_time)


func _unhandled_input(event: InputEvent) -> void:
	for slot in range(1, item_scenes.size() + 1):
		if event.is_action_pressed("equip_%d" % slot):
			_equip(0 if equipped_slot == slot else slot)
			get_viewport().set_input_as_handled()
			return
			
func _equip(slot: int) -> void:
	if equipped_item != null:
		equipped_item.queue_free()
		equipped_item = null
	equipped_slot = slot
	if slot <= 0 or slot > item_scenes.size():
		equipped_slot = 0
		_notify_inventory()
		return
	var scene := item_scenes[slot - 1]
	if scene == null:
		equipped_slot = 0
		_notify_inventory()
		return
	equipped_item = scene.instantiate()
	hand.add_child(equipped_item)
	_notify_inventory()


func _physics_process(delta: float) -> void:
	if _invuln > 0.0:
		_invuln -= delta

	if seated:
		if seat_anchor:
			global_position = seat_anchor.global_position
			global_rotation = seat_anchor.global_rotation
		if equipped_item and equipped_item.has_method("set_firing"):
			equipped_item.set_firing(false)
		return

	if equipped_item and equipped_item.has_method("set_firing"):
		equipped_item.set_firing(Input.is_action_pressed("attack"))

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := walk_speed
	if is_carrying():
		speed *= carry_speed_multiplier
	elif Input.is_action_pressed("sprint"):
		speed *= sprint_multiplier

	if _knockback.length() > 10.0:
		_knockback = _knockback.lerp(Vector2.ZERO, delta * knockback_decay)
		velocity = _knockback
	else:
		_knockback = Vector2.ZERO
		if input_dir != Vector2.ZERO:
			velocity = velocity.move_toward(input_dir * speed, acceleration * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	var target_angle := global_position.angle_to_point(get_global_mouse_position()) + deg_to_rad(90)
	if rotation_speed <= 0.0:
		global_rotation = target_angle
	else:
		global_rotation = lerp_angle(global_rotation, target_angle, 1.0 - exp(-rotation_speed * delta))

	$walkingparticles.emitting = true

	move_and_slide()


func sit(point: Node2D) -> void:
	seated = true
	seat_anchor = point
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)

func stand(point: Node2D) -> void:
	seated = false
	seat_anchor = null
	global_position = point.global_position
	$CollisionShape2D.set_deferred("disabled", false)


func is_carrying() -> bool:
	return carried != null and is_instance_valid(carried)


func pick_up(item: Node2D) -> bool:
	if is_carrying() or seated:
		return false
	carried = item
	_notify_inventory()
	return true
	
func release() -> Node2D:
	var item := carried
	carried = null
	_notify_inventory()
	return item
	
func inventory_frame() -> int:
	if is_carrying():
		return 3
	if equipped_slot >= 1 and equipped_slot <= 2:
		return equipped_slot
	return 0

func _notify_inventory() -> void:
	inventory_changed.emit(inventory_frame())
