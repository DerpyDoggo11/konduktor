extends CharacterBody2D

signal fuel_changed(fuel: float, normalized: float)
signal died()

@export var walk_speed: float = 150.0
@export var sprint_multiplier: float = 1.8
@export var acceleration: float = 1200.0
@export var friction: float = 1800.0
@export var rotation_speed: float = 10.0
@export var item_scenes: Array[PackedScene] = []

@export var fuel_frame_count: int = 9
@export var invert_fuel_frames: bool = true
@export var invuln_time: float = 0.4

@onready var hand: Node2D = $Hand
@onready var body_sprite: Sprite2D = $Player1

var seated: bool = false
var seat_anchor: Node2D = null
var equipped_slot: int = 0
var equipped_item: Node2D = null

var _train: Node = null
var _invuln: float = 0.0
var _dead: bool = false

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
		push_error("player: no node in group 'train' — fuel will not work")
		return
	_train.fuel_changed.connect(_on_train_fuel_changed)
	_on_train_fuel_changed(_train.fuel, _train.fuel / _train.max_fuel)

func _on_train_fuel_changed(f: float, normalized: float) -> void:
	_apply_fuel_frame(normalized)
	fuel_changed.emit(f, normalized)
	if f <= 0.0 and not _dead:
		_dead = true
		died.emit()
		var go := get_tree().get_first_node_in_group("gameOver")
		if go:
			go.show_game_over("You ran out of fuel.")

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

func take_damage(amount: float, _hit_from = null) -> void:
	if _dead or _invuln > 0.0 or _train == null:
		return
	_invuln = invuln_time
	_train.consume_fuel(amount)


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
		return
	var scene := item_scenes[slot - 1]
	if scene == null:
		equipped_slot = 0
		return
	equipped_item = scene.instantiate()
	hand.add_child(equipped_item)

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
	if Input.is_action_pressed("sprint"):
		speed *= sprint_multiplier

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	var target_angle := global_position.angle_to_point(get_global_mouse_position()) + deg_to_rad(90)
	if rotation_speed <= 0.0:
		global_rotation = target_angle
	else:
		global_rotation = lerp_angle(global_rotation, target_angle, 1.0 - exp(-rotation_speed * delta))

	move_and_slide()

func sit(point: Node2D) -> void:
	seated = true
	seat_anchor = point
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)

func stand(point: Node2D) -> void:
	seated = false
	seat_anchor = null
	global_position = point.global_position
	$CollisionShape2D.set_deferred("disabled", false)
