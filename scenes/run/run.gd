class_name Run
extends Node2D
## 1回のラン（1ステージ）。物を置いて制限時間を数え、目標の数だけ壊せばクリア（次のステージが解放される）。
## クリアしても時間切れまでは素材を集め続けられる。
## 壊れた物のごほうび・砕裂（Shatter）・残響（Echo）・精霊の輪のレベルアップもここで扱う。
## モンスター（Slime）は稼ぎの元であり脅威でもある。触れると体力が減り、体力が 0 になるとそこでランが終わる。
## 時間切れかやられたら結果を表示し、戻るボタンで finished を出す。

signal finished

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SLIME_SCENE := preload("res://scenes/slime/slime.tscn")
const OAK_SCENE := preload("res://scenes/oak/oak.tscn")
const BOLT_SCENE := preload("res://scenes/bolt/bolt.tscn")
const RING_SCENE := preload("res://scenes/spirit_ring/spirit_ring.tscn")
const DEBRIS_SCENE := preload("res://scenes/debris/debris.tscn")
const POPUP_SCENE := preload("res://scenes/popup_text/popup_text.tscn")

const EDGE_MARGIN := 80.0
const TOP_MARGIN := 120.0
const MIN_GAP := 125.0
const SHATTER_DELAY := 0.07
const WORLD_COLORS := {&"plains": Color(0.36, 0.6, 0.32), &"forest": Color(0.2, 0.38, 0.22)}
const DECOR_COLORS := {&"plains": Color(0.44, 0.7, 0.36), &"forest": Color(0.15, 0.3, 0.17)}
const SLIME_DEBRIS := Color(0.5, 0.75, 0.98)
const OAK_DEBRIS := Color(0.4, 0.7, 0.35)
const GEM_COLOR := Color(0.85, 0.85, 0.9)
const HURT_COLOR := Color(1.0, 0.4, 0.35)
const WOOD_COLOR := Color(0.95, 0.75, 0.45)
const DECOR_COUNT := 60

## 生成する側が add_child の前に入れる
var stage_index := 0

var _stage: StageDef
var _time_left := 0.0
var _broken_count := 0
var _gained_gem := 0
var _gained_wood := 0
var _ring_progress := 0
var _over := false
var _defeated := false
var _cleared := false
var _unlocked := false
var _player: Player
var _ring: SpiritRing
var _decor: Array[Vector2] = []

@onready var _world: Node2D = $World
@onready var _stick: VirtualStick = $HUD/VirtualStick
@onready var _info_label: Label = $HUD/InfoLabel
@onready var _material_label: Label = $HUD/MaterialLabel
@onready var _ring_label: Label = $HUD/RingLabel
@onready var _ring_bar: ProgressBar = $HUD/RingBar
@onready var _banner: Label = $HUD/Banner
@onready var _result_panel: PanelContainer = $HUD/ResultPanel
@onready var _result_title: Label = $HUD/ResultPanel/Box/Title
@onready var _result_body: Label = $HUD/ResultPanel/Box/Body
@onready var _back_button: Button = $HUD/ResultPanel/Box/BackButton


func _ready() -> void:
	_stage = Progress.stages[clampi(stage_index, 0, Progress.stages.size() - 1)]
	_time_left = Stats.run_time(Progress.levels)
	_result_panel.visible = false
	_banner.visible = false
	_back_button.pressed.connect(_on_back_pressed)

	var area := get_viewport_rect().size
	for _i in DECOR_COUNT:
		_decor.append(Vector2(randf() * area.x, randf() * area.y))

	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = area * 0.5 + Vector2(0, TOP_MARGIN * 0.25)
	_player.stick = _stick
	_player.hurt.connect(_on_player_hurt)
	_player.died.connect(_on_player_died)
	_world.add_child(_player)
	_ring = RING_SCENE.instantiate() as SpiritRing
	_player.add_child(_ring)
	_ring.level = mini(roundi(Stats.effect(&"ring_start", Progress.levels)), Balance.get_int("ring_max_level"))

	var taken: Array[Vector2] = [_player.position]
	for _i in _stage.slime_count:
		_spawn(SLIME_SCENE, _stage.slime_hp, _stage.slime_gem, area, taken)
	for _i in _stage.oak_count:
		_spawn(OAK_SCENE, _stage.oak_hp, _stage.oak_wood, area, taken)
	_update_hud()


