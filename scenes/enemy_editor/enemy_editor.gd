class_name EnemyEditor
extends Control
## 開発用の敵エディタ。data/enemies.csv の敵を選んで数値・動き・形・色を変え、その場で動きと3Dの見た目を確かめる。
## 左が一覧、中央が実際の動き（ゲームと同じ Monster をプレイヤー役と一緒に動かす）と3Dの見た目、右が数値。
## 変えた内容は CSV にして書き出す（エディタで開いたときは data/enemies.csv に保存、Web 版はダウンロードとコピー）。
## 書き出すまでの変更はこの端末に下書きとして残り、ゲームにも（再読み込みまで）反映される。

signal closed

const ENEMIES_PATH := "res://data/enemies.csv"
const DRAFT_PATH := "user://enemies_draft.csv"
const DOWNLOAD_NAME := "enemies.csv"
const DEFAULT_COLUMNS := ["id", "name", "move", "size", "hp_rate", "gem_rate", "speed_rate", "contact_damage",
		"golden", "model", "color", "angry_color", "memo"]
## 選べる動き（MonsterMove.create の名前）と、選べる仮モデルの形（MonsterModel の shape）
const MOVES := [[&"wander_chase", "うろつき、近づくと追う"], [&"dash", "ためて突進"], [&"chase", "ずっと追う（ボス向け）"]]
const MODELS := [[&"slime", "スライム"], [&"dasher", "角つき"], [&"king", "王冠つき"]]
const LOOKS := ["ふだん", "怒り顔", "金色"]
## 数値のつまみ: [項目, 表示名, 最小, 最大, 刻み]
const SLIDERS := [
	["size", "大きさ（半径）", 10.0, 150.0, 0.1],
	["hp_rate", "耐久の倍率", 0.1, 10.0, 0.05],
	["gem_rate", "宝石の倍率", 0.0, 10.0, 0.05],
	["speed_rate", "速さの倍率", 0.0, 3.0, 0.05],
	["contact_damage", "触れたときのダメージ", 0.0, 5.0, 1.0],
]
const GOLDEN_COLOR := Color(1.0, 0.82, 0.2)
## 画面の割り付け（見た目だけ）
const ARENA_POS := Vector2(232, 70)
const ARENA_SCALE := 0.45
const MODEL_RECT := Rect2(232, 422, 280, 282)
const INFO_RECT := Rect2(524, 422, 284, 282)
const LIST_RECT := Rect2(16, 70, 200, 400)
const STATUS_RECT := Rect2(16, 520, 200, 184)
const FORM_RECT := Rect2(824, 70, 440, 630)
const FLOOR_COLORS := [Color(0.55, 0.82, 0.36), Color(0.5, 0.76, 0.33)]
const TILE := 64.0
const TARGET_HIT_COLOR := Color(1.0, 0.35, 0.3)
## プレイヤー役が自動で回る円の半径と、1周の秒数（見た目だけ）
const PATROL_RADIUS := 260.0
const PATROL_TIME := 9.0
## 触ってプレイヤー役を動かしたあと、自動で回り始めるまでの秒数
const PATROL_RESUME := 3.0
const MODEL_TURN_SPEED := 0.8
const DRAFT_SAVE_DELAY := 0.8

var _defs: Array[EnemyDef] = []
var _columns: PackedStringArray = PackedStringArray(DEFAULT_COLUMNS)
var _index := 0
var _loading := false
var _draft_left := -1.0

var _list: ItemList
var _status: Label
var _info: Label
var _stage_pick: OptionButton
var _boss_check: CheckBox
var _look_pick: OptionButton
var _fields: Dictionary = {}

var _arena: SubViewport
var _target: Node2D
var _monster: Monster
var _patrol := 0.0
var _manual_left := 0.0
var _target_hit := 0.0

var _model_pivot: Node3D
var _model: MonsterModel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_layout()
	_load(true)


func _process(delta: float) -> void:
	_move_target(delta)
	if _model_pivot != null:
		_model_pivot.rotation.y += MODEL_TURN_SPEED * delta
	if _draft_left >= 0.0:
		_draft_left -= delta
		if _draft_left < 0.0:
			_save_text(DRAFT_PATH)


func _draw() -> void:
	draw_rect(get_viewport_rect(), Color(0.1, 0.11, 0.2))


# ---- 読み込みと書き出し ----

