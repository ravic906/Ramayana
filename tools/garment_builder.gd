extends RefCounted
## Clothes for the woman's body, as real geometry rather than paint on a
## close-fitting base mesh: a sari's draped skirt and a cloth layer over the
## torso and upper arms (the blouse, with the pallu across it to the left
## shoulder). Both share the body's skin, so they move with it. Colours use the
## outfit region masks (vertex colour), so NpcModel's palette applies:
##   R the sari's drape (skirt and pallu), G the zari border, B the blouse.
## Run from tools/build_rama.gd. Rest pose: metres, face toward +Z, X left.

const SKIRT_RINGS := 14
const SKIRT_SEGMENTS := 40
const SHELL_OFFSET := 0.007


## The bind index in `skin` for a bone name.
static func bind_of(skin: Skin, skeleton: Skeleton3D, bone: String) -> int:
	var b := skeleton.find_bone(bone)
	for i in skin.get_bind_count():
		if skin.get_bind_bone(i) == b or String(skin.get_bind_name(i)) == bone:
			return i
	return 0


## A cloth layer over the torso (waist to shoulders) and upper arms: the body's
## own triangles there, pushed out along their normals, keeping the skinning.
static func torso_shell(body_arrays: Array, waist: float, shoulder: float, arm_x: float) -> Array:
	var v: PackedVector3Array = body_arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = body_arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = body_arrays[Mesh.ARRAY_INDEX]
	var covered := func(p: Vector3) -> bool:
		return p.y > waist - 0.04 and p.y < shoulder + 0.06 and absf(p.x) < arm_x
	var tris := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		if covered.call(v[idx[t]]) and covered.call(v[idx[t + 1]]) and covered.call(v[idx[t + 2]]):
			tris.append_array([idx[t], idx[t + 1], idx[t + 2]])
	var FaceRig := load("res://tools/face_rig_builder.gd")
	var out: Array = FaceRig._subset(body_arrays, tris)
	var sv: PackedVector3Array = out[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = out[Mesh.ARRAY_NORMAL]
	var colors := PackedColorArray()
	colors.resize(sv.size())
	var pallu_a := Vector2(0.15, shoulder + 0.02)
	var pallu_b := Vector2(-0.17, waist - 0.02)
	for i in sv.size():
		sv[i] += sn[i] * SHELL_OFFSET
		var p := sv[i]
		var d := _dist_to_segment(Vector2(p.x, p.y), pallu_a, pallu_b)
		var c := Color(0, 0, 1)  # the blouse
		if d < 0.085:
			c = Color(1, 0, 0) if d < 0.075 else Color(0, 1, 0)  # the pallu, its zari edge
		elif p.y < waist + 0.03 and p.z > 0.0:
			c = Color(1, 0, 0)  # the drape tucked at the waist
		colors[i] = c
	out[Mesh.ARRAY_VERTEX] = sv
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_TANGENT] = null
	return out


## The sari's skirt: a flared, softly pleated drape from the waist to the
## ankles. Each ring is skinned to the pelvis at the top and blends toward the
## thigh and calf on its own side lower down, so the drape follows a walk.
static func skirt(waist_y: float, ankle_y: float, hip: Vector2, hem_r: float, binds: Dictionary) -> Array:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var index := PackedInt32Array()
	for r in SKIRT_RINGS + 1:
		var t := float(r) / SKIRT_RINGS
		var y := lerpf(waist_y, ankle_y, t)
		var flare := t * t * 0.6 + t * 0.4
		for s in SKIRT_SEGMENTS + 1:
			var a := TAU * s / SKIRT_SEGMENTS
			# Pleats fall at the front (the nivi drape gathers there).
			var front := maxf(cos(a), 0.0)
			var pleat := sin(a * 18.0) * 0.008 * front * (0.3 + t)
			var rx := lerpf(hip.x, hem_r, flare) + pleat
			var rz := lerpf(hip.y, hem_r * 0.85, flare) + pleat
			var p := Vector3(sin(a) * rx, y, cos(a) * rz)
			verts.append(p)
			normals.append(Vector3(sin(a), 0.15, cos(a)).normalized())
			uvs.append(Vector2(float(s) / SKIRT_SEGMENTS, t))
			var hem := t > 0.93 or (r == 0)
			colors.append(Color(0, 1, 0) if hem else Color(1, 0, 0))
			# Skinning: pelvis at the waist; lower, the leg on this side.
			var side := "l" if p.x >= 0.0 else "r"
			var leg_w := clampf((t - 0.2) / 0.8, 0.0, 1.0) * 0.55 * clampf(absf(p.x) / maxf(rx, 0.001) * 1.4, 0.0, 1.0)
			var thigh_w := leg_w * (1.0 - t) * 1.6
			var calf_w := leg_w - minf(thigh_w, leg_w)
			thigh_w = minf(thigh_w, leg_w)
			var pelvis_w := 1.0 - thigh_w - calf_w
			bones.append_array([binds["pelvis"], binds["thigh_" + side], binds["calf_" + side], binds["pelvis"]])
			weights.append_array([pelvis_w, thigh_w, calf_w, 0.0])
	var row := SKIRT_SEGMENTS + 1
	for r in SKIRT_RINGS:
		for s in SKIRT_SEGMENTS:
			var i := r * row + s
			index.append_array([i, i + 1, i + row, i + 1, i + row + 1, i + row])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = index
	return arrays


