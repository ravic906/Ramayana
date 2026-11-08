class_name ArcheryPose
extends SkeletonModifier3D
## Procedural archery pose applied on top of the animation (blend with
## `influence`). Analytic two-bone IK for both arms plus a head look-at:
##   - bow arm (left) reaches toward `bow_target`
##   - draw arm (right) pulls the string hand to `string_target` with the
##     elbow raised behind (`draw_pole`)
##   - the head turns to sight along the arrow toward `look_target`
## All targets are in world space and set every frame by RamaModel.

var bow_target := Vector3.ZERO
var bow_pole := Vector3.ZERO
var string_target := Vector3.ZERO
var draw_pole := Vector3.ZERO
var look_target := Vector3.ZERO
var head_weight := 0.8

## Solved hand positions (world space, full influence). Godot applies modifier
## results only for rendering, so props that follow the hands read these.
var solved_hand_l := Vector3.ZERO
var solved_hand_r := Vector3.ZERO

var _bones := {}


func _ready() -> void:
	var sk := get_skeleton()
	for b in ["upperarm_l", "lowerarm_l", "hand_l", "upperarm_r", "lowerarm_r", "hand_r", "Head"]:
		_bones[b] = sk.find_bone(b) if sk else -1


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _bones.get("Head", -1) < 0:
		return
	var to_local := sk.global_transform.affine_inverse()
	_solve_two_bone(sk, _bones["upperarm_l"], _bones["lowerarm_l"], _bones["hand_l"],
		to_local * bow_target, to_local * bow_pole)
	_solve_two_bone(sk, _bones["upperarm_r"], _bones["lowerarm_r"], _bones["hand_r"],
		to_local * string_target, to_local * draw_pole)
	_look_at(sk, _bones["Head"], to_local * look_target)
	solved_hand_l = sk.global_transform * sk.get_bone_global_pose(_bones["hand_l"]).origin
	solved_hand_r = sk.global_transform * sk.get_bone_global_pose(_bones["hand_r"]).origin


## Rotates upper and lower bones so the hand reaches `target` (skeleton space),
## bending toward `pole`. Out-of-reach targets straighten the arm toward them.
static func _solve_two_bone(sk: Skeleton3D, upper: int, lower: int, hand: int, target: Vector3, pole: Vector3) -> void:
	var a := sk.get_bone_global_pose(upper).origin
	var b := sk.get_bone_global_pose(lower).origin
	var c := sk.get_bone_global_pose(hand).origin
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	var to_t := target - a
	if to_t.length_squared() < 0.0001 or l1 < 0.001 or l2 < 0.001:
		return
	var dir := to_t.normalized()
	var d := clampf(to_t.length(), absf(l1 - l2) + 0.001, (l1 + l2) * 0.999)
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var bend := pole - a
	bend = bend - dir * bend.dot(dir)
	if bend.length_squared() < 0.0001:
		bend = dir.cross(Vector3.RIGHT)
	var elbow := a + dir * x + bend.normalized() * h

	var upper_pose := sk.get_bone_global_pose(upper)
	upper_pose.basis = Basis(_arc((b - a).normalized(), (elbow - a).normalized())) * upper_pose.basis
	sk.set_bone_global_pose(upper, upper_pose)

	var lower_pose := sk.get_bone_global_pose(lower)
	var hand_now := sk.get_bone_global_pose(hand).origin
	var wrist_goal := a + dir * d
	lower_pose.basis = Basis(_arc((hand_now - lower_pose.origin).normalized(),
		(wrist_goal - lower_pose.origin).normalized())) * lower_pose.basis
	sk.set_bone_global_pose(lower, lower_pose)


func _look_at(sk: Skeleton3D, head: int, target: Vector3) -> void:
	var pose := sk.get_bone_global_pose(head)
	var want := target - pose.origin
	if want.length_squared() < 0.0001:
		return
	var forward := pose.basis.z.normalized()  # head looks along +Z in this rig
	var q := Quaternion.IDENTITY.slerp(_arc(forward, want.normalized()), head_weight)
	pose.basis = Basis(q) * pose.basis
	sk.set_bone_global_pose(head, pose)


static func _arc(from: Vector3, to: Vector3) -> Quaternion:
	var dot := from.dot(to)
	if dot > 0.99999:
		return Quaternion.IDENTITY
	if dot < -0.99999:
		var axis := from.cross(Vector3.UP)
		if axis.length_squared() < 0.0001:
			axis = from.cross(Vector3.RIGHT)
		return Quaternion(axis.normalized(), PI)
	return Quaternion(from, to)
