extends SceneTree
## Builds Tataka's forest (Bala Kanda, missions 3-4): the lands of Malada and
## Karusha, silent and overgrown, a winding path to a ruined grove.
##
##   xvfb-run godot --rendering-driver opengl3 -s res://tools/build_forest.gd
##   (needs a real renderer: MultiMesh data lives in the RenderingServer)
##
## Output: res://kandas/01_bala/env/tataka_forest.scn
## Layout: Rama starts at the origin facing -Z; the path winds north to the
## grove (Tataka's arena) centred at GROVE, radius GROVE_RADIUS.

const OUT_SCENE := "res://kandas/01_bala/env/tataka_forest.scn"
const M := "res://assets/materials/env/"
const NATURE := "res://assets/env/nature/"
const SEED := 2207
const PATH_POINTS := [Vector3(0, 0, 4), Vector3(-5, 0, -16), Vector3(4, 0, -36), Vector3(-4, 0, -56), Vector3(3, 0, -76), Vector3(0, 0, -98)]
const GROVE := Vector3(0, 0, -122)
const GROVE_RADIUS := 21.0
const CLEAR_HALF_WIDTH := 6.5
const FAR_CELL := 28.0  # metres along z per far-tree cell
const NEAR_CELL := 16.0
const FAR_FOG_RANGE := 85.0
const NEAR_DETAIL_RANGE := 30.0

const MATERIAL_MAP := {
	"Bark_NormalTree": "bark", "Leaves_NormalTree": "leaves_jungle", "Leaves_TwistedTree": "leaves_dark",
	"Bark_TwistedTree": "bark_twisted", "Bark_DeadTree": "bark_dead", "Leaves": "plant", "Flowers": "flowers",
	"Grass": "grass", "Rocks": "rock", "Mushrooms": "mushrooms", "PathRocks": "pathrocks",
}
const ARCH_MASKS := {"sandstone": Color(0, 0, 0), "red_sandstone": Color(1, 0, 0), "marble": Color(0, 1, 0), "dark_stone": Color(0, 0, 1)}

var rng := RandomNumberGenerator.new()
var env_root: Node3D
var body: StaticBody3D
var mats := {}
var path_poly := PackedVector3Array()
var _groups := {}


func _initialize() -> void:
	rng.seed = SEED
	env_root = Node3D.new()
	env_root.name = "TatakaForest"
	body = StaticBody3D.new()
	body.name = "Collision"
	env_root.add_child(body)
	_bake_path()
	_ground()
	_ruins()
	_bones()
	_flush()
	_trees()
	_undergrowth()
	_atmosphere()
	_bloom_flowers()
	_grove_gate()
	_markers()
	_own(env_root, env_root)
	var packed := PackedScene.new()
	var err := packed.pack(env_root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_SCENE, ResourceSaver.FLAG_COMPRESS)
	print("Saved %s: %s" % [OUT_SCENE, error_string(err)])
	quit(0 if err == OK else 1)


# --- Helpers -----------------------------------------------------------------------

func mat(name: String) -> Material:
	if not mats.has(name):
		mats[name] = load(M + name + ".tres")
	return mats[name]


func at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


func put(mesh: Mesh, xf: Transform3D, material: String) -> void:
	if ARCH_MASKS.has(material):
		mesh = _masked(mesh, ARCH_MASKS[material])
		material = "arch"
	if not _groups.has(material):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_groups[material] = st
	for s in mesh.get_surface_count():
		(_groups[material] as SurfaceTool).append_from(mesh, s, xf)


func _masked(mesh: Mesh, mask: Color) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var colors := PackedColorArray()
		colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		colors.fill(mask)
		arrays[Mesh.ARRAY_COLOR] = colors
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


func _flush() -> void:
	for material: String in _groups:
		var mi := MeshInstance3D.new()
		mi.name = "Static_" + material
		mi.mesh = (_groups[material] as SurfaceTool).commit()
		mi.material_override = mat(material)
		env_root.add_child(mi)
	_groups.clear()


func collider_box(size: Vector3, xf: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)