## data/enemies.csv（use_draft なら、あれば下書き）を読み込む。
func _load(use_draft: bool) -> void:
	var path := ENEMIES_PATH
	if use_draft and FileAccess.file_exists(DRAFT_PATH):
		path = DRAFT_PATH
	_columns = _read_header(path)
	_defs.clear()
	for row in Balance.load_table(path):
		_defs.append(EnemyDef.from_row(row))
	_index = clampi(_index, 0, maxi(_defs.size() - 1, 0))
	_apply_to_game()
	_refresh_list()
	_show_def()
	_set_status("下書きを読み込みました（「元に戻す」で CSV の内容に戻せます）" if path == DRAFT_PATH else "data/enemies.csv を読み込みました")


func _read_header(path: String) -> PackedStringArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedStringArray(DEFAULT_COLUMNS)
	var header := file.get_csv_line()
	# 表に後から足した列もなくさないよう、知っている列が足りなければ後ろに足す
	for column: String in DEFAULT_COLUMNS:
		if not header.has(column):
			header.append(column)
	return header


func _csv_text() -> String:
	var lines := PackedStringArray([",".join(_columns)])
	for def in _defs:
		var row := def.to_row()
		var cells := PackedStringArray()
		for column in _columns:
			cells.append(_escape(str(row.get(column, ""))))
		lines.append(",".join(cells))
	return "\n".join(lines) + "\n"


static func _escape(text: String) -> String:
	if text.contains(",") or text.contains("\"") or text.contains("\n"):
		return "\"" + text.replace("\"", "\"\"") + "\""
	return text


