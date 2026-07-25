extends Area2D

@export var door: Node2D

@onready var button_up: Sprite2D = $ButtonUp
@onready var button_down: Sprite2D = $ButtonDown
@onready var prompt: Control = $Control

var player_in_range: Node = null

func _ready() -> void:
	if prompt:
		prompt.visible = false
	_refresh_sprites()

	if door and door.has_signal("state_changed"):
		door.state_changed.connect(func(_open): _refresh_sprites())

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	player_in_range = body
	if prompt:
		prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body != player_in_range:
		return
	player_in_range = null
	if prompt:
		prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range == null or not event.is_action_pressed("interact"):
		return
	if door and door.has_method("toggle"):
		door.toggle()
		_refresh_sprites()
	get_viewport().set_input_as_handled()

func _refresh_sprites() -> void:
	var open: bool = door.is_open if door else false
	button_down.visible = open
	button_up.visible = not open
