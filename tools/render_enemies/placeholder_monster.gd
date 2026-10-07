extends Node3D
## 仮の敵の3Dモデル（スライム・突進スライム・ボス・森の木）。Godot の基本図形だけで組み立てる。
## render_enemies が絵に焼くときに使う。本番のモデルができたら assets/models/<名前>.glb に置けば、こちらは使われない。
## 足元が原点、正面が +Z。set_walk(0〜1) で跳ねる動きの1周のどこかの姿勢にする。

const OUTLINE := Color(0.09, 0.07, 0.13)
const EYE_WHITE := Color(1, 1, 1)
const HIGHLIGHT := Color(1, 1, 1)
const HORN_COLOR := Color(1.0, 0.95, 0.75)
const CROWN_COLOR := Color(1.0, 0.82, 0.2)
const CROWN_GEM := Color(1.0, 0.3, 0.45)
const TRUNK_COLOR := Color(0.62, 0.38, 0.2)
const SLIME_RADIUS := 0.6
const SLIME_HEIGHT := 0.82

## 生成する側が add_child の前に入れる
var body_color := Color(0.3, 0.78, 1.0)
## &"slime" / &"dasher" / &"boss" / &"oak"
var shape := &"slime"
## 怒った眉（追ってきているとき）
var angry := false

var _body := Node3D.new()
var _blob: MeshInstance3D


func _ready() -> void:
	add_child(_body)
	if shape == &"oak":
		_build_oak()
	else:
		_build_slime()
	set_walk(0.0)


## phase は跳ねる動きの1周（0〜1）。2Dのころと同じく、横に広がると縦に縮む。
func set_walk(phase: float) -> void:
	if shape == &"oak":
		return
	var squash := 1.0 + sin(phase * TAU) * 0.07
	_body.scale = Vector3(squash, 1.0 / squash, squash)


func _build_slime() -> void:
	var center_y := SLIME_RADIUS * SLIME_HEIGHT
	_blob = _part(_sphere(SLIME_RADIUS), body_color, Vector3(0, center_y, 0), Vector3(1, SLIME_HEIGHT, 1), _body)
	# 左上のつや
	_part(_sphere(0.12), HIGHLIGHT, Vector3(-0.24, center_y + 0.32, 0.22), Vector3(1.2, 0.8, 0.8), _body, true)
	# 目（白目と黒目）
	var eye_y := center_y + 0.1
	for side in [-1.0, 1.0]:
		_part(_sphere(0.16), EYE_WHITE, Vector3(side * 0.22, eye_y, 0.46), Vector3(1, 1.15, 0.6), _body, true)
		_part(_sphere(0.095), OUTLINE, Vector3(side * 0.22, eye_y - 0.01, 0.55), Vector3(1, 1.2, 0.6), _body)
		if angry:
			var brow := _part(_box(Vector3(0.24, 0.05, 0.06)), OUTLINE, Vector3(side * 0.22, eye_y + 0.22, 0.5), Vector3.ONE, _body)
			# 内側（鼻の側）を下げて、つり上がった眉にする
			brow.rotation.z = side * deg_to_rad(25)
	# 口
	var mouth := TorusMesh.new()
	mouth.inner_radius = 0.06
	mouth.outer_radius = 0.09
	var smile := _part(mouth, OUTLINE, Vector3(0, eye_y - 0.2, 0.5), Vector3(1, 0.6, 0.6), _body)
	smile.rotation.x = deg_to_rad(90)
	if shape == &"dasher":
		# 頭の角
		var horn := CylinderMesh.new()
		horn.top_radius = 0.0
		horn.bottom_radius = 0.13
		horn.height = 0.38
		_part(horn, HORN_COLOR, Vector3(0, center_y * 2.0 + 0.08, 0.05), Vector3.ONE, _body)
	elif shape == &"boss":
		_build_crown(center_y * 2.0 - 0.06)


func _build_crown(base_y: float) -> void:
	var ring := CylinderMesh.new()
	ring.top_radius = 0.3
	ring.bottom_radius = 0.28
	ring.height = 0.14
	_part(ring, CROWN_COLOR, Vector3(0, base_y + 0.07, 0), Vector3.ONE, _body)
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.09
	spike.height = 0.24
	for i in 5:
		var angle := TAU * i / 5.0
		_part(spike, CROWN_COLOR, Vector3(sin(angle) * 0.25, base_y + 0.25, cos(angle) * 0.25), Vector3.ONE, _body)
	_part(_sphere(0.06), CROWN_GEM, Vector3(0, base_y + 0.08, 0.29), Vector3.ONE, _body, true)


func _build_oak() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.24
	trunk.height = 0.8
	_part(trunk, TRUNK_COLOR, Vector3(0, 0.4, 0), Vector3.ONE, _body)
	# 葉のかたまり: [位置, 半径]
	for puff in [[Vector3(-0.32, 1.05, 0.08), 0.42], [Vector3(0.32, 1.05, 0.08), 0.42],
			[Vector3(0, 1.4, -0.05), 0.5], [Vector3(0, 1.1, 0.3), 0.38]]:
		_part(_sphere(puff[1]), body_color, puff[0], Vector3.ONE, _body)
	_part(_sphere(0.1), HIGHLIGHT, Vector3(-0.28, 1.7, 0.2), Vector3(1.3, 0.8, 0.8), _body, true)


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _part(mesh: Mesh, color: Color, at: Vector3, scale_by: Vector3, parent: Node3D, glow := false) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_TOON
	material.roughness = 0.6
	if glow:
		material.emission_enabled = true
		material.emission = color * 0.6
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.scale = scale_by
	parent.add_child(node)
	return node
