class_name Debris
extends Node2D
## 物が壊れたときの演出（見た目だけ）。星形の閃光と、縁取りつきの破片が飛び散る。
## wave_radius を入れると衝撃波の輪も描く。

const LIFETIME := 0.5
const FLASH_TIME := 0.12
const PIECES := 10
const SPEED_MIN := 160.0
const SPEED_MAX := 380.0
const PIECE_RADIUS := 7.0
const STAR_POINTS := 8
const STAR_RADIUS := 56.0
const GRAVITY := 600.0

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
	if _time < FLASH_TIME:
		var k := 1.0 - _time / FLASH_TIME
		var star := PackedVector2Array()
		for i in STAR_POINTS * 2:
			var r := STAR_RADIUS * (1.0 if i % 2 == 0 else 0.4) * (1.2 - k * 0.4)
			star.append(Vector2.RIGHT.rotated(TAU * i / (STAR_POINTS * 2)) * r)
		draw_colored_polygon(star, Color(1, 1, 0.85, k))
	for velocity in _velocities:
		var at := velocity * _time + Vector2(0, GRAVITY * _time * _time * 0.5)
		var r := PIECE_RADIUS * (1.0 - t * 0.7)
		draw_circle(at, r + 2.5, Color(Toon.OUTLINE, 1.0 - t))
		draw_circle(at, r, Color(color, 1.0 - t))
	if wave_radius > 0.0:
		draw_arc(Vector2.ZERO, wave_radius * t, 0.0, TAU, 40, Color(1, 0.9, 0.5, 1.0 - t), 8.0 * (1.0 - t) + 2.0)
