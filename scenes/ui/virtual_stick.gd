class_name VirtualStick
extends Control
## 移動の入力。画面の左半分に触れた場所に出る仮想スティック。
## value は長さ 0〜1 の向き（触れていないときは Vector2.ZERO）。
## tap_mode のときはスティックの代わりに、触れた場所（指を動かせば追いかける）を目的地 target にする。
## PC ではマウスのドラッグでも操作できる（project.godot でタッチを模倣している）。

const RADIUS := 90.0
const KNOB_RADIUS := 36.0
const DEAD_ZONE := 0.15
const MARKER_RADIUS := 18.0
const MARKER_COLOR := Color(1, 1, 1, 0.8)

var value := Vector2.ZERO
## 生成する側が入れる。tap_mode のとき、ここに入る場所（ボタンなど）への接触は無視する
var tap_mode := false
var blockers: Array[Control] = []
## タップ移動の目的地（画面の座標）。has_target が false なら目的地なし
var target := Vector2.ZERO
var has_target := false

var _touch_index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO


## 目的地に着いたら移動する側が呼ぶ。
func clear_target() -> void:
	has_target = false
	queue_redraw()


func _input(event: InputEvent) -> void:
	if tap_mode:
		_tap_input(event)
		return
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


func _tap_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and not _is_blocked(touch.position):
			_touch_index = touch.index
			_set_target(touch.position)
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_set_target(drag.position)


func _set_target(at: Vector2) -> void:
	target = at
	has_target = true
	queue_redraw()


func _is_blocked(at: Vector2) -> bool:
	for control in blockers:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(at):
			return true
	return false


func _draw() -> void:
	if tap_mode:
		if has_target:
			draw_arc(target, MARKER_RADIUS, 0.0, TAU, 32, MARKER_COLOR, 4.0)
			draw_circle(target, 5.0, MARKER_COLOR)
		return
	if _touch_index == -1:
		return
	draw_circle(_origin, RADIUS, Color(1, 1, 1, 0.12))
	draw_arc(_origin, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
	draw_circle(_knob, KNOB_RADIUS, Color(1, 1, 1, 0.6))