func collider_cyl(pos: Vector3, radius: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	cs.position = pos + Vector3.UP * height * 0.5
	body.add_child(cs)


func multimesh(name: String, mesh: Mesh, xforms: Array, shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env_root.add_child(mmi)
	return mmi


func nature_mesh(file: String) -> Mesh:
	var inst := (load(NATURE + file + ".gltf") as PackedScene).instantiate()
	var mi := inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var src_mesh := mi.mesh as ArrayMesh
	var im := ImporterMesh.new()
	for s in src_mesh.get_surface_count():
		var src := src_mesh.surface_get_material(s)
		var key: String = MATERIAL_MAP.get(src.resource_name if src else "", "plant")
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, src_mesh.surface_get_arrays(s), [], {}, mat(key))
	im.generate_lods(25.0, 60.0, [])
	inst.free()
	return im.get_mesh()


## Detailed trees that don't cast shadows themselves; a shadow-only copy using
## the light proxy mesh casts them instead (shadow passes are half the cost).
func shadowed_by_proxy(name: String, mesh: Mesh, proxy: Mesh, xforms: Array) -> void:
	var cells := _cells(xforms, 24.0)
	for key: String in cells:
		var group: Array = cells[key]
		var detail := multimesh("%s_%s" % [name, key], mesh, group, false)
		detail.visibility_range_end = FAR_FOG_RANGE
		var sh := multimesh("%s_%s_Shadow" % [name, key], proxy, group, true)
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		sh.visibility_range_end = FAR_FOG_RANGE


func _cells(xforms: Array, size: float) -> Dictionary:
	var cells := {}
	for t in xforms:
		var o := (t as Transform3D).origin
		var key := "%d_%d" % [int(floor(o.x / size)), int(floor(o.z / size))]
		if not cells.has(key):
			cells[key] = []
		cells[key].append(t)
	return cells


## Trees in small cells: full detail up close, the proxy mesh further away.
func tree_cells(name: String, mesh: Mesh, proxy: Mesh, xforms: Array) -> void:
	var cells := _cells(xforms, NEAR_CELL)
	for key: String in cells:
		var detail := multimesh("%s_%s" % [name, key], mesh, cells[key], false)
		detail.visibility_range_end = NEAR_DETAIL_RANGE
		var far := multimesh("%s_%s_Far" % [name, key], proxy, cells[key], false)
		far.visibility_range_begin = NEAR_DETAIL_RANGE
		var sh := multimesh("%s_%s_Shadow" % [name, key], proxy, cells[key], true)
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## A cheap stand-in for distant trees: the bark's coarsest LOD plus about a
## third of the leaf cards, each enlarged so the canopy keeps its coverage.
func far_mesh(file: String) -> Mesh:
	var inst := (load(NATURE + file + ".gltf") as PackedScene).instantiate()
	var src_mesh := (inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh as ArrayMesh
	var out := ArrayMesh.new()
	for s in src_mesh.get_surface_count():
		var src := src_mesh.surface_get_material(s)
		var key: String = MATERIAL_MAP.get(src.resource_name if src else "", "plant")
		var arrays := src_mesh.surface_get_arrays(s)
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
		im.generate_lods(60.0, 60.0, [])
		if im.get_surface_lod_count(0) > 0:
			arrays[Mesh.ARRAY_INDEX] = im.get_surface_lod_indices(0, im.get_surface_lod_count(0) - 1)
		else:
			arrays = _thin_cards(arrays, 3, 1.45)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, mat(key))
	inst.free()
	return out


## Keeps one in `keep_every` connected leaf cards, scaled by `grow` about its centre.
func _thin_cards(arrays: Array, keep_every: int, grow: float) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var parent: Array[int] = []
	parent.resize(verts.size())
	for i in verts.size():
		parent[i] = i
	for t in range(0, idx.size(), 3):
		var r0: int = _find(parent, idx[t])
		for k in [1, 2]:
			var rk: int = _find(parent, idx[t + k])
			if rk != r0:
				parent[rk] = r0
	var comp_of := {}
	var keep := PackedInt32Array()
	var sums := {}
	for t in range(0, idx.size(), 3):
		var root: int = _find(parent, idx[t])
		if not comp_of.has(root):
			comp_of[root] = comp_of.size()
		if comp_of[root] % keep_every == 0:
			keep.append_array([idx[t], idx[t + 1], idx[t + 2]])
	# Grow each kept card about its centroid.
	var counts := {}
	for v in keep:
		var root: int = _find(parent, v)
		sums[root] = sums.get(root, Vector3.ZERO) + verts[v]
		counts[root] = counts.get(root, 0) + 1
	var moved := {}
	for v in keep:
		if moved.has(v):
			continue
		moved[v] = true
		var root: int = _find(parent, v)
		var c: Vector3 = sums[root] / float(counts[root])
		verts[v] = c + (verts[v] - c) * grow
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = keep
	return arrays


func _find(parent: Array[int], v: int) -> int:
	while parent[v] != v:
		parent[v] = parent[parent[v]]
		v = parent[v]
	return v


func rand_xf(pos: Vector3, scale_range: Vector2, tilt := 0.0) -> Transform3D:
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	if tilt > 0.0:
		b = Basis(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized(), rng.randf() * tilt) * b
	return Transform3D(b.scaled(Vector3.ONE * rng.randf_range(scale_range.x, scale_range.y)), pos)


func _own(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_own(c, owner_node)


# --- Path ----------------------------------------------------------------------------

func _bake_path() -> void:
	var curve := Curve3D.new()
	for i in PATH_POINTS.size():
		var p: Vector3 = PATH_POINTS[i]
		var prev: Vector3 = PATH_POINTS[maxi(i - 1, 0)]
		var next: Vector3 = PATH_POINTS[mini(i + 1, PATH_POINTS.size() - 1)]
		var tangent := (next - prev) * 0.25
		curve.add_point(p, -tangent, tangent)
	curve.bake_interval = 1.0
	path_poly = curve.get_baked_points()
	path_poly.append(GROVE)


func dist_to_path(p: Vector3) -> float:
	var best := INF
	for i in path_poly.size() - 1:
		var a := Vector2(path_poly[i].x, path_poly[i].z)
		var b := Vector2(path_poly[i + 1].x, path_poly[i + 1].z)
		var q := Vector2(p.x, p.z)
		var ab := b - a
		var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, q.distance_to(a + ab * t))
	return best


func _ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(220, 240)
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "ForestFloor"
	floor_mi.mesh = plane
	floor_mi.position = Vector3(0, 0, -70)
	floor_mi.material_override = mat("forest_floor")
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env_root.add_child(floor_mi)
	collider_box(Vector3(220, 1, 240), at(0, -0.5, -70))
	# Dirt path ribbon (soft edges), slightly above the floor.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := 2.4
	for i in path_poly.size() - 1:
		var a := path_poly[i]
		var b := path_poly[i + 1]
		var d := (b - a)
		d.y = 0.0
		if d.length() < 0.01:
			continue
		var side := d.normalized().cross(Vector3.UP) * half
		var y := Vector3.UP * 0.03
		var quad := [[a - side + y, 0.0], [a + side + y, 1.0], [b + side + y, 1.0], [b - side + y, 0.0]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(quad[idx][1], 0.0))
			st.add_vertex(quad[idx][0])
	var path_mi := MeshInstance3D.new()
	path_mi.name = "ForestPath"
	path_mi.mesh = st.commit()
	path_mi.material_override = mat("forest_path")
	path_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env_root.add_child(path_mi)
	# Bare earth disc in the grove.
	var disc := CylinderMesh.new()
	disc.top_radius = GROVE_RADIUS
	disc.bottom_radius = GROVE_RADIUS
	disc.height = 0.02
	disc.radial_segments = 32
	var grove_mi := MeshInstance3D.new()
	grove_mi.name = "GroveEarth"
	grove_mi.mesh = disc
	grove_mi.position = GROVE + Vector3.UP * 0.025
	grove_mi.material_override = mat("forest_path")
	grove_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env_root.add_child(grove_mi)
	# Boundary.
	collider_box(Vector3(1, 12, 240), at(-50, 6, -70))
	collider_box(Vector3(1, 12, 240), at(50, 6, -70))
	collider_box(Vector3(110, 12, 1), at(0, 6, 22))
	collider_box(Vector3(110, 12, 1), at(0, 6, -160))


# --- Ruins and bones -------------------------------------------------------------------

func _ruin(c: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	put(MeshKit.box(Vector3(6.0, 0.5, 4.0)), Transform3D(b, c + Vector3(0, 0.25, 0)), "dark_stone")
	var heights := [3.6, 1.4, 2.6, 0.8]
	var corners := [Vector3(-2.4, 0, -1.4), Vector3(2.4, 0, -1.4), Vector3(-2.4, 0, 1.4), Vector3(2.4, 0, 1.4)]
	for i in 4:
		var p: Vector3 = c + b * corners[i]
		var h: float = heights[i]
		put(MeshKit.cyl(0.22, 0.26, h, 8), at(p.x, 0.5 + h * 0.5, p.z), "sandstone")
		put(MeshKit.box(Vector3(0.6, 0.3, 0.6)), at(p.x, 0.65, p.z), "red_sandstone")
		collider_cyl(p, 0.35, h + 0.5)
	put(MeshKit.box(Vector3(3.2, 0.35, 0.5)), Transform3D(b, c + b * Vector3(-0.6, 3.95, -1.4)), "red_sandstone")
	var fallen := c + b * Vector3(1.5, 0, 2.8)
	put(MeshKit.cyl(0.24, 0.24, 3.2, 8), Transform3D(Basis(Vector3.BACK, PI / 2) * Basis(Vector3.UP, yaw + 0.4), fallen + Vector3.UP * 0.24), "sandstone")
	collider_box(Vector3(6.0, 0.5, 4.0), Transform3D(b, c + Vector3(0, 0.25, 0)))


func _ruins() -> void:
	_ruin(Vector3(-11, 0, -30), 0.3)
	_ruin(Vector3(10, 0, -70), -0.5)
	# Broken shrine at the far side of the grove.
	_ruin(GROVE + Vector3(0, 0, -GROVE_RADIUS + 3.0), 0.0)


func _bones() -> void:
	var bone := "marble"
	for i in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(GROVE_RADIUS * 0.4, GROVE_RADIUS - 2.0) if i < 9 else 0.0
		var p := GROVE + Vector3(cos(a) * r, 0, sin(a) * r) if i < 9 else path_poly[rng.randi_range(40, path_poly.size() - 2)] + Vector3(rng.randf_range(-3.5, 3.5), 0, 0)
		put(MeshKit.sphere(0.13, 8), at(p.x, 0.1, p.z), bone)
		put(MeshKit.box(Vector3(0.12, 0.06, 0.1)), at(p.x, 0.05, p.z + 0.12), bone)
		for k in 3:
			put(MeshKit.cyl(0.025, 0.025, 0.6, 5), Transform3D(Basis(Vector3.BACK, PI / 2).rotated(Vector3.UP, a + k * 0.3), p + Vector3(0.4, 0.04, 0.2 * k)), bone)


# --- Trees and undergrowth ---------------------------------------------------------------

func _trees() -> void:
	var jungle := nature_mesh("CommonTree_5")
	var jungle_b := nature_mesh("CommonTree_3")
	var twisted := nature_mesh("TwistedTree_1")
	var twisted_b := nature_mesh("TwistedTree_3")
	var dead := nature_mesh("DeadTree_1")
	var dead_b := nature_mesh("DeadTree_3")
	var near := {"a": [], "b": []}
	var far := {"a": [], "b": []}
	var hero := {"a": [], "b": []}
	var x := -46.0
	while x <= 46.0:
		var z := 18.0
		while z >= -156.0:
			var p := Vector3(x + rng.randf_range(-2.5, 2.5), 0, z + rng.randf_range(-2.5, 2.5))
			var dp := dist_to_path(p)
			var dg := Vector2(p.x - GROVE.x, p.z - GROVE.z).length()
			if dp > CLEAR_HALF_WIDTH and dg > GROVE_RADIUS + 5.0:
				var key := "a" if rng.randf() < 0.5 else "b"
				if dp < 11.0 and rng.randf() < 0.3:
					hero[key].append(rand_xf(p, Vector2(1.1, 1.5)))
				elif dp < 18.0:
					near[key].append(rand_xf(p, Vector2(1.5, 2.1)))
				else:
					far[key].append(rand_xf(p, Vector2(1.7, 2.3)))
				if dp < 18.0:
					collider_cyl(p, 0.6, 6.0)
			z -= 7.0
		x += 7.0
	var far_meshes := {"a": far_mesh("CommonTree_5"), "b": far_mesh("CommonTree_3")}
	shadowed_by_proxy("Trees_Hero_A", twisted, far_mesh("TwistedTree_1"), hero["a"])
	shadowed_by_proxy("Trees_Hero_B", twisted_b, far_mesh("TwistedTree_3"), hero["b"])
	tree_cells("Trees_Near_A", jungle, far_meshes["a"], near["a"])
	tree_cells("Trees_Near_B", jungle_b, far_meshes["b"], near["b"])
	# Far trees: the proxy mesh, in cells so culling works per cell.
	for side in ["a", "b"]:
		var cells := {}
		for t in far[side]:
			var o := (t as Transform3D).origin
			var key := "%s_%d" % ["W" if o.x < 0.0 else "E", int(floor(o.z / FAR_CELL))]
			if not cells.has(key):
				cells[key] = []
			cells[key].append(t)
		for key: String in cells:
			var cell := multimesh("Trees_Far_%s_%s" % [side, key], far_meshes[side], cells[key], false)
			cell.visibility_range_end = FAR_FOG_RANGE  # beyond this the fog has them
	# Dead trees ring the grove, leaving the path entrance open.
	var ring := {"a": [], "b": []}
	for i in 18:
		var a := TAU * i / 18.0 + rng.randf_range(-0.08, 0.08)
		var dir := Vector3(sin(a), 0, cos(a))
		if dir.z > 0.85:
			continue  # entrance from the path (south side)
		var p := GROVE + dir * (GROVE_RADIUS + rng.randf_range(1.5, 3.5))
		ring["a" if i % 2 == 0 else "b"].append(rand_xf(p, Vector2(1.3, 1.7), 0.15))
		collider_cyl(p, 0.8, 7.0)
	shadowed_by_proxy("Trees_Dead_A", dead, far_mesh("DeadTree_1"), ring["a"])
	shadowed_by_proxy("Trees_Dead_B", dead_b, far_mesh("DeadTree_3"), ring["b"])
	# The grove's edge is solid (except the entrance), so the fight stays inside.
	for i in 36:
		var a := TAU * i / 36.0
		var dir := Vector3(sin(a), 0, cos(a))
		if dir.z > 0.9:
			continue
		collider_box(Vector3(4.0, 6.0, 0.6), Transform3D(Basis(Vector3.UP, a), GROVE + dir * (GROVE_RADIUS + 1.0) + Vector3.UP * 3.0))


func _undergrowth() -> void:
	var ferns := []
	var mushrooms := []
	var rocks := []
	var pebbles := []
	for i in path_poly.size():
		if i % 3 != 0:
			continue
		var p := path_poly[i]
		for side in [-1.0, 1.0]:
			var off := Vector3(side * rng.randf_range(3.2, 6.0), 0, rng.randf_range(-1.5, 1.5))
			ferns.append(rand_xf(p + off, Vector2(0.9, 1.5)))
			if rng.randf() < 0.25:
				mushrooms.append(rand_xf(p + off * 1.2, Vector2(0.8, 1.3)))
			if rng.randf() < 0.18:
				rocks.append(rand_xf(p + off * 1.4, Vector2(0.8, 1.6), 0.4))
		if rng.randf() < 0.5:
			pebbles.append(rand_xf(p + Vector3(rng.randf_range(-1.8, 1.8), 0, 0), Vector2(0.8, 1.4)))
	multimesh("Ferns", nature_mesh("Fern_1"), ferns, false).visibility_range_end = 60.0
	multimesh("Mushrooms", nature_mesh("Mushroom_Common"), mushrooms, false).visibility_range_end = 40.0
	multimesh("Rocks", nature_mesh("Rock_Medium_2"), rocks)
	multimesh("Pebbles", nature_mesh("Pebble_Round_2"), pebbles, false).visibility_range_end = 40.0


# --- Atmosphere ------------------------------------------------------------------------------

func _atmosphere() -> void:
	var mist_points := [Vector3(-3, 0, -12), Vector3(2, 0, -42), Vector3(-2, 0, -66), Vector3(1, 0, -90), GROVE]
	for i in mist_points.size():
		var p := CPUParticles3D.new()
		p.name = "Mist%d" % i
		p.amount = 14
		p.lifetime = 12.0
		p.preprocess = 12.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(12, 0.6, 12)
		p.direction = Vector3(1, 0, 0.3)
		p.spread = 60.0
		p.gravity = Vector3.ZERO
		p.initial_velocity_min = 0.15
		p.initial_velocity_max = 0.4
		var q := QuadMesh.new()
		q.size = Vector2(7, 3.5)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(0.78, 0.82, 0.76, 0.18)
		m.albedo_texture = FX._soft_dot()
		q.material = m
		p.mesh = q
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0))
		curve.add_point(Vector2(0.3, 1))
		curve.add_point(Vector2(0.7, 1))
		curve.add_point(Vector2(1, 0))
		p.scale_amount_curve = curve
		p.position = mist_points[i] + Vector3.UP * 0.8
		env_root.add_child(p)
	# Spores drifting in the shafts of light.
	var spores := CPUParticles3D.new()
	spores.name = "Spores"
	spores.amount = 90
	spores.lifetime = 8.0
	spores.preprocess = 8.0
	spores.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	spores.emission_box_extents = Vector3(14, 4, 60)
	spores.gravity = Vector3(0, 0.05, 0)
	spores.initial_velocity_min = 0.05
	spores.initial_velocity_max = 0.25
	spores.spread = 180.0
	spores.mesh = FX.glow_quad(Color(0.85, 0.9, 0.5, 0.7), 0.06)
	spores.position = Vector3(0, 3, -55)
	env_root.add_child(spores)
	# Light shafts through the canopy.
	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shaft_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shaft_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaft_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shaft_mat.albedo_color = Color(0.9, 0.85, 0.55, 0.07)
	var shafts := []
	for i in 9:
		var p := path_poly[rng.randi_range(5, path_poly.size() - 6)] + Vector3(rng.randf_range(-4, 4), 0, 0)
		shafts.append(Transform3D(Basis(Vector3.BACK, 0.35).rotated(Vector3.UP, 0.5), p + Vector3(1.5, 7.0, 0)))
	var shaft_mesh := QuadMesh.new()
	shaft_mesh.size = Vector2(2.2, 16.0)
	shaft_mesh.material = shaft_mat
	multimesh("LightShafts", shaft_mesh, shafts, false)


