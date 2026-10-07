class_name JumpMove
extends WanderMove
## ジャンプ。歩き回り、プレイヤーが jump_notice_range より近づくと止まって力をため（着地点に予告の輪）、
## プレイヤーのいる所（jump_distance まで）へ跳ぶ。空中では当たらず、着地の瞬間は jump_impact_radius まで届く衝撃になる。
## 数値は balance.csv の jump_*。

enum State { WANDER, WINDUP, AIR, LAND, REST }

const MARK_COLOR := Color(1.0, 0.25, 0.2, 0.45)
const MARK_WIDTH := 6.0
## 着地の衝撃が当たる時間（秒。見た目と当たりを合わせるだけの短い時間）
const IMPACT_TIME := 0.12
## 跳ぶ高さ（ピクセル。見た目だけ）
const JUMP_HEIGHT := 90.0

var _state := State.WANDER
var _state_left := 0.0
var _from := Vector2.ZERO
var _landing := Vector2.ZERO


func reset() -> void:
	_state = State.WANDER


func step(delta: float) -> Vector2:
	_state_left -= delta
	match _state:
		State.WANDER:
			if distance_to_target() < Balance.get_float("jump_notice_range"):
				_state = State.WINDUP
				_state_left = Balance.get_float("jump_windup_time")
				_aim()
				return Vector2.ZERO
			return wander(delta) * monster.speed
		State.WINDUP:
			if _state_left > Balance.get_float("jump_windup_time") * 0.4:
				_aim()
			if _state_left <= 0.0:
				_state = State.AIR
				_state_left = Balance.get_float("jump_air_time")
				_from = monster.global_position
			return Vector2.ZERO
		State.AIR:
			if _state_left <= 0.0:
				_state = State.LAND
				_state_left = IMPACT_TIME
				return Vector2.ZERO
			# 残りの時間で着地点に着く速さ
			return (_landing - monster.global_position) / maxf(_state_left, delta)
		State.LAND:
			if _state_left <= 0.0:
				_state = State.REST
				_state_left = Balance.get_float("jump_rest_time")
			return Vector2.ZERO
		_:
			if _state_left <= 0.0:
				_state = State.WANDER
			return Vector2.ZERO


func is_angry() -> bool:
	return _state == State.WINDUP or _state == State.AIR


func can_touch() -> bool:
	return _state != State.AIR


func touch_bonus() -> float:
	return Balance.get_float("jump_impact_radius") if _state == State.LAND else 0.0


func lift() -> float:
	if _state != State.AIR:
		return 0.0
	var t := 1.0 - _state_left / maxf(Balance.get_float("jump_air_time"), 0.01)
	return sin(clampf(t, 0.0, 1.0) * PI) * JUMP_HEIGHT


func draw_under() -> void:
	if _state == State.WINDUP or _state == State.AIR:
		# 着地点の輪（キャラの大きさの倍率は掛かっているので、距離は割り戻す）
		var scale := maxf(monster.scale.x, 0.01)
		var at := (_landing - monster.global_position) / scale
		monster.draw_arc(at, Balance.get_float("jump_impact_radius") / scale, 0.0, TAU, 32, MARK_COLOR, MARK_WIDTH)


func _aim() -> void:
	var offset := Vector2.ZERO
	if monster.target != null:
		offset = (monster.target.global_position - monster.global_position).limit_length(Balance.get_float("jump_distance"))
	_landing = monster.global_position + offset
