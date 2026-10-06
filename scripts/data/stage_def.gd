class_name StageDef
extends RefCounted
## 1ステージ分の定義（data/stages.csv の1行）。

var id: StringName
var name := ""
var world: StringName
var rock_count := 0
var rock_hp := 1
var rock_stone := 0
var oak_count := 0
var oak_hp := 1
var oak_wood := 0
var goal := 1
var run_time := 60.0


static func from_row(row: Dictionary) -> StageDef:
	var def := StageDef.new()
	def.id = StringName(row.get("id", ""))
	def.name = row.get("name", "")
	def.world = StringName(row.get("world", ""))
	def.rock_count = String(row.get("rock_count", "0")).to_int()
	def.rock_hp = maxi(String(row.get("rock_hp", "1")).to_int(), 1)
	def.rock_stone = String(row.get("rock_stone", "0")).to_int()
	def.oak_count = String(row.get("oak_count", "0")).to_int()
	def.oak_hp = maxi(String(row.get("oak_hp", "1")).to_int(), 1)
	def.oak_wood = String(row.get("oak_wood", "0")).to_int()
	def.goal = maxi(String(row.get("goal", "1")).to_int(), 1)
	def.run_time = String(row.get("run_time", "60")).to_float()
	return def
