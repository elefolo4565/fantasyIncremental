class_name Slime
extends Breakable
## モンスター（スライム）。稼ぎの元であり、同時に脅威でもある。
## ふらふら歩き回り、プレイヤーが近づくと寄ってくる。触れると touched_player を出す（ダメージは Run が与える）。
## 壊すと宝石（Gem）が手に入り、しばらくするとプレイヤーから離れた場所に湧き直す。
## 魔導樹の「黄金スライム」があると、湧くたびに golden_chance の確率で金色になる（落とす宝石は Run が増やす）。

signal touched_player(slime: Slime)

const RADIUS := 34.0
## 3Dモデルを8方向×4コマに焼いた絵（tools/render_enemies で作り直せる）。追ってきているときは赤い怒り顔。
const SHEET := preload("res://assets/sprites/enemies/slime.png")
const ANGRY_SHEET := preload("res://assets/sprites/enemies/slime_angry.png")
## 魔導樹の「黄金スライム」で金色になったときの絵。
const GOLDEN_SHEET := preload("res://assets/sprites/enemies/slime_golden.png")
const SHEET_DIRECTIONS := 8
const SHEET_FRAMES := 4
## コマの中で足元が来る位置（render_enemies.gd の foot と合わせる）。
const SHEET_FOOT := Vector2(64, 104)
## 絵の1ピクセルを、この体の座標で何単位に描くか。
const SHEET_PIXEL := 1.0
const FOOT_Y := 30.0
## 跳ねる動きの速さ（1秒に何周するか）
const BOUNCE_RATE := 1.3
const HP_BAR_COLOR := Color(1.0, 0.3, 0.3)
const EDGE_MARGIN := 40.0
const TOP_MARGIN := 140.0
const SPAWN_TRIES := 30

## 生成する側が add_child の前に入れる
var target: Node2D
var speed := 0.0
var contact_damage := 1
## 湧くたびに金色になる確率（0〜1）
var golden_chance := 0.0
var golden := false

var _wander := Vector2.ZERO
var _wander_left := 0.0
var _chasing := false
var _bob := 0.0
var _placed := false
var _facing := Vector2.DOWN


func kind() -> StringName:
	return Stats.SLIME


func radius() -> float:
	return RADIUS


func respawn_time() -> float:
	return Balance.get_float("slime_respawn_time")


func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	_bob += delta
	var dir := _choose_direction(delta)
	velocity = dir * speed * (Balance.get_float("slime_chase_multiplier") if _chasing else 1.0)
	move_and_slide()
	_update_facing()
	var area := get_viewport_rect().size
	var clamped := position.clamp(Vector2(EDGE_MARGIN, TOP_MARGIN), area - Vector2(EDGE_MARGIN, EDGE_MARGIN))
	if clamped != position:
		position = clamped
		_wander = -_wander
	queue_redraw()
	if target != null and global_position.distance_to(target.global_position) \
			<= (radius() + Balance.get_float("slime_touch_reach")) * scale.x:
		touched_player.emit(self)


func _choose_direction(delta: float) -> Vector2:
	_chasing = target != null \
			and global_position.distance_to(target.global_position) < Balance.get_float("slime_aggro_range")
	if _chasing:
		return global_position.direction_to(target.global_position)
	_wander_left -= delta
	if _wander_left <= 0.0:
		_wander_left = randf_range(1.0, 2.5)
		_wander = Vector2.RIGHT.rotated(randf() * TAU) if randf() > 0.25 else Vector2.ZERO
	return _wander


## 体の絵は RADIUS の大きさで描く。radius() が大きい子クラス（ボス）はその分だけ拡大される。
func _body_scale() -> float:
	return radius() / RADIUS


## 子クラスで上書きできる。描く絵（金色のときは金色、追ってきているときは怒り顔）。
func _sheet() -> Texture2D:
	if golden:
		return GOLDEN_SHEET
	return ANGRY_SHEET if _chasing else SHEET


## 追ってきているときはプレイヤーのほうを、そうでなければ進む向きを向く。止まっているときは向きを変えない。
func _update_facing() -> void:
	if _chasing and target != null:
		_facing = global_position.direction_to(target.global_position)
	elif velocity.length_squared() > 1.0:
		_facing = velocity.normalized()


func _bar_color() -> Color:
	return HP_BAR_COLOR


func _respawn() -> void:
	if _placed and target != null:
		position = _far_spot()
	_placed = true
	golden = randf() < golden_chance
	super()


## プレイヤーから離れた場所を選ぶ（湧いた瞬間に当たらないように）。
func _far_spot() -> Vector2:
	var area := get_viewport_rect().size
	var best := position
	var best_distance := 0.0
	for _i in SPAWN_TRIES:
		var spot := Vector2(randf_range(EDGE_MARGIN, area.x - EDGE_MARGIN), randf_range(TOP_MARGIN, area.y - EDGE_MARGIN))
		var distance := spot.distance_to(target.global_position)
		if distance > best_distance:
			best = spot
			best_distance = distance
		if distance > Balance.get_float("slime_aggro_range") * 1.5:
			return spot
	return best


func _draw_body(flash_amount: float) -> void:
	Toon.shadow(self, Vector2(0, RADIUS - 4.0), Vector2(RADIUS * 0.95, RADIUS * 0.32))
	SpriteSheet.draw(self, _sheet(), _facing, fmod(_bob * BOUNCE_RATE, 1.0), Vector2(0, FOOT_Y),
			SHEET_FOOT, SHEET_PIXEL, SHEET_DIRECTIONS, SHEET_FRAMES, flash_amount)
