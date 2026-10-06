class_name UpgradeTree
extends Control
## 魔導樹の画面。強化ノードを並べ、選んだノードの説明・費用と「何発で壊れるか」の変化を見せて買えるようにする。
## ステージを選んで START を押すと start_requested を出す。
## 魔導樹はピンチ（PC ではホイール）で拡大し、ドラッグで動かせる。
## 左下のボタンで、ランでの移動（スティック／タップ移動）と BGM のオン/オフを切り替える（設定は保存する）。

signal start_requested(stage_index: int)

const CELL_SIZE := Vector2(126, 112)
const NODE_SIZE := Vector2(116, 64)
const SIDE_WIDTH := 456.0
const HEADER_HEIGHT := 64.0
const FOOTER_HEIGHT := 56.0
const BG_COLOR := Color(0.16, 0.36, 0.86)
const STRIPE_COLOR := Color(0.2, 0.42, 0.93)
const STRIPE_WIDTH := 48.0
const LINE_ON := Color(1.0, 0.82, 0.2)
const LINE_OFF := Color(0.1, 0.18, 0.45)
const SELECT_COLOR := Color(1, 1, 1)
const MAXED_COLOR := Color(1.0, 0.72, 0.1)
const READY_COLOR := Color(0.3, 0.85, 0.3)
const OPEN_COLOR := Color(0.45, 0.55, 0.85)
const LOCKED_COLOR := Color(0.24, 0.27, 0.42)
const LOCKED_TEXT := Color(0.62, 0.65, 0.78)
const POP_COLOR := Color(1.0, 0.85, 0.3)
const POP_TIME := 1.1
const ZOOM_MIN := 1.0
const ZOOM_MAX := 2.6
const WHEEL_ZOOM_STEP := 1.15
## これ以上指が動いたらドラッグとみなし、ノードを押したことにしない（画面上の点）
const DRAG_THRESHOLD := 14.0

var _buttons: Dictionary = {}
var _tree_origin := Vector2.ZERO
var _styles: Dictionary = {}
var _selected: UpgradeDef
var _reset_armed := false
var _zoom := 1.0
var _pan := Vector2.ZERO
var _touches: Dictionary = {}
var _drag_distance := 0.0

@onready var _clip: Control = $TreeClip
@onready var _nodes: Control = $TreeClip/Nodes
@onready var _material_label: Label = $MaterialLabel
@onready var _name_label: Label = $Side/Detail/Box/Name
@onready var _level_label: Label = $Side/Detail/Box/Level
@onready var _desc_label: Label = $Side/Detail/Box/Desc
@onready var _cost_label: Label = $Side/Detail/Box/Cost
@onready var _preview_label: Label = $Side/Detail/Box/Preview
@onready var _buy_button: Button = $Side/Detail/Box/BuyButton
@onready var _stage_label: Label = $Side/StagePanel/Box/Row/StageLabel
@onready var _prev_button: Button = $Side/StagePanel/Box/Row/PrevButton
@onready var _next_button: Button = $Side/StagePanel/Box/Row/NextButton
@onready var _stage_info: Label = $Side/StagePanel/Box/StageInfo
@onready var _start_button: Button = $Side/StagePanel/Box/StartButton
@onready var _reset_button: Button = $ResetButton
@onready var _move_button: Button = $MoveButton
@onready var _bgm_button: Button = $BgmButton


func _ready() -> void:
	for color: Color in [MAXED_COLOR, READY_COLOR, OPEN_COLOR, LOCKED_COLOR]:
		_styles[color] = _make_style(color)
	for def in Progress.upgrades:
		var button := Button.new()
		button.size = NODE_SIZE
		button.pivot_offset = NODE_SIZE * 0.5
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_on_node_pressed.bind(def))
		button.position = _cell_center(def) - NODE_SIZE * 0.5
		_nodes.add_child(button)
		_buttons[def.id] = button
	_apply_styles()
	_buy_button.pressed.connect(_on_buy_pressed)
	_prev_button.pressed.connect(_change_stage.bind(-1))
	_next_button.pressed.connect(_change_stage.bind(1))
	_start_button.pressed.connect(_on_start_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_move_button.pressed.connect(_on_move_pressed)
	_bgm_button.pressed.connect(_on_bgm_pressed)
	Progress.changed.connect(_refresh)
	resized.connect(_layout)
	_nodes.draw.connect(_draw_links)

	_selected = Progress.upgrades[0] if not Progress.upgrades.is_empty() else null
	for def in Progress.upgrades:
		if Progress.can_buy(def):
			_selected = def
			break
	_layout()
	_refresh()


func _apply_styles() -> void:
	UiStyle.button(_buy_button, UiStyle.GREEN)
	UiStyle.button(_start_button, UiStyle.YELLOW)
	UiStyle.button(_prev_button, UiStyle.BLUE)
	UiStyle.button(_next_button, UiStyle.BLUE)
	UiStyle.button(_reset_button, Color(0.85, 0.3, 0.3))
	UiStyle.button(_move_button, UiStyle.BLUE)
	UiStyle.button(_bgm_button, UiStyle.BLUE)
	for panel: PanelContainer in [$Side/Detail, $Side/StagePanel]:
		panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL, 16, 4, 6))
	for label: Label in [$Title, _material_label, _name_label, _level_label, _desc_label, _cost_label,
			_preview_label, _stage_label, _stage_info]:
		UiStyle.outline_label(label)


