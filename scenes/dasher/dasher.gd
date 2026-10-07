class_name Dasher
extends Slime
## 突進スライム。ふだんはふらふら歩き、プレイヤーが近くに来ると、その場で止まって力をため（予備動作）、素早く突進する。
## 予備動作のあいだは黄色く光り、突進する向きに線が出るので、見てから避けられる。突進のあとは少し休む。
## 耐久と落とす宝石はふつうのスライムと同じ（stages.csv の slime_hp・slime_gem）。

enum State { WANDER, WINDUP, DASH, REST }

## 頭に角のある橙色のスライム。予備動作と突進のあいだは黄色い怒り顔になる。
const DASHER_SHEET := preload("res://assets/sprites/enemies/dasher.png")
const WINDUP_SHEET := preload("res://assets/sprites/enemies/dasher_windup.png")
const AIM_COLOR := Color(1.0, 0.25, 0.2, 0.45)
const AIM_WIDTH := 18.0

var _state := State.WANDER
var _state_left := 0.0
var _dash_dir := Vector2.ZERO
var _dash_left := 0.0


func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	_bob += delta
	_state_left -= delta
	match _state:
		State.WANDER:
			_chasing = false
			if target != null and global_position.distance_to(target.global_position) < Balance.get_float("dasher_notice_range"):
				_state = State.WINDUP
				_state_left = Balance.get_float("dasher_windup_time")
				_dash_dir = global_position.direction_to(target.global_position)
				velocity = Vector2.ZERO
			else:
				velocity = _choose_wander(delta) * speed
		State.WINDUP:
			# 予備動作の途中までは向きを合わせ直し、最後の少しは向きを固定する（避ける余地を残す）
			if target != null and _state_left > Balance.get_float("dasher_aim_lock_time"):
				_dash_dir = global_position.direction_to(target.global_position)
			velocity = Vector2.ZERO
			if _state_left <= 0.0:
				_state = State.DASH
				_dash_left = Balance.get_float("dasher_dash_distance")
		State.DASH:
			_chasing = true
			velocity = _dash_dir * Balance.get_float("dasher_dash_speed")
			_dash_left -= velocity.length() * delta
			if _dash_left <= 0.0:
				_rest()
		State.REST:
			_chasing = false
			velocity = Vector2.ZERO
			if _state_left <= 0.0:
				_state = State.WANDER
	move_and_slide()
	_update_facing()
	var area := get_viewport_rect().size
	var clamped := position.clamp(Vector2(EDGE_MARGIN, TOP_MARGIN), area - Vector2(EDGE_MARGIN, EDGE_MARGIN))
	if clamped != position:
		position = clamped
		_wander = -_wander
		if _state == State.DASH:
			_rest()
	queue_redraw()
	if target != null and global_position.distance_to(target.global_position) \
			<= (radius() + Balance.get_float("slime_touch_reach")) * scale.x:
		touched_player.emit(self)


func _rest() -> void:
	_state = State.REST
	_state_left = Balance.get_float("dasher_rest_time")


func _choose_wander(delta: float) -> Vector2:
	_wander_left -= delta
	if _wander_left <= 0.0:
		_wander_left = randf_range(1.0, 2.5)
		_wander = Vector2.RIGHT.rotated(randf() * TAU) if randf() > 0.25 else Vector2.ZERO
	return _wander


func _respawn() -> void:
	_state = State.WANDER
	super()


func _sheet() -> Texture2D:
	return WINDUP_SHEET if _state == State.WINDUP or _state == State.DASH else DASHER_SHEET


## 予備動作と突進のあいだは突進する向きを向く。
func _update_facing() -> void:
	if _state == State.WINDUP or _state == State.DASH:
		_facing = _dash_dir
	else:
		super()


func _draw_body(flash_amount: float) -> void:
	if _state == State.WINDUP:
		# 突進する向きの線（スライムの大きさの倍率は掛かっているので、距離は割り戻す）
		var reach := Balance.get_float("dasher_dash_distance") / maxf(scale.x, 0.01)
		draw_line(Vector2.ZERO, _dash_dir * reach, AIM_COLOR, AIM_WIDTH)
	super(flash_amount)
