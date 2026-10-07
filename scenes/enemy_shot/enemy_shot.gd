class_name EnemyShot
extends Node2D
## 敵の弾1発。種類（ShotDef.kind）ごとに飛び方と当たり方が違う。
## 弾丸・矢じりはまっすぐ飛ぶ。ウェーブは進むほど横に広がる。爆弾は狙った場所へ放物線で飛び、着地で爆発する。
## レーザーは予告の線のあと、まっすぐな光線が少しのあいだ出る。
## プレイヤー（target）に当たると hit を出して消える（ダメージは受け取った側が与える）。

signal hit(damage: int, from: Vector2)

const OUTLINE_WIDTH := 3.0
const ARROW_LENGTH := 1.6
const BOMB_ARC := 90.0
const BOMB_FLASH_TIME := 0.25
const WARN_COLOR := Color(1.0, 0.25, 0.2, 0.35)

## 生成する側が add_child の前に入れる
var def: ShotDef
var direction := Vector2.RIGHT
var target: Node2D

var _age := 0.0
var _travelled := 0.0
var _origin := Vector2.ZERO
var _landing := Vector2.ZERO
var _flight := 1.0
var _exploded := -1.0
var _done := false


func _ready() -> void:
	_origin = position
	if def.kind == &"bomb":
		# 撃った向きへ、プレイヤーまでの距離（届く距離まで）だけ投げる。扇状に撃てば散らばって落ちる
		var distance := def.reach
		if target != null:
			distance = minf(position.distance_to(target.global_position), def.reach)
		_landing = position + direction * distance
		_flight = maxf(distance / maxf(def.speed, 1.0), 0.3)
	else:
		rotation = direction.angle()


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	match def.kind:
		&"bomb":
			_step_bomb()
		&"laser":
			_step_laser()
		_:
			var step := def.speed * delta
			position += direction * step
			_travelled += step
			if not _done and _touches_target():
				_hit_target()
				return
			if _travelled >= def.reach:
				queue_free()


func _step_bomb() -> void:
	if _exploded >= 0.0:
		if _age - _exploded > BOMB_FLASH_TIME:
			queue_free()
		return
	var t := minf(_age / _flight, 1.0)
	position = _origin.lerp(_landing, t)
	if t >= 1.0:
		_exploded = _age
		if target != null and target.global_position.distance_to(global_position) <= def.size + _hit_radius():
			_hit_target(false)


func _step_laser() -> void:
	var fire_at := def.windup
	var laser_time := Balance.get_float("laser_time")
	if _age >= fire_at + laser_time:
		queue_free()
		return
	if _age < fire_at or _done or target == null:
		return
	# 光線の線分とプレイヤーの距離
	var local := (target.global_position - global_position).rotated(-rotation)
	var along := clampf(local.x, 0.0, def.reach)
	if Vector2(local.x - along, local.y).length() <= def.size + _hit_radius():
		_hit_target(false)


func _touches_target() -> bool:
	if target == null:
		return false
	var offset := target.global_position - global_position
	if def.kind == &"wave":
		var local := offset.rotated(-rotation)
		return absf(local.x) <= def.size * 0.5 + _hit_radius() and absf(local.y) <= _wave_half_width() + _hit_radius()
	return offset.length() <= def.size + _hit_radius()


func _wave_half_width() -> float:
	var t := clampf(_travelled / def.reach, 0.0, 1.0)
	return def.size * lerpf(1.0, Balance.get_float("wave_growth"), t)


func _hit_radius() -> float:
	return Balance.get_float("shot_hit_radius")


## free_after が false のもの（爆発・光線）は、当たっても見た目が終わるまで残す。
func _hit_target(free_after := true) -> void:
	_done = true
	hit.emit(def.damage, global_position)
	if free_after:
		queue_free()


func _draw() -> void:
	match def.kind:
		&"arrow":
			var length := def.size * ARROW_LENGTH
			draw_line(Vector2(-length * 1.6, 0), Vector2(-length * 0.2, 0), Toon.OUTLINE, def.size * 0.7)
			draw_line(Vector2(-length * 1.6, 0), Vector2(-length * 0.2, 0), def.color.darkened(0.4), def.size * 0.35)
			Toon.polygon(self, PackedVector2Array([Vector2(length * 0.6, 0), Vector2(-length * 0.4, -def.size),
					Vector2(-length * 0.15, 0), Vector2(-length * 0.4, def.size)]), def.color, OUTLINE_WIDTH * 0.7)
		&"wave":
			var half := _wave_half_width()
			var points := PackedVector2Array()
			for i in 13:
				var a := lerpf(-1.0, 1.0, i / 12.0)
				points.append(Vector2(-a * a * def.size * 0.9, a * half))
			draw_polyline(points, Toon.OUTLINE, def.size * 0.7 + OUTLINE_WIDTH * 2.0, true)
			draw_polyline(points, def.color, def.size * 0.7, true)
			draw_polyline(points, Color(1, 1, 1, 0.6), def.size * 0.25, true)
		&"bomb":
			_draw_bomb()
		&"laser":
			_draw_laser()
		_:
			draw_circle(Vector2.ZERO, def.size * 1.6, Color(def.color, 0.25))
			Toon.blob(self, Vector2.ZERO, Vector2.ONE * def.size, def.color, OUTLINE_WIDTH)
			draw_circle(Vector2(-def.size * 0.3, -def.size * 0.3), def.size * 0.35, Color.WHITE)


func _draw_bomb() -> void:
	var landing := _landing - position
	if _exploded >= 0.0:
		var k := (_age - _exploded) / BOMB_FLASH_TIME
		draw_circle(Vector2.ZERO, def.size, Color(def.color, 0.7 * (1.0 - k)))
		draw_arc(Vector2.ZERO, def.size * (0.8 + k * 0.3), 0.0, TAU, 32, Color(1, 1, 1, 1.0 - k), 6.0)
		return
	# 着地点の予告の輪（だんだん濃くなる）
	var t := minf(_age / _flight, 1.0)
	draw_circle(landing, def.size, Color(WARN_COLOR, WARN_COLOR.a * (0.4 + t)))
	draw_arc(landing, def.size, 0.0, TAU, 32, Color(1, 0.3, 0.2, 0.8), 3.0)
	var lift := Vector2(0, -sin(t * PI) * BOMB_ARC)
	Toon.shadow(self, Vector2.ZERO, Vector2(10, 4))
	Toon.blob(self, lift, Vector2.ONE * 11.0, Color(0.2, 0.2, 0.25), OUTLINE_WIDTH)
	draw_circle(lift + Vector2(-3, -3), 3.5, Color(1, 1, 1, 0.7))
	draw_line(lift + Vector2(4, -9), lift + Vector2(8, -15), def.color, 3.0)


func _draw_laser() -> void:
	var end := Vector2(def.reach, 0)
	if _age < def.windup:
		var blink := 0.5 + 0.5 * sin(_age * 30.0)
		draw_line(Vector2.ZERO, end, Color(def.color, 0.35 + 0.35 * blink), 3.0)
		return
	var k := clampf((_age - def.windup) / maxf(Balance.get_float("laser_time"), 0.01), 0.0, 1.0)
	var width := def.size * 2.0 * (1.0 - k * 0.6)
	draw_line(Vector2.ZERO, end, Toon.OUTLINE, width + OUTLINE_WIDTH * 2.0)
	draw_line(Vector2.ZERO, end, def.color, width)
	draw_line(Vector2.ZERO, end, Color(1, 1, 1, 0.85), width * 0.4)
