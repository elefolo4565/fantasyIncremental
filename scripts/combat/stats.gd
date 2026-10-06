class_name Stats
extends RefCounted
## 強化の段から戦闘の数値（ダメージ・耐久・あと何発で壊れるか）を計算する。
## levels を差し替えれば「この強化を買ったら何発になるか」も同じ式で計算できる。

const ROCK := &"rock"
const OAK := &"oak"


## 強化の効果量（段 × upgrades.csv の value）。
static func effect(id: StringName, levels: Dictionary) -> float:
	var def := Progress.upgrade(id)
	if def == null:
		return 0.0
	return float(levels.get(id, 0)) * def.value


static func with_level(levels: Dictionary, id: StringName, delta: int) -> Dictionary:
	var copy := levels.duplicate()
	copy[id] = int(copy.get(id, 0)) + delta
	return copy


static func max_hp(base_hp: int, levels: Dictionary) -> int:
	return maxi(base_hp - roundi(effect(&"fracture", levels)), 1)


static func hit_damage(kind: StringName, undamaged: bool, focused: bool, levels: Dictionary) -> int:
	var damage := Balance.get_float("bolt_damage") + effect(&"power", levels)
	if kind == OAK:
		damage += effect(&"woodsplitter", levels)
	if undamaged:
		damage += effect(&"opening", levels)
	if focused:
		damage *= Balance.get_float("focus_multiplier")
	return maxi(roundi(damage), 1)


## 耐久がこの値以下になったら即座に壊れる（Finisher）。
static func finish_threshold(levels: Dictionary) -> int:
	return roundi(effect(&"finisher", levels))


## 耐久 hp の物を、普通の魔法弾であと何発で壊せるか。
static func hits_from(kind: StringName, hp: int, undamaged: bool, levels: Dictionary) -> int:
	var finish := finish_threshold(levels)
	var left := hp
	var fresh := undamaged
	var hits := 0
	while left > 0:
		left -= hit_damage(kind, fresh, false, levels)
		fresh = false
		hits += 1
		if left <= finish:
			break
	return hits


## 新品の物（耐久 base_hp）を壊すのに必要な回数。
static func hits_to_break(kind: StringName, base_hp: int, levels: Dictionary) -> int:
	return hits_from(kind, max_hp(base_hp, levels), true, levels)
