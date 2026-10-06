class_name Slime
extends Breakable
## モンスター（スライム）。稼ぎの元であり、同時に脅威でもある。
## ふらふら歩き回り、プレイヤーが近づくと寄ってくる。触れると touched_player を出す（ダメージは Run が与える）。
## 壊すと宝石（Gem）が手に入り、しばらくするとプレイヤーから離れた場所に湧き直す。

signal touched_player(slime: Slime)

const RADIUS := 34.0
const BODY_COLOR := Color(0.3, 0.78, 1.0)
const CHASE_BODY := Color(1.0, 0.45, 0.62)
const HP_BAR_COLOR := Color(1.0, 0.3, 0.3)
const EDGE_MARGIN := 40.0
const TOP_MARGIN := 140.0
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


func _bar_color() -> Color:
	return HP_BAR_COLOR


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
	var squash := 1.0 + sin(_bob * 8.0) * 0.07
	var size := Vector2(RADIUS * squash, RADIUS * 0.82 / squash)
	var center := Vector2(0, RADIUS - size.y - 2.0)
	Toon.shadow(self, Vector2(0, RADIUS - 4.0), Vector2(RADIUS * 0.95, RADIUS * 0.32))
	var body := (CHASE_BODY if _chasing else BODY_COLOR).lerp(FLASH_COLOR, flash_amount)
	Toon.shaded_blob(self, center, size, body)
	var look := Vector2.ZERO
	if target != null:
		look = global_position.direction_to(target.global_position)
	var eye_y := center.y - size.y * 0.15
	Toon.eye(self, Vector2(-12, eye_y), 8.0, look)
	Toon.eye(self, Vector2(12, eye_y), 8.0, look)
	if _chasing:
		draw_line(Vector2(-21, eye_y - 13), Vector2(-5, eye_y - 7), Toon.OUTLINE, 4.0)
		draw_line(Vector2(21, eye_y - 13), Vector2(5, eye_y - 7), Toon.OUTLINE, 4.0)
	draw_arc(Vector2(0, eye_y + 12), 6.0, 0.2, PI - 0.2, 8, Toon.OUTLINE, 3.0)
