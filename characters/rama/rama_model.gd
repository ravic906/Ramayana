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

## Stance turn while aiming: the left shoulder swings toward the target.
const AIM_STANCE_YAW := deg_to_rad(-70.0)
const DRAW_LENGTH := 0.66
const STRING_REST_X := -0.035
const BOW_HALF := 0.71

var anim_tree: AnimationTree
var bow: Node3D
var pose: ArcheryPose
## 0..1, smoothed: how far Rama is into his archery stance.
var aim_weight := 0.0
## 0..1: how far the string is drawn.
var draw := 0.0
## World-space aim direction (set by Rama while aiming).
var aim_dir := Vector3.FORWARD

var _aiming := false
var _attachments := {}
var _batch: PropBatch
var _bow_raise := 0.0
var _bow_mat: ShaderMaterial
var _string_top: MeshInstance3D
var _string_bottom: MeshInstance3D
var _nocked_arrow: Node3D
var _nock_point := Vector3.ZERO
var _astra_fx: Node3D


func _ready() -> void:
	_build_ornaments()
	_build_bow()
	_build_anim_tree()
	pose = ArcheryPose.new()
	pose.name = "ArcheryPose"
	pose.influence = 0.0
	skeleton.add_child(pose)


func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	aim_weight = move_toward(aim_weight, 1.0 if _aiming else 0.0, real_delta * 6.0)
	var w := smoothstep(0.0, 1.0, aim_weight)
	body.transform.basis = Basis(Vector3.UP, PI + AIM_STANCE_YAW * w)
	if pose:
		pose.influence = w
		_update_pose_targets()
	_update_bow(real_delta)


# --- Archery API --------------------------------------------------------------

func begin_aim() -> void:
	_aiming = true


func end_aim() -> void:
	_aiming = false
	draw = 0.0


func is_aiming() -> bool:
	return _aiming


func set_draw(amount: float) -> void:
	draw = clampf(amount, 0.0, 1.0)


