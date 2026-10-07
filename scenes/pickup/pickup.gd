class_name Pickup
extends Node2D
## 倒した敵が落とす素材（宝石・木材）。プレイヤーが回収範囲に入ると吸い寄せられ、触れたら collected を出す。
## 回収範囲は魔導樹の「引き寄せ」で広がる。素材を足すのは受け取った側（Run）。

signal collected(pickup: Pickup)

const GEM := &"gem"
const WOOD := &"wood"
const GEM_COLOR := Color(1.0, 0.55, 0.95)
const WOOD_COLOR := Color(0.78, 0.52, 0.28)
const WOOD_RING := Color(0.98, 0.82, 0.55)
const SIZE := 13.0
## 黒い縁取りの太さ（ピクセル。見た目だけ）
const OUTLINE_WIDTH := 2.0
const BOB_SPEED := 5.0
const BOB_HEIGHT := 4.0
const SCATTER := 28.0
const SCATTER_TIME := 0.25

## 生成する側が add_child の前に入れる
var kind := GEM
var amount := 1
var target: Node2D

var _time := 0.0
var _pulled := false
var _speed := 0.0


func _ready() -> void:
	_time = randf() * TAU
	# 落ちた場所から少し散らばる
	var tween := create_tween()
	var to := position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(SCATTER * 0.4, SCATTER)
	tween.tween_property(self, "position", to, SCATTER_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if target == null:
		return
	var distance := global_position.distance_to(target.global_position)
	if not _pulled and distance <= Stats.pickup_radius(Progress.levels):
		_pulled = true
	if not _pulled:
		return
	_speed = minf(_speed + Balance.get_float("pickup_pull_accel") * delta, Balance.get_float("pickup_pull_speed"))
	global_position = global_position.move_toward(target.global_position, _speed * delta)
	if global_position.distance_to(target.global_position) <= Balance.get_float("pickup_collect_reach"):
		collected.emit(self)
		queue_free()


## 回収範囲の外からでも吸い寄せ始める（大地の吸引）。
func pull() -> void:
	_pulled = true


func _draw() -> void:
	var at := Vector2(0, -absf(sin(_time * BOB_SPEED)) * BOB_HEIGHT)
	Toon.shadow(self, Vector2(0, SIZE * 0.6), Vector2(SIZE * 0.8, SIZE * 0.3))
	if kind == GEM:
		var points := PackedVector2Array([at + Vector2(0, -SIZE), at + Vector2(SIZE * 0.75, 0),
				at + Vector2(0, SIZE * 0.8), at + Vector2(-SIZE * 0.75, 0)])
		Toon.polygon(self, points, GEM_COLOR, OUTLINE_WIDTH)
		Toon.highlight(self, at + Vector2(-3, -4), Vector2(3, 2))
	else:
		var wood_log := Rect2(at - Vector2(SIZE, SIZE * 0.5), Vector2(SIZE * 2.0, SIZE))
		draw_rect(wood_log.grow(OUTLINE_WIDTH), Toon.OUTLINE)
		draw_rect(wood_log, WOOD_COLOR)
		draw_circle(at + Vector2(SIZE, 0), SIZE * 0.5, WOOD_RING)
