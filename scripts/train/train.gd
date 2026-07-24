extends Node2D

signal speed_changed(speed_ms: float, normalized: float)
signal rpm_changed(rpm: float)

@export var idle_rpm: float = 300.0
@export var max_rpm: float = 1800.0
@export var rpm_spool_rate: float = 400.0
@export var max_tractive_force: float = 220000.0

@export var mass: float = 120000.0 
@export var max_speed_ms: float = 33.0

@export var rolling_a: float = 2000.0 
@export var rolling_b: float = 300.0
@export var drag_c: float = 45.0 

@export var brake_force: float = 180000.0

var throttle_level: int = 0
var throttle_normalized: float = 0.0
var brake_normalized: float = 0.0

var rpm: float = 0.0
var speed_ms: float = 0.0  

var distance_m: float = 0.0

@onready var throttle: Area2D = $Throttle
@onready var speedometer: Area2D = $speedometer
@onready var map: Area2D = $map

func _ready() -> void:
	throttle.throttle_changed.connect(_on_throttle_changed)
	throttle.set_active(false)
	speedometer.set_active(false)
	map.set_active(false)
	rpm = idle_rpm

func _on_throttle_changed(level: int, normalized: float) -> void:
	throttle_level = level
	throttle_normalized = normalized

func _physics_process(delta: float) -> void:
	var target_rpm: float = lerpf(idle_rpm, max_rpm, throttle_normalized)
	rpm = move_toward(rpm, target_rpm, rpm_spool_rate * delta)

	var rpm_fraction: float = inverse_lerp(idle_rpm, max_rpm, rpm)
	var speed_falloff: float = 1.0 / (1.0 + speed_ms * 0.06)
	var tractive: float = max_tractive_force * rpm_fraction * speed_falloff

	var resistance: float = rolling_a + rolling_b * speed_ms + drag_c * speed_ms * speed_ms
	if speed_ms <= 0.01:
		resistance = 0.0

	var braking: float = brake_force * brake_normalized

	var net_force: float = tractive - resistance - braking
	var accel: float = net_force / mass

	speed_ms = maxf(0.0, speed_ms + accel * delta)
	distance_m += speed_ms * delta

	speed_changed.emit(speed_ms, clampf(speed_ms / max_speed_ms, 0.0, 1.0))
	rpm_changed.emit(rpm)