func set_aim_direction(dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		aim_dir = dir.normalized()


## Where the arrow sits on the string (world space).
func get_nock_position() -> Vector3:
	return _nock_point


func get_bone_world(bone: String) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


## Hand position including the archery IK (blended by its influence).
func get_hand_world(side: String) -> Vector3:
	var animated := get_bone_world("hand_" + side)
	if pose == null or pose.influence <= 0.0 or pose.solved_hand_l == Vector3.ZERO:
		return animated
	var solved := pose.solved_hand_l if side == "l" else pose.solved_hand_r
	return animated.lerp(solved, pose.influence)


## Distance from the drawing hand to where the IK wants it (for tests/debug).
func string_hand_error() -> float:
	return get_hand_world("r").distance_to(pose.string_target) if pose else INF


func _update_pose_targets() -> void:
	var right := aim_dir.cross(Vector3.UP).normalized()
	var head := get_bone_world("Head")
	var anchor := head + Vector3.DOWN * 0.07 + aim_dir * 0.07 + right * 0.03
	var grip := anchor + aim_dir * DRAW_LENGTH
	var pull := 1.0 - pow(1.0 - draw, 2.0)
	pose.bow_target = grip
	pose.bow_pole = get_bone_world("upperarm_l") + Vector3.DOWN * 0.5 - right * 0.3
	pose.string_target = (grip - aim_dir * 0.1).lerp(anchor, pull)
	pose.draw_pole = get_bone_world("upperarm_r") - aim_dir * 0.6 + Vector3.UP * 0.15 + right * 0.2
	pose.look_target = anchor + aim_dir * 20.0


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


func play_death() -> void:
	if anim_tree:
		anim_tree.active = false
	anim_player.play(&"death", 0.1)


func revive() -> void:
	anim_player.stop()
	if anim_tree:
		anim_tree.active = true


## Flames on the bow (and on the nocked arrow while drawing) while an astra is armed.
func set_astra_glow(astra: AstraResource) -> void:
	if _astra_fx == null:
		_astra_fx = Node3D.new()
		_astra_fx.name = "AstraFX"
		_astra_fx.top_level = true
		var flames := CPUParticles3D.new()
		flames.name = "Flames"
		flames.amount = 30
		flames.lifetime = 0.45
		flames.local_coords = false
		flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		flames.emission_sphere_radius = 0.05
		flames.direction = Vector3.UP
		flames.spread = 15.0
		flames.initial_velocity_min = 0.4
		flames.initial_velocity_max = 1.2
		flames.gravity = Vector3(0, 1.0, 0)
		var curve := Curve.new()
		curve.add_point(Vector2(0, 1))
		curve.add_point(Vector2(1, 0))
		flames.scale_amount_curve = curve
		_astra_fx.add_child(flames)
		var light := OmniLight3D.new()
		light.name = "Light"
		light.light_energy = 1.5
		light.omni_range = 3.0
		_astra_fx.add_child(light)
		add_child(_astra_fx)
	_astra_fx.visible = astra != null
	var flames := _astra_fx.get_node("Flames") as CPUParticles3D
	flames.emitting = false
	if astra != null:
		_astra_fx.global_position = get_hand_world("l")
		flames.mesh = FX.glow_quad(astra.color, 0.14)
		flames.restart()
		(_astra_fx.get_node("Light") as OmniLight3D).light_color = astra.color


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
	_batch = PropBatch.new(skeleton)
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
	_add("pelvis", _pleats(), load(MAT + "pitambara.tres"), _at(0, 0.985, 0.108), true)

	# Quiver on the back, its top over the right shoulder.
	var q_axis := Vector3(-0.42, 1.0, 0.0).normalized()
	var q := Transform3D(Basis(Vector3.BACK, Vector3.UP.signed_angle_to(q_axis, Vector3.BACK)), Vector3(0.02, 1.3, -0.21))
	_add("spine_03", _cyl(0.045, 0.038, 0.5, 14), load(MAT + "wood.tres"), q, true)
	for y in [-0.21, 0.0, 0.22]:
		_add("spine_03", _torus(0.04, 0.052, 14), gold_plain, q * _at(0, y, 0))
	for i in 5:
		var off := Vector3(cos(i * 1.3) * 0.02, 0.3, sin(i * 1.3) * 0.02)
		_add("spine_03", _cyl(0.005, 0.005, 0.16, 6), gold_plain, q * Transform3D(Basis(), off))
		_add("spine_03", _box(Vector3(0.004, 0.07, 0.03)), load(MAT + "saffron.tres"), q * Transform3D(Basis(), off + Vector3(0, 0.09, 0)))
	_batch.commit()


func _build_bow() -> void:
	bow = Node3D.new()
	bow.name = "Kodanda"
	bow.top_level = true
	var bow_mesh := MeshInstance3D.new()
	bow_mesh.mesh = _bow_mesh()
	_bow_mat = (load(MAT + "bow.tres") as ShaderMaterial).duplicate()
	bow_mesh.material_override = _bow_mat
	bow.add_child(bow_mesh)
	add_child(bow)
	var string_mat: Material = load(MAT + "string_mat.tres")
	_string_top = _string_segment(string_mat)
	_string_bottom = _string_segment(string_mat)
	_nocked_arrow = _build_nocked_arrow()


func _string_segment(material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _cyl(0.0035, 0.0035, 1.0, 4)
	mi.material_override = material
	mi.top_level = true
	add_child(mi)
	return mi


func _build_nocked_arrow() -> Node3D:
	var arrow := Node3D.new()
	arrow.name = "NockedArrow"
	arrow.top_level = true
	arrow.visible = false
	var shaft := Basis(Vector3.RIGHT, PI / 2)
	_add_to(arrow, _cyl(0.006, 0.006, 0.82, 6), load(MAT + "gold_plain.tres"), Transform3D(shaft, Vector3(0, 0, -0.41)))
	_add_to(arrow, _cyl(0.0, 0.016, 0.06, 6), load(MAT + "gold.tres"), Transform3D(shaft.rotated(Vector3.RIGHT, PI), Vector3(0, 0, -0.85)))
	for i in 3:
		var fin := Basis(Vector3.BACK, TAU * i / 3.0)
		_add_to(arrow, _box(Vector3(0.003, 0.03, 0.09)), load(MAT + "saffron.tres"), Transform3D(fin, Vector3(0, 0, -0.07) + fin * Vector3(0, 0.016, 0)))
	add_child(arrow)
	return arrow


## The bow follows the left hand; its orientation is set here: carried upright
## at Rama's side, raised for a snap shot, held vertical toward the target
## while aiming. The string bends to the drawing hand and the limbs flex.
func _update_bow(delta: float) -> void:
	if bow == null or skeleton == null:
		return
	_bow_raise = move_toward(_bow_raise, 1.0 if is_playing(&"shoot") else 0.0, delta * 8.0)
	var hand := get_hand_world("l")
	var b := body.global_transform.basis.orthonormalized()
	var axis := Vector3(0.05, 1.0, 0.2).lerp(Vector3(0.12, 1.0, 0.0), _bow_raise).normalized()
	var belly := Vector3(1.0, 0.0, 0.2).lerp(Vector3(0.0, 0.0, 1.0), _bow_raise)
	var carry := b * _frame(axis, belly)
	var right := aim_dir.cross(Vector3.UP).normalized()
	var aimed := _frame((Vector3.UP + right * 0.12).normalized(), aim_dir)
	var w := smoothstep(0.0, 1.0, aim_weight)
	var basis := Basis(carry.get_rotation_quaternion().slerp(aimed.get_rotation_quaternion(), w))
	bow.global_transform = Transform3D(basis, hand + (b * Vector3(0.0, -0.02, 0.03)) * (1.0 - w))

	var bend := draw * w
	_bow_mat.set_shader_parameter(&"bend", bend)
	var tip_x := STRING_REST_X - bend * 0.085
	var tip_y := BOW_HALF * (1.0 - bend * 0.03)
	var top := bow.global_transform * Vector3(tip_x, tip_y, 0.0)
	var bottom := bow.global_transform * Vector3(tip_x, -tip_y, 0.0)
	var rest_nock := bow.global_transform * Vector3(STRING_REST_X, 0.0, 0.0)
	_nock_point = rest_nock.lerp(get_hand_world("r"), clampf(w * 1.5 - 0.5, 0.0, 1.0)) if _aiming or w > 0.0 else rest_nock
	_place_segment(_string_top, top, _nock_point)
	_place_segment(_string_bottom, bottom, _nock_point)

	if _astra_fx and _astra_fx.visible:
		_astra_fx.global_position = (_nocked_arrow.global_transform * Vector3(0, 0, -0.85)) if _nocked_arrow.visible else hand
	_nocked_arrow.visible = _aiming and w > 0.6
	if _nocked_arrow.visible:
		var forward := (bow.global_position - _nock_point)
		if forward.length_squared() < 0.01:
			forward = aim_dir
		_nocked_arrow.global_transform = Transform3D(Basis.looking_at(forward.normalized(), Vector3.UP), _nock_point)


func _frame(up: Vector3, belly: Vector3) -> Basis:
	var y := up.normalized()
	var x := (belly - y * belly.dot(y)).normalized()
	return Basis(x, y, x.cross(y))


func _place_segment(mi: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var d := to - from
	var length := d.length()
	if length < 0.001:
		mi.visible = false
		return
	mi.visible = true
	var y := d / length
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.global_transform = Transform3D(Basis(x, y * length, x.cross(y)), (from + to) * 0.5)


func get_bow_tip_position() -> Vector3:
	return bow.global_position + bow.global_basis.x * 0.05 if bow else global_position


# --- Mesh helpers -----------------------------------------------------------

## Queues a prop for merging (see PropBatch); committed at the end of _build_ornaments.
func _add(bone: String, mesh: Mesh, material: Material, rest_xf: Transform3D, casts_shadow: bool = false) -> void:
	_batch.add(bone, mesh, material, rest_xf, casts_shadow)


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
