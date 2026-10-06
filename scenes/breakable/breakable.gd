class_name Breakable
extends CharacterBody2D
## 壊せる物の共通部分。耐久・被弾・破壊・復活と、頭の上の体力バーを受け持つ。
## 体力バーは減っているときだけ出し、数字は出さない（与えたダメージは damaged を受けた側が出す）。
## 種類ごとの見た目や性質は子クラス（Slime, Oak）で決める。

signal broken(target: Breakable)
signal damaged(target: Breakable, amount: int)

const GROUP := &"breakable"
const FLASH_COLOR := Color(1.0, 0.95, 0.8)
const FLASH_TIME := 0.12
const BAR_COLOR := Color(1.0, 0.82, 0.2)
const BAR_BACK := Color(0.25, 0.2, 0.3)
const OUTLINE_COLOR := Toon.OUTLINE
const POP_SCALE := Vector2(0.18, 0.12)
const BAR_HEIGHT := 10.0
const BAR_GAP := 14.0

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


## 中心から体力バーの下端までの高さ。
func bar_lift() -> float:
	return radius() + BAR_GAP


## 壊れたあと湧き直すか。ボスは湧き直さない。
func respawns() -> bool:
	return true


func is_alive() -> bool:
	return hp > 0


func is_undamaged() -> bool:
	return hp >= max_hp


func take_hit(damage: int) -> void:
	if hp <= 0:
		return
	var before := hp
	hp -= damage
	if hp <= Stats.finish_threshold(Progress.levels):
		hp = 0
	_flash = FLASH_TIME
	damaged.emit(self, before - hp)
	_on_hit()
	queue_redraw()
	if hp <= 0:
		_break()
	else:
		Sfx.play(&"hit", 0.08, -10.0)


## 子クラスで上書きする。被弾したときに呼ばれる。
func _on_hit() -> void:
	pass


## 子クラスで上書きできる。_draw_body で描いた絵を何倍にして見せるか。
func _body_scale() -> float:
	return 1.0


## 子クラスで上書きする。本体の絵を描く。flash は 0〜1。
func _draw_body(_flash_amount: float) -> void:
	pass


func _break() -> void:
	remove_from_group(GROUP)
	visible = false
	_shape.set_deferred("disabled", true)
	Sfx.play(&"break", 0.12, -4.0)
	broken.emit(self)
	if respawns():
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
	draw_set_transform(Vector2.ZERO, 0.0,
			Vector2(1.0 + pop * POP_SCALE.x, 1.0 - pop * POP_SCALE.y) * _body_scale())
	_draw_body(pop)
	draw_set_transform(Vector2.ZERO)
	# 減っているときだけ、頭の上に残りの体力をバーで出す（数字は出さない）
	if is_undamaged():
		return
	var bar := Rect2(-r * 0.8, -bar_lift() - BAR_HEIGHT, r * 1.6, BAR_HEIGHT)
	draw_rect(bar.grow(3.0), Toon.OUTLINE)
	draw_rect(bar, BAR_BACK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(hp) / maxi(max_hp, 1), bar.size.y)), _bar_color())


## 子クラスで上書きできる。耐久のバーの色。
func _bar_color() -> Color:
	return BAR_COLOR
