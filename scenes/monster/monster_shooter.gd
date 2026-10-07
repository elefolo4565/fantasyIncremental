class_name MonsterShooter
extends RefCounted
## 敵が弾を撃つ部品。動き（MonsterMove）とは別に、どの動きの敵にも付けられる。
## interval ごとに、プレイヤーが start_range 内にいれば予備動作（windup）のあと ShotDef の撃ち方で弾を出す。
## 弾は敵と同じ階層に足す。弾がプレイヤーに当たると monster.shot_hit を出す。

const SHOT_SCENE := preload("res://scenes/enemy_shot/enemy_shot.tscn")

var monster: Monster
var def: ShotDef

var _cooldown := 0.0
var _windup_left := -1.0
var _queue: PackedFloat32Array = []
var _gap_left := 0.0
var _turn := 0.0


func reset() -> void:
	_cooldown = def.interval * randf_range(0.5, 1.0)
	_windup_left = -1.0
	_queue.clear()


## 予備動作の途中か（0〜1。予備動作していなければ -1）。
func windup_progress() -> float:
	if _windup_left < 0.0:
		return -1.0
	return 1.0 - _windup_left / maxf(_volley_windup(), 0.01)


func step(delta: float) -> void:
	if not _queue.is_empty():
		_gap_left -= delta
		while not _queue.is_empty() and _gap_left <= 0.0:
			_fire(_queue[0])
			_queue.remove_at(0)
			_gap_left += def.burst_gap
		return
	if _windup_left >= 0.0:
		_windup_left -= delta
		if _windup_left < 0.0:
			_start_volley()
		return
	_cooldown -= delta
	if _cooldown > 0.0 or not _in_range():
		return
	_cooldown = def.interval
	_windup_left = _volley_windup()
	if _windup_left <= 0.0:
		_windup_left = -1.0
		_start_volley()


## レーザーは弾そのものが予告の線を出すので、敵の予備動作はしない。
func _volley_windup() -> float:
	return 0.0 if def.kind == &"laser" else def.windup


func _in_range() -> bool:
	if monster.target == null:
		return false
	return def.start_range <= 0.0 \
			or monster.global_position.distance_to(monster.target.global_position) <= def.start_range


func _start_volley() -> void:
	var angles := def.angles(_base_angle(), _turn)
	if def.pattern == &"spiral":
		_turn = wrapf(_turn + deg_to_rad(def.spread), 0.0, TAU)
	if def.is_sequential():
		_queue = angles
		_gap_left = 0.0
		step(0.0)
	else:
		for angle in angles:
			_fire(angle)


func _base_angle() -> float:
	match def.aim:
		&"player":
			if monster.target != null:
				return monster.global_position.direction_to(monster.target.global_position).angle()
		&"facing":
			return monster.facing().angle()
	return deg_to_rad(def.direction)


func _fire(angle: float) -> void:
	if not monster.is_alive() or monster.get_parent() == null:
		_queue.clear()
		return
	var shot := SHOT_SCENE.instantiate() as EnemyShot
	shot.def = def
	shot.direction = Vector2.RIGHT.rotated(angle)
	shot.target = monster.target
	shot.position = monster.position
	shot.hit.connect(monster.on_shot_hit)
	monster.get_parent().add_child(shot)
