extends Node3D
## 仮のプレイヤー（魔法使い）の3Dモデル。Godot の基本図形だけで組み立てる。
## render_player が8方向の絵に焼くときに使う。本番のモデルができたら assets/models/player.glb に置けば、こちらは使われない。
## 足元が原点、正面が +Z。set_walk(0〜1) で歩きの1周のどこかの姿勢にする。

const ROBE_COLOR := Color(0.55, 0.3, 0.95)
const HAT_COLOR := Color(0.32, 0.25, 0.85)
const BAND_COLOR := Color(1.0, 0.8, 0.15)
const SKIN_COLOR := Color(1.0, 0.82, 0.66)
const STAFF_COLOR := Color(0.6, 0.38, 0.2)
const GEM_COLOR := Color(0.4, 0.95, 1.0)
const SHOE_COLOR := Color(0.3, 0.2, 0.16)
const EYE_COLOR := Color(0.09, 0.07, 0.13)

var _body := Node3D.new()
var _foot_l: MeshInstance3D
var _foot_r: MeshInstance3D
var _staff := Node3D.new()


func _ready() -> void:
	add_child(_body)
	_foot_l = _part(_sphere(0.11), SHOE_COLOR, Vector3(-0.13, 0.08, 0.02), Vector3(1, 0.7, 1.5), self)
	_foot_r = _part(_sphere(0.11), SHOE_COLOR, Vector3(0.13, 0.08, 0.02), Vector3(1, 0.7, 1.5), self)
	# ローブ（すそ広がりの円すい台）
	var robe := CylinderMesh.new()
	robe.top_radius = 0.24
	robe.bottom_radius = 0.36
	robe.height = 0.72
	_part(robe, ROBE_COLOR, Vector3(0, 0.46, 0), Vector3.ONE, _body)
	# 大きな頭
	_part(_sphere(0.36), SKIN_COLOR, Vector3(0, 1.12, 0), Vector3(1, 0.95, 0.95), _body)
	# 目（正面 +Z 側）
	_part(_sphere(0.075), EYE_COLOR, Vector3(-0.13, 1.04, 0.33), Vector3(0.9, 1.4, 0.6), _body)
	_part(_sphere(0.075), EYE_COLOR, Vector3(0.13, 1.04, 0.33), Vector3(0.9, 1.4, 0.6), _body)
	# とんがり帽子
	var brim := CylinderMesh.new()
	brim.top_radius = 0.44
	brim.bottom_radius = 0.44
	brim.height = 0.06
	_part(brim, HAT_COLOR, Vector3(0, 1.38, 0), Vector3.ONE, _body)
	var band := CylinderMesh.new()
	band.top_radius = 0.33
	band.bottom_radius = 0.34
	band.height = 0.09
	_part(band, BAND_COLOR, Vector3(0, 1.43, 0), Vector3.ONE, _body)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.33
	cone.height = 0.75
	var tip := _part(cone, HAT_COLOR, Vector3(0, 1.76, -0.04), Vector3.ONE, _body)
	tip.rotation.x = deg_to_rad(-14)
	# 杖（右手側）
	_body.add_child(_staff)
	_staff.position = Vector3(0.42, 0.0, 0.12)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.035
	pole.bottom_radius = 0.035
	pole.height = 1.25
	_part(pole, STAFF_COLOR, Vector3(0, 0.66, 0), Vector3.ONE, _staff)
	_part(_sphere(0.11), GEM_COLOR, Vector3(0, 1.32, 0), Vector3.ONE, _staff, true)
	set_walk(0.0)


## phase は歩きの1周（0〜1）。足を前後に出し、体を上下に揺らす。
func set_walk(phase: float) -> void:
	var swing := sin(phase * TAU)
	_foot_l.position.z = 0.02 + swing * 0.24
	_foot_r.position.z = 0.02 - swing * 0.24
	_foot_l.position.y = 0.08 + maxf(swing, 0.0) * 0.05
	_foot_r.position.y = 0.08 + maxf(-swing, 0.0) * 0.05
	_body.position.y = absf(cos(phase * TAU)) * 0.05
	_staff.rotation.x = swing * 0.12


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
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
