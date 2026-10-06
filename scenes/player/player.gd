class_name Player
extends CharacterBody2D
## プレイヤー。スティックかキーボードで動き、近くの壊せる物へ魔法弾を自動で撃つ。
## 魔導樹の Twin Bolt で1度に撃つ数が増え、Focus で数発ごとに強い1発になる。
## モンスターに触れると体力が減り、少しのあいだ無敵になって弾き飛ばされる。体力が 0 になると died を出す。
## 草地（Grass）の中では移動が遅くなる。
## tuning が true のあいだ（大きさの調整中）は無敵で、攻撃もしない。

signal hurt
signal died

const BOLT_SCENE := preload("res://scenes/bolt/bolt.tscn")
const RADIUS := 20.0
## 3Dモデルを8方向×歩き4コマに焼いた絵（tools/render_player で作り直せる）。
## 行が向き（画面の右から時計回りに45度ずつ）、列が歩きのコマ。
const SHEET := preload("res://assets/sprites/player_sheet.png")
const SHEET_CELL := 128
const SHEET_DIRECTIONS := 8
const SHEET_FRAMES := 4
## コマの中で足元が来る位置（render_player.gd の FOOT と合わせる）。
const SHEET_FOOT := Vector2(64, 112)
## 絵の1ピクセルを、この体の座標で何単位に描くか。
const SHEET_PIXEL := 1.1
const FOOT_Y := 22.0
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
var _moving := false
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
	if _moving != (move != Vector2.ZERO):
		_moving = move != Vector2.ZERO
		queue_redraw()
	if move != Vector2.ZERO:
		_facing = move.normalized()
		_walk += delta * 14.0
		queue_redraw()
	var grass_rate := Grass.rate_at(get_tree(), global_position, Balance.get_float("grass_player_speed_rate"))
	velocity = move * Balance.get_float("player_speed") * grass_rate + _knockback
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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * DRAW_SCALE * _body_scale)
	Toon.shadow(self, Vector2(0, FOOT_Y), Vector2(22, 8))
	var direction := wrapi(roundi(_facing.angle() / (TAU / SHEET_DIRECTIONS)), 0, SHEET_DIRECTIONS)
	var frame := 0
	if _moving:
		frame = int(_walk / TAU * SHEET_FRAMES) % SHEET_FRAMES
	var source := Rect2(frame * SHEET_CELL, direction * SHEET_CELL, SHEET_CELL, SHEET_CELL)
	var size := Vector2.ONE * SHEET_CELL * SHEET_PIXEL
	var at := Vector2(0, FOOT_Y) - SHEET_FOOT * SHEET_PIXEL
	draw_texture_rect_region(SHEET, Rect2(at, size), source, tint)


func _read_move_input() -> Vector2:
	if stick != null and stick.tap_mode and stick.has_target:
		var offset := stick.target - global_position
		if offset.length() <= Balance.get_float("tap_arrive_distance"):
			stick.clear_target()
			return Vector2.ZERO
		return offset.normalized()
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
	Sfx.play(&"shot", 0.1, -14.0)