func _draw() -> void:
	# ブロスタのメニューのような斜めの縞
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	var stripes := ceili((size.x + size.y) / (STRIPE_WIDTH * 2.0))
	for i in stripes:
		var x := i * STRIPE_WIDTH * 2.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + STRIPE_WIDTH, 0),
				Vector2(x + STRIPE_WIDTH - size.y, size.y), Vector2(x - size.y, size.y)]), STRIPE_COLOR)


## ノード同士の線と選択枠。$TreeClip/Nodes の中に描くので、拡大・移動に一緒についてくる。
func _draw_links() -> void:
	for def in Progress.upgrades:
		if def.parent == &"" or Progress.upgrade(def.parent) == null:
			continue
		var color := LINE_ON if Progress.is_unlocked(def) else LINE_OFF
		var from := _cell_center(Progress.upgrade(def.parent))
		_nodes.draw_line(from, _cell_center(def), UiStyle.OUTLINE, 14.0)
		_nodes.draw_line(from, _cell_center(def), color, 7.0)
	if _selected != null:
		var rect := Rect2(_cell_center(_selected) - NODE_SIZE * 0.5, NODE_SIZE).grow(6.0)
		_nodes.draw_rect(rect.grow(3.0), UiStyle.OUTLINE, false, 4.0)
		_nodes.draw_rect(rect, SELECT_COLOR, false, 4.0)


## 魔導樹の中での位置（拡大前）。
func _cell_center(def: UpgradeDef) -> Vector2:
	return Vector2(def.cell) * CELL_SIZE + CELL_SIZE * 0.5


## 画面上の位置（拡大・移動後）。
func _node_center(def: UpgradeDef) -> Vector2:
	return _clip.position + _nodes.position + _cell_center(def) * _zoom


func _make_style(color: Color) -> StyleBoxFlat:
	return UiStyle.box(color, 12, 4, 5)


## 魔導樹を、右の説明欄を除いた場所の真ん中に置く。
func _layout() -> void:
	var area := _tree_area()
	_tree_origin = (area.position + (area.size - _tree_size()) * 0.5).max(Vector2(8.0, HEADER_HEIGHT))
	_apply_view()
	queue_redraw()


func _tree_size() -> Vector2:
	var cells := Vector2i.ONE
	for def in Progress.upgrades:
		cells = cells.max(def.cell + Vector2i.ONE)
	return Vector2(cells) * CELL_SIZE


## 魔導樹を置く場所（右の説明欄と上下の帯を除いたところ）。
func _tree_area() -> Rect2:
	return Rect2(0.0, HEADER_HEIGHT, size.x - SIDE_WIDTH, size.y - HEADER_HEIGHT - FOOTER_HEIGHT)


## 拡大率と移動量を $TreeClip/Nodes に反映する。木の真ん中が置き場所から出ないように抑える。
## 置き場所の外にはみ出した部分は $TreeClip で切る。
func _apply_view() -> void:
	var area := _tree_area()
	_clip.position = area.position
	_clip.size = area.size
	var half := _tree_size() * 0.5
	var center := _tree_origin + half + _pan
	var limit := (half * _zoom - area.size * 0.5).max(Vector2.ZERO)
	var area_center := area.get_center()
	center = center.clamp(area_center - limit, area_center + limit) if _zoom > ZOOM_MIN else _tree_origin + half
	_pan = center - _tree_origin - half
	_nodes.scale = Vector2.ONE * _zoom
	_nodes.position = center - half * _zoom - area.position


