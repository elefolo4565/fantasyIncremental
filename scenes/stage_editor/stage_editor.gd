class_name StageEditor
extends Control
## 開発用のステージエディタ。data/stages.csv のステージを選んで、出てくる敵の種類と数・湧き直す間隔・ボス・世界・草地や木を変える。
## 左がステージの一覧（上から順に解放される）、中央が出てくる敵の並びと試遊、右がステージの数値とボス。
## 「このステージを試遊」で、変えたステージをそのまま遊べる（終わるとここに戻る。試遊の素材や解放は残さない）。
## 変えた内容は敵エディタと同じく CSV にして書き出す（エディタで開いたときは data/stages.csv に保存、Web 版はダウンロードとコピー）。
## 書き出すまでの変更はこの端末に下書きとして残り、ゲームにも（再読み込みまで）反映される。

signal closed
## 選んだステージを試遊する（upgrades は TEST_UPGRADES の id）
signal test_requested(stage_index: int, upgrades: StringName)

const STAGES_PATH := "res://data/stages.csv"
const DRAFT_PATH := "user://stages_draft.csv"
const DOWNLOAD_NAME := "stages.csv"
const DEFAULT_COLUMNS := ["id", "name", "world", "enemies", "enemy_hp", "enemy_gem", "enemy_speed", "oak_count",
		"oak_hp", "oak_wood", "boss", "boss_after", "boss_hp", "boss_gem", "boss_speed", "grass", "respawn_time", "memo"]
## 選べる世界（地面の色が変わる。並びは一本道の順）
const WORLDS := [[&"plains", "平原"], [&"forest", "森"], [&"volcano", "火山"], [&"heaven", "天界"], [&"demon", "魔界"]]
## 試遊のときの強化
const TEST_UPGRADES := [[&"current", "今の強化のまま"], [&"none", "強化なし"], [&"max", "強化を全部最大"]]
## 数値のつまみ: [項目, 表示名, 最小, 最大, 刻み]。最大を超える値も ＋ で入れられる。
## 敵・ボスの耐久・宝石・速さはステージの基準で、敵ごとの倍率（enemies.csv）を掛けたものが実際の値（中央の下に出る）
const STAGE_SLIDERS := [
	["enemy_hp", "敵の耐久", 1.0, 300.0, 1.0],
	["enemy_gem", "敵の宝石", 0.0, 100.0, 1.0],
	["enemy_speed", "敵の速さ", 0.0, 300.0, 1.0],
	["respawn_time", "湧く秒数", 0.1, 20.0, 0.1],
	["grass", "草地の数", 0.0, 30.0, 1.0],
	["oak_count", "木の数", 0.0, 30.0, 1.0],
	["oak_hp", "木の耐久", 1.0, 300.0, 1.0],
	["oak_wood", "木の木材", 0.0, 50.0, 1.0],
]
const BOSS_SLIDERS := [
	["boss_after", "出るまでの数", 0.0, 100.0, 1.0],
	["boss_hp", "ボスの耐久", 1.0, 3000.0, 1.0],
	["boss_gem", "ボスの宝石", 0.0, 500.0, 1.0],
	["boss_speed", "ボスの速さ", 0.0, 300.0, 1.0],
]
const FLOAT_KEYS := ["enemy_speed", "respawn_time", "boss_speed"]
## 1種類の敵を出す数のつまみ
const COUNT_MIN := 1.0
const COUNT_MAX := 30.0
## 画面の割り付け（見た目だけ）
const LIST_RECT := Rect2(16, 70, 200, 380)
const STATUS_RECT := Rect2(16, 560, 200, 144)
const LINEUP_RECT := Rect2(232, 70, 480, 350)
const TEST_RECT := Rect2(232, 432, 480, 272)
const FORM_RECT := Rect2(728, 70, 536, 634)
const BG_COLOR := Color(0.1, 0.11, 0.2)
const HEADING_COLOR := Color(1, 0.85, 0.35)
const WARN_COLOR := Color(1.0, 0.6, 0.5)
const DELETE_COLOR := Color(0.85, 0.3, 0.3)
const DRAFT_SAVE_DELAY := 0.8

