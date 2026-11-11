extends RefCounted
## Gives the shared character rig a face that can act (the Quaternius base has
## no facial rig). Run from tools/build_rama.gd.
##
## - Splits the head out of the skinned body: blend shapes only on the small
##   head mesh keep skinning cheap on phones.
## - Mouth blend shapes (the lips already part along a modelled slit):
##   jaw_open, mouth_smile, mouth_frown, mouth_wide, mouth_round, lips_press,
##   cheek_raise; a dark mouth interior sits behind the lips.
## - Brow blend shapes on the Eyebrows mesh: brow_raise, brow_furrow, brow_sad.
## - Eyes split into EyeL/EyeR on the head (they turn to look), each with an
##   UpperLid shell that rotates down to blink.
## Names follow the ARKit idea so a commissioned model can replace this.
##
## Coordinates are the rig's rest pose: metres, face toward +Z, X to the left.

const LIP_Y := 1.6229
const MOUTH_CORNER_X := 0.0259
const MOUTH_FRONT_Z := 0.0912
const JAW_PIVOT := Vector3(0.0, 1.645, -0.005)
const JAW_MAX_DEG := 10.0
const EYE_RADIUS := 0.0150
const LID_OPEN_DEG := -58.0
const FACE_SHAPES := ["jaw_open", "mouth_smile", "mouth_frown", "mouth_wide", "mouth_round", "lips_press", "cheek_raise"]
const BROW_SHAPES := ["brow_raise", "brow_furrow", "brow_sad"]


## Splits `body` (a painted, skinned ArrayMesh) into [body_arrays, head_arrays]
## by head-bone weight. `head_binds` are the skin bind indices that count as head.
static func split_head(arrays: Array, head_binds: Array) -> Array:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var per := bones.size() / v.size()
	var head_w := PackedFloat32Array()
	head_w.resize(v.size())
	for i in v.size():
		var w := 0.0
		for k in per:
			if bones[i * per + k] in head_binds:
				w += weights[i * per + k]
		head_w[i] = w
	var body_tris := PackedInt32Array()
	var head_tris := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var is_head := head_w[idx[t]] >= 0.5 and head_w[idx[t + 1]] >= 0.5 and head_w[idx[t + 2]] >= 0.5
		(head_tris if is_head else body_tris).append_array([idx[t], idx[t + 1], idx[t + 2]])
	return [_subset(arrays, body_tris), _subset(arrays, head_tris)]


static func _subset(arrays: Array, tris: PackedInt32Array) -> Array:
	var remap := {}
	var order := PackedInt32Array()
	for i in tris:
		if not remap.has(i):
			remap[i] = order.size()
			order.append(i)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for a in Mesh.ARRAY_MAX:
		var src = arrays[a]
		if src == null or a == Mesh.ARRAY_INDEX or a >= Mesh.ARRAY_CUSTOM0 and a <= Mesh.ARRAY_CUSTOM3:
			continue
		var stride := 1
		var n: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if a == Mesh.ARRAY_TANGENT or a == Mesh.ARRAY_BONES or a == Mesh.ARRAY_WEIGHTS:
			stride = src.size() / n
		var dst = src.duplicate()
		dst.resize(order.size() * stride)
		for j in order.size():
			for s in stride:
				dst[j * stride + s] = src[order[j] * stride + s]
		out[a] = dst
	var new_idx := PackedInt32Array()
	new_idx.resize(tris.size())
	for j in tris.size():
		new_idx[j] = remap[tris[j]]
	out[Mesh.ARRAY_INDEX] = new_idx
	return out


## The head mesh with its expression blend shapes (normalized: absolute targets).
static func head_mesh(arrays: Array, material: Material) -> ArrayMesh:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var lower := _lower_lip_side(arrays)
	var shapes := []
	for shape_name in FACE_SHAPES:
		var moved := PackedVector3Array()
		moved.resize(v.size())
		for i in v.size():
			moved[i] = v[i] + _face_delta(shape_name, v[i], lower[i])
		shapes.append(_shape_arrays(arrays, moved))
	return _build(arrays, shapes, FACE_SHAPES, material)


