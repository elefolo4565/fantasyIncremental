class_name MonsterModel
extends Node3D
## 仮の敵の3Dモデル（スライム・突進スライム・王冠のスライム・ゴブリン・こうもり・戦士・オーガ・森の木）。
## 形は data/enemies.csv の model 列で選ぶ。Godot の基本図形だけで組み立てる。body_color は体（人型は肌、戦士は鎧）の色。
## tools/render_enemies が絵に焼くときと、敵エディタ（scenes/enemy_editor）の3Dの見た目に使う。
## 本番のモデルができたら assets/models/<名前>.glb に置けば、焼くときはそちらが使われる。
## 足元が原点、正面が +Z。set_walk(0〜1) で動きの1周（スライムは跳ねる、人型は歩く、こうもりは羽ばたく）のどこかの姿勢にする。

const OUTLINE := Color(0.09, 0.07, 0.13)
const EYE_WHITE := Color(1, 1, 1)
const HIGHLIGHT := Color(1, 1, 1)
const HORN_COLOR := Color(1.0, 0.95, 0.75)
const CROWN_COLOR := Color(1.0, 0.82, 0.2)
const CROWN_GEM := Color(1.0, 0.3, 0.45)
const TRUNK_COLOR := Color(0.62, 0.38, 0.2)
const SLIME_RADIUS := 0.6
const SLIME_HEIGHT := 0.82
const METAL_COLOR := Color(0.82, 0.85, 0.9)
const WOOD_COLOR := Color(0.55, 0.35, 0.18)
const CLOTH_COLOR := Color(0.5, 0.32, 0.2)
const DARK_CLOTH := Color(0.28, 0.22, 0.2)
const SKIN_COLOR := Color(1.0, 0.8, 0.64)
const TOOTH_COLOR := Color(1.0, 0.97, 0.88)
const CREST_COLOR := Color(0.9, 0.2, 0.2)
const GOLD_COLOR := Color(1.0, 0.8, 0.25)
## 歩く・羽ばたく大きさ（見た目だけ）
const LEG_SWING := 0.55
const ARM_SWING := 0.45
const WING_FLAP := 0.7
const HUMANOIDS := [&"goblin", &"warrior", &"ogre"]

## 生成する側が add_child の前に入れる
var body_color := Color(0.3, 0.78, 1.0)
## &"slime" / &"dasher" / &"king"（王冠） / &"goblin" / &"bat" / &"warrior" / &"ogre" / &"oak"
var shape := &"slime"
## 怒った眉（追ってきているとき）
var angry := false

var _body := Node3D.new()
var _blob: MeshInstance3D
## 人型の手足（付け根で回す）とこうもりの羽
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _wings: Array[Node3D] = []


func _ready() -> void:
	add_child(_body)
	match shape:
		&"oak":
			_build_oak()
		&"goblin":
			_build_goblin()
		&"warrior":
			_build_warrior()
		&"ogre":
			_build_ogre()
		&"bat":
			_build_bat()
		_:
			_build_slime()
	set_walk(0.0)


## phase は跳ねる動きの1周（0〜1）。2Dのころと同じく、横に広がると縦に縮む。
func set_walk(phase: float) -> void:
	if shape == &"oak":
		return
	var swing := sin(phase * TAU)
	if shape in HUMANOIDS:
		# 手足を前後に振り、体を上下に揺らす（左右の手足は逆に振る）
		for i in _legs.size():
			_legs[i].rotation.x = swing * LEG_SWING * (1.0 if i == 0 else -1.0)
		for i in _arms.size():
			_arms[i].rotation.x = swing * ARM_SWING * (-1.0 if i == 0 else 1.0)
		_body.position.y = absf(cos(phase * TAU)) * 0.04
		return
	if shape == &"bat":
		for i in _wings.size():
			_wings[i].rotation.z = swing * WING_FLAP * (1.0 if i == 0 else -1.0)
		_body.position.y = -swing * 0.06
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
	elif shape == &"king":
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


