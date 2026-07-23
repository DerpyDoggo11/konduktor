extends Area2D

@export var camera_point: Node2D
@export var seat_point: Node2D
@export var exit_point: Node2D

@onready var prompt: Control = $Control
@onready var button_up: Node = $Control/buttonUp
@onready var button_down: Node = $Control/buttonDown

var player_in_range: Node = null
var occupant: Node = null

func _ready() -> void:
	print("seat ready, monitoring: ", monitoring, " mask: ", collision_mask)
	print("shape: ", $CollisionShape2D.shape, " disabled: ", $CollisionShape2D.disabled)
	prompt.visible = false
	button_up.visible = true
	button_down.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	print("entered: ", body.name, " groups: ", body.get_groups())
	if not body.is_in_group("player"):
		return
	player_in_range = body
	if occupant == null:
		prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body != player_in_range:
		return
	player_in_range = null
	prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if occupant != null:
		_exit_seat()
		get_viewport().set_input_as_handled()
	elif player_in_range != null:
		_enter_seat(player_in_range)
		get_viewport().set_input_as_handled()

func _get_camera() -> Camera2D:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("set_target"):
		return cam
	return null
	
func _enter_seat(player: Node) -> void:
	occupant = player
	prompt.visible = false
	_press_feedback()

	var point: Node2D = seat_point if seat_point else self
	player.sit(point)

	var cam := _get_camera()
	if cam and camera_point:
		cam.set_target(camera_point)

func _exit_seat() -> void:
	var player = occupant
	occupant = null

	var point: Node2D = exit_point if exit_point else self
	player.stand(point)

	var cam := _get_camera()
	if cam:
		cam.set_target(player)

	if player_in_range != null:
		prompt.visible = true

func _press_feedback() -> void:
	button_up.visible = false
	button_down.visible = true
	await get_tree().create_timer(0.12).timeout
	button_up.visible = true
	button_down.visible = false
