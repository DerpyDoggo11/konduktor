extends Control

@export var fade_time := 0.25
var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # so it never eats clicks
	modulate.a = 0.0
	visible = false

func show_tip() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, fade_time)

func hide_tip() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	_tween.tween_callback(func(): visible = false)
