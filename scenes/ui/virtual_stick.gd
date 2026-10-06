class_name VirtualStick
extends Control
## 画面の左半分に触れた場所に出る仮想スティック。
## value は長さ 0〜1 の向き（触れていないときは Vector2.ZERO）。
## PC ではマウスのドラッグでも操作できる（project.godot でタッチを模倣している）。

const RADIUS := 90.0
const KNOB_RADIUS := 36.0
const DEAD_ZONE := 0.15

var value := Vector2.ZERO

var _touch_index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and touch.position.x < size.x * 0.5:
			_touch_index = touch.index
			_origin = touch.position
			_knob = touch.position
			value = Vector2.ZERO
			queue_redraw()
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			value = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _touch_index:
			return
		var offset := (drag.position - _origin).limit_length(RADIUS)
		_knob = _origin + offset
		value = offset / RADIUS
		if value.length() < DEAD_ZONE:
			value = Vector2.ZERO
		queue_redraw()


func _draw() -> void:
	if _touch_index == -1:
		return
	draw_circle(_origin, RADIUS, Color(1, 1, 1, 0.12))
	draw_arc(_origin, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
	draw_circle(_knob, KNOB_RADIUS, Color(1, 1, 1, 0.6))
