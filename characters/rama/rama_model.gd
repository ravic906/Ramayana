@tool
class_name RamaModel
extends Node3D
## Rama's visual: the rigged body (built by tools/build_rama.gd), procedural
## ornaments (kireeta crown, jewellery, dhoti pleats, quiver, the Kodanda bow)
## and an AnimationTree that blends locomotion with shoot / roll / hit one-shots.
##
## Ornaments are authored in the body's rest-pose space (Y up, facing +Z,
## metres) and converted to bone space, so they follow the animation.

const MAT := "res://assets/materials/"
const UPPER_BODY_BONES := [
	"spine_01", "spine_02", "spine_03", "neck_01", "Head",
	"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
	"clavicle_r", "upperarm_r", "lowerarm_r", "hand_r",
]
const FINGERS := ["index", "middle", "pinky", "ring", "thumb"]

## Locomotion blend positions (fraction of Rama's run speed).
const WALK_POINT := 0.4
const RUN_POINT := 1.0

@onready var body: Node3D = $Body
@onready var skeleton: Skeleton3D = $Body/Armature/Skeleton3D
@onready var anim_player: AnimationPlayer = $Body/AnimationPlayer

var anim_tree: AnimationTree
var bow: Node3D
var _attachments := {}
var _bow_aim := 0.0


func _ready() -> void:
	_build_ornaments()
	_build_bow()
	_build_anim_tree()


func _process(delta: float) -> void:
	_update_bow(delta)


# --- Public API used by Rama ------------------------------------------------

## speed_ratio: horizontal speed / run speed (0 = idle, 1 = run).
func set_locomotion(speed_ratio: float) -> void:
	if anim_tree:
		anim_tree.set("parameters/locomotion/blend_position", clampf(speed_ratio, 0.0, 1.0))


func get_locomotion() -> float:
	return anim_tree.get("parameters/locomotion/blend_position") if anim_tree else 0.0


func play_shoot() -> void:
	_fire(&"shoot")


## Plays the roll so it lasts `duration` seconds.
func play_roll(duration: float) -> void:
	if anim_tree == null:
		return
	var length := anim_player.get_animation(&"roll").length
	anim_tree.set("parameters/roll_speed/scale", length / maxf(duration, 0.05))
	_fire(&"roll")


func play_hit() -> void:
	_fire(&"hit")


func is_playing(one_shot: StringName) -> bool:
	return anim_tree != null and bool(anim_tree.get("parameters/%s/active" % one_shot))


func _fire(one_shot: StringName) -> void:
	if anim_tree:
		anim_tree.set("parameters/%s/request" % one_shot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


# --- Animation tree ---------------------------------------------------------

func _build_anim_tree() -> void:
	var bt := AnimationNodeBlendTree.new()

	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = 1.0
	for point in [[&"idle", 0.0], [&"walk", WALK_POINT], [&"run", RUN_POINT]]:
		loco.add_blend_point(_clip(point[0]), point[1])
	bt.add_node(&"locomotion", loco, Vector2(0, 0))

	var upper_filter := _upper_body_paths()
	bt.add_node(&"shoot_clip", _clip(&"shoot"), Vector2(0, 200))
	bt.add_node(&"shoot", _one_shot(0.05, 0.2, upper_filter), Vector2(300, 0))
	bt.connect_node(&"shoot", 0, &"locomotion")
	bt.connect_node(&"shoot", 1, &"shoot_clip")

	bt.add_node(&"roll_clip", _clip(&"roll"), Vector2(300, 200))
	bt.add_node(&"roll_speed", AnimationNodeTimeScale.new(), Vector2(450, 200))
	bt.connect_node(&"roll_speed", 0, &"roll_clip")
	bt.add_node(&"roll", _one_shot(0.05, 0.12, []), Vector2(600, 0))
	bt.connect_node(&"roll", 0, &"shoot")
	bt.connect_node(&"roll", 1, &"roll_speed")

	bt.add_node(&"hit_clip", _clip(&"hit"), Vector2(600, 200))
	bt.add_node(&"hit", _one_shot(0.05, 0.15, upper_filter), Vector2(900, 0))
	bt.connect_node(&"hit", 0, &"roll")
	bt.connect_node(&"hit", 1, &"hit_clip")
	bt.connect_node(&"output", 0, &"hit")

	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	anim_tree.tree_root = bt
	add_child(anim_tree)
	anim_tree.root_node = anim_tree.get_path_to(body)
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)
	anim_tree.set("parameters/roll_speed/scale", 1.0)
	anim_tree.active = true


