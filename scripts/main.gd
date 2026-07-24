extends Node2D

#@onready var marker: Node2D = $map/TrainMarker
#@onready var train_node: Node2D = $train

#func _ready() -> void:
	#train_node.speed_changed.connect(marker._on_speed_changed)
	#marker.switch_panel = train_node.get_node("SwitchPanel")