# ---- 人型（ゴブリン・戦士・オーガ） ----

## 小柄で緑の肌、長くとがった耳と大きな鼻。短剣を持つ。
func _build_goblin() -> void:
	_add_legs(0.3, 0.12, 0.075, DARK_CLOTH, DARK_CLOTH)
	var tunic := _cone(0.17, 0.25, 0.36)
	_part(tunic, CLOTH_COLOR, Vector3(0, 0.46, 0), Vector3.ONE, _body)
	_part(_cylinder(0.2, 0.05), WOOD_COLOR.darkened(0.3), Vector3(0, 0.36, 0), Vector3.ONE, _body)
	var head_y := 0.86
	_part(_sphere(0.3), body_color, Vector3(0, head_y, 0), Vector3(1.1, 0.95, 1), _body)
	for side in [-1.0, 1.0]:
		var ear := _part(_cone(0.0, 0.1, 0.36), body_color, Vector3(side * 0.42, head_y + 0.08, -0.02), Vector3(1, 1, 0.5), _body)
		ear.rotation.z = -side * deg_to_rad(70)
	_part(_sphere(0.08), body_color.darkened(0.08), Vector3(0, head_y - 0.04, 0.3), Vector3(0.9, 0.8, 1.4), _body)
	_add_face(head_y + 0.06, 0.12, 0.25, 0.085, true)
	# 口からのぞく牙
	for side in [-1.0, 1.0]:
		_part(_cone(0.0, 0.03, 0.07), TOOTH_COLOR, Vector3(side * 0.07, head_y - 0.13, 0.26), Vector3.ONE, _body)
	var arms := _add_arms(Vector3(0.22, 0.6, 0), 0.26, 0.055, body_color, body_color)
	# 右手の短剣
	var dagger := Node3D.new()
	arms[1].add_child(dagger)
	dagger.position = Vector3(0, -0.3, 0.06)
	dagger.rotation.x = deg_to_rad(70)
	_part(_box(Vector3(0.1, 0.03, 0.04)), WOOD_COLOR, Vector3.ZERO, Vector3.ONE, dagger)
	_part(_box(Vector3(0.05, 0.26, 0.02)), METAL_COLOR, Vector3(0, 0.14, 0), Vector3.ONE, dagger, true)


## 鎧（body_color）と羽根飾りのかぶと。右手に剣、左手に丸い盾。
func _build_warrior() -> void:
	_add_legs(0.4, 0.13, 0.085, DARK_CLOTH, WOOD_COLOR.darkened(0.3))
	_part(_cone(0.25, 0.22, 0.44), body_color, Vector3(0, 0.62, 0), Vector3.ONE, _body)
	_part(_cylinder(0.24, 0.06), WOOD_COLOR, Vector3(0, 0.43, 0), Vector3.ONE, _body)
	for side in [-1.0, 1.0]:
		_part(_sphere(0.13), body_color.lightened(0.15), Vector3(side * 0.27, 0.8, 0), Vector3(1, 0.8, 1), _body)
	var head_y := 1.07
	_part(_sphere(0.25), SKIN_COLOR, Vector3(0, head_y, 0), Vector3.ONE, _body)
	_add_face(head_y, 0.1, 0.22, 0.06, false)
	# かぶと: 頭の上半分と後ろをおおい、てっぺんに羽根飾り
	_part(_sphere(0.28), METAL_COLOR, Vector3(0, head_y + 0.07, -0.04), Vector3(1, 0.85, 1), _body)
	_part(_cylinder(0.29, 0.06), METAL_COLOR.darkened(0.15), Vector3(0, head_y + 0.08, 0), Vector3.ONE, _body)
	_part(_box(Vector3(0.06, 0.16, 0.36)), CREST_COLOR, Vector3(0, head_y + 0.33, -0.04), Vector3.ONE, _body)
	var arms := _add_arms(Vector3(0.3, 0.78, 0), 0.32, 0.07, body_color, SKIN_COLOR)
	var sword := Node3D.new()
	arms[1].add_child(sword)
	sword.position = Vector3(0, -0.36, 0.06)
	sword.rotation.x = deg_to_rad(60)
	_part(_box(Vector3(0.05, 0.12, 0.05)), WOOD_COLOR, Vector3(0, -0.02, 0), Vector3.ONE, sword)
	_part(_box(Vector3(0.22, 0.04, 0.06)), GOLD_COLOR, Vector3(0, 0.06, 0), Vector3.ONE, sword)
	_part(_box(Vector3(0.08, 0.5, 0.025)), METAL_COLOR, Vector3(0, 0.33, 0), Vector3.ONE, sword, true)
	var shield := _part(_cylinder(0.24, 0.05), body_color.darkened(0.25), Vector3(-0.06, -0.24, 0.1), Vector3.ONE, arms[0])
	shield.rotation = Vector3(deg_to_rad(90), 0, deg_to_rad(-20))
	_part(_sphere(0.07), GOLD_COLOR, Vector3(0, 0.03, 0), Vector3(1, 0.6, 1), shield)


