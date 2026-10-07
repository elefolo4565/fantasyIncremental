extends Node
## 魔導樹の強化の段・素材・解放したステージを持つオートロード。
## 強化ノード・ステージ・敵の定義は data/upgrades.csv・data/stages.csv・data/enemies.csv・data/shots.csv から読む。
## 進み具合は user://save.cfg に保存する（Web 版ではブラウザの中に残る）。

signal changed

const SAVE_PATH := "user://save.cfg"
const UPGRADES_PATH := "res://data/upgrades.csv"
const STAGES_PATH := "res://data/stages.csv"
const ENEMIES_PATH := "res://data/enemies.csv"
const SHOTS_PATH := "res://data/shots.csv"

var gem := 0
var wood := 0
## 強化の id → 今の段
var levels: Dictionary = {}
## 遊べる一番先のステージ（stages の番号）
var unlocked_stage := 0
var selected_stage := 0
## 敵・プレイヤーの大きさの倍率。戦闘画面のつまみで変えて試す（保存はしない）
var unit_scale := 1.0
## 草地の数の倍率（戦闘画面の「調整」つまみで変えられる。保存しない）
var grass_scale := 1.0
## 設定: true ならタップした場所へ移動する（false なら仮想スティック）
var tap_move := false
## 設定: BGM を鳴らすか
var bgm_on := true
var se_on := true

var upgrades: Array[UpgradeDef] = []
var stages: Array[StageDef] = []
## 敵のid → EnemyDef
var enemies: Dictionary = {}
## 弾のid → ShotDef
var shots: Dictionary = {}

var _by_id: Dictionary = {}
var _saving := true


func _ready() -> void:
	unit_scale = Balance.get_float("unit_scale")
	grass_scale = Balance.get_float("grass_scale")
	for row in Balance.load_table(UPGRADES_PATH):
		var def := UpgradeDef.from_row(row)
		upgrades.append(def)
		_by_id[def.id] = def
	for row in Balance.load_table(STAGES_PATH):
		stages.append(StageDef.from_row(row))
	for row in Balance.load_table(ENEMIES_PATH):
		var enemy := EnemyDef.from_row(row)
		enemies[enemy.id] = enemy
	for row in Balance.load_table(SHOTS_PATH):
		var shot_def := ShotDef.from_row(row)
		shots[shot_def.id] = shot_def
	_load_save()


func enemy(id: StringName) -> EnemyDef:
	var def := enemies.get(id) as EnemyDef
	if def == null:
		push_error("敵 %s が data/enemies.csv にありません" % id)
	return def


func shot(id: StringName) -> ShotDef:
	var def := shots.get(id) as ShotDef
	if def == null:
		push_error("弾 %s が data/shots.csv にありません" % id)
	return def


func upgrade(id: StringName) -> UpgradeDef:
	return _by_id.get(id) as UpgradeDef


func level(id: StringName) -> int:
	return levels.get(id, 0)


## 親を覚えていれば開く。前の魔導樹で覚えた段が残っているノードも開いたままにする。
func is_unlocked(def: UpgradeDef) -> bool:
	return def.parent == &"" or level(def.parent) > 0 or level(def.id) > 0


func is_maxed(def: UpgradeDef) -> bool:
	return level(def.id) >= def.max_level


func next_cost(def: UpgradeDef) -> Vector2i:
	return def.cost_for(level(def.id))


func can_buy(def: UpgradeDef) -> bool:
	if not is_unlocked(def) or is_maxed(def):
		return false
	var cost := next_cost(def)
	return gem >= cost.x and wood >= cost.y


func buy(def: UpgradeDef) -> bool:
	if not can_buy(def):
		return false
	var cost := next_cost(def)
	gem -= cost.x
	wood -= cost.y
	levels[def.id] = level(def.id) + 1
	_changed()
	return true


func add_materials(gained_gem: int, gained_wood: int) -> void:
	gem += gained_gem
	wood += gained_wood
	changed.emit()


## ステージをクリアしたときに呼ぶ。新しいステージが解放されたら true。
func clear_stage(index: int) -> bool:
	if index == unlocked_stage and unlocked_stage < stages.size() - 1:
		unlocked_stage += 1
		selected_stage = unlocked_stage
		_changed()
		return true
	_changed()
	return false


func set_tap_move(on: bool) -> void:
	tap_move = on
	_changed()


func set_bgm_on(on: bool) -> void:
	bgm_on = on
	_changed()


func set_se_on(on: bool) -> void:
	se_on = on
	_changed()


func reset() -> void:
	gem = 0
	wood = 0
	levels.clear()
	unlocked_stage = 0
	selected_stage = 0
	_changed()


## CI の動作確認用。全ての強化を最大にし、保存しない。
func enable_smoke_mode() -> void:
	_saving = false
	for def in upgrades:
		levels[def.id] = def.max_level
	unlocked_stage = stages.size() - 1
	selected_stage = unlocked_stage


func save() -> void:
	if not _saving:
		return
	var config := ConfigFile.new()
	config.set_value("materials", "gem", gem)
	config.set_value("materials", "wood", wood)
	config.set_value("stages", "unlocked", unlocked_stage)
	config.set_value("stages", "selected", selected_stage)
	config.set_value("options", "tap_move", tap_move)
	config.set_value("options", "bgm_on", bgm_on)
	config.set_value("options", "se_on", se_on)
	for id in levels:
		config.set_value("levels", String(id), levels[id])
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("進み具合を保存できませんでした (error %d)" % error)


func _changed() -> void:
	save()
	changed.emit()


func _load_save() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	gem = config.get_value("materials", "gem", 0)
	wood = config.get_value("materials", "wood", 0)
	unlocked_stage = clampi(config.get_value("stages", "unlocked", 0), 0, stages.size() - 1)
	selected_stage = clampi(config.get_value("stages", "selected", 0), 0, unlocked_stage)
	tap_move = bool(config.get_value("options", "tap_move", false))
	bgm_on = bool(config.get_value("options", "bgm_on", true))
	se_on = bool(config.get_value("options", "se_on", true))
	if config.has_section("levels"):
		for key in config.get_section_keys("levels"):
			var def := upgrade(StringName(key))
			if def != null:
				levels[def.id] = clampi(config.get_value("levels", key, 0), 0, def.max_level)
