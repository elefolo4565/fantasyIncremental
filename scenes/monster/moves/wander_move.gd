class_name WanderMove
extends MonsterMove
## ふらふら歩き回る部品（ほかの部品の、プレイヤーに気づいていないときの動きにも使う）。
## 1〜2.5秒ごとに向きを選び直し、ときどき立ち止まる。

const TURN_MIN := 1.0
const TURN_MAX := 2.5
const PAUSE_CHANCE := 0.25

var _wander := Vector2.ZERO
var _wander_left := 0.0


func step(delta: float) -> Vector2:
	return wander(delta) * monster.speed


func on_edge() -> void:
	_wander = -_wander


## 歩き回る向き（長さ1か0）。
func wander(delta: float) -> Vector2:
	_wander_left -= delta
	if _wander_left <= 0.0:
		_wander_left = randf_range(TURN_MIN, TURN_MAX)
		_wander = Vector2.RIGHT.rotated(randf() * TAU) if randf() > PAUSE_CHANCE else Vector2.ZERO
	return _wander