func _clip(clip_name: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = clip_name
	return node


func _one_shot(fade_in: float, fade_out: float, filter: Array) -> AnimationNodeOneShot:
	var node := AnimationNodeOneShot.new()
	node.fadein_time = fade_in
	node.fadeout_time = fade_out
	if not filter.is_empty():
		node.filter_enabled = true
		for path: NodePath in filter:
			node.set_filter_path(path, true)
	return node


func _upper_body_paths() -> Array:
	var bones: Array = UPPER_BODY_BONES.duplicate()
	for side in ["l", "r"]:
		for finger: String in FINGERS:
			for i in range(1, 5):
				bones.append("%s_0%d%s_%s" % [finger, i, "_leaf" if i == 4 else "", side])
	var paths := []
	for bone: String in bones:
		paths.append(NodePath("Armature/Skeleton3D:" + bone))
	return paths


# --- Ornaments --------------------------------------------------------------

func _build_ornaments() -> void:
	var gold: Material = load(MAT + "gold.tres")
	var gold_plain: Material = load(MAT + "gold_plain.tres")
	var ruby: Material = load(MAT + "ruby.tres")
	var pearl: Material = load(MAT + "pearl.tres")

	# Kireeta (crown) on the head.
	var cz := -0.01
	_add("Head", _cyl(0.118, 0.118, 0.07, 20), gold, _at(0, 1.745, cz))
	_add("Head", _cyl(0.07, 0.115, 0.13, 16), gold, _at(0, 1.845, cz))
	_add("Head", _torus(0.106, 0.124, 20), gold_plain, _at(0, 1.785, cz))
	_add("Head", _torus(0.082, 0.098, 18), gold_plain, _at(0, 1.86, cz))
	_add("Head", _sphere(0.05), gold, _at(0, 1.925, cz))
	_add("Head", _cyl(0.0, 0.018, 0.06, 8), gold, _at(0, 1.98, cz))
	_add("Head", _sphere(0.024), ruby, _at(0, 1.75, cz + 0.118))
	for side in [-1.0, 1.0]:
		_add("Head", _sphere(0.012), ruby, _at(0.06 * side, 1.75, cz + 0.1))
		# Makara-kundala earrings.
		_add("Head", _torus(0.012, 0.024, 12), gold,
			Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3(0.088 * side, 1.6, -0.01)))
		_add("Head", _sphere(0.012), gold, _at(0.088 * side, 1.57, -0.01))

	# Necklaces on the upper chest.
	var neck_tilt := Basis(Vector3.RIGHT, deg_to_rad(28)).scaled(Vector3(1.0, 1.0, 0.85))
	_add("spine_03", _torus(0.105, 0.118, 24), gold, Transform3D(neck_tilt, Vector3(0, 1.47, -0.03)))
	_add("spine_03", _torus(0.13, 0.14, 24), pearl,
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(38)).scaled(Vector3(1.0, 1.0, 0.85)), Vector3(0, 1.43, -0.03)))
	_add("spine_03", _sphere(0.026), ruby, _at(0, 1.39, 0.115))

	# Keyura (armlets) and kankana (bracelets). Arms lie along X in rest pose.
	var along_x := Basis(Vector3.BACK, PI / 2)
	for side in ["l", "r"]:
		var s := 1.0 if side == "l" else -1.0
		_add("upperarm_" + side, _torus(0.056, 0.072, 16), gold, Transform3D(along_x, Vector3(0.33 * s, 1.462, -0.06)))
		_add("lowerarm_" + side, _torus(0.036, 0.05, 14), gold, Transform3D(along_x, Vector3(0.62 * s, 1.455, -0.066)))

	# Kamarbandh (waistband) and the pleated front of the dhoti.
	_add("pelvis", _torus(0.15, 0.172, 24), gold,
		Transform3D(Basis().scaled(Vector3(1.04, 1.0, 0.8)), Vector3(0, 1.0, -0.025)))
	_add("pelvis", _pleats(), load(MAT + "pitambara.tres"), _at(0, 0.985, 0.108))

	# Quiver on the back, its top over the right shoulder.
	var quiver := Node3D.new()
	quiver.name = "Quiver"
	var q_axis := Vector3(-0.42, 1.0, 0.0).normalized()
	var q_basis := Basis(Vector3.BACK, Vector3.UP.signed_angle_to(q_axis, Vector3.BACK))
	_add_to(quiver, _cyl(0.045, 0.038, 0.5, 14), load(MAT + "wood.tres"), Transform3D.IDENTITY)
	for y in [-0.21, 0.0, 0.22]:
		_add_to(quiver, _torus(0.04, 0.052, 14), gold_plain, _at(0, y, 0))
	for i in 5:
		var off := Vector3(cos(i * 1.3) * 0.02, 0.3, sin(i * 1.3) * 0.02)
		_add_to(quiver, _cyl(0.005, 0.005, 0.16, 6), gold_plain, Transform3D(Basis(), off))
		_add_to(quiver, _box(Vector3(0.004, 0.07, 0.03)), load(MAT + "saffron.tres"), Transform3D(Basis(), off + Vector3(0, 0.09, 0)))
	_attach_node("spine_03", quiver, Transform3D(q_basis, Vector3(0.02, 1.3, -0.21)))


