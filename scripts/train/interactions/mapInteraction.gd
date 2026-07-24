extends Area2D

enum State { IDLE, PREVIEW, OPEN }

@export var open_zoom: float = 0.6
@export var open_scale: float = 1.0

var state: int = State.IDLE

@export var train: Node2D
@export var view_size: Vector2i = Vector2i(200, 200)
@export var icon_zoom: float = 0.2
@export var detail_zoom: float = 0.04
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
var _target_scale: float = 1.0


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
	
func _on_mouse_entered() -> void:
	if not active or state == State.OPEN:
		return
	hovered = true
	_set_state(State.PREVIEW)

func _on_mouse_exited() -> void:
	hovered = false
	if state == State.PREVIEW:
		_set_state(State.IDLE)

func _on_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:
		_set_state(State.IDLE if state == State.OPEN else State.OPEN)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if state != State.OPEN:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		_set_state(State.IDLE)
		get_viewport().set_input_as_handled()

func _set_state(new_state: int) -> void:
	state = new_state
	var showing: bool = state != State.IDLE

	detail.visible = showing
	icon.visible = not showing
	view.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if showing else SubViewport.UPDATE_DISABLED
	)
	set_process(showing)

	match state:
		State.OPEN:
			_target_zoom = open_zoom
			_target_scale = open_scale
			_push_cam()
		State.PREVIEW:
			_target_zoom = detail_zoom
			_target_scale = 1.0
			_push_cam()
		State.IDLE:
			_target_zoom = icon_zoom
			_target_scale = 1.0
			_pop_cam()

func set_active(value: bool) -> void:
	active = value
	if not active:
		hovered = false
		_set_state(State.IDLE)

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
	var w: float = 1.0 - exp(-zoom_speed * delta)
	var z: float = lerpf(mini_cam.zoom.x, _target_zoom, w)
	mini_cam.zoom = Vector2(z, z)
	var s: float = lerpf(detail.scale.x, _target_scale, w)
	detail.scale = Vector2(s, s)
	
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
