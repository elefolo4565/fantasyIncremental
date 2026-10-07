class_name StageDef
extends RefCounted
## 1ステージ分の定義（data/stages.csv の1行）。
## 出てくる敵は enemies に「敵のid:数」を | でつないで書く（例: slime:7|dasher:1）。敵の種類は data/enemies.csv。

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
	return def


## "slime:7|dasher:1" → [[&"slime", 7], [&"dasher", 1]]。数を省くと1。
static func _parse_enemies(text: String) -> Array:
	var result := []
	for part in text.split("|", false):
		var pair := part.strip_edges().split(":")
		var count := pair[1].to_int() if pair.size() > 1 else 1
		if not pair[0].strip_edges().is_empty() and count > 0:
			result.append([StringName(pair[0].strip_edges()), count])
	return result