## 開き直しても（試遊から戻っても）同じステージを選んだままにする
static var _last_index := 0
static var _last_upgrades := 0

var _defs: Array[StageDef] = []
var _columns: PackedStringArray = PackedStringArray(DEFAULT_COLUMNS)
var _index := 0
var _loading := false
var _draft_left := -1.0
## 選べる敵の id（Progress.enemies の並び）
var _enemy_ids: Array[StringName] = []

var _list: ItemList
var _status: Label
var _summary: Label
var _lineup: VBoxContainer
var _upgrades_pick: OptionButton
var _fields: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for id in Progress.enemies:
		_enemy_ids.append(id)
	_build_layout()
	_index = _last_index
	_load(true)


func _process(delta: float) -> void:
	if _draft_left >= 0.0:
		_draft_left -= delta
		if _draft_left < 0.0:
			_save_draft()


func _draw() -> void:
	draw_rect(get_viewport_rect(), BG_COLOR)


# ---- 読み込みと書き出し ----

## data/stages.csv（use_draft なら、あれば下書き）を読み込む。
func _load(use_draft: bool) -> void:
	var path := STAGES_PATH
	if use_draft and FileAccess.file_exists(DRAFT_PATH):
		path = DRAFT_PATH
	_columns = _read_header(path)
	_defs.clear()
	for row in Balance.load_table(path):
		_defs.append(StageDef.from_row(row))
	_index = clampi(_index, 0, maxi(_defs.size() - 1, 0))
	_apply_to_game()
	_refresh_list()
	_show_def()
	_set_status("下書きを読み込みました（「元に戻す」で CSV の内容に戻せます）" if path == DRAFT_PATH else "data/stages.csv を読み込みました")


## 表に後から足した列もなくさないよう、知っている列が足りなければ memo の前（なければ後ろ）に足す。
func _read_header(path: String) -> PackedStringArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedStringArray(DEFAULT_COLUMNS)
	var header := file.get_csv_line()
	for column: String in DEFAULT_COLUMNS:
		if not header.has(column):
			var memo_at := header.find("memo")
			if memo_at >= 0:
				header.insert(memo_at, column)
			else:
				header.append(column)
	return header


func _csv_text() -> String:
	return EnemyEditor._table_text(_columns, _defs.map(func(def: StageDef) -> Dictionary: return def.to_row()))


func _save_draft() -> void:
	_draft_left = -1.0
	EnemyEditor._save_text(DRAFT_PATH, _csv_text())


## 変えたら、下書きを少し後に保存し、ゲームにも反映する。
func _changed() -> void:
	if _loading:
		return
	_draft_left = DRAFT_SAVE_DELAY
	_apply_to_game()
	_refresh_summary()


func _apply_to_game() -> void:
	var list: Array[StageDef] = []
	list.assign(_defs)
	Progress.set_stages(list)


func _on_copy_pressed() -> void:
	Sfx.play(&"click")
	DisplayServer.clipboard_set("data/stages.csv\n" + _csv_text())
	_set_status("stages.csv をコピーしました。Claude に貼れば data/stages.csv に反映します")


func _on_save_pressed() -> void:
	Sfx.play(&"click")
	if OS.has_feature("editor"):
		_set_status("data/stages.csv に保存しました" if EnemyEditor._save_text(STAGES_PATH, _csv_text())
				else "data/stages.csv に保存できませんでした")
	elif OS.has_feature("web"):
		JavaScriptBridge.download_buffer(_csv_text().to_utf8_buffer(), DOWNLOAD_NAME, "text/csv")
		_set_status("stages.csv をダウンロードしました")
	else:
		EnemyEditor._save_text("user://" + DOWNLOAD_NAME, _csv_text())
		_set_status("%s に保存しました" % ProjectSettings.globalize_path("user://"))


func _on_revert_pressed() -> void:
	Sfx.play(&"click")
	if FileAccess.file_exists(DRAFT_PATH):
		DirAccess.remove_absolute(DRAFT_PATH)
	_draft_left = -1.0
	_load(false)


