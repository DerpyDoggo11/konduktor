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
	prompt.visible = false
	button_up.visible = true
	button_down.visible = false

func _on_body_entered(body: Node) -> void:
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
	
func _get_camera() -> Camera2D:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("set_target"):
		return cam
	return null
	
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if occupant != null:
		_exit_seat()
		get_viewport().set_input_as_handled()
	elif player_in_range != null:
		_enter_seat(player_in_range)
		get_viewport().set_input_as_handled()
	
func _enter_seat(player: Node) -> void:
	occupant = player
	prompt.visible = false
	_press_feedback()

	var point: Node2D = seat_point if seat_point else self
	player.sit(point)
	
	get_parent().get_parent().get_parent().throttle.set_active(true)
	get_parent().get_parent().get_parent().speedometer.set_active(true)
	get_parent().get_parent().get_parent().brake.set_active(true)
	get_parent().get_parent().get_parent().switchPanel.set_active(true)
	
	var cam = _get_camera()
	cam.set_target(camera_point, cam.seated_zoom, false)

func _exit_seat() -> void:
	var player = occupant
	occupant = null

	var point: Node2D = exit_point if exit_point else self
	player.stand(point)
	
	get_parent().get_parent().get_parent().throttle.set_active(false)
	get_parent().get_parent().get_parent().speedometer.set_active(false)
	get_parent().get_parent().get_parent().brake.set_active(false)
	get_parent().get_parent().get_parent().switchPanel.set_active(false)
	
	var cam = _get_camera()
	cam.set_target(player, cam.walk_zoom, false) 
	
	if player_in_range != null:
		prompt.visible = true

func _press_feedback() -> void:
	button_up.visible = false
	button_down.visible = true
	await get_tree().create_timer(0.12).timeout
	button_up.visible = true
	button_down.visible = false
