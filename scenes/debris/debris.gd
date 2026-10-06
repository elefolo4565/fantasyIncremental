class_name Debris
extends Node2D
## 物が壊れたときの破片（見た目だけ）。wave を true にすると衝撃波の輪も描く。

const LIFETIME := 0.45
const PIECES := 9
const SPEED_MIN := 120.0
const SPEED_MAX := 320.0
const PIECE_RADIUS := 6.0

var color := Color.WHITE
var wave_radius := 0.0

var _time := 0.0
var _velocities: Array[Vector2] = []


func _ready() -> void:
	for _i in PIECES:
		_velocities.append(Vector2.RIGHT.rotated(randf() * TAU) * randf_range(SPEED_MIN, SPEED_MAX))


func _process(delta: float) -> void:
	_time += delta
	if _time >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _time / LIFETIME
	var fade := Color(color, 1.0 - t)
	for velocity in _velocities:
		draw_circle(velocity * _time, PIECE_RADIUS * (1.0 - t * 0.6), fade)
	if wave_radius > 0.0:
		draw_arc(Vector2.ZERO, wave_radius * t, 0.0, TAU, 40, Color(1, 0.9, 0.6, 1.0 - t), 4.0)
