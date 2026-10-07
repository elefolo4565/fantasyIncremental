class_name ZigzagMove
extends WanderMove
## ジグザグ。歩き回り、プレイヤーが slime_aggro_range より近づくと、左右に揺れながら追ってくる（怒り顔）。
## 揺れの速さと幅は balance.csv の zigzag_*、追う速さは slime_chase_multiplier 倍。

var _chasing := false
var _phase := 0.0


func reset() -> void:
	_phase = randf() * TAU


func step(delta: float) -> Vector2:
	_chasing = distance_to_target() < Balance.get_float("slime_aggro_range")
	if not _chasing:
		return wander(delta) * monster.speed
	_phase += delta * TAU * Balance.get_float("zigzag_frequency")
	var forward := direction_to_target()
	var sway := forward.orthogonal() * sin(_phase) * Balance.get_float("zigzag_width")
	return (forward + sway).normalized() * monster.speed * Balance.get_float("slime_chase_multiplier")


func is_angry() -> bool:
	return _chasing
