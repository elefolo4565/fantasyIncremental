class_name UpgradeTree
extends Control
## 魔導樹の画面。中央の核から攻撃・生命・収益の3軸が放射状に伸び、強化ノードが並ぶ。
## ノードは丸いアイコンと段（1/5 など）だけで見せ、名前・説明・費用は選んだときに右の欄に出して買えるようにする。
## ステージを選んで START を押すと start_requested を出す。
## 魔導樹はピンチ（PC ではホイール）で拡大し、ドラッグで動かせる。背景には、核を幹にした世界樹（攻撃の側が葉、生命・収益の側が根）を描く。
## 左下のボタンで、ランでの移動（スティック／タップ移動）と BGM のオン/オフを切り替える（設定は保存する）。

signal start_requested(stage_index: int)

## 中心からノード1段ぶんの距離
const RING_SPACING := 105.0
const NODE_SIZE := Vector2(72, 72)
## ノードの中のアイコンの半径・軸の色の輪の半径と太さ
const ICON_RADIUS := 19.0
const AXIS_RING_RADIUS := 29.0
const AXIS_RING_WIDTH := 4.0
## 段を出す札の大きさと文字の大きさ
const BADGE_SIZE := Vector2(44, 20)
const BADGE_FONT_SIZE := 14
const LOCKED_ICON_TINT := Color(0.55, 0.58, 0.7)
const TREE_MARGIN := 24.0
const CORE_RADIUS := 30.0
const CORE_COLOR := Color(0.95, 0.97, 1.0)
## 軸ごとの [向き（度、右が0で時計回り）, 色, 名前]
const AXES := {
	&"attack": [-90.0, Color(1.0, 0.48, 0.27), "攻撃"],
	&"life": [150.0, Color(0.31, 0.85, 0.48), "生命"],
	&"income": [30.0, Color(1.0, 0.8, 0.2), "収益"],
}
const AXIS_LABEL_SIZE := 30
const RING_COLOR := Color(1, 1, 1, 0.12)
## 背景の世界樹の色
const WOOD_DARK := Color(0.3, 0.19, 0.12)
const WOOD_LIGHT := Color(0.46, 0.3, 0.18)
const LEAF_DARK := Color(0.1, 0.36, 0.22)
const LEAF_LIGHT := Color(0.2, 0.55, 0.3)
const LEAF_GLOW := Color(0.55, 0.9, 0.5, 0.18)
## 葉のかたまり [中心（核から、RING_SPACING 単位）, 半径（同じ単位）]
const CANOPY := [
	[Vector2(0.0, -2.7), 1.9], [Vector2(-1.6, -2.2), 1.35], [Vector2(1.6, -2.2), 1.35],
	[Vector2(-1.1, -3.5), 1.3], [Vector2(1.1, -3.5), 1.3], [Vector2(0.0, -4.2), 1.15],
	[Vector2(-2.5, -1.4), 0.95], [Vector2(2.5, -1.4), 0.95], [Vector2(-2.6, -3.0), 0.9],
	[Vector2(2.6, -3.0), 0.9],
]
## 太い枝と根 [向き（度）, 長さ（RING_SPACING 単位）, 曲がり具合, 根元の太さ（ピクセル）]
const LIMBS := [
	[-90.0, 3.4, 0.0, 34.0], [-128.0, 2.9, -0.35, 22.0], [-52.0, 2.9, 0.35, 22.0],
	[-160.0, 2.4, -0.3, 16.0], [-20.0, 2.4, 0.3, 16.0],
]
const ROOTS := [
	[150.0, 4.2, 0.25, 40.0], [30.0, 4.2, -0.25, 40.0], [118.0, 3.3, -0.3, 24.0],
	[62.0, 3.3, 0.3, 24.0], [172.0, 3.0, 0.3, 18.0], [8.0, 3.0, -0.3, 18.0], [90.0, 2.4, 0.0, 22.0],
]
const LIMB_STEPS := 14
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
const ZOOM_MAX := 2.2
const WHEEL_ZOOM_STEP := 1.15
## これ以上指が動いたらドラッグとみなし、ノードを押したことにしない（画面上の点）
const DRAG_THRESHOLD := 14.0

var _buttons: Dictionary = {}
## 放射状の座標（核が原点）で、全ノードと軸の名前を囲む四角
var _bounds := Rect2()
var _max_ring := 1
var _styles: Dictionary = {}
var _badge_style: StyleBoxFlat
var _selected: UpgradeDef
var _reset_armed := false
var _zoom := 1.0
## 魔導樹の置き場所の真ん中に来る、魔導樹の中の点（拡大前）
var _view_center := Vector2.ZERO
var _view_ready := false
## 魔導樹全体が置き場所に収まる拡大率（これより小さくはしない）
var _zoom_min := 1.0
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
@onready var _se_button: Button = $SeButton


