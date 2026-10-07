class_name EnemyEditor
extends Control
## 開発用の敵エディタ。data/enemies.csv の敵を選んで数値・動き・形・色を変え、その場で動きと3Dの見た目を確かめる。
## 左が一覧、中央が実際の動き（ゲームと同じ Monster をプレイヤー役と一緒に動かす）と3Dの見た目、右が数値。
## 右の下では撃つ弾（data/shots.csv の1行）を選び、弾の種類・狙い・数・向き・撃ち方を変えられる。
## 変えた内容は CSV にして書き出す（エディタで開いたときは data/enemies.csv・data/shots.csv に保存、Web 版はダウンロードとコピー）。
## 書き出すまでの変更はこの端末に下書きとして残り、ゲームにも（再読み込みまで）反映される。
## 形や色を変えたとき（とまだ絵を焼いていない敵）は、SpriteBaker でその場で絵を焼いて中央の動く絵にも出す。

signal closed

const ENEMIES_PATH := "res://data/enemies.csv"
const DRAFT_PATH := "user://enemies_draft.csv"
const DOWNLOAD_NAME := "enemies.csv"
const DEFAULT_COLUMNS := ["id", "name", "move", "size", "hp_rate", "gem_rate", "speed_rate", "contact_damage",
		"golden", "model", "color", "angry_color", "shot", "memo"]
const SHOTS_PATH := "res://data/shots.csv"
const SHOTS_DRAFT_PATH := "user://shots_draft.csv"
const SHOTS_DOWNLOAD_NAME := "shots.csv"
const SHOT_COLUMNS := ["id", "name", "kind", "aim", "pattern", "count", "spread", "direction", "interval",
		"burst_gap", "windup", "speed", "size", "reach", "damage", "start_range", "color", "memo"]
## 弾の選択肢（ShotDef の kind・aim・pattern）
const SHOT_KINDS := [[&"bullet", "弾丸"], [&"arrow", "矢じり"], [&"wave", "ウェーブ"], [&"bomb", "爆弾"], [&"laser", "レーザー"]]
const SHOT_AIMS := [[&"player", "プレイヤーを狙う"], [&"fixed", "決まった向き"], [&"facing", "向いている向き"]]
const SHOT_PATTERNS := [[&"fan", "扇状に同時"], [&"ring", "全方位に同時"], [&"burst", "同じ向きに連射"],
		[&"spiral", "回しながら連射"]]
## 弾の数値のつまみ: [項目, 表示名, 最小, 最大, 刻み]
const SHOT_SLIDERS := [
	["count", "発射数", 1.0, 36.0, 1.0],
	["spread", "広がり（度）", 0.0, 360.0, 1.0],
	["direction", "向き（0=右 90=下）", 0.0, 359.0, 1.0],
	["interval", "撃つ間隔（秒）", 0.2, 10.0, 0.1],
	["burst_gap", "連射の間（秒）", 0.0, 1.0, 0.02],
	["windup", "予備動作（秒）", 0.0, 3.0, 0.05],
	["speed", "弾の速さ", 0.0, 800.0, 10.0],
	["size", "弾の大きさ", 2.0, 200.0, 1.0],
	["reach", "届く距離", 50.0, 1400.0, 10.0],
	["damage", "ダメージ", 0.0, 5.0, 1.0],
	["start_range", "撃つ距離（0=いつも）", 0.0, 1400.0, 10.0],
]
const SHOT_INT_KEYS := ["count", "damage"]
## 選べる動き（MonsterMove.create の名前）と、選べる仮モデルの形（MonsterModel の shape）
const MOVES := [[&"wander_chase", "うろつき、近づくと追う"], [&"dash", "ためて突進"], [&"chase", "ずっと追う（ボス向け）"]]
const MODELS := [[&"slime", "スライム"], [&"dasher", "角つき"], [&"king", "王冠つき"], [&"goblin", "ゴブリン"],
		[&"bat", "こうもり"], [&"warrior", "戦士"], [&"ogre", "オーガ"]]
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
## 色をつまみで動かしているあいだは焼かず、手を止めてからこの秒数で焼く
const BAKE_DELAY := 0.4