func _process(delta: float) -> void:
	if _over:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	if _time_left <= 0.0:
		_finish()
	_update_hud()


func _on_player_hurt() -> void:
	Sfx.play(&"hurt")
	_popup(_player.global_position + Vector2(0, -30), "-%d" % Balance.get_int("slime_contact_damage"), HURT_COLOR, 30)
	_update_hud()


func _on_player_died() -> void:
	if _over:
		return
	_defeated = true
	_finish()


func _on_slime_touched(slime: Slime) -> void:
	if not _over:
		_player.take_damage(Balance.get_int("slime_contact_damage"), slime.global_position)


func _draw() -> void:
	var area := get_viewport_rect()
	draw_rect(area, WORLD_COLORS.get(_stage.world, Color.DIM_GRAY))
	var decor: Color = DECOR_COLORS.get(_stage.world, Color.GRAY)
	for spot in _decor:
		draw_line(spot, spot + Vector2(-4, -10), decor, 3.0)
		draw_line(spot, spot + Vector2(4, -9), decor, 3.0)


func _spawn(scene: PackedScene, base_hp: int, reward: int, area: Vector2, taken: Array[Vector2]) -> void:
	var target := scene.instantiate() as Breakable
	target.base_hp = base_hp
	target.reward = reward
	target.position = _find_free_spot(area, taken)
	taken.append(target.position)
	target.broken.connect(_on_broken)
	var slime := target as Slime
	if slime != null:
		slime.target = _player
		slime.speed = _stage.slime_speed
		slime.touched_player.connect(_on_slime_touched)
	_world.add_child(target)


func _find_free_spot(area: Vector2, taken: Array[Vector2]) -> Vector2:
	var spot := Vector2.ZERO
	for _attempt in 60:
		spot = Vector2(
			randf_range(EDGE_MARGIN, area.x - EDGE_MARGIN),
			randf_range(TOP_MARGIN, area.y - EDGE_MARGIN))
		var ok := spot.distance_to(_player.position) >= Balance.get_float("slime_aggro_range")
		for other in taken:
			if spot.distance_to(other) < MIN_GAP:
				ok = false
				break
		if ok:
			return spot
	return spot


func _on_broken(target: Breakable) -> void:
	if _over:
		return
	var at := target.global_position
	_broken_count += 1
	var is_slime := target.kind() == Stats.SLIME
	if is_slime:
		_gained_gem += target.reward
		Progress.add_materials(target.reward, 0)
	else:
		_gained_wood += target.reward
		Progress.add_materials(0, target.reward)

	var shatter := roundi(Stats.effect(&"shatter", Progress.levels))
	var debris := DEBRIS_SCENE.instantiate() as Debris
	debris.color = SLIME_DEBRIS if is_slime else OAK_DEBRIS
	debris.wave_radius = Balance.get_float("shatter_radius") if shatter > 0 else 0.0
	debris.position = at
	_world.add_child(debris)
	_popup(at, "+%d" % target.reward, GEM_COLOR if is_slime else WOOD_COLOR)

	if shatter > 0:
		get_tree().create_timer(SHATTER_DELAY).timeout.connect(_shatter.bind(at, shatter))
	for _i in roundi(Stats.effect(&"echo", Progress.levels)):
		_fire_echo.call_deferred(at)
	_advance_ring()

	if not _cleared and _broken_count >= _stage.goal:
		_on_goal_reached()


func _on_goal_reached() -> void:
	_cleared = true
	_unlocked = Progress.clear_stage(stage_index)
	Sfx.play(&"clear")
	_banner.text = "STAGE CLEAR!"
	if _unlocked:
		_banner.text += "\n%s unlocked" % Progress.stages[Progress.unlocked_stage].name
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2.ONE * 0.5
	var tween := _banner.create_tween()
	tween.tween_property(_banner, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.2)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_banner.hide)


