extends Control

@export var scroll_speed := 60.0  # pixels per second
@export var next_scene: String = "res://scenes/main_menu.tscn"

@onready var text: Control = $CreditsText

func _ready() -> void:
	await get_tree().process_frame  # let layout settle so size.y is correct
	text.position.y = size.y        # start just below the visible area

func _process(delta: float) -> void:
	text.position.y -= scroll_speed * delta
	if text.position.y + text.size.y < 0.0:
		set_process(false)
		get_tree().change_scene_to_file(next_scene)