var _defs: Array[EnemyDef] = []
var _columns: PackedStringArray = PackedStringArray(DEFAULT_COLUMNS)
var _shots: Array[ShotDef] = []
var _shot_columns: PackedStringArray = PackedStringArray(SHOT_COLUMNS)
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
var _shot_fields: Dictionary = {}
## 弾を選んでいないときに隠す、弾の設定の行
var _shot_rows: Array[Control] = []

var _arena: SubViewport
var _target: Node2D
var _monster: Monster
var _patrol := 0.0
var _manual_left := 0.0
var _target_hit := 0.0

var _model_pivot: Node3D
var _model: MonsterModel

var _baker: SpriteBaker
var _bake_left := -1.0
## 敵 → その場で焼いた絵の形と色（変わっていれば焼き直す）
var _baked_looks: Dictionary = {}
## id → data/enemies.csv での形と色（assets/sprites/enemies/ の絵はこれで焼いてある）
var _file_looks: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_baker = SpriteBaker.new()
	_baker.baked.connect(_on_baked)
	add_child(_baker)
	_build_layout()
	_load(true)


func _process(delta: float) -> void:
	_move_target(delta)
	if _model_pivot != null:
		_model_pivot.rotation.y += MODEL_TURN_SPEED * delta
	if _draft_left >= 0.0:
		_draft_left -= delta
		if _draft_left < 0.0:
			_save_drafts()
	if _bake_left >= 0.0:
		_bake_left -= delta
		if _bake_left < 0.0 and not _defs.is_empty():
			_set_status("絵を焼いています…")
			_baker.bake(_current())


func _draw() -> void:
	draw_rect(get_viewport_rect(), Color(0.1, 0.11, 0.2))


# ---- 読み込みと書き出し ----

## data/enemies.csv と data/shots.csv（use_draft なら、あれば下書き）を読み込む。
func _load(use_draft: bool) -> void:
	var path := ENEMIES_PATH
	if use_draft and FileAccess.file_exists(DRAFT_PATH):
		path = DRAFT_PATH
	_columns = _read_header(path, DEFAULT_COLUMNS)
	_file_looks.clear()
	for row in Balance.load_table(ENEMIES_PATH):
		var saved := EnemyDef.from_row(row)
		_file_looks[saved.id] = _look_of(saved)
	_defs.clear()
	for row in Balance.load_table(path):
		_defs.append(EnemyDef.from_row(row))
	var shots_path := SHOTS_PATH
	if use_draft and FileAccess.file_exists(SHOTS_DRAFT_PATH):
		shots_path = SHOTS_DRAFT_PATH
	_shot_columns = _read_header(shots_path, SHOT_COLUMNS)
	_shots.clear()
	for row in Balance.load_table(shots_path):
		_shots.append(ShotDef.from_row(row))
	_refresh_shot_pick()
	_index = clampi(_index, 0, maxi(_defs.size() - 1, 0))
	_apply_to_game()
	_refresh_list()
	_show_def()
	_set_status("下書きを読み込みました（「元に戻す」で CSV の内容に戻せます）" if path == DRAFT_PATH else "data/enemies.csv を読み込みました")


func _read_header(path: String, known: Array) -> PackedStringArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedStringArray(known)
	var header := file.get_csv_line()
	# 表に後から足した列もなくさないよう、知っている列が足りなければ memo の前（なければ後ろ）に足す
	for column: String in known:
		if not header.has(column):
			var memo_at := header.find("memo")
			if memo_at >= 0:
				header.insert(memo_at, column)
			else:
				header.append(column)
	return header


func _csv_text() -> String:
	return _table_text(_columns, _defs.map(func(def: EnemyDef) -> Dictionary: return def.to_row()))


func _shots_text() -> String:
	return _table_text(_shot_columns, _shots.map(func(def: ShotDef) -> Dictionary: return def.to_row()))