func _ready() -> void:
	for color: Color in [MAXED_COLOR, READY_COLOR, OPEN_COLOR, LOCKED_COLOR]:
		_styles[color] = _make_style(color)
	_badge_style = UiStyle.box(UiStyle.OUTLINE, int(BADGE_SIZE.y * 0.5), 0, 0)
	_badge_style.set_content_margin_all(0.0)
	_compute_bounds()
	# 線は $TreeClip/Nodes に描く。Control は自分の大きさの外を描いても、その四角が画面から外れると
	# 丸ごと描かれなくなるので、魔導樹全体の大きさにしておく（拡大すると枝が消える不具合の対策）。
	_nodes.size = _tree_size()
	for def in Progress.upgrades:
		var button := Button.new()
		button.size = NODE_SIZE
		button.pivot_offset = NODE_SIZE * 0.5
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_node_pressed.bind(def))
		button.draw.connect(_draw_node.bind(button, def))
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
	_se_button.pressed.connect(_on_se_pressed)
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
	UiStyle.button(_se_button, UiStyle.BLUE)
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


## ノード同士の線・軸の名前・選択枠。$TreeClip/Nodes の中に描くので、拡大・移動に一緒についてくる。
func _draw_links() -> void:
	var core := _core()
	_draw_world_tree(core)
	for ring in range(1, _max_ring + 1):
		_nodes.draw_arc(core, ring * RING_SPACING, 0.0, TAU, 96, RING_COLOR, 3.0)
	var font := ThemeDB.fallback_font
	for axis: StringName in AXES:
		var at := core + _direction(axis, 0.0) * (_max_ring + 0.8) * RING_SPACING
		var width := 160.0
		var origin := at + Vector2(-width * 0.5, AXIS_LABEL_SIZE * 0.35)
		_nodes.draw_string_outline(font, origin, AXES[axis][2], HORIZONTAL_ALIGNMENT_CENTER, width,
				AXIS_LABEL_SIZE, 10, UiStyle.OUTLINE)
		_nodes.draw_string(font, origin, AXES[axis][2], HORIZONTAL_ALIGNMENT_CENTER, width, AXIS_LABEL_SIZE,
				AXES[axis][1])
	for def in Progress.upgrades:
		var parent := Progress.upgrade(def.parent)
		var from := core if parent == null else _cell_center(parent)
		var color: Color = _axis_color(def) if Progress.is_unlocked(def) else LINE_OFF
		_nodes.draw_line(from, _cell_center(def), UiStyle.OUTLINE, 14.0)
		_nodes.draw_line(from, _cell_center(def), color, 7.0)
	_nodes.draw_circle(core, CORE_RADIUS + 4.0, UiStyle.OUTLINE)
	_nodes.draw_circle(core, CORE_RADIUS, CORE_COLOR)
	if _selected != null:
		var radius := NODE_SIZE.x * 0.5 + 8.0
		_nodes.draw_arc(_cell_center(_selected), radius, 0.0, TAU, 48, UiStyle.OUTLINE, 10.0, true)
		_nodes.draw_arc(_cell_center(_selected), radius, 0.0, TAU, 48, SELECT_COLOR, 5.0, true)


## ノード1つの中身（軸の色の輪・アイコン・段の札）。ボタンの丸い下地の上に描く。
func _draw_node(button: Button, def: UpgradeDef) -> void:
	var center := NODE_SIZE * 0.5
	var unlocked := Progress.is_unlocked(def)
	var axis_color := _axis_color(def) if unlocked else LOCKED_COLOR.lightened(0.15)
	button.draw_arc(center, AXIS_RING_RADIUS, 0.0, TAU, 40, axis_color, AXIS_RING_WIDTH, true)
	SkillIcon.draw(button, def.icon, center, ICON_RADIUS, Color.WHITE if unlocked else LOCKED_ICON_TINT)
	var badge := Rect2(Vector2(center.x - BADGE_SIZE.x * 0.5, NODE_SIZE.y - BADGE_SIZE.y * 0.6), BADGE_SIZE)
	button.draw_style_box(_badge_style, badge)
	var text := "%d/%d" % [Progress.level(def.id), def.max_level]
	var font := ThemeDB.fallback_font
	var baseline := badge.position + Vector2(0, (badge.size.y + BADGE_FONT_SIZE * 0.7) * 0.5)
	var text_color := MAXED_COLOR if Progress.is_maxed(def) else (Color.WHITE if unlocked else LOCKED_TEXT)
	button.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, BADGE_FONT_SIZE, text_color)


