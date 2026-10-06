class_name Bolt
extends Area2D
## 魔法弾。まっすぐ飛び、当たった物の耐久を減らす。
## 魔導樹の Pierce で貫通し、Ricochet で最後の1発のあと別の物へ跳ね返る。

const RADIUS := 7.0
const COLOR := Color(0.55, 0.85, 1.0)
const FOCUS_COLOR := Color(1.0, 0.55, 0.9)
const FOCUS_SCALE := 1.7

var direction := Vector2.RIGHT
## 集中（Focus）の強い1発か
var focused := false

var _pierce_left := 0
var _ricochet_left := 0
var _travelled := 0.0
var _hit: Array[Breakable] = []
var _spent := false


func _ready() -> void:
	_pierce_left = roundi(Stats.effect(&"pierce", Progress.levels))
	_ricochet_left = roundi(Stats.effect(&"ricochet", Progress.levels))
	if focused:
		scale = Vector2.ONE * FOCUS_SCALE
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var step := Balance.get_float("bolt_speed") * delta
	position += direction * step
	_travelled += step
	if _travelled > Balance.get_float("fire_range") * 1.5:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, FOCUS_COLOR if focused else COLOR)
	draw_circle(Vector2.ZERO, RADIUS * 0.5, Color.WHITE)


func _on_body_entered(body: Node2D) -> void:
	var target := body as Breakable
	if _spent or target == null or not target.is_alive() or _hit.has(target):
		return
	_hit.append(target)
	target.take_hit(Stats.hit_damage(target.kind(), target.is_undamaged(), focused, Progress.levels))
	if _pierce_left > 0:
		_pierce_left -= 1
		return
	if _ricochet_left > 0:
		var next := _find_bounce_target()
		if next != null:
			_ricochet_left -= 1
			direction = global_position.direction_to(next.global_position)
			_travelled = 0.0
			return
	_spent = true
	queue_free()


func _find_bounce_target() -> Breakable:
	var best: Breakable = null
	var best_distance := Balance.get_float("fire_range")
	for node in get_tree().get_nodes_in_group(Breakable.GROUP):
		var candidate := node as Breakable
		if candidate == null or _hit.has(candidate):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best