static func _table_text(columns: PackedStringArray, rows: Array) -> String:
	var lines := PackedStringArray([",".join(columns)])
	for row: Dictionary in rows:
		var cells := PackedStringArray()
		for column in columns:
			cells.append(_escape(str(row.get(column, ""))))
		lines.append(",".join(cells))
	return "\n".join(lines) + "\n"


static func _escape(text: String) -> String:
	if text.contains(",") or text.contains("\"") or text.contains("\n"):
		return "\"" + text.replace("\"", "\"\"") + "\""
	return text


static func _save_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	return true


func _save_drafts() -> void:
	_save_text(DRAFT_PATH, _csv_text())
	_save_text(SHOTS_DRAFT_PATH, _shots_text())


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
	var shot_table := {}
	for def in _shots:
		shot_table[def.id] = def
	Progress.shots = shot_table


func _on_copy_pressed() -> void:
	Sfx.play(&"click")
	DisplayServer.clipboard_set("data/enemies.csv\n" + _csv_text() + "\ndata/shots.csv\n" + _shots_text())
	_set_status("CSV（敵と弾の2つ）をコピーしました。Claude に貼れば data/ に反映して絵も焼き直します")


func _on_save_pressed() -> void:
	Sfx.play(&"click")
	if OS.has_feature("editor"):
		var ok := _save_text(ENEMIES_PATH, _csv_text()) and _save_text(SHOTS_PATH, _shots_text())
		_set_status("data/enemies.csv と data/shots.csv に保存しました。絵は tools/render_enemies で焼き直してください" if ok \
				else "data/ に保存できませんでした")
	elif OS.has_feature("web"):
		JavaScriptBridge.download_buffer(_csv_text().to_utf8_buffer(), DOWNLOAD_NAME, "text/csv")
		JavaScriptBridge.download_buffer(_shots_text().to_utf8_buffer(), SHOTS_DOWNLOAD_NAME, "text/csv")
		_set_status("enemies.csv と shots.csv をダウンロードしました")
	else:
		_save_text("user://" + DOWNLOAD_NAME, _csv_text())
		_save_text("user://" + SHOTS_DOWNLOAD_NAME, _shots_text())
		_set_status("%s に保存しました" % ProjectSettings.globalize_path("user://"))