## 画面上の点 focus を動かさずに拡大率を変える。
func _zoom_at(focus: Vector2, zoom: float) -> void:
	var new_zoom := clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	var local := (focus - _clip.position - _nodes.position) / _zoom
	var new_position := focus - local * new_zoom
	_zoom = new_zoom
	_pan = new_position + _tree_size() * 0.5 * _zoom - _tree_origin - _tree_size() * 0.5
	_apply_view()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var at := touch.position - global_position
		if touch.pressed:
			if not _tree_area().has_point(at):
				return
			if _touches.is_empty():
				_drag_distance = 0.0
			_touches[touch.index] = at
		else:
			_touches.erase(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _touches.has(drag.index):
			return
		var at := drag.position - global_position
		if _touches.size() >= 2:
			var other: Vector2 = _touches[_touches.keys().filter(func(i: int) -> bool: return i != drag.index)[0]]
			var before := other.distance_to(_touches[drag.index])
			var after := other.distance_to(at)
			if before > 1.0:
				_zoom_at((other + at) * 0.5, _zoom * after / before)
			_drag_distance = DRAG_THRESHOLD + 1.0
		else:
			_drag_distance += drag.relative.length()
			if _drag_distance > DRAG_THRESHOLD:
				_pan += drag.relative
				_apply_view()
		_touches[drag.index] = at
	elif event is InputEventMouseButton:
		var wheel := event as InputEventMouseButton
		var at := wheel.position - global_position
		if not wheel.pressed or not _tree_area().has_point(at):
			return
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(at, _zoom * WHEEL_ZOOM_STEP)
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(at, _zoom / WHEEL_ZOOM_STEP)


func _refresh() -> void:
	_material_label.text = "宝石 %d　　木材 %d" % [Progress.gem, Progress.wood]
	for def in Progress.upgrades:
		var button: Button = _buttons[def.id]
		button.text = "%s\n%d/%d" % [def.name, Progress.level(def.id), def.max_level]
		var color := OPEN_COLOR
		if Progress.is_maxed(def):
			color = MAXED_COLOR
		elif not Progress.is_unlocked(def):
			color = LOCKED_COLOR
		elif Progress.can_buy(def):
			color = READY_COLOR
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, _styles[color])
		var text_color := LOCKED_TEXT if color == LOCKED_COLOR else Color.WHITE
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(state, text_color)
		button.add_theme_color_override("font_outline_color", UiStyle.OUTLINE)
		button.add_theme_constant_override("outline_size", 6 if color != LOCKED_COLOR else 0)
	_refresh_detail()
	_refresh_stage()
	_move_button.text = "移動: タップ" if Progress.tap_move else "移動: スティック"
	_bgm_button.text = "BGM: オン" if Progress.bgm_on else "BGM: オフ"
	_nodes.queue_redraw()


func _refresh_detail() -> void:
	if _selected == null:
		return
	var def := _selected
	_name_label.text = def.name
	_level_label.text = "Lv %d / %d" % [Progress.level(def.id), def.max_level]
	_desc_label.text = def.description()
	if Progress.is_maxed(def):
		_cost_label.text = "最大まで覚えた"
	elif not Progress.is_unlocked(def):
		_cost_label.text = "先に「%s」を覚える" % Progress.upgrade(def.parent).name
	else:
		var cost := Progress.next_cost(def)
		var parts := PackedStringArray()
		if cost.x > 0 or cost.y == 0:
			parts.append("宝石 %d" % cost.x)
		if cost.y > 0:
			parts.append("木材 %d" % cost.y)
		_cost_label.text = "必要: " + "　".join(parts)
	_preview_label.text = "\n".join(_hit_lines(def))
	_buy_button.disabled = not Progress.can_buy(def)


## 選んだステージで「この強化を買うと何発で壊れるようになるか」を並べる。
func _hit_lines(def: UpgradeDef) -> PackedStringArray:
	var lines := PackedStringArray()
	if Progress.is_maxed(def):
		return lines
	var now := Progress.levels
	var after := Stats.with_level(now, def.id, 1)
	for target in _stage_targets():
		var before_hits := Stats.hits_to_break(target[0], target[2], now)
		var after_hits := Stats.hits_to_break(target[0], target[2], after)
		if before_hits != after_hits:
			lines.append("%s: %d発 → %d発" % [target[1], before_hits, after_hits])
	if not lines.is_empty():
		lines.insert(0, "%sでは:" % Progress.stages[Progress.selected_stage].name)
	var stats_before := _stat_texts(now)
	var stats_after := _stat_texts(after)
	for label in stats_before:
		if stats_before[label] != stats_after[label]:
			lines.append("%s: %s → %s" % [label, stats_before[label], stats_after[label]])
	return lines