func _on_back_pressed() -> void:
	Sfx.play(&"click")
	_remember()
	closed.emit()


## 選んでいるステージを試遊する（CI の動作確認からも呼ぶ）。
func test_play_selected() -> void:
	if _defs.is_empty():
		return
	_remember()
	_apply_to_game()
	test_requested.emit(_index, TEST_UPGRADES[_upgrades_pick.selected][0])


func _on_test_pressed() -> void:
	Sfx.play(&"click")
	if _defs.is_empty():
		return
	var problem := _problem(_current())
	if not problem.is_empty():
		Sfx.play(&"deny")
		_set_status(problem)
		return
	test_play_selected()


## 下書きを今すぐ保存し、選んでいるステージと試遊の強化を覚えておく。
func _remember() -> void:
	if _draft_left >= 0.0:
		_save_draft()
	_last_index = _index
	_last_upgrades = _upgrades_pick.selected


func _set_status(text: String) -> void:
	_status.text = text


# ---- 一覧 ----

func _refresh_list() -> void:
	_list.clear()
	for i in _defs.size():
		_list.add_item(_item_text(i, _defs[i]))
	if not _defs.is_empty():
		_list.select(_index)
		_list.ensure_current_is_visible()


static func _item_text(index: int, def: StageDef) -> String:
	return "%d. %s" % [index + 1, def.name]


func _on_list_selected(index: int) -> void:
	Sfx.play(&"click")
	_index = index
	_show_def()


func _on_new_pressed() -> void:
	Sfx.play(&"click")
	var def: StageDef
	if _defs.is_empty():
		def = StageDef.from_row({"world": "plains", "enemies": "slime:6", "enemy_hp": "6", "enemy_gem": "2",
				"enemy_speed": "40", "boss": "king_slime", "boss_after": "5", "boss_hp": "20", "boss_gem": "6",
				"boss_speed": "40"})
	else:
		# 最後のステージを元にする（続きのステージを作ることが多いので）
		def = _defs[-1].copy()
		def.memo = ""
	def.id = _free_id(String(def.world) + "_%d" % (_count_world(def.world) + 1))
	def.name = "%s %d" % [_world_name(def.world), _count_world(def.world) + 1]
	_insert_def(_defs.size(), def)


func _on_duplicate_pressed() -> void:
	Sfx.play(&"click")
	if _defs.is_empty():
		return
	var def := _current().copy()
	def.id = _free_id(String(def.id))
	def.name += "（コピー）"
	_insert_def(_index + 1, def)


func _on_delete_pressed() -> void:
	if _defs.size() <= 1:
		Sfx.play(&"deny")
		_set_status("ステージは1つは残します")
		return
	Sfx.play(&"click")
	var def := _current()
	_defs.remove_at(_index)
	_index = clampi(_index, 0, _defs.size() - 1)
	_refresh_list()
	_show_def()
	_changed()
	_set_status("%s を消しました（「元に戻す」で CSV の内容に戻せます）" % def.name)


func _on_move_pressed(step: int) -> void:
	var to := _index + step
	if to < 0 or to >= _defs.size():
		Sfx.play(&"deny")
		return
	Sfx.play(&"click")
	var def := _defs[_index]
	_defs[_index] = _defs[to]
	_defs[to] = def
	_index = to
	_refresh_list()
	_changed()


func _insert_def(at: int, def: StageDef) -> void:
	_defs.insert(at, def)
	_index = at
	_refresh_list()
	_show_def()
	_changed()
	_set_status("%s を足しました" % def.name)


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


func _count_world(world: StringName) -> int:
	var count := 0
	for def in _defs:
		if def.world == world:
			count += 1
	return count


static func _world_name(world: StringName) -> String:
	for option in WORLDS:
		if option[0] == world:
			return option[1]
	return String(world)


func _current() -> StageDef:
	return _defs[_index]


# ---- 右の欄 ----