func _build_bow() -> void:
	bow = Node3D.new()
	bow.name = "Kodanda"
	bow.top_level = true
	var bow_mesh := MeshInstance3D.new()
	bow_mesh.mesh = _bow_mesh()
	bow_mesh.material_override = load(MAT + "bow.tres")
	bow.add_child(bow_mesh)
	var string := MeshInstance3D.new()
	string.mesh = _cyl(0.003, 0.003, 1.42, 4)
	string.material_override = load(MAT + "string_mat.tres")
	string.position = Vector3(-0.035, 0.0, 0.0)
	bow.add_child(string)
	add_child(bow)


## The bow follows the left hand, but its orientation is set here: carried
## upright at Rama's side, raised vertical facing forward while shooting.
func _update_bow(delta: float) -> void:
	if bow == null or skeleton == null:
		return
	var target := 1.0 if is_playing(&"shoot") else 0.0
	_bow_aim = move_toward(_bow_aim, target, delta * 8.0)
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hand_l"))
	var b := body.global_transform.basis.orthonormalized()
	var axis := Vector3(0.05, 1.0, 0.2).lerp(Vector3(0.12, 1.0, 0.0), _bow_aim).normalized()
	var belly := Vector3(1.0, 0.0, 0.2).lerp(Vector3(0.0, 0.0, 1.0), _bow_aim)
	var y := axis
	var x := (belly - y * belly.dot(y)).normalized()
	var z := x.cross(y)
	bow.global_transform = Transform3D(b * Basis(x, y, z), hand.origin + b * Vector3(0.0, -0.02, 0.03))


func get_bow_tip_position() -> Vector3:
	return bow.global_position + bow.global_basis.x * 0.05 if bow else global_position


# --- Mesh helpers -----------------------------------------------------------

func _add(bone: String, mesh: Mesh, material: Material, rest_xf: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	_attach_node(bone, mi, rest_xf)
	return mi


func _add_to(parent: Node3D, mesh: Mesh, material: Material, xf: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.transform = xf
	parent.add_child(mi)


func _attach_node(bone: String, node: Node3D, rest_xf: Transform3D) -> void:
	if not _attachments.has(bone):
		var att := BoneAttachment3D.new()
		att.name = "Att_" + bone
		att.bone_name = bone
		skeleton.add_child(att)
		_attachments[bone] = att
	node.transform = skeleton.get_bone_global_rest(skeleton.find_bone(bone)).affine_inverse() * rest_xf
	_attachments[bone].add_child(node)


func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


func _cyl(top: float, bottom: float, height: float, segments: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


func _torus(inner: float, outer: float, segments: int) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = segments
	m.ring_segments = 8
	return m


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## Fan of pleats hanging from the waist to below the knee, gold hem at the bottom.
func _pleats() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 9
	var rows := 6
	var length := 0.56
	var pitambara := Color(1, 0, 0)  # region masks, see pitambara.tres
	var hem := Color(0, 1, 0)
	for r in rows:
		for c in cols - 1:
			var quad := []
			for corner in [[c, r], [c + 1, r], [c + 1, r + 1], [c, r + 1]]:
				var u := float(corner[0]) / (cols - 1)
				var v := float(corner[1]) / rows
				var width := lerpf(0.11, 0.21, v)
				var depth := (0.018 if int(corner[0]) % 2 == 0 else -0.004) * lerpf(0.4, 1.0, v)
				quad.append([Vector3((u - 0.5) * width, -v * length, depth + v * 0.02), v])
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_color(hem if quad[idx][1] > 0.9 else pitambara)
				st.set_uv(Vector2(0, quad[idx][1]))
				st.add_vertex(quad[idx][0])
	st.generate_normals()
	return st.commit()


## Kodanda: a tapered, recurved tube. Grip at the origin, limbs along Y,
## belly bulging toward +X; the string runs along the Y axis.
func _bow_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 24
	var sides := 6
	var half := 0.71
	var gold := Color(0, 0, 0)  # region masks, see bow.tres
	var grip := Color(1, 0, 0)
	var rings := []
	for i in segs + 1:
		var t := lerpf(-1.0, 1.0, float(i) / segs)
		var at := absf(t)
		var x := 0.11 * (1.0 - t * t) - 0.035 * maxf(at - 0.82, 0.0) / 0.18
		var center := Vector3(x, t * half, 0.0)
		var radius := lerpf(0.017, 0.007, at)
		var color := grip if at < 0.1 else gold
		var ring := []
		for s in sides:
			var a := TAU * s / sides
			ring.append(center + Vector3(cos(a) * radius, 0.0, sin(a) * radius))
		rings.append([ring, color])
	for i in segs:
		for s in sides:
			var s2 := (s + 1) % sides
			var a: Vector3 = rings[i][0][s]
			var b: Vector3 = rings[i][0][s2]
			var c: Vector3 = rings[i + 1][0][s2]
			var d: Vector3 = rings[i + 1][0][s]
			for p in [[a, i], [c, i + 1], [b, i], [a, i], [d, i + 1], [c, i + 1]]:
				st.set_color(rings[p[1]][1])
				st.add_vertex(p[0])
	st.generate_normals()
	return st.commit()