## 大きな体と太い手足、小さな頭に下あごの牙。右手にこん棒。
func _build_ogre() -> void:
	_add_legs(0.36, 0.2, 0.12, body_color, body_color.darkened(0.15))
	_part(_cone(0.33, 0.38, 0.2), CLOTH_COLOR, Vector3(0, 0.42, 0), Vector3.ONE, _body)
	_part(_sphere(0.42), body_color, Vector3(0, 0.78, 0), Vector3(1.05, 1, 0.9), _body)
	_part(_sphere(0.2), body_color.lightened(0.12), Vector3(0, 0.72, 0.24), Vector3(1.2, 1, 0.6), _body)
	var head_y := 1.24
	_part(_sphere(0.22), body_color, Vector3(0, head_y, 0.06), Vector3.ONE, _body)
	_add_face(head_y + 0.03, 0.09, 0.26, 0.06, true)
	for side in [-1.0, 1.0]:
		_part(_cone(0.0, 0.04, 0.12), TOOTH_COLOR, Vector3(side * 0.09, head_y - 0.08, 0.24), Vector3.ONE, _body)
		_part(_sphere(0.06), body_color, Vector3(side * 0.22, head_y + 0.02, 0.02), Vector3(0.6, 1, 0.8), _body)
	var arms := _add_arms(Vector3(0.44, 0.98, 0), 0.44, 0.1, body_color, body_color)
	var club := Node3D.new()
	arms[1].add_child(club)
	club.position = Vector3(0, -0.5, 0.08)
	# 外側へ傾けて肩にかつぐ（正面からも見えるように）
	club.rotation = Vector3(deg_to_rad(20), 0, deg_to_rad(-30))
	_part(_cone(0.15, 0.06, 0.72), WOOD_COLOR, Vector3(0, 0.32, 0), Vector3.ONE, club)


## 足（付け根で回す）。hip_y は付け根の高さ、spread は左右の間、radius は太さ。足の長さは hip_y と同じ。
func _add_legs(hip_y: float, spread: float, radius: float, color: Color, foot_color: Color) -> void:
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * spread, hip_y, 0)
		_body.add_child(hip)
		_part(_capsule(radius, hip_y), color, Vector3(0, -hip_y * 0.5, 0), Vector3.ONE, hip)
		_part(_sphere(radius * 1.25), foot_color, Vector3(0, -hip_y + radius * 0.8, radius * 0.6),
				Vector3(1, 0.7, 1.5), hip)
		_legs.append(hip)