## 選んでいるステージの値を欄に入れる。
func _show_def() -> void:
	if _defs.is_empty():
		return
	_loading = true
	var def := _current()
	(_fields["id"] as LineEdit).text = String(def.id)
	(_fields["name"] as LineEdit).text = def.name
	(_fields["world"] as OptionButton).select(EnemyEditor._find_option(WORLDS, def.world))
	_fill_enemy_pick(_fields["boss"] as OptionButton, def.boss)
	for spec in STAGE_SLIDERS + BOSS_SLIDERS:
		var value := float(def.get(spec[0]))
		(_fields[spec[0]] as HSlider).value = value
		_update_value_label(spec[0], value)
	(_fields["memo"] as TextEdit).text = def.memo
	_loading = false
	_rebuild_lineup()
	_refresh_summary()


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
	_set_status("")
	_changed()


func _on_name_changed(text: String) -> void:
	if _loading:
		return
	_current().name = text
	_list.set_item_text(_index, _item_text(_index, _current()))
	_changed()


func _on_world_selected(index: int) -> void:
	if _loading:
		return
	_current().world = WORLDS[index][0]
	_changed()


func _on_boss_selected(index: int) -> void:
	if _loading:
		return
	_current().boss = _enemy_ids[index] if index < _enemy_ids.size() else _current().boss
	_changed()


func _on_slider_changed(value: float, key: String) -> void:
	_update_value_label(key, value)
	if _loading:
		return
	if key in FLOAT_KEYS:
		_current().set(key, value)
	else:
		_current().set(key, roundi(value))
	_changed()


## つまみの横の − ＋ で1刻みずつ動かす（指でつまみを細かく合わせにくいので）。
func _on_step_pressed(slider: HSlider, step_sign: int) -> void:
	Sfx.play(&"click")
	slider.value = maxf(slider.value + slider.step * step_sign, slider.min_value)


func _update_value_label(key: String, value: float) -> void:
	var label := _fields[key + "_label"] as Label
	label.text = EnemyDef._num(value) if key in FLOAT_KEYS else str(roundi(value))


func _on_memo_changed() -> void:
	if _loading:
		return
	_current().memo = (_fields["memo"] as TextEdit).text.replace("\n", " ")
	_changed()


## 敵を選ぶ欄の中身（enemies.csv の全部）を作り、selected を選ぶ。表にない id はそのまま末尾に出す。
func _fill_enemy_pick(pick: OptionButton, selected: StringName) -> void:
	pick.clear()
	for id in _enemy_ids:
		var enemy := Progress.enemies[id] as EnemyDef
		pick.add_item(EnemyEditor._item_text(enemy.name, id))
	var at := _enemy_ids.find(selected)
	if at < 0:
		pick.add_item("%s（enemies.csv にない）" % selected)
		at = _enemy_ids.size()
	pick.select(at)


# ---- 出てくる敵の並び ----

## 選んでいるステージの敵を1種類1行で並べ直す。行は「敵の種類・数のつまみ・消す」。
func _rebuild_lineup() -> void:
	for child in _lineup.get_children():
		child.queue_free()
	var def := _current()
	for i in def.enemies.size():
		_lineup.add_child(_lineup_row(i, def.enemies[i]))
	var add := Button.new()
	add.text = "＋ 敵を足す"
	add.focus_mode = Control.FOCUS_NONE
	add.custom_minimum_size = Vector2(0, 48)
	UiStyle.button(add, UiStyle.GREEN, 18)
	add.pressed.connect(_on_add_enemy_pressed)
	_lineup.add_child(add)


func _lineup_row(i: int, entry: Array) -> Control:
	var box := VBoxContainer.new()
	var top := HBoxContainer.new()
	box.add_child(top)
	var pick := OptionButton.new()
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.clip_text = true
	pick.add_theme_font_size_override("font_size", 18)
	_fill_enemy_pick(pick, entry[0])
	pick.item_selected.connect(_on_lineup_enemy_selected.bind(i))
	top.add_child(pick)
	var remove := Button.new()
	remove.text = "消す"
	remove.focus_mode = Control.FOCUS_NONE
	remove.custom_minimum_size = Vector2(72, 0)
	UiStyle.button(remove, DELETE_COLOR, 16)
	remove.pressed.connect(_on_remove_enemy_pressed.bind(i))
	top.add_child(remove)
	var key := "count_%d" % i
	var spec := [key, "", COUNT_MIN, COUNT_MAX, 1.0]
	var row := _slider_row(spec, _on_count_changed.bind(i))
	var label := Label.new()
	label.text = "数"
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)
	row.move_child(label, 0)
	box.add_child(row)
	var slider := _fields[key] as HSlider
	slider.set_value_no_signal(entry[1])
	_update_value_label(key, entry[1])
	return box


