extends CanvasLayer

@export var title_scene: String = "res://scenes/titlescreen.tscn"
@export var fade_time: float = 0.6
@export var text_fade_time: float = 0.5
@export var hold_time: float = 1.4
@export var default_title: String = "Game over"

@onready var fade: ColorRect = $Fade
@onready var text: Control = $Menu
@onready var title_label: Label = $Menu/Title
@onready var reason_label: Label = $Menu/Reason

var _shown: bool = false

func _ready() -> void:
	add_to_group("game_over")
	fade.color.a = 0.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_game_over(reason: String = "", title: String = "") -> void:
	if _shown:
		return
	_shown = true

	title_label.text = default_title if title == "" else title
	reason_label.text = reason
	reason_label.visible = reason != ""

	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, fade_time)
	tween.tween_property(text, "modulate:a", 1.0, text_fade_time)
	tween.tween_interval(hold_time)
	tween.tween_property(text, "modulate:a", 0.0, text_fade_time)
	tween.tween_callback(_load_title)

func _load_title() -> void:
	get_tree().paused = false
	ResourceLoader.load_threaded_request(title_scene)
	var timer := Timer.new()
	add_child(timer)
	timer.wait_time = 0.05
	timer.timeout.connect(func():
		var status = ResourceLoader.load_threaded_get_status(title_scene)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			timer.stop()
			var scene = ResourceLoader.load_threaded_get(title_scene)
			get_tree().call_deferred("change_scene_to_packed", scene)
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			timer.stop()
			push_error("failed to load %s" % title_scene)
	)
	timer.start()