func _on_revert_pressed() -> void:
	Sfx.play(&"click")
	for path in [DRAFT_PATH, SHOTS_DRAFT_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_draft_left = -1.0
	_load(false)


func _on_back_pressed() -> void:
	Sfx.play(&"click")
	if _draft_left >= 0.0:
		_save_drafts()
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
	_show_shot()
	_loading = false
	_rebuild_monster()
	_rebuild_model()
	_refresh_info()
	if _needs_bake(_current()):
		_queue_bake(0.0)


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
	_queue_bake(0.0)


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
	_queue_bake(BAKE_DELAY)


func _on_memo_changed() -> void:
	if _loading:
		return
	_current().memo = (_fields["memo"] as TextEdit).text.replace("\n", " ")
	_changed()


# ---- 弾の欄 ----

## 弾を選ぶ欄の中身（なし＋shots.csv の全部）を作り直す。
func _refresh_shot_pick() -> void:
	var pick := _fields.get("shot") as OptionButton
	if pick == null:
		return
	pick.clear()
	pick.add_item("撃たない")
	for def in _shots:
		pick.add_item(_item_text(def.name, def.id))


func _current_shot() -> ShotDef:
	if _defs.is_empty():
		return null
	for def in _shots:
		if def.id == _current().shot:
			return def
	return null


## 選んでいる敵の弾の値を欄に入れる。弾がなければ弾の設定の行を隠す。
func _show_shot() -> void:
	var was_loading := _loading
	_loading = true
	var shot := _current_shot()
	var index := 0
	if shot != null:
		index = _shots.find(shot) + 1
	(_fields["shot"] as OptionButton).select(index)
	for row in _shot_rows:
		row.visible = shot != null
	if shot != null:
		(_shot_fields["name"] as LineEdit).text = shot.name
		(_shot_fields["kind"] as OptionButton).select(_find_option(SHOT_KINDS, shot.kind))
		(_shot_fields["aim"] as OptionButton).select(_find_option(SHOT_AIMS, shot.aim))
		(_shot_fields["pattern"] as OptionButton).select(_find_option(SHOT_PATTERNS, shot.pattern))
		for spec in SHOT_SLIDERS:
			var value := float(shot.get(spec[0]))
			(_shot_fields[spec[0]] as HSlider).value = value
			_update_shot_slider_label(spec[0], value)
		(_shot_fields["color"] as ColorPickerButton).color = shot.color
		var users := _enemies_using_shot(shot.id)
		(_shot_fields["users"] as Label).text = "この弾を使う敵: " + "・".join(users)
	_loading = was_loading


func _enemies_using_shot(id: StringName) -> PackedStringArray:
	var names := PackedStringArray()
	for def in _defs:
		if def.shot == id:
			names.append(def.name)
	return names


func _on_shot_selected(index: int) -> void:
	if _loading:
		return
	_current().shot = &"" if index == 0 else _shots[index - 1].id
	_show_shot()
	_changed()
	_rebuild_monster()


## 選んでいる弾を写して、この敵だけの弾にする（ほかの敵の弾を変えずに調整したいとき）。
func _on_shot_duplicate_pressed() -> void:
	var shot := _current_shot()
	if shot == null:
		return
	Sfx.play(&"click")
	var copy := shot.copy()
	var id := String(shot.id) + "_2"
	var n := 3
	while _has_shot_id(StringName(id)):
		id = "%s_%d" % [shot.id, n]
		n += 1
	copy.id = StringName(id)
	copy.name += "（コピー）"
	_shots.append(copy)
	_current().shot = copy.id
	_refresh_shot_pick()
	_show_shot()
	_changed()
	_rebuild_monster()
	_set_status("弾 %s を作り、%s に付けました" % [copy.id, _current().name])


func _has_shot_id(id: StringName) -> bool:
	for def in _shots:
		if def.id == id:
			return true
	return false


func _on_shot_name_changed(text: String) -> void:
	var shot := _current_shot()
	if _loading or shot == null:
		return
	shot.name = text
	(_fields["shot"] as OptionButton).set_item_text(_shots.find(shot) + 1, _item_text(text, shot.id))
	_changed()


func _on_shot_option_selected(index: int, key: String) -> void:
	var shot := _current_shot()
	if _loading or shot == null:
		return
	var options: Array = {"kind": SHOT_KINDS, "aim": SHOT_AIMS, "pattern": SHOT_PATTERNS}[key]
	shot.set(key, options[index][0])
	_changed()
	_rebuild_monster()


func _on_shot_slider_changed(value: float, key: String) -> void:
	_update_shot_slider_label(key, value)
	var shot := _current_shot()
	if _loading or shot == null:
		return
	if key in SHOT_INT_KEYS:
		shot.set(key, roundi(value))
	else:
		shot.set(key, value)
	_changed()


func _update_shot_slider_label(key: String, value: float) -> void:
	var label := _shot_fields[key + "_label"] as Label
	label.text = str(roundi(value)) if key in SHOT_INT_KEYS else EnemyDef._num(value)


func _on_shot_color_changed(color: Color) -> void:
	var shot := _current_shot()
	if _loading or shot == null:
		return
	shot.color = color
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
	for node in _arena.get_children():
		if node is EnemyShot:
			node.queue_free()
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
	_monster.shot_hit.connect(func(_damage: int, _from: Vector2) -> void: _target_hit = 0.3)
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


# ---- その場で焼く絵 ----

## 形と色の組（これが焼いた絵と同じなら焼き直さない）。
static func _look_of(def: EnemyDef) -> String:
	return "%s/%s/%s" % [def.model, def.color.to_html(), def.angry_color.to_html()]


## まだ焼いた絵がない敵か、焼いてから形や色を変えた敵。
func _needs_bake(def: EnemyDef) -> bool:
	if _baked_looks.has(def):
		return _baked_looks[def] != _look_of(def)
	return not ResourceLoader.exists(EnemyDef.SPRITE_DIR + String(def.id) + ".png") \
			or _file_looks.get(def.id, "") != _look_of(def)


func _queue_bake(delay: float) -> void:
	if not _defs.is_empty() and _needs_bake(_current()):
		_bake_left = delay


func _on_baked(def: EnemyDef, sheets: Dictionary) -> void:
	def.use_sheets(sheets)
	_baked_looks[def] = _look_of(def)
	_set_status("%s の絵を焼きました（保存する絵は Claude が tools/render_enemies で焼き直します）" % def.name)
	# 焼いている間にまた変えていたら、もう一度焼く
	if def == _current() and _needs_bake(def):
		_queue_bake(0.0)


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
	var shot_pick := OptionButton.new()
	shot_pick.item_selected.connect(_on_shot_selected)
	_form_row(grid, "弾", shot_pick, "shot")
	for spec in SLIDERS:
		var row := _slider_row(spec, _on_slider_changed.bind(spec[0]))
		_fields[spec[0]] = row.get_child(0)
		_fields[spec[0] + "_label"] = row.get_child(1)
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
	_build_shot_form(grid)


## 弾の設定の行。ここで変えた値は、同じ弾を使うすべての敵に効く。
func _build_shot_form(grid: GridContainer) -> void:
	var duplicate := Button.new()
	duplicate.text = "この敵だけの弾にする"
	duplicate.focus_mode = Control.FOCUS_NONE
	UiStyle.button(duplicate, UiStyle.BLUE, 16)
	duplicate.pressed.connect(_on_shot_duplicate_pressed)
	var heading := _shot_row(grid, "弾の設定", duplicate, "")
	heading.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	var users := Label.new()
	users.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	users.add_theme_color_override("font_color", Color(0.75, 0.8, 0.95))
	_shot_row(grid, "", users, "users")
	var name_edit := LineEdit.new()
	name_edit.text_changed.connect(_on_shot_name_changed)
	_shot_row(grid, "弾の名前", name_edit, "name")
	for spec in [["kind", "弾の種類", SHOT_KINDS], ["aim", "狙い", SHOT_AIMS], ["pattern", "撃ち方", SHOT_PATTERNS]]:
		var pick := OptionButton.new()
		for option: Array in spec[2]:
			pick.add_item(option[1])
		pick.item_selected.connect(_on_shot_option_selected.bind(spec[0]))
		_shot_row(grid, spec[1], pick, spec[0])
	for spec in SHOT_SLIDERS:
		var row := _slider_row(spec, _on_shot_slider_changed.bind(spec[0]))
		_shot_fields[spec[0]] = row.get_child(0)
		_shot_fields[spec[0] + "_label"] = row.get_child(1)
		_shot_row(grid, spec[1], row, "")
	var picker := ColorPickerButton.new()
	picker.edit_alpha = false
	picker.custom_minimum_size = Vector2(0, 36)
	picker.color_changed.connect(_on_shot_color_changed)
	_shot_row(grid, "弾の色", picker, "color")


## 弾の設定の1行。弾を選んでいないときは隠す。
func _shot_row(grid: GridContainer, text: String, control: Control, key: String) -> Label:
	var label := _form_row(grid, text, control, "")
	_shot_rows.append_array([label, control])
	if key != "":
		_shot_fields[key] = control
	return label


## つまみと値の表示を横に並べた行。
func _slider_row(spec: Array, on_changed: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var slider := HSlider.new()
	slider.min_value = spec[2]
	slider.max_value = spec[3]
	slider.step = spec[4]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 32)
	slider.value_changed.connect(on_changed)
	row.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size = Vector2(56, 0)
	value.add_theme_font_size_override("font_size", 18)
	row.add_child(value)
	return row


func _form_row(grid: GridContainer, text: String, control: Control, key: String) -> Label:
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
	return label


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