# --- Bloom (after Tataka) and gate ---------------------------------------------------------

## Flowers and grass that grow back over the grove after Tataka's defeat.
## Instances start invisible; the level animates them toward "targets".
func _bloom_flowers() -> void:
	for spec in [["Bloom_FlowersA", "Flower_3_Group", 110, Vector2(0.7, 1.1)], ["Bloom_FlowersB", "Flower_4_Group", 45, Vector2(0.6, 0.9)], ["Bloom_Grass", "Grass_Common_Short", 320, Vector2(0.8, 1.3)]]:
		var targets := []
		for i in int(spec[2]):
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * (GROVE_RADIUS - 1.5)
			targets.append(rand_xf(GROVE + Vector3(cos(a) * r, 0.02, sin(a) * r), spec[3]))
		var hidden := []
		for t in targets:
			hidden.append((t as Transform3D).scaled_local(Vector3.ONE * 0.001))
		var mmi := multimesh(spec[0], nature_mesh(spec[1]), hidden, false)
		mmi.set_meta(&"bloom_targets", targets)
		mmi.visible = false  # nothing to draw until the bloom; the level shows it
		mmi.add_to_group(&"bloom", true)


func _grove_gate() -> void:
	# Closed after Rama enters the grove (the level enables its collision).
	var gate := StaticBody3D.new()
	gate.name = "GroveGate"
	gate.collision_layer = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(16, 6, 1)
	cs.shape = shape
	gate.add_child(cs)
	gate.position = GROVE + Vector3(0, 3, GROVE_RADIUS + 1.5)
	env_root.add_child(gate)


func _markers() -> void:
	for spec in [["GroveEntry", GROVE + Vector3(0, 0, GROVE_RADIUS - 3.0)], ["TatakaSpot", GROVE + Vector3(0, 0, -8.0)], ["GroveCenter", GROVE]]:
		var m := Marker3D.new()
		m.name = spec[0]
		m.position = spec[1]
		env_root.add_child(m)
