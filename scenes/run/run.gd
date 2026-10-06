class_name Run
extends Node2D
## 1回のラン（1ステージ）。物を置いて制限時間を数え、決まった数を倒すとボスが出る。ボスを倒せばクリア（次のステージが解放される）。
## 倒した物は素材（Pickup）を落とし、プレイヤーが近づいて拾ったぶんだけ手に入る。クリアしたときは落ちている素材も全部手に入る。
## 砕裂（Shatter）・残響（Echo）・精霊の輪のレベルアップもここで扱う。
## モンスター（Slime）は稼ぎの元であり脅威でもある。触れると体力が減り、体力が 0 になるとそこでランが終わる。
## クリア・時間切れ・やられたら結果を表示し、戻るボタンで finished を出す。
## 平原の2面からは草地（Grass）を置く。数は stages.csv の grass × Progress.grass_scale。
## 右上の「調整」から、キャラの大きさの倍率と草地の数の倍率をつまみで試せる（開いているあいだは時間が止まり、無敵で攻撃しない）。

signal finished

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SLIME_SCENE := preload("res://scenes/slime/slime.tscn")
const DASHER_SCENE := preload("res://scenes/dasher/dasher.tscn")
const BOSS_SCENE := preload("res://scenes/boss/boss.tscn")
const PICKUP_SCENE := preload("res://scenes/pickup/pickup.tscn")
const OAK_SCENE := preload("res://scenes/oak/oak.tscn")
const BOLT_SCENE := preload("res://scenes/bolt/bolt.tscn")
const RING_SCENE := preload("res://scenes/spirit_ring/spirit_ring.tscn")
const DEBRIS_SCENE := preload("res://scenes/debris/debris.tscn")
const POPUP_SCENE := preload("res://scenes/popup_text/popup_text.tscn")
const GRASS_SCENE := preload("res://scenes/grass/grass.tscn")

const EDGE_MARGIN := 80.0
const TOP_MARGIN := 150.0
const MIN_GAP := 125.0
const SHATTER_DELAY := 0.07
## 地面の市松模様の2色と、草の色（ブロスタの床のように）
const TILE_COLORS := {
	&"plains": [Color(0.55, 0.82, 0.36), Color(0.5, 0.76, 0.33)],
	&"forest": [Color(0.3, 0.6, 0.32), Color(0.27, 0.55, 0.29)],
}
const DECOR_COLORS := {&"plains": Color(0.36, 0.62, 0.24), &"forest": Color(0.17, 0.4, 0.2)}
const FLOWER_COLORS := [Color(1.0, 0.85, 0.25), Color(1.0, 0.5, 0.65), Color(1, 1, 1)]
const TILE_SIZE := 64.0
const SHAKE_DECAY := 30.0
const SHAKE_ON_BREAK := 5.0
const SHAKE_ON_HURT := 10.0
const SLIME_DEBRIS := Color(0.3, 0.78, 1.0)
const BOSS_DEBRIS := Boss.KING_COLOR
const BOSS_SPAWN_TRIES := 30
const OAK_DEBRIS := Color(0.4, 0.7, 0.35)
const GEM_COLOR := Color(1.0, 0.55, 0.95)
const HURT_COLOR := Color(1.0, 0.4, 0.35)
const WOOD_COLOR := Color(0.95, 0.75, 0.45)
const DECOR_COUNT := 60
const DAMAGE_COLOR := Color(1, 1, 1)
const DAMAGE_SIZE := 24
## 与えたダメージの数字を出しておく時間（見た目だけ、秒）
const DAMAGE_LIFETIME := 0.45
const DAMAGE_JITTER := 14.0
## 大きさのつまみの範囲と刻み（調整用の道具なので見た目の定数として置く）
const SCALE_MIN := 0.4
const SCALE_MAX := 1.5
const SCALE_STEP := 0.05
const GRABBER_RADIUS := 22
const GRASS_SCALE_MIN := 0.0
const GRASS_SCALE_MAX := 3.0
const GRASS_SCALE_STEP := 0.25
## 草地をプレイヤーの開始位置から離す余白（ピクセル）
const GRASS_START_CLEARANCE := 70.0
const GRASS_SPOT_TRIES := 40

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
var _boss: Boss
var _boss_called := false
var _last_contact_damage := 0
var _player: Player
var _ring: SpiritRing
var _decor: Array[Vector2] = []
var _shake := 0.0
var _tuning := false
var _size_button: Button
var _size_panel: PanelContainer
var _size_label: Label
var _grass_label: Label
## つまみで増やしたときに同じ場所へ出せるよう、草地の場所と半径を最大数まで先に決めておく
var _grass_spots: Array[Vector3] = []
var _grass_nodes: Array[Grass] = []
## 草地は地面のすぐ上に描く（World は y 順で並べるので、その手前に別の層を置く）
var _grass_layer: Node2D

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
	_apply_styles()
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
	_player.set_body_scale(Progress.unit_scale)
	_ring = RING_SCENE.instantiate() as SpiritRing
	_player.add_child(_ring)
	_ring.level = mini(roundi(Stats.effect(&"ring_start", Progress.levels)), Balance.get_int("ring_max_level"))

	_grass_layer = Node2D.new()
	add_child(_grass_layer)
	move_child(_grass_layer, _world.get_index())
	_plan_grass(area)
	_apply_grass()
	var taken: Array[Vector2] = [_player.position]
	for _i in _stage.slime_count:
		_spawn(SLIME_SCENE, _stage.slime_hp, _stage.slime_gem, area, taken)
	for _i in _stage.dasher_count:
		_spawn(DASHER_SCENE, _stage.slime_hp, _stage.slime_gem, area, taken)
	for _i in _stage.oak_count:
		_spawn(OAK_SCENE, _stage.oak_hp, _stage.oak_wood, area, taken)
	_build_size_tuner()
	_stick.tap_mode = Progress.tap_move
	_stick.blockers = [_size_button, _size_panel, _result_panel]
	_update_hud()