## 腕（肩で回す）。shoulder は右肩の位置（左は x を反転）。返すのは [左腕, 右腕]。
func _add_arms(shoulder: Vector3, length: float, radius: float, color: Color, hand_color: Color) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * shoulder.x, shoulder.y, shoulder.z)
		pivot.rotation.z = side * deg_to_rad(12)
		_body.add_child(pivot)
		_part(_capsule(radius, length), color, Vector3(0, -length * 0.5, 0), Vector3.ONE, pivot)
		_part(_sphere(radius * 1.3), hand_color, Vector3(0, -length, 0), Vector3.ONE, pivot)
		_arms.append(pivot)
		result.append(pivot)
	return result


## 目（と怒った眉）。eye_y は目の高さ、gap は左右の間の半分、front は顔の前面の z、size は黒目の大きさ。
func _add_face(eye_y: float, gap: float, front: float, size: float, whites: bool) -> void:
	for side in [-1.0, 1.0]:
		if whites:
			_part(_sphere(size * 1.5), EYE_WHITE, Vector3(side * gap, eye_y, front), Vector3(1, 1.1, 0.6), _body, true)
		_part(_sphere(size), OUTLINE, Vector3(side * gap, eye_y, front + size * 0.8), Vector3(1, 1.3, 0.6), _body)
		if angry:
			var brow := _part(_box(Vector3(size * 3.0, size * 0.6, 0.05)), OUTLINE,
					Vector3(side * gap, eye_y + size * 2.0, front + size), Vector3.ONE, _body)
			brow.rotation.z = side * deg_to_rad(25)


# ---- こうもり ----

## 宙に浮く丸い体に大きな耳と牙、左右に羽。羽ばたいて上下に揺れる。
func _build_bat() -> void:
	var body_y := 0.8
	_part(_sphere(0.3), body_color, Vector3(0, body_y, 0), Vector3(1, 0.95, 0.9), _body)
	_part(_sphere(0.18), body_color.lightened(0.2), Vector3(0, body_y - 0.08, 0.16), Vector3(1, 1, 0.6), _body)
	for side in [-1.0, 1.0]:
		var ear := _part(_cone(0.0, 0.11, 0.3), body_color, Vector3(side * 0.16, body_y + 0.32, 0), Vector3(1, 1, 0.5), _body)
		ear.rotation.z = -side * deg_to_rad(18)
		_part(_cone(0.0, 0.025, 0.08), TOOTH_COLOR, Vector3(side * 0.06, body_y - 0.12, 0.26), Vector3.ONE, _body)
		# 小さな足
		_part(_sphere(0.05), body_color.darkened(0.3), Vector3(side * 0.1, body_y - 0.3, 0), Vector3.ONE, _body)
	_add_face(body_y + 0.05, 0.11, 0.24, 0.06, true)
	var wing_color := body_color.darkened(0.35)
	for side in [-1.0, 1.0]:
		var root := Node3D.new()
		root.position = Vector3(side * 0.24, body_y + 0.05, -0.04)
		# 少し後ろへ反らせて、横から見ても羽の形がわかるようにする
		root.rotation.y = side * deg_to_rad(25)
		_body.add_child(root)
		# 羽の骨と、ぎざぎざの膜（平たい楕円を3枚並べる）
		var bone := _part(_capsule(0.03, 0.62), wing_color.darkened(0.2), Vector3(side * 0.3, 0.1, 0), Vector3.ONE, root)
		bone.rotation.z = side * deg_to_rad(-70)
		for i in 3:
			var x: float = side * (0.14 + i * 0.17)
			_part(_sphere(0.15), wing_color, Vector3(x, 0.02 - i * 0.02, 0), Vector3(0.75, 1.3 - i * 0.2, 0.15), root)
		_wings.append(root)


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


func _cylinder(radius: float, height: float) -> CylinderMesh:
	return _cone(radius, radius, height)


## 上下で太さの違う筒（top が 0 なら円すい）。
func _cone(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	return mesh


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
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
