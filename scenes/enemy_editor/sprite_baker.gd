class_name SpriteBaker
extends Node
## 敵エディタの中で、敵の仮モデル（MonsterModel）をその場で8方向×4コマの絵に焼く。
## 形や色を変えたとき、中央の動くプレビューにも新しい見た目を出すために使う（焼いた絵は保存しない）。
## 写し方は tools/render_enemies/render_enemies.gd と同じ。縁取りだけ、速さのために簡単なやり方にしている。
## 焼き終わると baked を出す（sheets は ""・"angry" の絵）。焼いている途中で次を頼むと、前のは捨てる。

signal baked(def: EnemyDef, sheets: Dictionary)

## render_enemies.gd と合わせる
const CELL := 128
const DIRECTIONS := 8
const FRAMES := 4
const CAMERA_PITCH := 40.0
const CAMERA_SIZE := 2.2
const FOOT := Vector2(64, 104)
const OUTLINE_COLOR := Color(0.09, 0.07, 0.13)
const OUTLINE_PX := 5
## 縁取りで影をずらして重ねる向きの数
const OUTLINE_STEPS := 16

var _viewport: SubViewport
var _camera: Camera3D
var _pivot: Node3D
var _outline_fill: Image
var _ticket := 0


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
	_camera.size = CAMERA_SIZE
	_viewport.add_child(_camera)
	# 原点（足元）がコマの FOOT に映るようにカメラを置く
	var pixel := CAMERA_SIZE / CELL
	var basis := _camera.transform.basis
	_camera.position = basis.z * 10.0 + basis.y * (FOOT.y - CELL * 0.5) * pixel + basis.x * (CELL * 0.5 - FOOT.x) * pixel
	_outline_fill = Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	_outline_fill.fill(OUTLINE_COLOR)


## def のふだんと怒り顔の絵を焼く。終わると baked を出す。
func bake(def: EnemyDef) -> void:
	_ticket += 1
	var ticket := _ticket
	var sheets := {}
	for variant in [&"", &"angry"]:
		var sheet := await _bake_sheet(def, variant == &"angry", ticket)
		if sheet == null:
			return
		sheets[variant] = ImageTexture.create_from_image(sheet)
	baked.emit(def, sheets)


func is_busy() -> bool:
	return _pivot.get_child_count() > 0


func _bake_sheet(def: EnemyDef, angry: bool, ticket: int) -> Image:
	var model := MonsterModel.new()
	model.shape = def.model
	model.body_color = def.angry_color if angry else def.color
	model.angry = angry
	_pivot.add_child(model)
	var sheet := Image.create(CELL * FRAMES, CELL * DIRECTIONS, false, Image.FORMAT_RGBA8)
	for direction in DIRECTIONS:
		# 画面の右から時計回りに45度ずつ。画面の右＝ワールドの +X、画面の下＝ワールドの +Z
		var angle := TAU * direction / DIRECTIONS
		_pivot.rotation.y = atan2(cos(angle), sin(angle))
		for frame in FRAMES:
			model.set_walk(float(frame) / FRAMES)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			if ticket != _ticket:
				model.free()
				return null
			var image := _viewport.get_texture().get_image()
			image.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(_outlined(image), Rect2i(0, 0, CELL, CELL), Vector2i(frame * CELL, direction * CELL))
	model.free()
	return sheet


## 絵の形をまわりにずらして縁取り色で敷き、その上に元の絵を重ねる。
func _outlined(image: Image) -> Image:
	var result := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	var rect := Rect2i(0, 0, CELL, CELL)
	for radius in [OUTLINE_PX * 0.5, OUTLINE_PX]:
		for i in OUTLINE_STEPS:
			var offset := Vector2(radius, 0).rotated(TAU * i / OUTLINE_STEPS)
			result.blend_rect_mask(_outline_fill, image, rect, Vector2i(roundi(offset.x), roundi(offset.y)))
	result.blend_rect(image, rect, Vector2i.ZERO)
	return result