func _save_text(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(_csv_text())
	return true


## 変えたら、下書きを少し後に保存し、ゲームにも反映する。
func _changed() -> void:
	if _loading:
		return
	_draft_left = DRAFT_SAVE_DELAY
	_apply_to_game()
	_refresh_info()


func _apply_to_game() -> void:
	var table := {}
	for def in _defs:
		table[def.id] = def
	Progress.enemies = table


func _on_copy_pressed() -> void:
	Sfx.play(&"click")
	DisplayServer.clipboard_set(_csv_text())
	_set_status("CSV をコピーしました。Claude に貼れば data/enemies.csv に反映して絵も焼き直します")


func _on_save_pressed() -> void:
	Sfx.play(&"click")
	if OS.has_feature("editor"):
		var ok := _save_text(ENEMIES_PATH)
		_set_status("data/enemies.csv に保存しました。絵は tools/render_enemies で焼き直してください" if ok \
				else "data/enemies.csv に保存できませんでした")
	elif OS.has_feature("web"):
		JavaScriptBridge.download_buffer(_csv_text().to_utf8_buffer(), DOWNLOAD_NAME, "text/csv")
		_set_status("enemies.csv をダウンロードしました")
	else:
		var path := "user://" + DOWNLOAD_NAME
		_save_text(path)
		_set_status("%s に保存しました" % ProjectSettings.globalize_path(path))


func _on_revert_pressed() -> void:
	Sfx.play(&"click")
	if FileAccess.file_exists(DRAFT_PATH):
		DirAccess.remove_absolute(DRAFT_PATH)
	_draft_left = -1.0
	_load(false)


func _on_back_pressed() -> void:
	Sfx.play(&"click")
	if _draft_left >= 0.0:
		_save_text(DRAFT_PATH)
	closed.emit()


func _set_status(text: String) -> void:
	_status.text = text


# ---- 一覧 ----

func _refresh_list() -> void:
	_list.clear()
	for def in _defs:
		_list.add_item(_item_text(def.name, def.id))
	if not _defs.is_empty():
		_list.select(_index)


static func _item_text(enemy_name: String, id: StringName) -> String:
	return "%s（%s）" % [enemy_name, id]


func _on_list_selected(index: int) -> void:
	Sfx.play(&"click")
	_index = index
	_show_def()


func _on_new_pressed() -> void:
	Sfx.play(&"click")
	var def := EnemyDef.from_row({"id": _free_id("new_enemy"), "name": "新しい敵", "move": "wander_chase",
			"size": "34", "hp_rate": "1", "gem_rate": "1", "speed_rate": "1", "contact_damage": "1",
			"golden": "0", "model": "slime", "color": "8ad35a", "angry_color": "ff739e"})
	_add_def(def)


func _on_duplicate_pressed() -> void:
	Sfx.play(&"click")
	if _defs.is_empty():
		return
	var def := _current().copy()
	def.id = _free_id(String(def.id))
	def.name += "（コピー）"
	_add_def(def)


func _on_delete_pressed() -> void:
	if _defs.is_empty():
		return
	var def := _current()
	var stages := _stages_using(def.id)
	if not stages.is_empty():
		Sfx.play(&"deny")
		_set_status("%s は %s で使われているので消せません（stages.csv から外してから）" % [def.name, "・".join(stages)])
		return
	Sfx.play(&"click")
	_defs.remove_at(_index)
	_index = clampi(_index, 0, maxi(_defs.size() - 1, 0))
	_refresh_list()
	_show_def()
	_changed()
	_set_status("%s を消しました" % def.name)


func _add_def(def: EnemyDef) -> void:
	_defs.append(def)
	_index = _defs.size() - 1
	_refresh_list()
	_show_def()
	_changed()
	_set_status("%s を足しました。ステージに出すには stages.csv の enemies に「%s:数」を足します" % [def.name, def.id])


func _free_id(base: String) -> StringName:
	var id := base
	var n := 2
	while _has_id(StringName(id)):
		id = "%s_%d" % [base, n]
		n += 1
	return StringName(id)


func _has_id(id: StringName) -> bool:
	for def in _defs:
		if def.id == id:
			return true
	return false


## その敵を出しているステージの名前。
func _stages_using(id: StringName) -> PackedStringArray:
	var names := PackedStringArray()
	for stage in Progress.stages:
		var used := stage.boss == id
		for entry in stage.enemies:
			used = used or entry[0] == id
		if used:
			names.append(stage.name)
	return names


func _current() -> EnemyDef:
	return _defs[_index]


# ---- 数値の欄 ----

## 選んでいる敵の値を欄に入れ、プレビューを作り直す。
func _show_def() -> void:
	if _defs.is_empty():
		return
	_loading = true
	var def := _current()
	(_fields["id"] as LineEdit).text = String(def.id)
	(_fields["id"] as LineEdit).editable = _stages_using(def.id).is_empty()
	(_fields["name"] as LineEdit).text = def.name
	(_fields["move"] as OptionButton).select(_find_option(MOVES, def.move))
	(_fields["model"] as OptionButton).select(_find_option(MODELS, def.model))
	for spec in SLIDERS:
		var value: float = def.get(spec[0])
		(_fields[spec[0]] as HSlider).value = value
		_update_slider_label(spec[0], value)
	(_fields["golden"] as CheckBox).button_pressed = def.golden
	(_fields["color"] as ColorPickerButton).color = def.color
	(_fields["angry_color"] as ColorPickerButton).color = def.angry_color
	(_fields["memo"] as TextEdit).text = def.memo
	_boss_check.button_pressed = _is_boss_somewhere(def.id)
	_loading = false
	_rebuild_monster()
	_rebuild_model()
	_refresh_info()


func _is_boss_somewhere(id: StringName) -> bool:
	for stage in Progress.stages:
		if stage.boss == id:
			return true
	return false


static func _find_option(options: Array, id: StringName) -> int:
	for i in options.size():
		if options[i][0] == id:
			return i
	return 0


func _on_id_changed(text: String) -> void:
	if _loading:
		return
	var clean := text.strip_edges().to_lower()
	var id := StringName(clean)
	if clean.is_empty() or not clean.is_valid_ascii_identifier():
		_set_status("id は半角の英小文字・数字・_ で書きます")
		return
	if id != _current().id and _has_id(id):
		_set_status("id %s はもう使われています" % clean)
		return
	_current().id = id
	_list.set_item_text(_index, _item_text(_current().name, id))
	_set_status("")
	_changed()


func _on_name_changed(text: String) -> void:
	if _loading:
		return
	_current().name = text
	_list.set_item_text(_index, _item_text(text, _current().id))
	_changed()


func _on_move_selected(index: int) -> void:
	if _loading:
		return
	_current().move = MOVES[index][0]
	_changed()
	_rebuild_monster()


func _on_model_selected(index: int) -> void:
	if _loading:
		return
	_current().model = MODELS[index][0]
	_changed()
	_rebuild_model()


func _on_slider_changed(value: float, key: String) -> void:
	_update_slider_label(key, value)
	if _loading:
		return
	if key == "contact_damage":
		_current().contact_damage = roundi(value)
	else:
		_current().set(key, value)
	_changed()
	_rebuild_monster()


func _update_slider_label(key: String, value: float) -> void:
	var label := _fields[key + "_label"] as Label
	label.text = str(roundi(value)) if key == "contact_damage" else EnemyDef._num(value)


func _on_golden_toggled(on: bool) -> void:
	if _loading:
		return
	_current().golden = on
	_changed()


func _on_color_changed(color: Color, key: String) -> void:
	if _loading:
		return
	_current().set(key, color)
	_changed()
	_rebuild_model()


func _on_memo_changed() -> void:
	if _loading:
		return
	_current().memo = (_fields["memo"] as TextEdit).text.replace("\n", " ")
	_changed()


## 選んだステージでの実際の耐久・宝石・速さ。
func _refresh_info() -> void:
	if _defs.is_empty() or Progress.stages.is_empty():
		return
	var def := _current()
	var stage := Progress.stages[clampi(_stage_pick.selected, 0, Progress.stages.size() - 1)]
	var boss := _boss_check.button_pressed
	var hp := def.hp_from(stage.boss_hp if boss else stage.enemy_hp)
	var gem := def.gem_from(stage.boss_gem if boss else stage.enemy_gem)
	var speed := def.speed_from(stage.boss_speed if boss else stage.enemy_speed)
	var lines := PackedStringArray([
		"%sに%sとして出すと" % [stage.name, "ボス" if boss else "敵"],
		"耐久 %d　宝石 %d　速さ %d" % [hp, gem, roundi(speed)],
	])
	var stages := _stages_using(def.id)
	lines.append("出ているステージ: " + ("・".join(stages) if not stages.is_empty() else "なし"))
	_info.text = "\n".join(lines)


# ---- 動きのプレビュー ----

func _rebuild_monster() -> void:
	if _monster != null:
		_monster.queue_free()
		_monster = null
	if _defs.is_empty() or Progress.stages.is_empty():
		return
	var def := _current()
	var stage := Progress.stages[clampi(_stage_pick.selected, 0, Progress.stages.size() - 1)]
	var boss := _boss_check.button_pressed
	_monster = (load("res://scenes/monster/monster.tscn") as PackedScene).instantiate() as Monster
	_monster.def = def
	_monster.target = _target
	_monster.is_boss = boss
	_monster.speed = def.speed_from(stage.boss_speed if boss else stage.enemy_speed)
	_monster.contact_damage = def.contact_damage
	_monster.base_hp = def.hp_from(stage.boss_hp if boss else stage.enemy_hp)
	_monster.position = Vector2(_arena.size) * Vector2(0.25, 0.6)
	_monster.scale = Vector2.ONE * Progress.unit_scale
	_monster.touched_player.connect(func(_m: Monster) -> void: _target_hit = 0.3)
	_monster.broken.connect(_on_monster_broken)
	_arena.add_child(_monster)


func _on_monster_broken(_target_broken: Breakable) -> void:
	if _monster != null and _monster.is_boss:
		get_tree().create_timer(1.0).timeout.connect(_rebuild_monster)


func _on_hit_pressed() -> void:
	if _monster != null and _monster.is_alive():
		_monster.take_hit(maxi(_monster.max_hp / 4, 1))


## プレイヤー役は円を描いて回る。プレビューを触るとその場所へ動き、しばらくそこに止まる。
func _move_target(delta: float) -> void:
	if _target == null:
		return
	_target_hit = maxf(_target_hit - delta, 0.0)
	_target.queue_redraw()
	if _manual_left > 0.0:
		_manual_left -= delta
		return
	_patrol += delta * TAU / PATROL_TIME
	var center := Vector2(_arena.size) * 0.5 + Vector2(0, 50)
	_target.position = _target.position.lerp(center + Vector2(cos(_patrol), sin(_patrol) * 0.55) * PATROL_RADIUS,
			minf(delta * 4.0, 1.0))


func _on_arena_input(event: InputEvent) -> void:
	var pressed := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	var dragged := event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask != 0
	if pressed or dragged:
		_target.position = (event as InputEventMouse).position
		_manual_left = PATROL_RESUME


func _draw_floor(canvas: Node2D) -> void:
	var size := Vector2(_arena.size)
	canvas.draw_rect(Rect2(Vector2.ZERO, size), FLOOR_COLORS[0])
	for y in ceili(size.y / TILE):
		for x in ceili(size.x / TILE):
			if (x + y) % 2 == 1:
				canvas.draw_rect(Rect2(Vector2(x, y) * TILE, Vector2.ONE * TILE), FLOOR_COLORS[1])


func _draw_target() -> void:
	var body := Progress.unit_scale * Balance.get_float("player_size_rate") * Player.DRAW_SCALE
	_target.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * body)
	Toon.shadow(_target, Vector2(0, Player.FOOT_Y), Vector2(22, 8))
	var facing := Vector2.DOWN
	if _monster != null:
		facing = _target.position.direction_to(_monster.position)
	var tint := TARGET_HIT_COLOR if _target_hit > 0.0 else Color.WHITE
	_target.draw_texture_rect_region(Player.SHEET,
			Rect2(Vector2(0, Player.FOOT_Y) - Player.SHEET_FOOT * Player.SHEET_PIXEL, Vector2.ONE * Player.SHEET_CELL * Player.SHEET_PIXEL),
			Rect2(0, wrapi(roundi(facing.angle() / (TAU / Player.SHEET_DIRECTIONS)), 0, Player.SHEET_DIRECTIONS) * Player.SHEET_CELL,
					Player.SHEET_CELL, Player.SHEET_CELL), tint)


