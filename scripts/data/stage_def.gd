class_name StageDef
extends RefCounted
## 1ステージ分の定義（data/stages.csv の1行）。
## 出てくる敵は enemies に「敵のid:数」を | でつないで書く（例: slime:7|dasher:1）。敵の種類は data/enemies.csv。
## ステージエディタ（scenes/stage_editor）でも変えられる。

var id: StringName
var name := ""
var world: StringName
## [敵のid, 数] の並び
var enemies: Array = []
## このステージの敵の基準の耐久・宝石・移動速度（敵ごとの倍率を掛ける）
var enemy_hp := 1
var enemy_gem := 0
var enemy_speed := 0.0
var oak_count := 0
var oak_hp := 1
var oak_wood := 0
## ボスの敵のid
var boss: StringName
## この数だけ倒すとボスが出る
var boss_after := 1
var boss_hp := 1
var boss_gem := 0
var boss_speed := 0.0
## 草地の数（平原のギミック）
var grass := 0
## 倒した敵（ボス以外）が湧き直すまでの秒数。空なら balance.csv の slime_respawn_time
var respawn_time := 0.0
var memo := ""


static func from_row(row: Dictionary) -> StageDef:
	var def := StageDef.new()
	def.id = StringName(row.get("id", ""))
	def.name = row.get("name", "")
	def.world = StringName(row.get("world", ""))
	def.enemies = _parse_enemies(row.get("enemies", ""))
	def.enemy_hp = maxi(String(row.get("enemy_hp", "1")).to_int(), 1)
	def.enemy_gem = String(row.get("enemy_gem", "0")).to_int()
	def.enemy_speed = String(row.get("enemy_speed", "0")).to_float()
	def.oak_count = String(row.get("oak_count", "0")).to_int()
	def.oak_hp = maxi(String(row.get("oak_hp", "1")).to_int(), 1)
	def.oak_wood = String(row.get("oak_wood", "0")).to_int()
	def.boss = StringName(row.get("boss", ""))
	def.boss_after = maxi(String(row.get("boss_after", "1")).to_int(), 0)
	def.boss_hp = maxi(String(row.get("boss_hp", "1")).to_int(), 1)
	def.boss_gem = String(row.get("boss_gem", "0")).to_int()
	def.boss_speed = String(row.get("boss_speed", "0")).to_float()
	def.grass = String(row.get("grass", "0")).to_int()
	var respawn := String(row.get("respawn_time", "")).strip_edges()
	def.respawn_time = respawn.to_float() if not respawn.is_empty() else Balance.get_float("slime_respawn_time")
	def.memo = row.get("memo", "")
	return def


## stages.csv の1行に戻す（ステージエディタが書き出すとき）。
func to_row() -> Dictionary:
	return {
		"id": String(id), "name": name, "world": String(world), "enemies": enemies_text(),
		"enemy_hp": str(enemy_hp), "enemy_gem": str(enemy_gem), "enemy_speed": EnemyDef._num(enemy_speed),
		"oak_count": str(oak_count), "oak_hp": str(oak_hp), "oak_wood": str(oak_wood),
		"boss": String(boss), "boss_after": str(boss_after), "boss_hp": str(boss_hp), "boss_gem": str(boss_gem),
		"boss_speed": EnemyDef._num(boss_speed), "grass": str(grass), "respawn_time": EnemyDef._num(respawn_time),
		"memo": memo,
	}


func copy() -> StageDef:
	return StageDef.from_row(to_row())


## [[&"slime", 7], [&"dasher", 1]] → "slime:7|dasher:1"
func enemies_text() -> String:
	var parts := PackedStringArray()
	for entry in enemies:
		parts.append("%s:%d" % [entry[0], entry[1]])
	return "|".join(parts)


## "slime:7|dasher:1" → [[&"slime", 7], [&"dasher", 1]]。数を省くと1。
static func _parse_enemies(text: String) -> Array:
	var result := []
	for part in text.split("|", false):
		var pair := part.strip_edges().split(":")
		var count := pair[1].to_int() if pair.size() > 1 else 1
		if not pair[0].strip_edges().is_empty() and count > 0:
			result.append([StringName(pair[0].strip_edges()), count])
	return result
