class_name ShotFramer
extends RefCounted
## Film-grammar camera placement for dialogue: close-ups, over-the-shoulder
## shots and two-shots, worked out from where the actors' faces are.
##
## An actor is any node whose subtree holds the shared rig (a Skeleton3D with
## HeadAttachment/EyeL and EyeR, built by tools/build_rama.gd).

enum Kind { CLOSE, OTS, TWO }

const CLOSE_DISTANCE := 0.95
const CLOSE_FOV := 26.0
const OTS_FOV := 30.0
const TWO_FOV := 38.0


## [eye centre, facing direction (flat, unit)] of an actor, or [] if it has no face.
static func face_of(actor: Node) -> Array:
	if not is_instance_valid(actor):
		return []
	var sk := actor as Skeleton3D
	if sk == null:
		sk = actor.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		return []
	var l := sk.get_node_or_null("HeadAttachment/EyeL") as Node3D
	var r := sk.get_node_or_null("HeadAttachment/EyeR") as Node3D
	if l == null or r == null:
		return []
	var eyes := (l.global_position + r.global_position) * 0.5
	# The eye pivots carry the face's rest frame: +Z looks out of the face.
	var fwd := l.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	return [eyes, fwd.normalized()]


## The FaceController of an actor (RamaModel/NpcModel `face_rig`, or a node
## with a `model` that has one), or null.
static func face_rig_of(actor: Node) -> FaceController:
	if not is_instance_valid(actor):
		return null
	if "face_rig" in actor:
		return actor.get("face_rig") as FaceController
	if "model" in actor and actor.get("model") is Node and "face_rig" in actor.get("model"):
		return actor.get("model").get("face_rig") as FaceController
	return null


## Returns {position, look, fov, focus} for a shot of `speaker`, optionally
## favouring `listener` (Node or null). `side` (+1/-1) picks which side of the
## line of action the camera sits on, so cuts never cross it.
static func frame(kind: Kind, speaker: Node, listener: Node = null, side := 1.0, blockers: Array = []) -> Dictionary:
	var s := face_of(speaker)
	if s.is_empty():
		return {}
	var eye: Vector3 = s[0]
	var fwd: Vector3 = s[1]
	var l := face_of(listener) if listener else []
	match kind:
		Kind.OTS:
			if l.is_empty():
				return frame(Kind.CLOSE, speaker, null, side, blockers)
			var leye: Vector3 = l[0]
			var to := (eye - leye)
			to.y = 0.0
			var dir := to.normalized()
			var right := dir.cross(Vector3.UP).normalized() * side
			# Just behind and beside the listener's head, the speaker over their shoulder.
			var pos := leye - dir * 0.75 + right * 0.5 + Vector3.UP * 0.04
			return {"position": pos, "look": eye + right * -0.12 - Vector3.UP * 0.05, "fov": OTS_FOV,
				"focus": pos.distance_to(eye)}
		Kind.TWO:
			if l.is_empty():
				return frame(Kind.CLOSE, speaker, null, side, blockers)
			var leye2: Vector3 = l[0]
			var mid := (eye + leye2) * 0.5
			var across := (eye - leye2)
			across.y = 0.0
			var sep := maxf(across.length(), 0.8)
			var perp := across.normalized().cross(Vector3.UP) * side
			# Choose the side both faces turn toward.
			if perp.dot(fwd) < 0.0 and perp.dot(l[1]) < 0.0:
				perp = -perp
			var dist := sep * 0.95 + 1.1
			var pos2 := mid + perp * dist + Vector3.UP * 0.1
			return {"position": pos2, "look": mid - Vector3.UP * 0.15, "fov": TWO_FOV, "focus": dist}
	# Close-up: in front of the face, a little off-axis toward the listener (or
	# to `side`), lens slightly below the eyes so the eyes sit in the upper third.
	var off := fwd.cross(Vector3.UP).normalized() * side
	if not l.is_empty():
		var tl: Vector3 = l[0] - eye
		tl.y = 0.0
		if tl.length_squared() > 0.0001:
			off = fwd.cross(Vector3.UP).normalized()
			if off.dot(tl) < 0.0:
				off = -off
	# Try toward the listener first, then the other side, then straight on and
	# tighter: the first view no other actor's head or body blocks.
	for attempt in [[off, CLOSE_DISTANCE], [-off, CLOSE_DISTANCE], [Vector3.ZERO, CLOSE_DISTANCE], [off, 0.62], [-off, 0.62]]:
		var dir3: Vector3 = (fwd + (attempt[0] as Vector3) * 0.42).normalized()
		var cpos: Vector3 = eye + dir3 * float(attempt[1]) - Vector3.UP * 0.02
		if not _blocked(cpos, eye, blockers, speaker):
			return {"position": cpos, "look": eye - Vector3.UP * 0.065, "fov": CLOSE_FOV, "focus": attempt[1]}
	return {}


## Whether another actor stands between the camera and the speaker's eyes
## (their head or chest within ~0.4 m of the sight line).
static func _blocked(cam: Vector3, eye: Vector3, blockers: Array, speaker: Node) -> bool:
	for b in blockers:
		if b == speaker or not is_instance_valid(b):
			continue
		var f := face_of(b)
		if f.is_empty():
			continue
		for p: Vector3 in [f[0], (f[0] as Vector3) - Vector3.UP * 0.45]:
			var seg := eye - cam
			var t := clampf((p - cam).dot(seg) / seg.length_squared(), 0.0, 1.0)
			if t > 0.02 and t < 0.98 and p.distance_to(cam + seg * t) < 0.4:
				return true
	return false