## 背景の世界樹。核が幹の真ん中で、上に枝と葉、下に根が広がる。
func _draw_world_tree(core: Vector2) -> void:
	for root: Array in ROOTS:
		_draw_limb(core, root, WOOD_DARK)
	for limb: Array in LIMBS:
		_draw_limb(core + Vector2(0, -RING_SPACING * 0.6), limb, WOOD_DARK)
	for blob: Array in CANOPY:
		_nodes.draw_circle(core + blob[0] * RING_SPACING, blob[1] * RING_SPACING, LEAF_DARK)
	for blob: Array in CANOPY:
		var radius: float = blob[1] * RING_SPACING
		_nodes.draw_circle(core + blob[0] * RING_SPACING + Vector2(-0.12, -0.15) * radius, radius * 0.78, LEAF_LIGHT)
	for blob: Array in CANOPY:
		var radius: float = blob[1] * RING_SPACING
		_nodes.draw_circle(core + blob[0] * RING_SPACING + Vector2(-0.3, -0.35) * radius, radius * 0.3, LEAF_GLOW)
	# 幹（根元は太く、葉の中へ細くなる）
	var trunk := PackedVector2Array([
		core + Vector2(-48, 40), core + Vector2(-26, -RING_SPACING * 1.6),
		core + Vector2(26, -RING_SPACING * 1.6), core + Vector2(48, 40)])
	_nodes.draw_colored_polygon(trunk, WOOD_DARK)
	_nodes.draw_colored_polygon(PackedVector2Array([trunk[0] + Vector2(14, 0), trunk[1] + Vector2(8, 0),
			trunk[1] + Vector2(22, 0), trunk[0] + Vector2(40, 0)]), WOOD_LIGHT)


## from から伸びる、先へ行くほど細くなる曲がった枝（根）を描く。spec は LIMBS / ROOTS の1行。
func _draw_limb(from: Vector2, spec: Array, color: Color) -> void:
	var direction := Vector2.RIGHT.rotated(deg_to_rad(spec[0]))
	var to: Vector2 = from + direction * float(spec[1]) * RING_SPACING
	var bend: Vector2 = direction.orthogonal() * float(spec[2]) * float(spec[1]) * RING_SPACING
	var control := (from + to) * 0.5 + bend
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in LIMB_STEPS + 1:
		var t := float(i) / LIMB_STEPS
		var point := from.lerp(control, t).lerp(control.lerp(to, t), t)
		var tangent := (control - from).lerp(to - control, t).normalized()
		var half := lerpf(float(spec[3]), 3.0, t)
		left.append(point + tangent.orthogonal() * half)
		right.append(point - tangent.orthogonal() * half)
	right.reverse()
	_nodes.draw_colored_polygon(left + right, color)


func _axis_color(def: UpgradeDef) -> Color:
	return AXES[def.axis][1] if AXES.has(def.axis) else LINE_ON


## 軸の向きから degrees だけずらした向き。
func _direction(axis: StringName, degrees: float) -> Vector2:
	var base: float = AXES[axis][0] if AXES.has(axis) else 0.0
	return Vector2.RIGHT.rotated(deg_to_rad(base + degrees))


## 核を原点にしたノードの位置。
func _radial(def: UpgradeDef) -> Vector2:
	return _direction(def.axis, def.angle) * def.ring * RING_SPACING


func _compute_bounds() -> void:
	_bounds = Rect2(Vector2.ZERO, Vector2.ZERO).grow(CORE_RADIUS)
	for def in Progress.upgrades:
		_max_ring = maxi(_max_ring, def.ring)
		_bounds = _bounds.merge(Rect2(_radial(def) - NODE_SIZE * 0.5, NODE_SIZE))
	for axis: StringName in AXES:
		var at := _direction(axis, 0.0) * (_max_ring + 0.8) * RING_SPACING
		_bounds = _bounds.merge(Rect2(at - Vector2(80, AXIS_LABEL_SIZE), Vector2(160, AXIS_LABEL_SIZE * 2)))
	_bounds = _bounds.grow(TREE_MARGIN)


## 魔導樹の中での核の位置（拡大前）。
func _core() -> Vector2:
	return -_bounds.position


## 魔導樹の中での位置（拡大前）。
func _cell_center(def: UpgradeDef) -> Vector2:
	return _radial(def) - _bounds.position


## 画面上の位置（拡大・移動後）。
func _node_center(def: UpgradeDef) -> Vector2:
	return _clip.position + _nodes.position + _cell_center(def) * _zoom


func _make_style(color: Color) -> StyleBoxFlat:
	return UiStyle.box(color, int(NODE_SIZE.x * 0.5), 4, 5)


## 最初は核を真ん中にして等倍で見せる。ピンチで縮めると全体が見える。
func _layout() -> void:
	var area := _tree_area()
	var tree := _tree_size()
	_zoom_min = minf(minf(area.size.x / tree.x, area.size.y / tree.y), 1.0)
	if not _view_ready:
		_view_ready = true
		_view_center = _core()
	_zoom = clampf(_zoom, _zoom_min, ZOOM_MAX)
	_apply_view()
	queue_redraw()