# ---- 3Dの見た目 ----

func _rebuild_model() -> void:
	if _model != null:
		_model.queue_free()
		_model = null
	if _defs.is_empty():
		return
	var def := _current()
	_model = MonsterModel.new()
	_model.shape = def.model
	match _look_pick.selected:
		1:
			_model.body_color = def.angry_color
			_model.angry = true
		2:
			_model.body_color = GOLDEN_COLOR
		_:
			_model.body_color = def.color
	_model_pivot.add_child(_model)


# ---- 画面の組み立て ----

func _build_layout() -> void:
	var title := _label("敵エディタ（開発用）", 30, Vector2(20, 12))
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	var x := 1264.0
	for spec in [["戻る", UiStyle.BLUE, _on_back_pressed], ["元に戻す", Color(0.85, 0.3, 0.3), _on_revert_pressed],
			["保存", UiStyle.GREEN, _on_save_pressed], ["CSVをコピー", UiStyle.YELLOW, _on_copy_pressed]]:
		var width := 120.0 if String(spec[0]).length() <= 4 else 170.0
		x -= width
		_button(spec[0], spec[1], Rect2(x, 10, width, 48), spec[2])
		x -= 10.0
	_status = _label("", 15, STATUS_RECT.position)
	_status.size = STATUS_RECT.size
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))

	_list = ItemList.new()
	_list.position = LIST_RECT.position
	_list.size = LIST_RECT.size
	_list.add_theme_font_size_override("font_size", 18)
	_list.item_selected.connect(_on_list_selected)
	add_child(_list)
	var bottom := LIST_RECT.end.y + 6.0
	_button("新規", UiStyle.GREEN, Rect2(LIST_RECT.position.x, bottom, 64, 42), _on_new_pressed, 16)
	_button("複製", UiStyle.BLUE, Rect2(LIST_RECT.position.x + 68, bottom, 64, 42), _on_duplicate_pressed, 16)
	_button("削除", Color(0.85, 0.3, 0.3), Rect2(LIST_RECT.position.x + 136, bottom, 64, 42), _on_delete_pressed, 16)

	_build_arena()
	_build_model_view()
	_build_info()
	_build_form()


