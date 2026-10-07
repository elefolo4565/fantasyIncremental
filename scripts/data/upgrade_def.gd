class_name UpgradeDef
extends RefCounted
## 魔導樹の強化ノード1つ分の定義（data/upgrades.csv の1行）。

var id: StringName
var name := ""
var parent: StringName
var max_level := 1
var value := 0.0
var gem_costs: PackedInt32Array = []
var wood_costs: PackedInt32Array = []
## 魔導樹の軸（attack / life / income）
var axis: StringName
## 中心から何段目か
var ring := 1
## 軸の向きからずらす角度（度）
var angle := 0.0
var desc := ""


static func from_row(row: Dictionary) -> UpgradeDef:
	var def := UpgradeDef.new()
	def.id = StringName(row.get("id", ""))
	def.name = row.get("name", "")
	def.parent = StringName(row.get("parent", ""))
	def.max_level = maxi(String(row.get("max_level", "1")).to_int(), 1)
	def.value = String(row.get("value", "0")).to_float()
	def.gem_costs = _parse_costs(row.get("cost_gem", ""), def.max_level)
	def.wood_costs = _parse_costs(row.get("cost_wood", ""), def.max_level)
	def.axis = StringName(row.get("axis", ""))
	def.ring = maxi(String(row.get("ring", "1")).to_int(), 1)
	def.angle = String(row.get("angle", "0")).to_float()
	def.desc = row.get("desc", "")
	return def


## 次の段（level + 1）を買う費用。x が石、y が木。
func cost_for(level: int) -> Vector2i:
	var i := clampi(level, 0, max_level - 1)
	return Vector2i(gem_costs[i], wood_costs[i])


## 説明文の {v} を value に、{balance のキー} をその数値に置き換える。
func description() -> String:
	var text := desc.replace("{v}", _format(value))
	var regex := RegEx.create_from_string("\\{([a-z_]+)\\}")
	for found in regex.search_all(text):
		var key := found.get_string(1)
		if Balance.has(key):
			text = text.replace(found.get_string(), _format(Balance.get_float(key)))
	return text


static func _format(number: float) -> String:
	if is_equal_approx(number, roundf(number)):
		return str(roundi(number))
	return str(snappedf(number, 0.01))


static func _parse_costs(text: String, count: int) -> PackedInt32Array:
	var costs: PackedInt32Array = []
	var parts := text.split("|", false)
	for i in count:
		costs.append(parts[mini(i, parts.size() - 1)].to_int() if parts.size() > 0 else 0)
	return costs
