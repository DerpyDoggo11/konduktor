extends Sprite2D

@export var bottom_margin: float = 5.0
@export var hotbar_scale: float = 3.0
@export var frame_count: int = 4
@export var left_margin: float = 5.0

const FRAME_NONE := 0
const FRAME_CARRY := 3

func _ready() -> void:
	add_to_group("inventory")
	hframes = 1
	vframes = frame_count
	frame = FRAME_NONE
	scale = Vector2.ONE * hotbar_scale
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = true

	get_viewport().size_changed.connect(_reposition)
	_reposition()

	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_signal("inventory_changed"):
		player.inventory_changed.connect(set_state)
		set_state(player.inventory_frame())

func _reposition() -> void:
	var view: Vector2 = get_viewport_rect().size
	var half_w: float = texture.get_width() * 0.5 * scale.x
	var half_h: float = (texture.get_height() / float(vframes)) * 0.5 * scale.y
	position = Vector2(half_w + left_margin, view.y - half_h - bottom_margin)

func set_state(new_frame: int) -> void:
	frame = clampi(new_frame, 0, frame_count - 1)
