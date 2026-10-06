class_name Player
extends CharacterBody2D
## プレイヤー。スティックかキーボードで動き、近くの壊せる物へ魔法弾を自動で撃つ。
## 魔導樹の Twin Bolt で1度に撃つ数が増え、Focus で数発ごとに強い1発になる。
## モンスターに触れると体力が減り、少しのあいだ無敵になって弾き飛ばされる。体力が 0 になると died を出す。
## tuning が true のあいだ（大きさの調整中）は無敵で、攻撃もしない。

signal hurt
signal died

const BOLT_SCENE := preload("res://scenes/bolt/bolt.tscn")
const RADIUS := 20.0
const ROBE_COLOR := Color(0.55, 0.3, 0.95)
const HAT_COLOR := Color(0.32, 0.25, 0.85)
const BAND_COLOR := Color(1.0, 0.8, 0.15)
const SKIN_COLOR := Color(1.0, 0.82, 0.66)
const STAFF_COLOR := Color(0.6, 0.38, 0.2)
const GEM_COLOR := Color(0.4, 0.95, 1.0)
const HURT_COLOR := Color(1.0, 0.35, 0.3)
const DRAW_SCALE := 1.35
const BLINK_RATE := 18.0

var stick: VirtualStick
var tuning := false
var max_hp := 1
var hp := 1

var _fire_cooldown := 0.0
var _invincible := 0.0
var _knockback := Vector2.ZERO
var _facing := Vector2.RIGHT
var _walk := 0.0
var _shot_count := 0
var _body_scale := 1.0

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	max_hp = maxi(Balance.get_int("player_hp"), 1)
	hp = max_hp


## 見た目と当たり判定の大きさを変える（子の精霊の輪は変えない）。
func set_body_scale(value: float) -> void:
	_body_scale = value
	_shape.scale = Vector2.ONE * value
	queue_redraw()


func is_alive() -> bool:
	return hp > 0


## from から押し返されるように弾き飛ぶ。無敵のあいだは何もしない。
func take_damage(amount: int, from: Vector2) -> void:
	if hp <= 0 or _invincible > 0.0 or tuning:
		return
	hp = maxi(hp - amount, 0)
	_invincible = Balance.get_float("player_invincible_time")
	_knockback = from.direction_to(global_position) * Balance.get_float("player_knockback")
	queue_redraw()
	hurt.emit()
	if hp <= 0:
		died.emit()


func _physics_process(delta: float) -> void:
	if _invincible > 0.0:
		_invincible = maxf(_invincible - delta, 0.0)
		queue_redraw()
	_knockback = _knockback.move_toward(Vector2.ZERO, Balance.get_float("player_knockback") * 4.0 * delta)
	var move := _read_move_input()
	if move != Vector2.ZERO:
		_facing = move.normalized()
		_walk += delta * 14.0
		queue_redraw()
	velocity = move * Balance.get_float("player_speed") + _knockback
	move_and_slide()
	var area := get_viewport_rect().size
	var margin := Vector2.ONE * RADIUS * _body_scale
	global_position = global_position.clamp(margin, area - margin)

	if tuning:
		return
	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		var bolt_count := 1 + roundi(Stats.effect(&"twin", Progress.levels))
		var targets := _find_targets(bolt_count)
		if not targets.is_empty():
			_fire_volley(targets, bolt_count)
			_fire_cooldown = Stats.fire_interval(Progress.levels)


func _draw() -> void:
	var blink := _invincible > 0.0 and int(_invincible * BLINK_RATE) % 2 == 0
	var tint := Color.WHITE if not blink else HURT_COLOR
	var bob := sin(_walk) * 2.5
	var side := -1.0 if _facing.x < 0.0 else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * DRAW_SCALE * _body_scale)
	Toon.shadow(self, Vector2(0, 22), Vector2(22, 8))
	# 杖（体の後ろ側）
	var staff_top := Vector2(side * 24, -30 + bob)
	draw_line(Vector2(side * 18, 20), staff_top, Toon.OUTLINE, 9.0)
	draw_line(Vector2(side * 18, 20), staff_top, STAFF_COLOR * tint, 4.0)
	Toon.blob(self, staff_top, Vector2(7, 7), GEM_COLOR * tint)
	# ローブ
	var robe := PackedVector2Array([Vector2(-13, -2 + bob), Vector2(13, -2 + bob), Vector2(19, 22), Vector2(-19, 22)])
	Toon.polygon(self, robe, ROBE_COLOR * tint)
	# 大きな頭
	var head := Vector2(0, -16 + bob)
	Toon.blob(self, head, Vector2(17, 16), SKIN_COLOR * tint)
	Toon.eye(self, head + Vector2(-6 + _facing.x * 3, 2), 4.0, _facing)
	Toon.eye(self, head + Vector2(6 + _facing.x * 3, 2), 4.0, _facing)
	# とんがり帽子
	var hat := PackedVector2Array([head + Vector2(-22, -6), head + Vector2(22, -6), head + Vector2(-side * 6, -44)])
	Toon.polygon(self, hat, HAT_COLOR * tint)
	draw_line(head + Vector2(-20, -8), head + Vector2(20, -8), BAND_COLOR * tint, 6.0)


func _read_move_input() -> Vector2:
	if stick != null and stick.value != Vector2.ZERO:
		return stick.value
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir == Vector2.ZERO:
		dir = Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	return dir.limit_length(1.0)


## 射程内の壊せる物を近い順に最大 count 個返す。
func _find_targets(count: int) -> Array[Breakable]:
	var in_range: Array[Breakable] = []
	var fire_range := Stats.fire_range(Progress.levels)
	for node in get_tree().get_nodes_in_group(Breakable.GROUP):
		var candidate := node as Breakable
		if candidate != null and global_position.distance_to(candidate.global_position) < fire_range:
			in_range.append(candidate)
	in_range.sort_custom(func(a: Breakable, b: Breakable) -> bool:
		return global_position.distance_squared_to(a.global_position) \
				< global_position.distance_squared_to(b.global_position))
	return in_range.slice(0, count)


## 狙える相手が足りない分は、一番近い相手の左右にずらして撃つ。
func _fire_volley(targets: Array[Breakable], bolt_count: int) -> void:
	var spread := deg_to_rad(Balance.get_float("twin_spread"))
	var focus_every := maxi(Balance.get_int("focus_every"), 1)
	var has_focus := Stats.effect(&"focus", Progress.levels) > 0.0
	for i in bolt_count:
		var dir := global_position.direction_to(targets[mini(i, targets.size() - 1)].global_position)
		if i >= targets.size():
			var extra := i - targets.size() + 1
			dir = dir.rotated(spread * ceilf(extra / 2.0) * (1.0 if extra % 2 == 1 else -1.0))
		_shot_count += 1
		var bolt := BOLT_SCENE.instantiate() as Bolt
		bolt.direction = dir
		bolt.focused = has_focus and _shot_count % focus_every == 0
		get_parent().add_child(bolt)
		bolt.global_position = global_position
