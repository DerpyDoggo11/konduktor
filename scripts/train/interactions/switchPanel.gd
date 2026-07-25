extends Node2D

signal switch_changed(direction: int)

@onready var buttons: Array = [$LeftArrow, $UpArrow, $RightArrow]

var selected: int = TrackSegment.Dir.STRAIGHT

func _ready() -> void:
	add_to_group("switch_panel")

	for b in buttons:
		b.panel = self
	_refresh_buttons()

	await get_tree().process_frame
	var marker := get_tree().get_first_node_in_group("train_marker")
	if marker and marker.has_signal("segment_changed"):
		marker.segment_changed.connect(_on_segment_changed)
		if marker.segment:
			_on_segment_changed(marker.segment)
			
	await get_tree().process_frame
	var train := get_tree().get_first_node_in_group("train")
	if train:
		train.junction_approaching.connect(_on_junction_approaching)
		train.junction_cleared.connect(_on_junction_cleared)
		
func _on_junction_approaching(seg: TrackSegment) -> void:
	for b in buttons:
		b.set_flashing(seg.has_exit(b.direction) and b.direction != TrackSegment.Dir.STRAIGHT)

func _on_junction_cleared() -> void:
	for b in buttons:
		b.set_flashing(false)
		
func set_active(value: bool) -> void:
	for b in buttons:
		b.set_active(value)

func select(dir: int) -> void:
	if dir == selected:
		return
	selected = dir
	_refresh_buttons()
	switch_changed.emit(selected)

func _on_segment_changed(seg: TrackSegment) -> void:
	for b in buttons:
		b.set_available(seg != null and seg.has_exit(b.direction))

func _refresh_buttons() -> void:
	for b in buttons:
		b.set_selected(b.direction == selected)
