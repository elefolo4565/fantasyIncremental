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
var oak_count := 0
var oak_hp := 1
var oak_wood := 0
var goal := 1


static func from_row(row: Dictionary) -> StageDef:
	var def := StageDef.new()
	def.id = StringName(row.get("id", ""))
	def.name = row.get("name", "")
	def.world = StringName(row.get("world", ""))
	def.slime_count = String(row.get("slime_count", "0")).to_int()
	def.slime_hp = maxi(String(row.get("slime_hp", "1")).to_int(), 1)
	def.slime_gem = String(row.get("slime_gem", "0")).to_int()
	def.slime_speed = String(row.get("slime_speed", "0")).to_float()
	def.oak_count = String(row.get("oak_count", "0")).to_int()
	def.oak_hp = maxi(String(row.get("oak_hp", "1")).to_int(), 1)
	def.oak_wood = String(row.get("oak_wood", "0")).to_int()
	def.goal = maxi(String(row.get("goal", "1")).to_int(), 1)
	return def