## 大きさを試すためのボタンとつまみを作る。
func _build_size_tuner() -> void:
	var hud := $HUD as CanvasLayer
	_size_button = Button.new()
	_size_button.text = "調整"
	_size_button.focus_mode = Control.FOCUS_NONE
	_size_button.add_theme_font_size_override("font_size", 24)
	_size_button.position = Vector2(get_viewport_rect().size.x - 164.0, 66.0)
	_size_button.size = Vector2(140, 48)
	UiStyle.button(_size_button, UiStyle.BLUE)
	_size_button.pressed.connect(_set_tuning.bind(true))
	hud.add_child(_size_button)

	_size_panel = PanelContainer.new()
	_size_panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL, 16, 4, 6))
	_size_panel.position = Vector2(get_viewport_rect().size.x - 504.0, 124.0)
	_size_panel.custom_minimum_size = Vector2(480, 0)
	_size_panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_size_panel.add_child(box)
	_size_label = Label.new()
	_size_label.add_theme_font_size_override("font_size", 28)
	_size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.outline_label(_size_label)
	box.add_child(_size_label)
	var slider := HSlider.new()
	slider.min_value = SCALE_MIN
	slider.max_value = SCALE_MAX
	slider.step = SCALE_STEP
	slider.value = Progress.unit_scale
	slider.custom_minimum_size = Vector2(0, 56)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_scale_changed)
	_style_slider(slider)
	box.add_child(slider)
	_grass_label = Label.new()
	_grass_label.add_theme_font_size_override("font_size", 28)
	_grass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.outline_label(_grass_label)
	box.add_child(_grass_label)
	var grass_slider := HSlider.new()
	grass_slider.min_value = GRASS_SCALE_MIN
	grass_slider.max_value = GRASS_SCALE_MAX
	grass_slider.step = GRASS_SCALE_STEP
	grass_slider.value = Progress.grass_scale
	grass_slider.custom_minimum_size = Vector2(0, 56)
	grass_slider.focus_mode = Control.FOCUS_NONE
	grass_slider.value_changed.connect(_on_grass_scale_changed)
	_style_slider(grass_slider)
	box.add_child(grass_slider)
	var note := Label.new()
	note.text = "調整中は時間が止まり、無敵で攻撃しません"
	note.add_theme_font_size_override("font_size", 18)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	var close := Button.new()
	close.text = "閉じる"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 24)
	close.custom_minimum_size = Vector2(0, 52)
	UiStyle.button(close, UiStyle.YELLOW)
	close.pressed.connect(_set_tuning.bind(false))
	box.add_child(close)
	hud.add_child(_size_panel)
	_refresh_size_label()