static func brow_mesh(arrays: Array, material: Material) -> ArrayMesh:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var shapes := []
	for shape_name in BROW_SHAPES:
		var moved := PackedVector3Array()
		moved.resize(v.size())
		for i in v.size():
			moved[i] = v[i] + _brow_delta(shape_name, v[i])
		shapes.append(_shape_arrays(arrays, moved))
	return _build(arrays, shapes, BROW_SHAPES, material)


static func _build(arrays: Array, shapes: Array, names: Array, material: Material) -> ArrayMesh:
	for a in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		arrays[a] = null
	var m := ArrayMesh.new()
	m.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	for n in names:
		m.add_blend_shape(n)
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes)
	m.surface_set_material(0, material)
	return m


static func _shape_arrays(arrays: Array, moved: PackedVector3Array) -> Array:
	var s := []
	s.resize(Mesh.ARRAY_MAX)
	s[Mesh.ARRAY_VERTEX] = moved
	s[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
	if arrays[Mesh.ARRAY_TANGENT] != null:
		s[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
	return s


## For vertices near the lip line, which lip they belong to: the side their
## neighbouring triangles lie on (the slit makes the line itself ambiguous).
static func _lower_lip_side(arrays: Array) -> PackedByteArray:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var sum := PackedFloat32Array()
	var cnt := PackedInt32Array()
	sum.resize(v.size())
	cnt.resize(v.size())
	for t in range(0, idx.size(), 3):
		var cy := (v[idx[t]].y + v[idx[t + 1]].y + v[idx[t + 2]].y) / 3.0
		for k in 3:
			sum[idx[t + k]] += cy
			cnt[idx[t + k]] += 1
	var out := PackedByteArray()
	out.resize(v.size())
	for i in v.size():
		var avg := sum[i] / maxf(cnt[i], 1)
		out[i] = 1 if (v[i].y < LIP_Y - 0.0012 or (absf(v[i].y - LIP_Y) <= 0.0012 and avg < v[i].y)) else 0
	return out


static func _smooth(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _gauss(p: Vector3, c: Vector3, sigma: float) -> float:
	return exp(-p.distance_squared_to(c) / (2.0 * sigma * sigma))


static func _face_delta(shape: String, p: Vector3, lower: int) -> Vector3:
	if p.z < 0.02:
		return Vector3.ZERO  # only the face, never the back of the head
	var side := signf(p.x) if absf(p.x) > 0.0001 else 1.0
	var corner := Vector3(side * MOUTH_CORNER_X, LIP_Y, 0.0776)
	var near_lips := _gauss(p, Vector3(0, LIP_Y, MOUTH_FRONT_Z - 0.006), 0.016)
	var at_corner := _gauss(p, corner, 0.011)
	match shape:
		"jaw_open":
			if lower == 0:
				return Vector3.ZERO
			var w := (1.0 - _smooth(0.035, 0.062, absf(p.x))) * _smooth(1.572, 1.592, p.y)
			var rel := p - JAW_PIVOT
			var a := deg_to_rad(JAW_MAX_DEG) * w
			var rotated := Vector3(rel.x, rel.y * cos(a) - rel.z * sin(a), rel.y * sin(a) + rel.z * cos(a))
			return rotated - rel
		"mouth_smile":
			return Vector3(side * 0.0028, 0.0042, -0.0018) * at_corner + Vector3(0, 0.0012, 0) * _gauss(p, Vector3(side * 0.035, 1.645, 0.075), 0.012)
		"mouth_frown":
			return Vector3(side * 0.0008, -0.0038, 0.0) * at_corner
		"mouth_wide":
			return Vector3(side * 0.0055, 0.0004, -0.0012) * at_corner
		"mouth_round":
			return Vector3(-side * 0.0065, 0.0, 0.0012) * at_corner + Vector3(0, 0, 0.0028) * near_lips
		"lips_press":
			# Lips roll in and thin; the corners stay put so the slit never tears.
			var mid := 1.0 - _smooth(0.008, 0.022, absf(p.x))
			var dir := 1.0 if lower == 1 else -1.0
			return Vector3(0, dir * 0.0006, -0.0010) * near_lips * mid
		"cheek_raise":
			return Vector3(0, 0.0028, 0.0010) * _gauss(p, Vector3(side * 0.036, 1.650, 0.074), 0.011)
	return Vector3.ZERO


static func _brow_delta(shape: String, p: Vector3) -> Vector3:
	var inner := 1.0 - _smooth(0.012, 0.045, absf(p.x))
	var outer := _smooth(0.035, 0.06, absf(p.x))
	var side := signf(p.x) if absf(p.x) > 0.0001 else 1.0
	match shape:
		"brow_raise":
			return Vector3(0, 0.0045 + 0.0015 * inner, 0.0006)
		"brow_furrow":
			return Vector3(-side * 0.0018, -0.0032, 0.0008) * inner
		"brow_sad":
			return Vector3(0, 0.0042 * inner - 0.0018 * outer, 0)
	return Vector3.ZERO


## Splits the two eyeballs into left/right meshes centred on their own pivot
## (unskinned; they ride the head attachment). Returns [[center, mesh], ...].
static func split_eyes(arrays: Array, material: Material) -> Array:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var out := []
	for side in [1.0, -1.0]:
		var tris := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			if signf(v[idx[t]].x) == side:
				tris.append_array([idx[t], idx[t + 1], idx[t + 2]])
		var sub := _subset(arrays, tris)
		var sv: PackedVector3Array = sub[Mesh.ARRAY_VERTEX]
		var mn := Vector3(INF, INF, INF)
		var mx := -mn
		for p in sv:
			mn = mn.min(p)
			mx = mx.max(p)
		var c := (mn + mx) * 0.5
		for i in sv.size():
			sv[i] -= c
		sub[Mesh.ARRAY_VERTEX] = sv
		sub[Mesh.ARRAY_BONES] = null
		sub[Mesh.ARRAY_WEIGHTS] = null
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sub)
		m.surface_set_material(0, material)
		out.append([c, m])
	return out


## A skin-coloured shell over the top and front of an eyeball; rotating it about
## the eye centre (X axis) closes the eye. Painted with the skin region (black).
static func lid_mesh(material: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := EYE_RADIUS + 0.0013
	var rings := 10
	var segs := 14
	var theta_max := deg_to_rad(132.0)
	var phi_max := deg_to_rad(105.0)
	var pts := []
	for i in rings + 1:
		var row := []
		var th := theta_max * float(i) / rings
		for j in segs + 1:
			var ph := -phi_max + 2.0 * phi_max * float(j) / segs
			row.append(Vector3(sin(th) * sin(ph), cos(th), sin(th) * cos(ph)) * r)
		pts.append(row)
	for i in rings:
		for j in segs:
			var quad := [pts[i][j], pts[i + 1][j], pts[i + 1][j + 1], pts[i][j + 1]]
			for k in [0, 2, 1, 0, 3, 2]:
				var p: Vector3 = quad[k]
				st.set_color(Color(0, 0, 0))
				st.set_normal(p.normalized())
				st.set_uv(Vector2(float(j) / segs, float(i) / rings))
				st.add_vertex(p)
	st.generate_tangents()
	var m := st.commit()
	m.surface_set_material(0, material)
	return m


## A dark hollow behind the lips, seen when the mouth opens.
static func mouth_interior() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "MouthInterior"
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 16
	s.rings = 8
	mi.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.11, 0.035, 0.035)
	mat.roughness = 1.0
	mi.material_override = mat
	mi.scale = Vector3(0.021, 0.016, 0.012)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
