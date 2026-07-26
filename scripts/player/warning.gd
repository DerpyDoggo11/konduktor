extends Control

enum Step { PICK_UP, DEPOSIT, THROTTLE, ADVICE, DONE }

@export var low_fuel_ratio: float = 0.25
@export var advice_seconds: float = 6.0
@export var top_margin: float = 24.0
@export var fade_time: float = 0.25

@export var color_tutorial: Color = Color(0.6, 0.9, 1.0)
@export var color_warn: Color = Color(1.0, 0.75, 0.2)
@export var color_danger: Color = Color(1.0, 0.35, 0.3)

@onready var label: Label = $warningLabel

var step: int = Step.PICK_UP

var _train: Node = null
var _player: Node = null
var _advice_timer: float = 0.0
var _low_fuel: bool = false
var _junction: String = ""
var _shown_text: String = ""
var _tween: Tween = null

func _ready() -> void:
	add_to_group("warning_hud")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modulate.a = 0.0

	get_viewport().size_changed.connect(_reposition)
	_reposition()

	await get_tree().process_frame

	_player = get_tree().get_first_node_in_group("player")
	if _player and _player.has_signal("inventory_changed"):
		_player.inventory_changed.connect(_on_inventory_changed)

	_train = get_tree().get_first_node_in_group("train")
	if _train:
		_train.fuel_changed.connect(_on_fuel_changed)
		_train.junction_approaching.connect(_on_junction_approaching)
		_train.junction_cleared.connect(_on_junction_cleared)
		if _train.has_signal("fuel_added"):
			_train.fuel_added.connect(_on_fuel_added)
		if _train.throttle and _train.throttle.has_signal("throttle_changed"):
			_train.throttle.throttle_changed.connect(_on_throttle_changed)

	_refresh()

func _reposition() -> void:
	var view: Vector2 = get_viewport_rect().size
	size = Vector2(view.x, 48)
	position = Vector2(0, top_margin)
	label.size = size

func _process(delta: float) -> void:
	if step == Step.ADVICE:
		_advice_timer -= delta
		if _advice_timer <= 0.0:
			step = Step.DONE
			_refresh()


func _on_inventory_changed(frame: int) -> void:
	if step == Step.PICK_UP and frame == 3:
		step = Step.DEPOSIT
		_refresh()

func _on_fuel_added(_amount: float) -> void:
	if step == Step.DEPOSIT:
		step = Step.THROTTLE
		_refresh()

func _on_throttle_changed(level: int, _n: float) -> void:
	if step == Step.THROTTLE and level > 0:
		step = Step.ADVICE
		_advice_timer = advice_seconds
		_refresh()

func _on_fuel_changed(_f: float, normalized: float) -> void:
	var low: bool = normalized <= low_fuel_ratio
	if low != _low_fuel:
		_low_fuel = low
		_refresh()

func _on_junction_approaching(good_dirs: Array, bad_dirs: Array) -> void:
	_junction = "choice" if not good_dirs.is_empty() else "dead_end"
	if good_dirs.is_empty() and bad_dirs.is_empty():
		_junction = ""
	_refresh()

func _on_junction_cleared() -> void:
	_junction = ""
	_refresh()

func _refresh() -> void:
	var text: String = ""
	var col: Color = color_warn

	match step:
		Step.PICK_UP:
			text = "Pick up the fuel canister on the ground [E]"
			col = color_tutorial
		Step.DEPOSIT:
			text = "Carry it to the engine and fill the tank [E]"
			col = color_tutorial
		Step.THROTTLE:
			text = "Load the other fuel canister, then sit at the driver's seat and raise the throttle"
			col = color_tutorial
		Step.ADVICE:
			text = "Stop at fuel depots to restock on fuel or else you'll run out"
			col = color_tutorial
		_:
			if _junction == "dead_end":
				text = "Dead end ahead switch the points or brake"
				col = color_danger
			elif _low_fuel:
				text = "Low fuel"
				col = color_danger
			elif _junction == "choice":
				text = "Junction ahead  choose a direction"
				col = color_warn

	_show(text, col)

func _show(text: String, col: Color) -> void:
	if text == _shown_text:
		return
	_shown_text = text

	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()

	if text == "":
		_tween.tween_property(self, "modulate:a", 0.0, fade_time)
		return

	label.text = text
	label.modulate = col
	_tween.tween_property(self, "modulate:a", 1.0, fade_time)
