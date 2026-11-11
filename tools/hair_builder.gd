extends RefCounted
## Rama's hair, after temple iconography: gathered up into the kireeta, the
## face open, a few dark curling locks behind the ears to the shoulders.
## Built from the UBC pack (a close cap from Hair_SimpleParted; the back of
## Hair_Long, with every strand in front of the face removed) plus procedural
## curled locks. Run from tools/build_rama.gd. Coordinates are the rest pose
## (metres, face toward +Z).

## Hair_Long triangles kept: behind this depth (the ears are at ~z 0), or above
## the brow line on the crown (hidden by the kireeta).
const BACK_Z := -0.015
const CROWN_Y := 1.735
## Curled locks: per side, [root (x magnitude, y, z), length].
const LOCKS := [[Vector3(0.084, 1.668, -0.03), 0.19], [Vector3(0.08, 1.676, -0.058), 0.2], [Vector3(0.07, 1.684, -0.088), 0.18]]
const LOCK_RADIUS := 0.012


## One mesh: cap + trimmed back hair + curls. `long_src`/`cap_src` are the pack
## meshes (in rest-pose model space).
static func build(long_src: ArrayMesh, cap_src: ArrayMesh, material: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_filtered(st, long_src, func(c: Vector3) -> bool: return c.z < BACK_Z or c.y > CROWN_Y)
	_append_filtered(st, cap_src, func(_c: Vector3) -> bool: return true)
	for spec in LOCKS:
		for side in [-1.0, 1.0]:
			var root: Vector3 = spec[0]
			root.x *= side
			_curl(st, root, spec[1], side)
	st.generate_tangents()
	var m := st.commit()
	m.surface_set_material(0, material)
	return m


static func _append_filtered(st: SurfaceTool, src: ArrayMesh, keep: Callable) -> void:
	var a := src.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var uv = a[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	for t in range(0, idx.size(), 3):
		var c := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
		if not keep.call(c):
			continue
		for k in 3:
			var i := idx[t + k]
			st.set_normal(n[i])
			if uv != null:
				st.set_uv((uv as PackedVector2Array)[i])
			st.add_vertex(v[i])


## A tapered lock that falls behind the ear and turns in loose spirals.
static func _curl(st: SurfaceTool, root: Vector3, length: float, side: float) -> void:
	var rings := 18
	var segs := 6
	var turns := 2.2
	var prev: Array = []
	for i in rings + 1:
		var t := float(i) / rings
		# The guide line falls down and a little back and out; the strand
		# spirals around it, widening toward the tip like a natural curl.
		var guide := root + Vector3(side * 0.02 * t, -length * t, -0.015 * t)
		var a := t * turns * TAU
		var swirl := 0.006 + 0.012 * t
		var centre := guide + Vector3(cos(a) * swirl * side, 0, sin(a) * swirl)
		var r := LOCK_RADIUS * (1.0 - 0.65 * t)
		var ring: Array = []
		for j in segs:
			var b := TAU * j / segs
			var off := Vector3(cos(b), 0, sin(b)) * r
			ring.append([centre + off, off.normalized()])
		if not prev.is_empty():
			for j in segs:
				var j2 := (j + 1) % segs
				var quad := [prev[j], ring[j], ring[j2], prev[j2]]
				for k in [0, 1, 2, 0, 2, 3]:
					st.set_normal(quad[k][1])
					st.set_uv(Vector2(float(j) / segs, t))
					st.add_vertex(quad[k][0])
		prev = ring
	# Close the tip.
	var tip_c: Vector3 = (prev[0][0] + prev[segs / 2][0]) * 0.5 + Vector3.DOWN * 0.006
	for j in segs:
		var j2 := (j + 1) % segs
		for p in [prev[j], [tip_c, Vector3.DOWN], prev[j2]]:
			st.set_normal(p[1])
			st.set_uv(Vector2(0.5, 1.0))
			st.add_vertex(p[0])