func _shatter(at: Vector2, damage: int) -> void:
	if _over:
		return
	var reach := Balance.get_float("shatter_radius")
	for node in get_tree().get_nodes_in_group(Breakable.GROUP):
		var target := node as Breakable
		if target != null and target.is_alive() and target.global_position.distance_to(at) <= reach:
			target.take_hit(damage)


func _fire_echo(at: Vector2) -> void:
	var best: Breakable = null
	var best_distance := Balance.get_float("fire_range")
	for node in get_tree().get_nodes_in_group(Breakable.GROUP):
		var candidate := node as Breakable
		if candidate == null:
			continue
		var distance := at.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	if best == null:
		return
	var bolt := BOLT_SCENE.instantiate() as Bolt
	bolt.direction = at.direction_to(best.global_position)
	_world.add_child(bolt)
	bolt.global_position = at


func _advance_ring() -> void:
	var max_level := Balance.get_int("ring_max_level")
	if _ring.level >= max_level:
		return
	_ring_progress += 1
	if _ring_progress < maxi(Balance.get_int("ring_breaks_per_level"), 1):
		return
	_ring_progress = 0
	_ring.level += 1
	Sfx.play(&"ring")
	_popup(_player.global_position + Vector2(0, -40), "SPIRIT RING Lv%d" % _ring.level, SpiritRing.ORB_COLOR, 30)
	var burst := roundi(Stats.effect(&"ring_burst", Progress.levels))
	if burst > 0:
		for node in get_tree().get_nodes_in_group(Breakable.GROUP):
			var target := node as Breakable
			if target != null and target.is_alive():
				target.take_hit(burst)


func _popup(at: Vector2, text: String, color: Color, size := 26) -> void:
	var popup := POPUP_SCENE.instantiate() as PopupText
	popup.text = text
	popup.color = color
	popup.font_size = size
	popup.position = at
	_world.add_child(popup)


func _finish() -> void:
	_over = true
	_world.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	_stick.visible = false
	_banner.visible = false
	Progress.save()
	Sfx.play(&"timeup")
	if _defeated:
		_result_title.text = "DEFEATED"
	else:
		_result_title.text = "STAGE CLEAR!" if _cleared else "TIME UP"
	var lines := PackedStringArray()
	lines.append("Broken: %d / %d" % [_broken_count, _stage.goal])
	var gained := "+%d Gem" % _gained_gem
	if _gained_wood > 0 or _stage.oak_count > 0:
		gained += "   +%d Wood" % _gained_wood
	lines.append(gained)
	if _unlocked:
		lines.append("New stage: %s" % Progress.stages[Progress.unlocked_stage].name)
	elif _cleared and _defeated:
		lines.append("Stage cleared before you fell")
	elif not _cleared:
		lines.append("Break %d to clear this stage" % _stage.goal)
	elif stage_index == Progress.stages.size() - 1:
		lines.append("You cleared the last stage of this prototype!")
	_result_body.text = "\n".join(lines)
	_result_panel.visible = true
	_update_hud()


func _update_hud() -> void:
	var goal := "CLEAR" if _cleared else "Goal %d/%d" % [_broken_count, _stage.goal]
	_info_label.text = "%s    Time %d    HP %d/%d    %s" % [_stage.name, ceili(_time_left), _player.hp, _player.max_hp, goal]
	_material_label.text = "Gem %d   Wood %d" % [Progress.gem, Progress.wood]
	var max_level := Balance.get_int("ring_max_level")
	var need := maxi(Balance.get_int("ring_breaks_per_level"), 1)
	_ring_label.text = "Spirit Ring Lv%d" % _ring.level + (" MAX" if _ring.level >= max_level else "")
	_ring_bar.value = 1.0 if _ring.level >= max_level else float(_ring_progress) / need


func _on_back_pressed() -> void:
	Sfx.play(&"click")
	finished.emit()
