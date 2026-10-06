class_name Breakable
extends CharacterBody2D
## 壊せる物の共通部分。耐久・被弾・破壊・復活と、「あと何発で壊れるか」の表示を受け持つ。
## 種類ごとの見た目や性質は子クラス（Slime, Oak）で決める。

signal broken(target: Breakable)

const GROUP := &"breakable"
const FLASH_COLOR := Color(1.0, 0.95, 0.8)
const FLASH_TIME := 0.08
const BAR_COLOR := Color(1.0, 0.8, 0.3)
const OUTLINE_COLOR := Color(0.2, 0.17, 0.15)

## 生成する側が add_child の前に入れる
var base_hp := 1
var reward := 0

var max_hp := 1
var hp := 0

var _flash := 0.0

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_respawn()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		queue_redraw()


func kind() -> StringName:
	return &""


func radius() -> float:
	return 36.0


func respawn_time() -> float:
	return 3.0


func is_alive() -> bool:
	return hp > 0


func is_undamaged() -> bool:
	return hp >= max_hp


## 普通の魔法弾であと何発で壊れるか。
func hits_left() -> int:
	return Stats.hits_from(kind(), hp, is_undamaged(), Progress.levels)


func take_hit(damage: int) -> void:
	if hp <= 0:
		return
	hp -= damage
	if hp <= Stats.finish_threshold(Progress.levels):
		hp = 0
	_flash = FLASH_TIME
	_on_hit()
	queue_redraw()
	if hp <= 0:
		_break()
	else:
		Sfx.play(&"hit", 0.08, -10.0)


## 子クラスで上書きする。被弾したときに呼ばれる。
func _on_hit() -> void:
	pass


## 子クラスで上書きする。本体の絵を描く。flash は 0〜1。
func _draw_body(_flash_amount: float) -> void:
	pass


func _break() -> void:
	remove_from_group(GROUP)
	visible = false
	_shape.set_deferred("disabled", true)
	Sfx.play(&"break", 0.12, -4.0)
	broken.emit(self)
	get_tree().create_timer(respawn_time()).timeout.connect(_respawn)


func _respawn() -> void:
	max_hp = Stats.max_hp(base_hp, Progress.levels)
	hp = max_hp
	visible = true
	_shape.set_deferred("disabled", false)
	add_to_group(GROUP)
	queue_redraw()


func _draw() -> void:
	_draw_body(_flash / FLASH_TIME)
	var r := radius()
	var bar := Rect2(-r, r + 8.0, r * 2.0, 6.0)
	draw_rect(bar, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(hp) / maxi(max_hp, 1), bar.size.y)), BAR_COLOR)
	var font := ThemeDB.fallback_font
	var text := str(hits_left())
	var at := Vector2(-r, 10.0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 28, 6, Color(0, 0, 0, 0.6))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 28, Color.WHITE)