## Hair that follows the head exactly: the head mesh's own scalp (above a
## natural hairline: the forehead, over the ears, down to the nape), pushed
## out a little, keeping the head's skinning.
static func scalp(head_arrays: Array, eye_y: float, face_z: float) -> Array:
	var v: PackedVector3Array = head_arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = head_arrays[Mesh.ARRAY_INDEX]
	var hair := func(p: Vector3) -> bool:
		var front := p.z > face_z - 0.035           # the face side
		var side := absf(p.x) > 0.055
		if front and not side:
			return p.y > eye_y + 0.052                # the forehead's hairline
		if p.z > -0.02:
			return p.y > eye_y + 0.012 + (0.02 if p.z > 0.02 else 0.0)  # over the ears
		return p.y > eye_y - 0.075                    # the back, down to the nape
	var tris := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		if hair.call(v[idx[t]]) and hair.call(v[idx[t + 1]]) and hair.call(v[idx[t + 2]]):
			tris.append_array([idx[t], idx[t + 1], idx[t + 2]])
	var FaceRig := load("res://tools/face_rig_builder.gd")
	var out: Array = FaceRig._subset(head_arrays, tris)
	var sv: PackedVector3Array = out[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = out[Mesh.ARRAY_NORMAL]
	for i in sv.size():
		sv[i] += sn[i] * 0.006
	out[Mesh.ARRAY_VERTEX] = sv
	out[Mesh.ARRAY_TANGENT] = null
	out[Mesh.ARRAY_COLOR] = null
	return out


## Long hair with the face clear, and a bun (juda) at the nape: the woman's
## everyday style. `long_src` is the pack's long hair, already fitted.
static func gathered_hair(long_src: ArrayMesh, cap_src: ArrayMesh, head_back: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The scalp itself is built from the head (scalp()); here, the back's
	# strands gathered down to the bun. (cap_src is unused, kept for callers.)
	var a := long_src.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var cut_z := head_back.z + 0.075
	for t in range(0, idx.size(), 3):
		var c := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
		# Keep the crown and the back; drop strands over the face and the long fall.
		# Sides and back behind the face, and the whole crown; nothing over the face.
		if (c.z < 0.015 and c.y > head_back.y - 0.04) or c.y > head_back.y + 0.08:
			for k in 3:
				st.set_normal(n[idx[t + k]])
				st.add_vertex(v[idx[t + k]])
	# The bun: a coil at the nape.
	var bun_c := head_back + Vector3(0, -0.02, -0.035)
	var bun := SphereMesh.new()
	bun.radius = 0.052
	bun.height = 0.085
	bun.radial_segments = 16
	bun.rings = 8
	st.append_from(bun, 0, Transform3D(Basis(), bun_c))
	var coil := TorusMesh.new()
	coil.inner_radius = 0.028
	coil.outer_radius = 0.05
	st.append_from(coil, 0, Transform3D(Basis(Vector3.RIGHT, PI / 2), bun_c + Vector3(0, 0, -0.02)))
	st.generate_normals()
	return st.commit()


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
