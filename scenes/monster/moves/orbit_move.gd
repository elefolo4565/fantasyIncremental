class_name OrbitMove
extends WanderMove
## 周回。プレイヤーが orbit_notice_range より近づくと、半径 orbit_radius の円を描いて回り、
## orbit_lunge_interval ごとに orbit_lunge_time のあいだプレイヤーへ詰め寄る（詰め寄るときは怒り顔）。
## 数値は balance.csv の orbit_*。

enum State { WANDER, CIRCLE, LUNGE }

var _state := State.WANDER
var _state_left := 0.0
## 回る向き（1 で時計回り、-1 で反時計回り）
var _turn := 1.0


func reset() -> void:
	_state = State.WANDER
	_turn = 1.0 if randf() < 0.5 else -1.0


func step(delta: float) -> Vector2:
	var distance := distance_to_target()
	_state_left -= delta
	match _state:
		State.WANDER:
			if distance < Balance.get_float("orbit_notice_range"):
				_circle()
			return wander(delta) * monster.speed
		State.LUNGE:
			if _state_left <= 0.0:
				_circle()
			return direction_to_target() * monster.speed * Balance.get_float("orbit_lunge_multiplier")
		_:
			if distance > Balance.get_float("orbit_notice_range") * 1.5:
				_state = State.WANDER
			elif _state_left <= 0.0:
				_state = State.LUNGE
				_state_left = Balance.get_float("orbit_lunge_time")
			# 円に沿う向きに、円の内側・外側へのずれを直す向きを足す
			var to_target := direction_to_target()
			var radius := Balance.get_float("orbit_radius")
			var correct := clampf((distance - radius) / radius, -1.0, 1.0)
			return (to_target.orthogonal() * _turn + to_target * correct).normalized() * monster.speed


func on_edge() -> void:
	super()
	_turn = -_turn


func is_angry() -> bool:
	return _state == State.LUNGE


func facing() -> Vector2:
	return direction_to_target() if _state == State.CIRCLE else Vector2.ZERO


func _circle() -> void:
	_state = State.CIRCLE
	_state_left = Balance.get_float("orbit_lunge_interval") * randf_range(0.7, 1.3)