func _on_lineup_enemy_selected(index: int, i: int) -> void:
	if index >= _enemy_ids.size():
		return
	_current().enemies[i][0] = _enemy_ids[index]
	_changed()


func _on_count_changed(value: float, i: int) -> void:
	_update_value_label("count_%d" % i, value)
	_current().enemies[i][1] = roundi(value)
	_changed()


func _on_add_enemy_pressed() -> void:
	Sfx.play(&"click")
	if _enemy_ids.is_empty():
		return
	# まだ出ていない敵を先に選ぶ
	var pick := _enemy_ids[0]
	for id in _enemy_ids:
		var used := false
		for entry in _current().enemies:
			used = used or entry[0] == id
		if not used and id != _current().boss:
			pick = id
			break
	_current().enemies.append([pick, 1])
	_rebuild_lineup()
	_changed()


func _on_remove_enemy_pressed(i: int) -> void:
	Sfx.play(&"click")
	_current().enemies.remove_at(i)
	_rebuild_lineup()
	_changed()


# ---- まとめ ----

## このステージで実際に出る敵の耐久・宝石・速さと、気をつけること。
func _refresh_summary() -> void:
	if _defs.is_empty():
		return
	var def := _current()
	var lines := PackedStringArray()
	var total := 0
	for entry in def.enemies:
		total += int(entry[1])
		var enemy := Progress.enemies.get(entry[0]) as EnemyDef
		if enemy != null:
			lines.append("%s ×%d　耐久 %d・宝石 %d・速さ %d" % [enemy.name, entry[1], enemy.hp_from(def.enemy_hp),
					enemy.gem_from(def.enemy_gem), roundi(enemy.speed_from(def.enemy_speed))])
	var boss := Progress.enemies.get(def.boss) as EnemyDef
	if boss != null:
		lines.append("ボス %s　耐久 %d・宝石 %d・速さ %d" % [boss.name, boss.hp_from(def.boss_hp),
				boss.gem_from(def.boss_gem), roundi(boss.speed_from(def.boss_speed))])
	lines.append("同時に %d 体。%d 体倒すとボス。倒した敵は %s 秒で湧き直す" % [total, def.boss_after,
			EnemyDef._num(def.respawn_time)])
	var problem := _problem(def)
	if not problem.is_empty():
		lines.append(problem)
	_summary.text = "\n".join(lines)
	_summary.add_theme_color_override("font_color", WARN_COLOR if not problem.is_empty() else Color.WHITE)


## 試遊できない設定なら、その理由。
func _problem(def: StageDef) -> String:
	if not Progress.enemies.has(def.boss):
		return "ボスを選んでください"
	if def.enemies.is_empty() and def.boss_after > 0:
		return "敵がいないとボスが出ません（敵を足すか、何体倒すと出るかを 0 に）"
	for entry in def.enemies:
		if not Progress.enemies.has(entry[0]):
			return "敵 %s が enemies.csv にありません" % entry[0]
	return ""


# ---- 画面の組み立て ----

