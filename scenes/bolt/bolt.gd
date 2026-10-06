class_name Bolt
extends Area2D
## 魔法弾。まっすぐ飛び、最初に当たった岩の耐久を減らして消える。

const RADIUS := 7.0
const COLOR := Color(0.55, 0.85, 1.0)

var direction := Vector2.RIGHT

var _travelled := 0.0
var _spent := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var step := Balance.get_float("bolt_speed") * delta
	position += direction * step
	_travelled += step
	if _travelled > Balance.get_float("fire_range") * 1.5:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, COLOR)
	draw_circle(Vector2.ZERO, RADIUS * 0.5, Color.WHITE)


func _on_body_entered(body: Node2D) -> void:
	if _spent or not (body is Rock):
		return
	_spent = true
	(body as Rock).take_hit(Balance.get_int("bolt_damage"))
	queue_free()
