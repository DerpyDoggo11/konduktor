extends Area2D

@export var train: Node2D
@export var track_root_path: NodePath
@export var view_size: Vector2i = Vector2i(400, 400)
@export var idle_zoom: float = 0.2
@export var open_scale: float = 6.0
@export var fit_padding: float = 200.0
@export var zoom_speed: float = 8.0
@export var minimap_cull_layer: int = 2

@onready var view: SubViewport = $MapView
@onready var mini_cam: Camera2D = $MapView/MapCam
@onready var icon: Sprite2D = $Icon
@onready var detail: Node2D = $ScreenNode
@onready var screen: Sprite2D = $ScreenNode/Screen
@onready var close_button: Area2D = $ScreenNode/CloseButton

var is_open: bool = false
var _target_zoom: float = 0.2
var _target_scale: float = 1.0

var _fit_zoom: float = 0.1
var _fit_center: Vector2 = Vector2.ZERO
var _fit_valid: bool = false

func _ready() -> void:
	add_to_group("map")

	view.size = view_size
	view.world_2d = get_viewport().world_2d
	view.transparent_bg = true
	view.canvas_cull_mask = 1 << (minimap_cull_layer - 1)
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED

	screen.texture = view.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_target_zoom = idle_zoom
	mini_cam.zoom = Vector2.ONE * idle_zoom
	mini_cam.enabled = true
	mini_cam.make_current()

	detail.visible = false
	detail.scale = Vector2.ONE
	icon.visible = true
	close_button.input_pickable = false
	set_process(false)

	if close_button.has_signal("input_event"):
		close_button.input_event.connect(_on_close_input)

	await get_tree().process_frame
	_compute_fit()

func _compute_fit() -> void:
	var root := get_node_or_null(track_root_path)
	if root == null:
		root = get_tree().get_first_node_in_group("track_root")
	if root == null:
		push_warning("map: no track root found")
		return

	var min_p := Vector2.INF
	var max_p := -Vector2.INF

	for child in root.get_children():
		var seg := child as TrackSegment
		if seg == null or seg.curve == null:
			continue
		for p in seg.curve.get_baked_points():
			var g: Vector2 = seg.to_global(p)
			min_p = min_p.min(g)
			max_p = max_p.max(g)

	if min_p.x == INF:
		return

	min_p -= Vector2.ONE * fit_padding
	max_p += Vector2.ONE * fit_padding

	_fit_center = (min_p + max_p) * 0.5
	var span: Vector2 = max_p - min_p
	_fit_zoom = minf(float(view_size.x) / span.x, float(view_size.y) / span.y)
	_fit_valid = true

func open() -> void:
	if is_open:
		return
	is_open = true

	detail.visible = true
	icon.visible = false
	close_button.input_pickable = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	set_process(true)

	_target_zoom = _fit_zoom if _fit_valid else idle_zoom
	_target_scale = open_scale

	var cam := _get_camera()
	if cam:
		cam.push_target(detail, cam.map_zoom, false)

func close() -> void:
	if not is_open:
		return
	is_open = false

	close_button.input_pickable = false
	_target_zoom = idle_zoom
	_target_scale = 1.0

	var cam := _get_camera()
	if cam:
		cam.pop_target()

	await get_tree().create_timer(0.4).timeout
	if not is_open:
		detail.visible = false
		icon.visible = true
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		set_process(false)

func _on_close_input(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		close()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var w: float = 1.0 - exp(-zoom_speed * delta)

	if is_open and _fit_valid:
		mini_cam.global_position = mini_cam.global_position.lerp(_fit_center, w)
	elif train:
		mini_cam.global_position = train.global_position

	var z: float = lerpf(mini_cam.zoom.x, _target_zoom, w)
	mini_cam.zoom = Vector2(z, z)

	var s: float = lerpf(detail.scale.x, _target_scale, w)
	detail.scale = Vector2(s, s)

func _get_camera() -> Camera2D:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("set_target"):
		return cam
	return null