## スマホの指でもつかみやすいように、太い溝と大きなつまみにする。
func _style_slider(slider: HSlider) -> void:
	var track := UiStyle.box(Color(0.12, 0.12, 0.22), 10, 3, 0)
	track.content_margin_top = 8.0
	track.content_margin_bottom = 8.0
	var filled := UiStyle.box(UiStyle.BLUE, 10, 3, 0)
	filled.content_margin_top = 8.0
	filled.content_margin_bottom = 8.0
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	var knob := _circle_texture(GRABBER_RADIUS, UiStyle.YELLOW)
	for icon in ["grabber", "grabber_highlight"]:
		slider.add_theme_icon_override(icon, knob)


func _circle_texture(radius: int, color: Color) -> ImageTexture:
	var image := Image.create_empty(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	var center := Vector2(radius, radius)
	for y in radius * 2:
		for x in radius * 2:
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if distance <= radius - 4.0:
				image.set_pixel(x, y, color)
			elif distance <= radius:
				image.set_pixel(x, y, Toon.OUTLINE)
	return ImageTexture.create_from_image(image)


func _set_tuning(on: bool) -> void:
	Sfx.play(&"click")
	_tuning = on and not _over
	_size_panel.visible = _tuning
	_size_button.visible = not _tuning and not _over
	_player.tuning = _tuning


func _on_scale_changed(value: float) -> void:
	Progress.unit_scale = value
	_player.set_body_scale(value)
	for child in _world.get_children():
		var target := child as Breakable
		if target != null:
			target.scale = Vector2.ONE * value
	_refresh_size_label()


func _refresh_size_label() -> void:
	_size_label.text = "キャラの大きさ ×%.2f" % Progress.unit_scale
	_grass_label.text = "草の量 ×%.2f（%d か所）" % [Progress.grass_scale, _grass_nodes.size()]


func _on_grass_scale_changed(value: float) -> void:
	Progress.grass_scale = value
	_apply_grass()
	_refresh_size_label()


## 草地を置ける場所を、つまみの最大まで増やしたときの数だけ先に決める。プレイヤーの開始位置には置かない。
func _plan_grass(area: Vector2) -> void:
	var most := ceili(_stage.grass * GRASS_SCALE_MAX)
	var radius_min := Balance.get_float("grass_radius_min")
	var radius_max := maxf(Balance.get_float("grass_radius_max"), radius_min)
	for _i in most:
		var radius := randf_range(radius_min, radius_max)
		var spot := Vector2.ZERO
		for _attempt in GRASS_SPOT_TRIES:
			spot = Vector2(randf_range(radius, area.x - radius), randf_range(TOP_MARGIN * 0.5, area.y - radius))
			if spot.distance_to(_player.position) >= radius + GRASS_START_CLEARANCE:
				break
		_grass_spots.append(Vector3(spot.x, spot.y, radius))


## 今の倍率に合う数だけ草地を出す（増えた分は足し、減った分は消す）。
func _apply_grass() -> void:
	var count := mini(roundi(_stage.grass * Progress.grass_scale), _grass_spots.size())
	while _grass_nodes.size() > count:
		_grass_nodes.pop_back().queue_free()
	while _grass_nodes.size() < count:
		var plan := _grass_spots[_grass_nodes.size()]
		var grass := GRASS_SCENE.instantiate() as Grass
		grass.radius = plan.z
		grass.position = Vector2(plan.x, plan.y)
		_grass_layer.add_child(grass)
		_grass_nodes.append(grass)


func _apply_styles() -> void:
	UiStyle.button(_back_button, UiStyle.YELLOW)
	_result_panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL, 20, 5, 8))
	for label: Label in [_info_label, _material_label, _ring_label, _banner, _result_title, _result_body]:
		UiStyle.outline_label(label, 10)
	_ring_bar.add_theme_stylebox_override("background", UiStyle.box(Color(0.15, 0.15, 0.25), 8, 4, 0))
	var fill := UiStyle.box(SpiritRing.ORB_COLOR, 8, 0, 0)
	fill.set_content_margin_all(0.0)
	_ring_bar.add_theme_stylebox_override("fill", fill)


