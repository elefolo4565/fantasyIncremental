class_name StageDef
extends RefCounted
## 1ステージ分の定義（data/stages.csv の1行）。

var id: StringName
var name := ""
var world: StringName
var slime_count := 0
var slime_hp := 1
var slime_gem := 0
var slime_speed := 0.0
## 突進スライムの数（耐久・宝石はスライムと同じ）
var dasher_count := 0
var oak_count := 0
var oak_hp := 1
var oak_wood := 0
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
	def.slime_count = String(row.get("slime_count", "0")).to_int()
	def.slime_hp = maxi(String(row.get("slime_hp", "1")).to_int(), 1)
	def.slime_gem = String(row.get("slime_gem", "0")).to_int()
	def.slime_speed = String(row.get("slime_speed", "0")).to_float()
	def.dasher_count = String(row.get("dasher_count", "0")).to_int()
	def.oak_count = String(row.get("oak_count", "0")).to_int()
	def.oak_hp = maxi(String(row.get("oak_hp", "1")).to_int(), 1)
	def.oak_wood = String(row.get("oak_wood", "0")).to_int()
	def.boss_after = maxi(String(row.get("boss_after", "1")).to_int(), 0)
	def.boss_hp = maxi(String(row.get("boss_hp", "1")).to_int(), 1)
	def.boss_gem = String(row.get("boss_gem", "0")).to_int()
	def.boss_speed = String(row.get("boss_speed", "0")).to_float()
	def.grass = String(row.get("grass", "0")).to_int()
	return def
