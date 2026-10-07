class_name DashMove
extends WanderMove
## 突進。ふだんは歩き回り、プレイヤーが dasher_notice_range より近づくと、その場で止まって力をため（予備動作）、
## まっすぐ突進して、少し休む。予備動作のあいだは突進する向きに線が出るので、見てから避けられる。
## 数値は balance.csv の dasher_*。

enum State { WANDER, WINDUP, DASH, REST }

const AIM_COLOR := Color(1.0, 0.25, 0.2, 0.45)
const AIM_WIDTH := 18.0

var _state := State.WANDER
var _state_left := 0.0
var _dash_dir := Vector2.ZERO
var _dash_left := 0.0


func reset() -> void:
	_state = State.WANDER


func step(delta: float) -> Vector2:
	_state_left -= delta
	match _state:
		State.WANDER:
			if distance_to_target() < Balance.get_float("dasher_notice_range"):
				_state = State.WINDUP
				_state_left = Balance.get_float("dasher_windup_time")
				_dash_dir = direction_to_target()
				return Vector2.ZERO
			return wander(delta) * monster.speed
		State.WINDUP:
			# 予備動作の途中までは向きを合わせ直し、最後の少しは向きを固定する（避ける余地を残す）
			if monster.target != null and _state_left > Balance.get_float("dasher_aim_lock_time"):
				_dash_dir = direction_to_target()
			if _state_left <= 0.0:
				_state = State.DASH
				_dash_left = Balance.get_float("dasher_dash_distance")
			return Vector2.ZERO
		State.DASH:
			var velocity := _dash_dir * Balance.get_float("dasher_dash_speed")
			_dash_left -= velocity.length() * delta
			if _dash_left <= 0.0:
				_rest()
			return velocity
		_:
			if _state_left <= 0.0:
				_state = State.WANDER
			return Vector2.ZERO


func is_angry() -> bool:
	return _state == State.WINDUP or _state == State.DASH


func facing() -> Vector2:
	return _dash_dir if is_angry() else Vector2.ZERO


func on_edge() -> void:
	super()
	if _state == State.DASH:
		_rest()


func draw_under() -> void:
	if _state == State.WINDUP:
		# 突進する向きの線（キャラの大きさの倍率は掛かっているので、距離は割り戻す）
		var reach := Balance.get_float("dasher_dash_distance") / maxf(monster.scale.x, 0.01)
		monster.draw_line(Vector2.ZERO, _dash_dir * reach, AIM_COLOR, AIM_WIDTH)


func _rest() -> void:
	_state = State.REST
	_state_left = Balance.get_float("dasher_rest_time")
