class_name Stats
extends RefCounted
## 強化の段から戦闘の数値（ダメージ・耐久・あと何発で壊れるか）を計算する。
## levels を差し替えれば「この強化を買ったら何発になるか」も同じ式で計算できる。

const SLIME := &"slime"
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


## ラン1回の活動時間（秒）。Hourglass で伸びる。
static func run_time(levels: Dictionary) -> float:
	return Balance.get_float("run_time") + effect(&"hourglass", levels)


## 魔法弾を撃つ間隔（秒）。Quick Cast の段ごとに「1秒あたりの発数」が value 倍ずつ増える。
static func fire_interval(levels: Dictionary) -> float:
	return Balance.get_float("fire_interval") / (1.0 + effect(&"quick_cast", levels))


## 自動攻撃が狙える距離（ピクセル）。Far Sight で伸びる。
static func fire_range(levels: Dictionary) -> float:
	return Balance.get_float("fire_range") + effect(&"far_sight", levels)


## 落ちた素材を吸い寄せ始める距離（ピクセル）。
static func pickup_radius(levels: Dictionary) -> float:
	return Balance.get_float("pickup_radius") + effect(&"magnet", levels)


## プレイヤーの体力の上限。生命の芽で増える。
static func player_hp(levels: Dictionary) -> int:
	return maxi(Balance.get_int("player_hp") + roundi(effect(&"vitality", levels)), 1)


## 被弾したあとの無敵時間（秒）。守りの光で伸びる。
static func invincible_time(levels: Dictionary) -> float:
	return Balance.get_float("player_invincible_time") + effect(&"ward", levels)


## プレイヤーの移動速度（ピクセル/秒）。俊足で上がる。
static func player_speed(levels: Dictionary) -> float:
	return Balance.get_float("player_speed") + effect(&"swift", levels)


## 背水: 体力が残り1のときの撃つ間隔（秒）。背水がなければ普段と同じ。
static func fire_interval_at(hp: int, levels: Dictionary) -> float:
	var boost := effect(&"last_stand", levels) if hp == 1 else 0.0
	return Balance.get_float("fire_interval") / (1.0 + effect(&"quick_cast", levels) + boost)


## 倒した敵（ボス以外）が落とす素材の数。豊穣で増える。
static func drop_amount(base: int, levels: Dictionary) -> int:
	return base + roundi(effect(&"harvest", levels))


## ボスが落とす宝石の数。懸賞で増える（端数は切り上げ）。
static func boss_reward(base: int, levels: Dictionary) -> int:
	return ceili(base * (1.0 + effect(&"bounty", levels) / 100.0))
