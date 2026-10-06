class_name Slime
extends Breakable
## モンスター（スライム）。稼ぎの元であり、同時に脅威でもある。
## ふらふら歩き回り、プレイヤーが近づくと寄ってくる。触れると touched_player を出す（ダメージは Run が与える）。
## 壊すと宝石（Gem）が手に入り、しばらくするとプレイヤーから離れた場所に湧き直す。

signal touched_player(slime: Slime)

const RADIUS := 34.0
const BODY_COLOR := Color(0.45, 0.7, 0.95)
const SHADE_COLOR := Color(0.3, 0.5, 0.78)
const EYE_COLOR := Color(0.1, 0.1, 0.18)
const CHASE_COLOR := Color(1.0, 0.45, 0.4)
const EDGE_MARGIN := 40.0
const TOP_MARGIN := 100.0
const SPAWN_TRIES := 30

## 生成する側が add_child の前に入れる
var target: Node2D
var speed := 0.0

var _wander := Vector2.ZERO
var _wander_left := 0.0
var _chasing := false
var _bob := 0.0
var _placed := false


func kind() -> StringName:
	return Stats.SLIME


func radius() -> float:
	return RADIUS


func respawn_time() -> float:
	return Balance.get_float("slime_respawn_time")


func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	_bob += delta
	var dir := _choose_direction(delta)
	velocity = dir * speed * (Balance.get_float("slime_chase_multiplier") if _chasing else 1.0)
	move_and_slide()
	var area := get_viewport_rect().size
	var clamped := position.clamp(Vector2(EDGE_MARGIN, TOP_MARGIN), area - Vector2(EDGE_MARGIN, EDGE_MARGIN))
	if clamped != position:
		position = clamped
		_wander = -_wander
	queue_redraw()
	if target != null and global_position.distance_to(target.global_position) \
			<= RADIUS + Balance.get_float("slime_touch_reach"):
		touched_player.emit(self)


func _choose_direction(delta: float) -> Vector2:
	_chasing = target != null \
			and global_position.distance_to(target.global_position) < Balance.get_float("slime_aggro_range")
	if _chasing:
		return global_position.direction_to(target.global_position)
	_wander_left -= delta
	if _wander_left <= 0.0:
		_wander_left = randf_range(1.0, 2.5)
		_wander = Vector2.RIGHT.rotated(randf() * TAU) if randf() > 0.25 else Vector2.ZERO
	return _wander


func _respawn() -> void:
	if _placed and target != null:
		position = _far_spot()
	_placed = true
	super()


## プレイヤーから離れた場所を選ぶ（湧いた瞬間に当たらないように）。
func _far_spot() -> Vector2:
	var area := get_viewport_rect().size
	var best := position
	var best_distance := 0.0
	for _i in SPAWN_TRIES:
		var spot := Vector2(randf_range(EDGE_MARGIN, area.x - EDGE_MARGIN), randf_range(TOP_MARGIN, area.y - EDGE_MARGIN))
		var distance := spot.distance_to(target.global_position)
		if distance > best_distance:
			best = spot
			best_distance = distance
		if distance > Balance.get_float("slime_aggro_range") * 1.5:
			return spot
	return best


func _draw_body(flash_amount: float) -> void:
	var squash := 1.0 + sin(_bob * 8.0) * 0.06
	var size := Vector2(RADIUS * squash, RADIUS / squash)
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * i / 24.0
		var point := Vector2(cos(angle) * size.x, sin(angle) * size.y)
		if point.y > 0.0:
			point.y *= 0.75
		points.append(point + Vector2(0, 4))
	draw_colored_polygon(points, SHADE_COLOR.lerp(FLASH_COLOR, flash_amount))
	draw_circle(Vector2(0, -2), RADIUS * 0.78, BODY_COLOR.lerp(FLASH_COLOR, flash_amount))
	var eye_color := CHASE_COLOR if _chasing else EYE_COLOR
	draw_circle(Vector2(-12, -21), 4.0, eye_color)
	draw_circle(Vector2(12, -21), 4.0, eye_color)
	points.append(points[0])
	draw_polyline(points, OUTLINE_COLOR, 3.0)