func _process(delta: float) -> void:
	_shake = maxf(_shake - SHAKE_DECAY * delta, 0.0)
	position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	if _over or _tuning:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	if _time_left <= 0.0:
		_finish()
	_update_hud()


func _on_player_hurt() -> void:
	Sfx.play(&"hurt")
	_shake = SHAKE_ON_HURT
	_popup(_player.global_position + Vector2(0, -30), "-%d" % _last_contact_damage, HURT_COLOR, 30)
	_update_hud()


func _on_player_died() -> void:
	if _over:
		return
	_defeated = true
	_finish()


func _on_slime_touched(slime: Slime) -> void:
	if not _over:
		_last_contact_damage = slime.contact_damage
		_player.take_damage(slime.contact_damage, slime.global_position)


func _draw() -> void:
	var area := get_viewport_rect().grow(16.0)
	var tiles: Array = TILE_COLORS.get(_stage.world, [Color.DIM_GRAY, Color.GRAY])
	draw_rect(area, tiles[0])
	var cols := ceili(area.size.x / TILE_SIZE) + 1
	var rows := ceili(area.size.y / TILE_SIZE) + 1
	for y in rows:
		for x in cols:
			if (x + y) % 2 == 1:
				draw_rect(Rect2(area.position + Vector2(x, y) * TILE_SIZE, Vector2.ONE * TILE_SIZE), tiles[1])
	var decor: Color = DECOR_COLORS.get(_stage.world, Color.GRAY)
	for i in _decor.size():
		var spot := _decor[i]
		if i % 5 == 0:
			draw_circle(spot, 6.0, Toon.OUTLINE)
			draw_circle(spot, 4.0, FLOWER_COLORS[i % FLOWER_COLORS.size()])
		else:
			draw_line(spot, spot + Vector2(-5, -11), decor, 4.0)
			draw_line(spot, spot + Vector2(0, -14), decor, 4.0)
			draw_line(spot, spot + Vector2(5, -11), decor, 4.0)


func _spawn(scene: PackedScene, base_hp: int, reward: int, area: Vector2, taken: Array[Vector2]) -> void:
	var target := scene.instantiate() as Breakable
	target.base_hp = base_hp
	target.reward = reward
	target.position = _find_free_spot(area, taken)
	target.scale = Vector2.ONE * Progress.unit_scale
	taken.append(target.position)
	target.broken.connect(_on_broken)
	target.damaged.connect(_on_damaged)
	var slime := target as Slime
	if slime != null:
		slime.target = _player
		slime.speed = _stage.slime_speed
		slime.contact_damage = Balance.get_int("slime_contact_damage")
		slime.touched_player.connect(_on_slime_touched)
	_world.add_child(target)


