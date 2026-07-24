extends Area2D

@export var train: Node2D
@export var view_size: Vector2i = Vector2i(200, 200)
@export var icon_zoom: float = 0.01
@export var detail_zoom: float = 0.05
@export var zoom_speed: float = 8.0
@export var minimap_cull_layer: int = 2

@onready var view: SubViewport = $MapView
@onready var mini_cam: Camera2D = $MapView/MapCam
@onready var icon: Sprite2D = $Icon
@onready var detail: Node2D = $ScreenNode
@onready var screen: Sprite2D = $ScreenNode/Screen

var active: bool = false
var hovered: bool = false
var _pushed: bool = false
var _target_zoom: float = 0.0

func _ready() -> void:
	view.size = view_size
	view.world_2d = get_viewport().world_2d
	view.transparent_bg = true
	#view.canvas_cull_mask = 1 << (minimap_cull_layer - 1)
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED

	screen.texture = view.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_target_zoom = icon_zoom
	mini_cam.zoom = Vector2.ONE * icon_zoom
	mini_cam.enabled = true

	detail.visible = false
	icon.visible = true
	set_process(false)

func set_active(value: bool) -> void:
	active = value
	if not active:
		hovered = false
		_pop_cam()
	_refresh()

func _on_mouse_entered() -> void:
	if not active:
		return
	hovered = true
	_refresh()
	_push_cam()

func _on_mouse_exited() -> void:
	hovered = false
	_refresh()
	_pop_cam()

func _refresh() -> void:
	var show_detail: bool = active and hovered
	detail.visible = show_detail
	icon.visible = not show_detail
	_target_zoom = detail_zoom if show_detail else icon_zoom

	view.render_target_update_mode = (SubViewport.UPDATE_ALWAYS if show_detail else SubViewport.UPDATE_DISABLED)
	set_process(show_detail)

func _process(delta: float) -> void:
	if train:
		mini_cam.global_position = train.global_position
	var z: float = lerpf(mini_cam.zoom.x, _target_zoom, 1.0 - exp(-zoom_speed * delta))
	mini_cam.zoom = Vector2(z, z)

func _get_camera() -> Camera2D:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("set_target"):
		return cam
	return null

func _push_cam() -> void:
	if _pushed:
		return
	var cam := _get_camera()
	if cam:
		cam.push_target(detail, cam.control_zoom, false)
		_pushed = true

func _pop_cam() -> void:
	if not _pushed:
		return
	_pushed = false
	var cam := _get_camera()
	if cam:
		cam.pop_target()
