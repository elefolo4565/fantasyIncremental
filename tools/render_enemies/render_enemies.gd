extends Node
## 敵（data/enemies.csv の全種類）と森の木の3Dモデルを絵に焼き、assets/sprites/enemies/ に保存する道具。
## ゲームには含まれない（開発用）。使い方は tools/render_enemies/README.md。
## assets/models/<名前>.glb があればそれを、なければ仮のモデル（scenes/monster/monster_model.gd）を焼く。

const OUTPUT_DIR := "res://assets/sprites/enemies/"
const MODEL_DIR := "res://assets/models/"
const CELL := 128
const CAMERA_PITCH := 40.0
const OUTLINE_COLOR := Color(0.09, 0.07, 0.13)
const OUTLINE_PX := 5
const WALK_ANIMATION := &"walk"
## 敵の絵は data/enemies.csv の1行ごとに、ふだん（<id>.png）・怒り顔（<id>_angry.png）・金色（<id>_golden.png、golden=1 の敵だけ）を焼く。
## 形は model 列、色は color・angry_color 列。8方向×跳ねる動き4コマ。
const ENEMIES_PATH := "res://data/enemies.csv"
const GOLDEN_COLOR := Color(1.0, 0.82, 0.2)
## 向きの数・コマ数・足元の位置を変えたら、scenes/monster/monster.gd の SHEET_* も合わせる。
const DIRECTIONS := 8
const FRAMES := 4
const CAMERA_SIZE := 2.2
const FOOT := Vector2(64, 104)
## 敵のほかに焼く絵。name はファイル名（.png / .glb）。directions は向きの数、frames は動きのコマ数。
## camera_size はコマの縦に映る広さ（モデルの単位）、foot はコマの中で足元が来る位置。
const EXTRA_JOBS := [
	{"name": "oak", "shape": &"oak", "color": Color(0.3, 0.78, 0.25), "angry": false,
			"directions": 1, "frames": 1, "camera_size": 2.6, "foot": Vector2(64, 112)},
	{"name": "oak_regen", "shape": &"oak", "color": Color(0.6, 1.0, 0.45), "angry": false,
			"directions": 1, "frames": 1, "camera_size": 2.6, "foot": Vector2(64, 112)},
]

var _viewport: SubViewport
var _camera: Camera3D
var _pivot: Node3D


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(CELL, CELL)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.75, 0.85)
	environment.ambient_light_energy = 0.55
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-35), 0)
	light.light_energy = 1.1
	_viewport.add_child(light)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.rotation.x = deg_to_rad(-CAMERA_PITCH)
	_viewport.add_child(_camera)
	_render_all.call_deferred()


func _render_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for job: Dictionary in _enemy_jobs() + EXTRA_JOBS:
		await _render(job)
	get_tree().quit()


## enemies.csv から焼く絵の一覧を作る。
func _enemy_jobs() -> Array:
	var jobs := []
	for row in Balance.load_table(ENEMIES_PATH):
		var enemy := EnemyDef.from_row(row)
		var base := {"shape": enemy.model, "directions": DIRECTIONS, "frames": FRAMES,
				"camera_size": CAMERA_SIZE, "foot": FOOT}
		jobs.append(base.merged({"name": String(enemy.id), "color": enemy.color, "angry": false}))
		jobs.append(base.merged({"name": String(enemy.id) + "_angry", "color": enemy.angry_color, "angry": true}))
		if enemy.golden:
			jobs.append(base.merged({"name": String(enemy.id) + "_golden", "color": GOLDEN_COLOR, "angry": false}))
	return jobs


func _render(job: Dictionary) -> void:
	var model := _load_model(job)
	_pivot.add_child(model)
	var animation := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_place_camera(job["camera_size"], job["foot"])
	var directions: int = job["directions"]
	var frames: int = job["frames"]
	var sheet := Image.create(CELL * frames, CELL * directions, false, Image.FORMAT_RGBA8)
	for direction in directions:
		# 画面の右から時計回りに45度ずつ。画面の右＝ワールドの +X、画面の下＝ワールドの +Z
		# 向きが1つだけのもの（木）は正面（画面の下）を向ける
		var angle := TAU * direction / directions if directions > 1 else PI * 0.5
		_pivot.rotation.y = atan2(cos(angle), sin(angle))
		for frame in frames:
			_pose(model, animation, float(frame) / frames)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var image := _viewport.get_texture().get_image()
			image.convert(Image.FORMAT_RGBA8)
			_add_outline(image)
			sheet.blit_rect(image, Rect2i(0, 0, CELL, CELL), Vector2i(frame * CELL, direction * CELL))
	var path: String = OUTPUT_DIR + job["name"] + ".png"
	var error := sheet.save_png(path)
	print("render_enemies: ", path, " に保存しました (", error_string(error), ")")
	model.queue_free()
	await get_tree().process_frame


## 原点（足元）がコマの foot に映るようにカメラを置く。
func _place_camera(camera_size: float, foot: Vector2) -> void:
	_camera.size = camera_size
	_camera.position = Vector3.ZERO
	var pixel := camera_size / CELL
	var basis := _camera.global_transform.basis
	_camera.position = basis.z * 10.0 + basis.y * (foot.y - CELL * 0.5) * pixel \
			+ basis.x * (CELL * 0.5 - foot.x) * pixel


func _load_model(job: Dictionary) -> Node3D:
	var path: String = MODEL_DIR + job["name"] + ".glb"
	if ResourceLoader.exists(path):
		print("render_enemies: ", path, " を焼きます")
		return (load(path) as PackedScene).instantiate() as Node3D
	var model := MonsterModel.new()
	model.shape = job["shape"]
	model.body_color = job["color"]
	model.angry = job["angry"]
	return model


func _pose(model: Node3D, animation: AnimationPlayer, phase: float) -> void:
	if animation != null and animation.has_animation(WALK_ANIMATION):
		animation.play(WALK_ANIMATION)
		animation.seek(phase * animation.get_animation(WALK_ANIMATION).length, true)
		animation.pause()
	elif model.has_method(&"set_walk"):
		model.call(&"set_walk", phase)


## 不透明な部分のまわりを OUTLINE_PX ぶん縁取り色で囲む（ブロスタ風の太い縁）。
func _add_outline(image: Image) -> void:
	var source := image.duplicate() as Image
	for y in CELL:
		for x in CELL:
			if source.get_pixel(x, y).a > 0.5:
				continue
			var near := false
			for dy in range(-OUTLINE_PX, OUTLINE_PX + 1):
				for dx in range(-OUTLINE_PX, OUTLINE_PX + 1):
					if dx * dx + dy * dy > OUTLINE_PX * OUTLINE_PX + 1:
						continue
					var sx := x + dx
					var sy := y + dy
					if sx >= 0 and sy >= 0 and sx < CELL and sy < CELL and source.get_pixel(sx, sy).a > 0.5:
						near = true
						break
				if near:
					break
			if near:
				image.set_pixel(x, y, OUTLINE_COLOR)