## プレイヤーからなるべく離れた場所にボスを出す。
func _spawn_boss() -> void:
	var area := get_viewport_rect().size
	var spot := Vector2.ZERO
	var best_distance := -1.0
	for _i in BOSS_SPAWN_TRIES:
		var candidate := Vector2(randf_range(EDGE_MARGIN, area.x - EDGE_MARGIN), randf_range(TOP_MARGIN, area.y - EDGE_MARGIN))
		var distance := candidate.distance_to(_player.position)
		if distance > best_distance:
			spot = candidate
			best_distance = distance
	_boss = BOSS_SCENE.instantiate() as Boss
	_boss.base_hp = _stage.boss_hp
	_boss.reward = _stage.boss_gem
	_boss.position = spot
	_boss.scale = Vector2.ONE * Progress.unit_scale
	_boss.target = _player
	_boss.speed = _stage.boss_speed
	_boss.contact_damage = Balance.get_int("boss_contact_damage")
	_boss.broken.connect(_on_broken)
	_boss.damaged.connect(_on_damaged)
	_boss.touched_player.connect(_on_slime_touched)
	_world.add_child(_boss)
	Sfx.play(&"ring")
	Bgm.play(&"boss")
	_show_banner("ボス出現！")


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


## 与えたダメージを、当たった物の頭の上に短く出す。
func _on_damaged(target: Breakable, amount: int) -> void:
	if _over or amount <= 0:
		return
	var above := (target.bar_lift() + Breakable.BAR_HEIGHT) * target.scale.x + 8.0
	var at := target.global_position + Vector2(randf_range(-DAMAGE_JITTER, DAMAGE_JITTER), -above)
	_popup(at, str(amount), DAMAGE_COLOR, DAMAGE_SIZE, DAMAGE_LIFETIME)


func _on_broken(target: Breakable) -> void:
	if _over:
		return
	var at := target.global_position
	var is_boss := target == _boss
	if not is_boss:
		_broken_count += 1
	_shake = maxf(_shake, SHAKE_ON_BREAK * (2.0 if is_boss else 1.0))
	var is_slime := target.kind() == Stats.SLIME

	var shatter := roundi(Stats.effect(&"shatter", Progress.levels))
	var debris := DEBRIS_SCENE.instantiate() as Debris
	debris.color = BOSS_DEBRIS if is_boss else (SLIME_DEBRIS if is_slime else OAK_DEBRIS)
	debris.wave_radius = Balance.get_float("shatter_radius") if shatter > 0 else 0.0
	debris.position = at
	_world.add_child(debris)

	if is_boss:
		Sfx.play(&"boss_break")
		_add_materials(Pickup.GEM, target.reward, at)
		_on_boss_defeated()
		return
	_drop(Pickup.GEM if is_slime else Pickup.WOOD, target.reward, at)
	if shatter > 0:
		get_tree().create_timer(SHATTER_DELAY).timeout.connect(_shatter.bind(at, shatter))
	for _i in roundi(Stats.effect(&"echo", Progress.levels)):
		_fire_echo.call_deferred(at)
	_advance_ring()

	if not _boss_called and _broken_count >= _stage.boss_after:
		_boss_called = true
		_spawn_boss.call_deferred()


## 倒した場所に素材を落とす。拾ったときに _on_collected で手に入る。
func _drop(kind: StringName, amount: int, at: Vector2) -> void:
	if amount <= 0:
		return
	var pickup := PICKUP_SCENE.instantiate() as Pickup
	pickup.kind = kind
	pickup.amount = amount
	pickup.target = _player
	pickup.position = at
	pickup.collected.connect(_on_collected)
	_world.add_child.call_deferred(pickup)


func _on_collected(pickup: Pickup) -> void:
	if _over:
		return
	Sfx.play(&"pickup", 0.06, -6.0)
	_add_materials(pickup.kind, pickup.amount, _player.global_position + Vector2(0, -40))


func _add_materials(kind: StringName, amount: int, at: Vector2) -> void:
	if kind == Pickup.GEM:
		_gained_gem += amount
		Progress.add_materials(amount, 0)
	else:
		_gained_wood += amount
		Progress.add_materials(0, amount)
	_popup(at, "+%d" % amount, GEM_COLOR if kind == Pickup.GEM else WOOD_COLOR)