func _build_arena() -> void:
	var container := SubViewportContainer.new()
	container.position = ARENA_POS
	container.size = Vector2(1280, 720)
	container.scale = Vector2.ONE * ARENA_SCALE
	container.gui_input.connect(_on_arena_input)
	add_child(container)
	_arena = SubViewport.new()
	_arena.size = Vector2i(1280, 720)
	_arena.handle_input_locally = false
	container.add_child(_arena)
	var floor_layer := Node2D.new()
	floor_layer.draw.connect(_draw_floor.bind(floor_layer))
	_arena.add_child(floor_layer)
	_target = Node2D.new()
	_target.position = Vector2(_arena.size) * 0.5
	_target.draw.connect(_draw_target)
	_arena.add_child(_target)
	_label("触るとプレイヤー役がそこへ動きます", 16, ARENA_POS + Vector2(0, 720 * ARENA_SCALE + 2))


func _build_model_view() -> void:
	var panel := _panel(MODEL_RECT)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_look_pick = OptionButton.new()
	for look in LOOKS:
		_look_pick.add_item(look)
	_look_pick.add_theme_font_size_override("font_size", 18)
	_look_pick.item_selected.connect(func(_i: int) -> void: _rebuild_model())
	box.add_child(_look_pick)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(container)
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	container.add_child(view)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-35), 0)
	view.add_child(light)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.75, 0.85)
	environment.ambient_light_energy = 0.55
	var world := WorldEnvironment.new()
	world.environment = environment
	view.add_child(world)
	_model_pivot = Node3D.new()
	view.add_child(_model_pivot)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.6
	camera.rotation.x = deg_to_rad(-40)
	camera.position = camera.transform.basis.z * 10.0 + Vector3(0, 0.75, 0)
	view.add_child(camera)


