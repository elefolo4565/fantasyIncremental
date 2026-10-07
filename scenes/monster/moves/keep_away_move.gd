class_name KeepAwayMove
extends WanderMove
## 距離をとる。プレイヤーが keep_notice_range より近づくと、keep_near〜keep_far の距離を保ちながら横へ回り込む。
## 近すぎれば離れ、遠すぎれば寄る。弾を撃つ敵（enemies.csv の shot）と組み合わせる向け。いつもプレイヤーのほうを向く。
## 数値は balance.csv の keep_*。

## 横へ回り込む向きを変えるまでの秒数（見た目の揺らぎ）
const SIDE_MIN := 1.5
const SIDE_MAX := 3.5

var _noticed := false
var _side := 1.0
var _side_left := 0.0


func reset() -> void:
	_noticed = false
	_side = 1.0 if randf() < 0.5 else -1.0


func step(delta: float) -> Vector2:
	var distance := distance_to_target()
	_noticed = distance < Balance.get_float("keep_notice_range")
	if not _noticed:
		return wander(delta) * monster.speed
	_side_left -= delta
	if _side_left <= 0.0:
		_side_left = randf_range(SIDE_MIN, SIDE_MAX)
		_side = -_side
	var to_target := direction_to_target()
	var radial := 0.0
	if distance < Balance.get_float("keep_near"):
		radial = -1.0
	elif distance > Balance.get_float("keep_far"):
		radial = 1.0
	var sideways := to_target.orthogonal() * _side * Balance.get_float("keep_strafe_rate")
	return (to_target * radial + sideways).limit_length(1.0) * monster.speed


func on_edge() -> void:
	super()
	_side = -_side


func facing() -> Vector2:
	return direction_to_target() if _noticed else Vector2.ZERO
