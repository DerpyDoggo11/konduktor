extends Button

func _on_pressed() -> void:
	disabled = true
	$AudioStreamPlayer2.play()
	
	#var drill = get_tree().get_first_node_in_group("backgroundDrill")
	#if drill:
	#	await drill.backgroundExitAnimation()
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.size = get_viewport().get_visible_rect().size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# dis so broken but IT WORK
	var shader = Shader.new()
	shader.code = "
	shader_type canvas_item;
	void fragment() {
		vec4 tex = texture(TEXTURE, UV);
		COLOR = vec4(COLOR.rgb, tex.a * 0.7 * COLOR.a);
	}
	"
	
	var mat = ShaderMaterial.new()
	mat.shader = shader

	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(overlay)
	get_tree().root.add_child(canvas)

	var tween = get_tree().create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 0.5)
	tween.tween_callback(func():

		ResourceLoader.load_threaded_request("res://scenes/main.tscn")

		var timer = Timer.new()
		canvas.add_child(timer)
		timer.wait_time = 0.05
		timer.timeout.connect(func():
			var status = ResourceLoader.load_threaded_get_status("res://scenes/main.tscn")
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				timer.stop()
				var scene = ResourceLoader.load_threaded_get("res://scenes/main.tscn")
				get_tree().call_deferred("change_scene_to_packed", scene)

				var state = { "elapsed": 0.0 }
				var fade_time = 0.5
				var dt = 1.0 / 60.0

				var fade_timer = Timer.new()
				canvas.add_child(fade_timer)
				fade_timer.wait_time = dt
				fade_timer.timeout.connect(func():
					state.elapsed += dt
					var t = clampf(state.elapsed / fade_time, 0.0, 1.0)
					overlay.color.a = 1.0 - t

					if t >= 1.0:
						fade_timer.stop()
						canvas.queue_free()
				)
				fade_timer.start()
		)
		timer.start()
	)

func _on_focus_entered() -> void:
	$AudioStreamPlayer.play()
