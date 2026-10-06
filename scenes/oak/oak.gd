class_name Oak
extends Breakable
## 森の木。壊すと木材が手に入る。しばらく叩かずにいると耐久が少しずつ戻る（魔導樹の Withering で止まる）。

const RADIUS := 40.0
const CANOPY_CENTER := Vector2(0, -8)
const TRUNK_COLOR := Color(0.62, 0.38, 0.2)
const LEAF_COLOR := Color(0.3, 0.78, 0.25)
const REGEN_COLOR := Color(0.6, 1.0, 0.45)
## 葉のかたまり: [中心からのずれ, 半径]
const PUFFS := [[Vector2(-16, 4), 22.0], [Vector2(16, 4), 22.0], [Vector2(0, -12), 26.0]]

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
	Toon.shadow(self, Vector2(0, 36), Vector2(RADIUS * 0.9, 12))
	var trunk := PackedVector2Array([Vector2(-10, 8), Vector2(10, 8), Vector2(13, 38), Vector2(-13, 38)])
	Toon.polygon(self, trunk, TRUNK_COLOR.lerp(FLASH_COLOR, flash_amount))
	var regrowing := hp < max_hp and _since_hit >= Balance.get_float("oak_regen_delay") \
			and Stats.effect(&"withering", Progress.levels) <= 0.0
	var leaf := (REGEN_COLOR if regrowing else LEAF_COLOR).lerp(FLASH_COLOR, flash_amount)
	# 縁取りを先に全部塗ってから葉を重ねると、ひとかたまりの木に見える
	for puff in PUFFS:
		draw_circle(CANOPY_CENTER + puff[0], puff[1] + Toon.OUTLINE_WIDTH, Toon.OUTLINE)
	for puff in PUFFS:
		draw_circle(CANOPY_CENTER + puff[0] + Vector2(0, 3), puff[1], leaf.darkened(0.3))
	for puff in PUFFS:
		draw_circle(CANOPY_CENTER + puff[0], puff[1] - 3.0, leaf)
	Toon.highlight(self, CANOPY_CENTER + Vector2(-14, -18), Vector2(9, 6))
