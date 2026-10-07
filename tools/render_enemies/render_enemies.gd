extends Node
## 敵（スライム・突進スライム・ボス・森の木）の3Dモデルを絵に焼き、assets/sprites/enemies/ に保存する道具。
## ゲームには含まれない（開発用）。使い方は tools/render_enemies/README.md。
## assets/models/<名前>.glb があればそれを、なければ仮のモデル（placeholder_monster.gd）を焼く。

const OUTPUT_DIR := "res://assets/sprites/enemies/"
const MODEL_DIR := "res://assets/models/"
const CELL := 128
const CAMERA_PITCH := 40.0
const OUTLINE_COLOR := Color(0.09, 0.07, 0.13)
const OUTLINE_PX := 5
const WALK_ANIMATION := &"walk"
## 焼く絵の一覧。name はファイル名（.png / .glb）。directions は向きの数、frames は動きのコマ数。
## camera_size はコマの縦に映る広さ（モデルの単位）、foot はコマの中で足元が来る位置。
## 向きの数・コマ数・foot を変えたら、使う側（scenes/slime/slime.gd などの SHEET_*）も合わせる。
const JOBS := [
	{"name": "slime", "shape": &"slime", "color": Color(0.3, 0.78, 1.0), "angry": false,
			"directions": 8, "frames": 4, "camera_size": 2.2, "foot": Vector2(64, 104)},
	{"name": "slime_angry", "shape": &"slime", "color": Color(1.0, 0.45, 0.62), "angry": true,
			"directions": 8, "frames": 4, "camera_size": 2.2, "foot": Vector2(64, 104)},
	{"name": "slime_golden", "shape": &"slime", "color": Color(1.0, 0.82, 0.2), "angry": false,
			"directions": 8, "frames": 4, "camera_size": 2.2, "foot": Vector2(64, 104)},
	{"name": "dasher", "shape": &"dasher", "color": Color(1.0, 0.62, 0.2), "angry": false,
			"directions": 8, "frames": 4, "camera_size": 2.2, "foot": Vector2(64, 104)},
	{"name": "dasher_windup", "shape": &"dasher", "color": Color(1.0, 0.95, 0.3), "angry": true,
			"directions": 8, "frames": 4, "camera_size": 2.2, "foot": Vector2(64, 104)},
	{"name": "boss", "shape": &"boss", "color": Color(0.62, 0.42, 1.0), "angry": true,
			"directions": 8, "frames": 4, "camera_size": 2.2, "foot": Vector2(64, 104)},
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
	for job: Dictionary in JOBS:
		await _render(job)
	get_tree().quit()


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
	var model := Node3D.new()
	model.set_script(load("res://tools/render_enemies/placeholder_monster.gd"))
	model.set("shape", job["shape"])
	model.set("body_color", job["color"])
	model.set("angry", job["angry"])
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
