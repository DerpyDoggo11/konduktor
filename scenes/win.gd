extends CanvasLayer

@export var title_scene: String = "res://scenes/titlescreen.tscn"
@export var fade_time: float = 0.6
@export var text_fade_time: float = 0.5
@export var hold_time: float = 1.4

@onready var fade: ColorRect = $Fade2
@onready var text: Control = $Menu2

var _shown: bool = false

func _ready() -> void:
	fade.color.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_game_win() -> void:
	print("show win")
	if _shown:
		return
	_shown = true

	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, fade_time)
	tween.tween_property(text, "modulate:a", 1.0, text_fade_time)
