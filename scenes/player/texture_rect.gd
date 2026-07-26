extends TextureRect

@export var frame_count: int = 4
@export var vertical_strip: bool = true

var _atlas := AtlasTexture.new()
var _player: Node = null
var _frame: int = -1

func _ready() -> void:
	_atlas.atlas = preload("res://assets/player/UiTHingGameGamejam.png")
	texture = _atlas
	expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_set_frame(0)
	await get_tree().process_frame
	print("pos=", global_position, " size=", size)
	print("visible_in_tree=", is_visible_in_tree(), " modulate=", modulate, " self_modulate=", self_modulate)
	print("atlas=", _atlas.atlas, " region=", _atlas.region)
	print("parent=", get_parent(), " parent_rect=", (get_parent() as Control).get_rect() if get_parent() is Control else "not a Control")
	print("viewport=", get_viewport_rect().size)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	modulate = Color.RED
	
	var n: Node = self
	while n != null:
		if n is CanvasItem:
			print(n.name, " mod=", n.modulate, " self_mod=", n.self_modulate, " vis=", n.visible)
		elif n is CanvasLayer:
			print(n.name, " layer=", n.layer, " vis=", n.visible, " xform=", n.transform)
		n = n.get_parent()

func _draw() -> void:
	print("_draw ran, size=", size)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0, 0, 1), true)
func _frame_size() -> Vector2:
	var t: Texture2D = _atlas.atlas
	if t == null or frame_count <= 0:
		return Vector2.ZERO
	if vertical_strip:
		return Vector2(t.get_width(), float(t.get_height()) / frame_count)
	return Vector2(float(t.get_width()) / frame_count, t.get_height())

func _set_frame(i: int) -> void:
	_frame = i
	var fs := _frame_size()
	var origin := Vector2(0, i * fs.y) if vertical_strip else Vector2(i * fs.x, 0)
	_atlas.region = Rect2(origin, fs)
	custom_minimum_size = fs
	size = fs

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	var f: int = 3 if _player.is_carrying() else _player.equipped_slot
	if f != _frame:
		_set_frame(f)
