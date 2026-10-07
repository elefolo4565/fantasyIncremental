class_name WanderChaseMove
extends WanderMove
## 歩き回り、プレイヤーが slime_aggro_range より近づくと怒って追ってくる（速さは slime_chase_multiplier 倍）。

var _chasing := false


func step(delta: float) -> Vector2:
	_chasing = distance_to_target() < Balance.get_float("slime_aggro_range")
	if _chasing:
		return direction_to_target() * monster.speed * Balance.get_float("slime_chase_multiplier")
	return wander(delta) * monster.speed


func is_angry() -> bool:
	return _chasing