func _tree_size() -> Vector2:
	return _bounds.size


## 魔導樹を置く場所（右の説明欄と上下の帯を除いたところ）。
func _tree_area() -> Rect2:
	return Rect2(0.0, HEADER_HEIGHT, size.x - SIDE_WIDTH, size.y - HEADER_HEIGHT - FOOTER_HEIGHT)


## 拡大率と見ている場所を $TreeClip/Nodes に反映する。魔導樹の外ばかり映らないように抑える。
## 置き場所の外にはみ出した部分は $TreeClip で切る。
func _apply_view() -> void:
	var area := _tree_area()
	_clip.position = area.position
	_clip.size = area.size
	var tree := _tree_size()
	var half_view := area.size * 0.5 / _zoom
	for i in 2:
		if half_view[i] * 2.0 >= tree[i]:
			_view_center[i] = tree[i] * 0.5
		else:
			_view_center[i] = clampf(_view_center[i], half_view[i], tree[i] - half_view[i])
	_nodes.scale = Vector2.ONE * _zoom
	_nodes.position = area.size * 0.5 - _view_center * _zoom


## 画面上の点 focus を動かさずに拡大率を変える。
func _zoom_at(focus: Vector2, zoom: float) -> void:
	var new_zoom := clampf(zoom, _zoom_min, ZOOM_MAX)
	var local := (focus - _clip.position - _nodes.position) / _zoom
	var new_position := focus - _clip.position - local * new_zoom
	_zoom = new_zoom
	_view_center = (_clip.size * 0.5 - new_position) / _zoom
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
				_view_center -= drag.relative / _zoom
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
		var color := OPEN_COLOR
		if Progress.is_maxed(def):
			color = MAXED_COLOR
		elif not Progress.is_unlocked(def):
			color = LOCKED_COLOR
		elif Progress.can_buy(def):
			color = READY_COLOR
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, _styles[color])
		button.queue_redraw()
	_refresh_detail()
	_refresh_stage()
	_move_button.text = "移動: タップ" if Progress.tap_move else "移動: スティック"
	_bgm_button.text = "BGM: オン" if Progress.bgm_on else "BGM: オフ"
	_se_button.text = "効果音: オン" if Progress.se_on else "効果音: オフ"
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
	_preview_label.text = "\n".join(_change_lines(def))
	_buy_button.disabled = not Progress.can_buy(def)


## この強化を買うと変わる数値（体力・活動時間・攻撃間隔など）を並べる。
## 「何発で倒せるか」は出さない（ユーザー指示 2026-10-06）。
func _change_lines(def: UpgradeDef) -> PackedStringArray:
	var lines := PackedStringArray()
	if Progress.is_maxed(def):
		return lines
	var now := Progress.levels
	var after := Stats.with_level(now, def.id, 1)
	var stats_before := _stat_texts(now)
	var stats_after := _stat_texts(after)
	for label in stats_before:
		if stats_before[label] != stats_after[label]:
			lines.append("%s: %s → %s" % [label, stats_before[label], stats_after[label]])
	return lines


## 強化によって変わる数値（体力・活動時間・攻撃間隔など）を表示用の文字にする。
func _stat_texts(levels: Dictionary) -> Dictionary:
	return {
		"体力": "%d" % Stats.player_hp(levels),
		"無敵時間": "%.1f秒" % Stats.invincible_time(levels),
		"移動の速さ": "%d" % roundi(Stats.player_speed(levels)),
		"活動時間": "%d秒" % roundi(Stats.run_time(levels)),
		"発射間隔": "%.2f秒" % Stats.fire_interval(levels),
		"射程": "%d" % roundi(Stats.fire_range(levels)),
	}


## 選んだステージに出る物の [種類, 表示名, 耐久] の一覧。
func _stage_targets() -> Array:
	var stage := Progress.stages[Progress.selected_stage]
	var targets := []
	for entry in stage.enemies:
		var enemy := Progress.enemy(entry[0])
		if enemy != null:
			targets.append([Stats.MONSTER, enemy.name, enemy.hp_from(stage.enemy_hp)])
	if stage.oak_count > 0:
		targets.append([Stats.OAK, "木", stage.oak_hp])
	var boss := Progress.enemy(stage.boss)
	if boss != null:
		targets.append([Stats.MONSTER, "ボス", boss.hp_from(stage.boss_hp)])
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


func _on_se_pressed() -> void:
	Progress.set_se_on(not Progress.se_on)
	Sfx.play(&"click")


func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "もう一度押すと消去"
		return
	_reset_armed = false
	_reset_button.text = "最初からやり直す"
	Progress.reset()