func _build_info() -> void:
	var panel := _panel(INFO_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_stage_pick = OptionButton.new()
	for stage in Progress.stages:
		_stage_pick.add_item(stage.name)
	_stage_pick.add_theme_font_size_override("font_size", 18)
	_stage_pick.item_selected.connect(func(_i: int) -> void:
		_refresh_info()
		_rebuild_monster())
	box.add_child(_stage_pick)
	_boss_check = CheckBox.new()
	_boss_check.text = "ボスとして見る"
	_boss_check.add_theme_font_size_override("font_size", 18)
	_boss_check.toggled.connect(func(_on: bool) -> void:
		if _loading:
			return
		_refresh_info()
		_rebuild_monster())
	box.add_child(_boss_check)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 16)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_info)
	var hit := Button.new()
	hit.text = "叩く（耐久の1/4）"
	hit.focus_mode = Control.FOCUS_NONE
	UiStyle.button(hit, UiStyle.YELLOW, 18)
	hit.pressed.connect(_on_hit_pressed)
	box.add_child(hit)


func _build_form() -> void:
	var panel := _panel(FORM_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.custom_minimum_size = Vector2(FORM_RECT.size.x - 48.0, 0)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	var id_edit := LineEdit.new()
	id_edit.text_changed.connect(_on_id_changed)
	_form_row(grid, "id（半角）", id_edit, "id")
	var name_edit := LineEdit.new()
	name_edit.text_changed.connect(_on_name_changed)
	_form_row(grid, "名前", name_edit, "name")
	var move_pick := OptionButton.new()
	for option in MOVES:
		move_pick.add_item(option[1])
	move_pick.item_selected.connect(_on_move_selected)
	_form_row(grid, "動き", move_pick, "move")
	for spec in SLIDERS:
		var row := HBoxContainer.new()
		var slider := HSlider.new()
		slider.min_value = spec[2]
		slider.max_value = spec[3]
		slider.step = spec[4]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.custom_minimum_size = Vector2(0, 32)
		slider.value_changed.connect(_on_slider_changed.bind(spec[0]))
		row.add_child(slider)
		var value := Label.new()
		value.custom_minimum_size = Vector2(56, 0)
		value.add_theme_font_size_override("font_size", 18)
		row.add_child(value)
		_fields[spec[0]] = slider
		_fields[spec[0] + "_label"] = value
		_form_row(grid, spec[1], row, "")
	var golden := CheckBox.new()
	golden.text = "黄金スライムで金色に"
	golden.toggled.connect(_on_golden_toggled)
	_form_row(grid, "金色", golden, "golden")
	var model_pick := OptionButton.new()
	for option in MODELS:
		model_pick.add_item(option[1])
	model_pick.item_selected.connect(_on_model_selected)
	_form_row(grid, "形", model_pick, "model")
	for spec in [["color", "体の色"], ["angry_color", "怒り顔の色"]]:
		var picker := ColorPickerButton.new()
		picker.edit_alpha = false
		picker.custom_minimum_size = Vector2(0, 36)
		picker.color_changed.connect(_on_color_changed.bind(spec[0]))
		_form_row(grid, spec[1], picker, spec[0])
	var memo := TextEdit.new()
	memo.custom_minimum_size = Vector2(0, 110)
	memo.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	memo.text_changed.connect(_on_memo_changed)
	_form_row(grid, "メモ", memo, "memo")


func _form_row(grid: GridContainer, text: String, control: Control, key: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.custom_minimum_size = Vector2(120, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.add_theme_font_size_override("font_size", 18)
	# 長い選択肢や文字で右の欄がはみ出さないようにする
	var button := control as Button
	if button != null:
		button.clip_text = true
	grid.add_child(control)
	if key != "":
		_fields[key] = control


func _panel(rect: Rect2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL, 14, 4, 4))
	add_child(panel)
	return panel


func _label(text: String, font_size: int, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	UiStyle.outline_label(label, 6)
	add_child(label)
	return label


func _button(text: String, color: Color, rect: Rect2, action: Callable, font_size := 20) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	UiStyle.button(button, color, font_size)
	button.pressed.connect(action)
	add_child(button)
	return button
