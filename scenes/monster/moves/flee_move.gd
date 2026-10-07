class_name FleeMove
extends WanderMove
## 逃げる。歩き回り、プレイヤーが flee_range より近づくと背を向けて逃げる（速さは flee_speed_multiplier 倍）。
## 画面の端に追い詰められたら、端に沿って横へ逃げる向きを変える。宝石の多い「逃げる宝物」役の敵向け。

var _fleeing := false
var _side := 1.0


func reset() -> void:
	_fleeing = false
	_side = 1.0 if randf() < 0.5 else -1.0


func step(delta: float) -> Vector2:
	_fleeing = distance_to_target() < Balance.get_float("flee_range")
	if not _fleeing:
		return wander(delta) * monster.speed
	var away := -direction_to_target()
	# 真後ろへ逃げるだけだと端で止まるので、少し横へずらす
	var dir := (away + away.orthogonal() * _side * 0.5).normalized()
	return dir * monster.speed * Balance.get_float("flee_speed_multiplier")


func on_edge() -> void:
	super()
	_side = -_side
