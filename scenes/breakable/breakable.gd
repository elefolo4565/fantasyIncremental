class_name Breakable
extends CharacterBody2D
## 壊せる物の共通部分。耐久・被弾・破壊・復活と、「あと何発で壊れるか」の表示を受け持つ。
## 種類ごとの見た目や性質は子クラス（Slime, Oak）で決める。

signal broken(target: Breakable)

const GROUP := &"breakable"
const FLASH_COLOR := Color(1.0, 0.95, 0.8)
const FLASH_TIME := 0.12
const BAR_COLOR := Color(1.0, 0.82, 0.2)
const BAR_BACK := Color(0.25, 0.2, 0.3)
const OUTLINE_COLOR := Toon.OUTLINE
const POP_SCALE := Vector2(0.18, 0.12)

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
	var r := radius()
	var pop := _flash / FLASH_TIME
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 + pop * POP_SCALE.x, 1.0 - pop * POP_SCALE.y))
	_draw_body(pop)
	draw_set_transform(Vector2.ZERO)
	# 頭の上に「あと何発で倒せるか」を、耐久のバーに重ねて出す（ブロスタの体力表示ふう）
	var bar := Rect2(-r * 0.85, -r - 34.0, r * 1.7, 24.0)
	draw_rect(bar.grow(3.0), Toon.OUTLINE)
	draw_rect(bar, BAR_BACK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(hp) / maxi(max_hp, 1), bar.size.y)), _bar_color())
	Toon.label(self, Vector2(0, bar.end.y - 3.0), str(hits_left()), 24, Color.WHITE, r * 2.0)


## 子クラスで上書きできる。耐久のバーの色。
func _bar_color() -> Color:
	return BAR_COLOR
