extends Node2D

@export var train_path: NodePath
@export var pixels_per_meter: float = 16.0

func _ready() -> void:
	var train := get_node(train_path)
	train.speed_changed.connect(_on_speed_changed)

var current_speed: float = 0.0

func _on_speed_changed(speed_ms: float, _n: float) -> void:
	current_speed = speed_ms

func _physics_process(delta: float) -> void:
	position.y += current_speed * pixels_per_meter * delta
