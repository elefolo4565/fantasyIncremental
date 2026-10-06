extends Node
## プレイヤーの3Dモデルを8方向×歩き4コマの絵に焼き、assets/sprites/player_sheet.png に保存する道具。
## ゲームには含まれない（開発用）。使い方は tools/render_player/README.md。
## assets/models/player.glb があればそれを、なければ仮のモデル（placeholder_wizard.gd）を焼く。

const OUTPUT_PATH := "res://assets/sprites/player_sheet.png"
const MODEL_PATH := "res://assets/models/player.glb"
const CELL := 128
const DIRECTIONS := 8
const FRAMES := 4
## 足元が来る位置（コマの左上から）。player.gd の SHEET_FOOT と合わせる。
const FOOT := Vector2(64, 112)
## カメラの見下ろす角度（度）と、コマの縦に映る広さ（モデルの単位）。
const CAMERA_PITCH := 40.0
const CAMERA_SIZE := 2.7
const OUTLINE_COLOR := Color(0.09, 0.07, 0.13)
const OUTLINE_PX := 5
## glb にこの名前のアニメーションがあれば歩きに使う。
const WALK_ANIMATION := &"walk"

var _viewport: SubViewport
var _pivot: Node3D
var _model: Node3D
var _animation: AnimationPlayer


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
	_model = _load_model()
	_pivot.add_child(_model)
	_animation = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	camera.rotation.x = deg_to_rad(-CAMERA_PITCH)
	_viewport.add_child(camera)
	# 原点（足元）がコマの FOOT に映るようにカメラをずらす
	var pixel := CAMERA_SIZE / CELL
	var back := camera.global_transform.basis.z * 10.0
	var up := camera.global_transform.basis.y * (FOOT.y - CELL * 0.5) * pixel
	var right := camera.global_transform.basis.x * (CELL * 0.5 - FOOT.x) * pixel
	camera.position = back + up + right
	_render.call_deferred()


func _load_model() -> Node3D:
	if ResourceLoader.exists(MODEL_PATH):
		print("render_player: ", MODEL_PATH, " を焼きます")
		return (load(MODEL_PATH) as PackedScene).instantiate() as Node3D
	print("render_player: 仮のモデルを焼きます")
	var model := Node3D.new()
	model.set_script(load("res://tools/render_player/placeholder_wizard.gd"))
	return model


func _render() -> void:
	var sheet := Image.create(CELL * FRAMES, CELL * DIRECTIONS, false, Image.FORMAT_RGBA8)
	for direction in DIRECTIONS:
		# 画面の右から時計回りに45度ずつ。画面の右＝ワールドの +X、画面の下＝ワールドの +Z
		var angle := TAU * direction / DIRECTIONS
		_pivot.rotation.y = atan2(cos(angle), sin(angle))
		for frame in FRAMES:
			_pose(float(frame) / FRAMES)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var image := _viewport.get_texture().get_image()
			image.convert(Image.FORMAT_RGBA8)
			_add_outline(image)
			sheet.blit_rect(image, Rect2i(0, 0, CELL, CELL), Vector2i(frame * CELL, direction * CELL))
	var error := sheet.save_png(OUTPUT_PATH)
	print("render_player: ", OUTPUT_PATH, " に保存しました (", error_string(error), ")")
	get_tree().quit()


func _pose(phase: float) -> void:
	if _animation != null and _animation.has_animation(WALK_ANIMATION):
		_animation.play(WALK_ANIMATION)
		_animation.seek(phase * _animation.get_animation(WALK_ANIMATION).length, true)
		_animation.pause()
	elif _model.has_method(&"set_walk"):
		_model.call(&"set_walk", phase)


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
