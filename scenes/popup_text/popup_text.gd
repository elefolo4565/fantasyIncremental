class_name PopupText
extends Node2D
## 少し浮き上がって消える文字（「+3」など、見た目だけ）。

const LIFETIME := 0.8
const RISE := 50.0
const WIDTH := 160.0

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
	var at := Vector2(-WIDTH * 0.5, -RISE * t)
	var font := ThemeDB.fallback_font
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, WIDTH, font_size, 6, Color(0, 0, 0, 0.7 * (1.0 - t)))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, WIDTH, font_size, Color(color, 1.0 - t * t))
