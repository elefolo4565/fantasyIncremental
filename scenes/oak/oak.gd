class_name Oak
extends Breakable
## 森の木。壊すと木材が手に入る。しばらく叩かずにいると耐久が少しずつ戻る（魔導樹の Withering で止まる）。

const RADIUS := 40.0
## 3Dモデルを焼いた絵（tools/render_enemies で作り直せる）。耐久が戻っているあいだは明るい葉の絵にする。
const SHEET := preload("res://assets/sprites/enemies/oak.png")
const REGEN_SHEET := preload("res://assets/sprites/enemies/oak_regen.png")
## コマの中で足元が来る位置（render_enemies.gd の foot と合わせる）。
const SHEET_FOOT := Vector2(64, 112)
## 絵の1ピクセルを、この体の座標で何単位に描くか。
const SHEET_PIXEL := 1.0
const FOOT_Y := 36.0

var _since_hit := 0.0
var _regen_timer := 0.0


func kind() -> StringName:
	return Stats.OAK


func radius() -> float:
	return RADIUS


func respawn_time() -> float:
	return Balance.get_float("oak_respawn_time")


func _process(delta: float) -> void:
	super(delta)
	if hp <= 0 or hp >= max_hp or Stats.effect(&"withering", Progress.levels) > 0.0:
		return
	_since_hit += delta
	queue_redraw()
	if _since_hit < Balance.get_float("oak_regen_delay"):
		return
	_regen_timer += delta
	var interval := maxf(Balance.get_float("oak_regen_interval"), 0.05)
	if _regen_timer >= interval:
		_regen_timer -= interval
		hp = mini(hp + 1, max_hp)
		queue_redraw()


func _on_hit() -> void:
	_since_hit = 0.0
	_regen_timer = 0.0


func _draw_body(flash_amount: float) -> void:
	Toon.shadow(self, Vector2(0, FOOT_Y), Vector2(RADIUS * 0.9, 12))
	var regrowing := hp < max_hp and _since_hit >= Balance.get_float("oak_regen_delay") \
			and Stats.effect(&"withering", Progress.levels) <= 0.0
	SpriteSheet.draw(self, REGEN_SHEET if regrowing else SHEET, Vector2.DOWN, 0.0, Vector2(0, FOOT_Y),
			SHEET_FOOT, SHEET_PIXEL, 1, 1, flash_amount)