## 地面に落ちたままの素材。
func _lying_pickups() -> Array[Pickup]:
	var result: Array[Pickup] = []
	for child in _world.get_children():
		var pickup := child as Pickup
		if pickup != null and not pickup.is_queued_for_deletion():
			result.append(pickup)
	return result


## ボスを倒したらクリア。落ちている素材は全部手に入れて、ランを終える。
func _on_boss_defeated() -> void:
	_cleared = true
	_unlocked = Progress.clear_stage(stage_index)
	for pickup in _lying_pickups():
		_add_materials(pickup.kind, pickup.amount, pickup.global_position)
		pickup.queue_free()
	Sfx.play(&"clear")
	_finish()


func _show_banner(text: String) -> void:
	_banner.text = text
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
	var best_distance := Stats.fire_range(Progress.levels)
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
	_popup(_player.global_position + Vector2(0, -40), "精霊の輪 Lv%d" % _ring.level, SpiritRing.ORB_COLOR, 30)
	var burst := roundi(Stats.effect(&"ring_burst", Progress.levels))
	if burst > 0:
		for node in get_tree().get_nodes_in_group(Breakable.GROUP):
			var target := node as Breakable
			if target != null and target.is_alive():
				target.take_hit(burst)


func _popup(at: Vector2, text: String, color: Color, size := 26, lifetime := 0.8) -> void:
	var popup := POPUP_SCENE.instantiate() as PopupText
	popup.text = text
	popup.color = color
	popup.font_size = size
	popup.lifetime = lifetime
	popup.position = at
	_world.add_child(popup)


func _finish() -> void:
	_over = true
	_tuning = false
	_player.tuning = false
	_size_panel.visible = false
	_size_button.visible = false
	_world.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	_stick.visible = false
	_banner.visible = false
	Progress.save()
	if not _cleared:
		Sfx.play(&"timeup")
	if _cleared:
		_result_title.text = "ステージクリア！"
	else:
		_result_title.text = "やられた…" if _defeated else "時間切れ"
	var lines := PackedStringArray()
	lines.append("倒した数: %d" % _broken_count)
	var gained := "宝石 +%d" % _gained_gem
	if _gained_wood > 0 or _stage.oak_count > 0:
		gained += "　木材 +%d" % _gained_wood
	lines.append(gained)
	var missed := 0
	for pickup in _lying_pickups():
		missed += pickup.amount
	if missed > 0:
		lines.append("拾えなかった素材: %d" % missed)
	if _unlocked:
		lines.append("新しいステージ: %s" % Progress.stages[Progress.unlocked_stage].name)
	elif _cleared and stage_index == Progress.stages.size() - 1:
		lines.append("試作の最後のステージをクリア！")
	elif not _cleared and _boss != null:
		lines.append("ボスを倒せばクリア")
	elif not _cleared:
		lines.append("%d体倒すとボスが出る" % _stage.boss_after)
	_result_body.text = "\n".join(lines)
	_result_panel.visible = true
	_update_hud()


func _update_hud() -> void:
	var goal := "クリア"
	if not _cleared:
		goal = "ボスを倒せ！" if _boss != null else "ボスまで %d/%d" % [_broken_count, _stage.boss_after]
	_info_label.text = "%s　　残り%d秒　　HP %d/%d　　%s" % [_stage.name, ceili(_time_left), _player.hp, _player.max_hp, goal]
	_material_label.text = "宝石 %d　木材 %d" % [Progress.gem, Progress.wood]
	var max_level := Balance.get_int("ring_max_level")
	var need := maxi(Balance.get_int("ring_breaks_per_level"), 1)
	_ring_label.text = "精霊の輪 Lv%d" % _ring.level + ("（最大）" if _ring.level >= max_level else "")
	_ring_bar.value = 1.0 if _ring.level >= max_level else float(_ring_progress) / need


func _on_back_pressed() -> void:
	Sfx.play(&"click")
	finished.emit()
