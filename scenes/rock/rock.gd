class_name Rock
extends StaticBody2D
## 壊せる岩。耐久が 0 になると消え、しばらくすると元に戻る。
## 残り耐久（あと何発で壊れるか）を岩の上に表示する。

signal broken(rock: Rock)

const GROUP := &"breakable"
const RADIUS := 36.0
const COLOR := Color(0.58, 0.52, 0.46)
const FLASH_COLOR := Color(1.0, 0.95, 0.8)
const FLASH_TIME := 0.08

var hp := 0

var _flash := 0.0

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_respawn()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()


func take_hit(damage: int) -> void:
	if hp <= 0:
		return
	hp -= damage
	_flash = FLASH_TIME
	queue_redraw()
	if hp <= 0:
		_break()


func _break() -> void:
	remove_from_group(GROUP)
	visible = false
	_shape.set_deferred("disabled", true)
	broken.emit(self)
	get_tree().create_timer(Balance.get_float("rock_respawn_time")).timeout.connect(_respawn)


func _respawn() -> void:
	hp = Balance.get_int("rock_hp")
	visible = true
	_shape.set_deferred("disabled", false)
	add_to_group(GROUP)
	queue_redraw()


func _draw() -> void:
	var color := COLOR.lerp(FLASH_COLOR, _flash / FLASH_TIME)
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(0.25, 0.22, 0.2), 3.0)
	var max_hp := maxi(Balance.get_int("rock_hp"), 1)
	var bar := Rect2(-RADIUS, RADIUS + 8.0, RADIUS * 2.0, 6.0)
	draw_rect(bar, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(hp) / max_hp, bar.size.y)), Color(1.0, 0.8, 0.3))
	draw_string(ThemeDB.fallback_font, Vector2(-RADIUS, 9.0), str(hp),
		HORIZONTAL_ALIGNMENT_CENTER, RADIUS * 2.0, 26, Color.WHITE)
