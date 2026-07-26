extends CanvasLayer

@export var title_scene: String = "res://scenes/titlescreen.tscn"
@export var fade_time: float = 0.6
@export var text_fade_time: float = 0.5
@export var hold_time: float = 1.4
@export var default_title: String = "Game over"

@onready var fade: ColorRect = $Fade
@onready var text: Control = $Menu
@onready var title_label: Label = $"Menu/1/2/Title"
@onready var reason_label: Label = $"Menu/1/2/Reason"
@onready var reason2_label: Label = $"Menu/1/2/Reason/Reason2"
@onready var reason3_label: Label = $"Menu/1/2/Reason/Reason3"

var _shown: bool = false

func _ready() -> void:
	add_to_group("gameOver")
	fade.color.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_game_over(reason: String = "", title: String = "") -> void:
	if _shown:
		return
	_shown = true

	title_label.text = reason
	reason_label.text = title
	reason2_label.text = title
	reason3_label.text = title
#	reason_label.visible = reason != ""

	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, fade_time)
	tween.tween_property(text, "modulate:a", 1.0, text_fade_time)