## 発数以外で強化によって変わる数値（活動時間・攻撃間隔・射程）を表示用の文字にする。
func _stat_texts(levels: Dictionary) -> Dictionary:
	return {
		"活動時間": "%d秒" % roundi(Stats.run_time(levels)),
		"発射間隔": "%.2f秒" % Stats.fire_interval(levels),
		"射程": "%d" % roundi(Stats.fire_range(levels)),
	}


## 選んだステージに出る物の [種類, 表示名, 耐久] の一覧。
func _stage_targets() -> Array:
	var stage := Progress.stages[Progress.selected_stage]
	var targets := []
	if stage.slime_count > 0:
		targets.append([Stats.SLIME, "スライム", stage.slime_hp])
	if stage.oak_count > 0:
		targets.append([Stats.OAK, "木", stage.oak_hp])
	targets.append([Stats.SLIME, "ボス", stage.boss_hp])
	return targets


func _refresh_stage() -> void:
	var stage := Progress.stages[Progress.selected_stage]
	_stage_label.text = stage.name
	_prev_button.disabled = Progress.selected_stage <= 0
	_next_button.disabled = Progress.selected_stage >= Progress.unlocked_stage
	var parts := PackedStringArray()
	for target in _stage_targets():
		parts.append("%s %d発" % [target[1], Stats.hits_to_break(target[0], target[2], Progress.levels)])
	_stage_info.text = "　".join(parts) + "\n%d体倒すとボス。%d秒以内に倒せばクリア" \
			% [stage.boss_after, roundi(Stats.run_time(Progress.levels))]


func _on_node_pressed(def: UpgradeDef) -> void:
	if _drag_distance > DRAG_THRESHOLD:
		return
	Sfx.play(&"click")
	_selected = def
	_refresh()


func _on_buy_pressed() -> void:
	var def := _selected
	if def == null:
		return
	var before: Array[int] = []
	for target in _stage_targets():
		before.append(Stats.hits_to_break(target[0], target[2], Progress.levels))
	var stats_before := _stat_texts(Progress.levels)
	if not Progress.buy(def):
		Sfx.play(&"deny")
		return
	Sfx.play(&"buy")
	var text := "覚えた！"
	var stats_after := _stat_texts(Progress.levels)
	for label: String in stats_before:
		if stats_before[label] != stats_after[label]:
			text = "%s %s → %s！" % [label, stats_before[label], stats_after[label]]
	var targets := _stage_targets()
	for i in targets.size():
		var after := Stats.hits_to_break(targets[i][0], targets[i][2], Progress.levels)
		if after != before[i]:
			text = "%s %d発 → %d発！" % [targets[i][1], before[i], after]
			break
	var button: Button = _buttons[def.id]
	_pop(text, _node_center(def) + Vector2(0, -NODE_SIZE.y * 0.5))
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * 1.25, 0.08)
	tween.tween_property(button, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


## 買った瞬間に、ノードの上へ大きな文字を飛び出させる。
func _pop(text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", POP_COLOR)
	label.add_theme_color_override("font_outline_color", UiStyle.OUTLINE)
	label.add_theme_constant_override("outline_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var label_size := label.get_minimum_size()
	label.position = Vector2(clampf(at.x - label_size.x * 0.5, 8.0, size.x - label_size.x - 8.0), at.y - label_size.y)
	label.pivot_offset = label_size * 0.5
	label.scale = Vector2.ONE * 0.4
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 40.0, POP_TIME * 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, POP_TIME * 0.6).set_delay(POP_TIME * 0.2)
	tween.tween_callback(label.queue_free)


func _change_stage(step: int) -> void:
	Sfx.play(&"click")
	Progress.selected_stage = clampi(Progress.selected_stage + step, 0, Progress.unlocked_stage)
	_refresh()


func _on_start_pressed() -> void:
	Sfx.play(&"click")
	Progress.save()
	start_requested.emit(Progress.selected_stage)


func _on_move_pressed() -> void:
	Sfx.play(&"click")
	Progress.set_tap_move(not Progress.tap_move)


func _on_bgm_pressed() -> void:
	Sfx.play(&"click")
	Progress.set_bgm_on(not Progress.bgm_on)


func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "もう一度押すと消去"
		return
	_reset_armed = false
	_reset_button.text = "最初からやり直す"
	Progress.reset()
