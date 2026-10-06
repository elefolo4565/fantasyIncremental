class_name PopupText
extends Node2D
## 少し浮き上がって消える文字（「+3」など、見た目だけ）。

const LIFETIME := 0.8
const RISE := 50.0
const WIDTH := 260.0

var text := ""
var color := Color.WHITE
var font_size := 26

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	if _time >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _time / LIFETIME
	# 出た瞬間に少し大きく弾んでから、浮き上がって消える
	var pop := 1.0 + maxf(0.0, 0.35 - t) * 1.6
	draw_set_transform(Vector2(0, -RISE * t), 0.0, Vector2.ONE * pop)
	var fade := 1.0 - t * t
	var font := ThemeDB.fallback_font
	var at := Vector2(-WIDTH * 0.5, 0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, WIDTH, font_size, 10, Color(Toon.OUTLINE, fade))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, WIDTH, font_size, Color(color, fade))