func _build_layout() -> void:
	var title := _label("ステージエディタ（開発用）", 30, Vector2(20, 12))
	title.add_theme_color_override("font_color", HEADING_COLOR)
	var x := 1264.0
	for spec in [["戻る", UiStyle.BLUE, _on_back_pressed], ["元に戻す", DELETE_COLOR, _on_revert_pressed],
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
	_button("削除", DELETE_COLOR, Rect2(LIST_RECT.position.x + 136, bottom, 64, 42), _on_delete_pressed, 16)
	bottom += 48.0
	_button("▲ 前へ", UiStyle.BLUE, Rect2(LIST_RECT.position.x, bottom, 98, 42), _on_move_pressed.bind(-1), 16)
	_button("▼ 後へ", UiStyle.BLUE, Rect2(LIST_RECT.position.x + 102, bottom, 98, 42), _on_move_pressed.bind(1), 16)

	_build_lineup()
	_build_test()
	_build_form()


func _build_lineup() -> void:
	var panel := _panel(LINEUP_RECT)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_heading("出てくる敵（倒すと湧き直す）"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_lineup = VBoxContainer.new()
	_lineup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lineup.add_theme_constant_override("separation", 12)
	scroll.add_child(_lineup)


func _build_test() -> void:
	var panel := _panel(TEST_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 16)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_summary)
	_upgrades_pick = OptionButton.new()
	for option in TEST_UPGRADES:
		_upgrades_pick.add_item(option[1])
	_upgrades_pick.add_theme_font_size_override("font_size", 18)
	_upgrades_pick.select(_last_upgrades)
	box.add_child(_upgrades_pick)
	var test := Button.new()
	test.text = "このステージを試遊"
	test.focus_mode = Control.FOCUS_NONE
	test.custom_minimum_size = Vector2(0, 56)
	UiStyle.button(test, UiStyle.YELLOW, 24)
	test.pressed.connect(_on_test_pressed)
	box.add_child(test)
	var note := Label.new()
	note.text = "試遊で拾った素材や解放は残りません。終わるとここに戻ります"
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color(0.75, 0.8, 0.95))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)


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
	var world_pick := OptionButton.new()
	for option in WORLDS:
		world_pick.add_item(option[1])
	world_pick.item_selected.connect(_on_world_selected)
	_form_row(grid, "世界", world_pick, "world")
	for spec in STAGE_SLIDERS:
		_form_row(grid, spec[1], _slider_row(spec, _on_slider_changed.bind(spec[0])), "")
	var boss_heading := _form_row(grid, "ボス", Control.new(), "")
	boss_heading.add_theme_color_override("font_color", HEADING_COLOR)
	var boss_pick := OptionButton.new()
	boss_pick.item_selected.connect(_on_boss_selected)
	_form_row(grid, "ボスの敵", boss_pick, "boss")
	for spec in BOSS_SLIDERS:
		_form_row(grid, spec[1], _slider_row(spec, _on_slider_changed.bind(spec[0])), "")
	var memo := TextEdit.new()
	memo.custom_minimum_size = Vector2(0, 110)
	memo.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	memo.text_changed.connect(_on_memo_changed)
	_form_row(grid, "メモ", memo, "memo")


## − つまみ ＋ 値 を横に並べた行。つまみと値の表示は _fields の spec[0] と spec[0]_label に入れる。
func _slider_row(spec: Array, on_changed: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var slider := HSlider.new()
	slider.min_value = spec[2]
	slider.max_value = spec[3]
	slider.step = spec[4]
	slider.allow_greater = true
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 32)
	slider.value_changed.connect(on_changed)
	row.add_child(_step_button("−", slider, -1))
	row.add_child(slider)
	row.add_child(_step_button("＋", slider, 1))
	var value := Label.new()
	value.custom_minimum_size = Vector2(56, 0)
	value.add_theme_font_size_override("font_size", 18)
	row.add_child(value)
	_fields[spec[0]] = slider
	_fields[spec[0] + "_label"] = value
	return row


func _step_button(text: String, slider: HSlider, step_sign: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(40, 40)
	UiStyle.button(button, UiStyle.BLUE, 18)
	button.pressed.connect(_on_step_pressed.bind(slider, step_sign))
	return button


func _form_row(grid: GridContainer, text: String, control: Control, key: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.custom_minimum_size = Vector2(120, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.add_theme_font_size_override("font_size", 18)
	var button := control as Button
	if button != null:
		button.clip_text = true
	grid.add_child(control)
	if key != "":
		_fields[key] = control
	return label


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", HEADING_COLOR)
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
