extends SceneTree
## Builds the road along the Sarayu (Bala Kanda, mission 2): the brothers leave
## Ayodhya behind Vishvamitra and walk the river's bank to a sandbank camp,
## where at dusk he teaches them Bala and Atibala.
##
##   xvfb-run godot --rendering-driver opengl3 -s res://tools/build_sarayu.gd
##   (needs a real renderer: MultiMesh data lives in the RenderingServer)
##
## Output: res://kandas/01_bala/env/sarayu_road.scn
## Layout: Rama starts at the origin facing -Z (north). The road runs north for
## ~340 m; the river flows beside it to the east (+X), RIVER_OFFSET from the
## road's centre line. Ayodhya's walls stand behind (south). Three acts:
##   z 0..-100     fields, mango groves and the ghat with its shrine and boats
##   z -100..-250  reeds, sandbanks, a meadow where a herd grazes
##   z -250..-340  the sandbank camp

const OUT_SCENE := "res://kandas/01_bala/env/sarayu_road.scn"
const M := "res://assets/materials/env/"
const NATURE := "res://assets/env/nature/"
const SEED := 1911
const PATH_POINTS := [Vector3(0, 0, 6), Vector3(-3, 0, -40), Vector3(3, 0, -90), Vector3(-2, 0, -140),
	Vector3(5, 0, -190), Vector3(0, 0, -240), Vector3(4, 0, -290), Vector3(6, 0, -322)]
const RIVER_OFFSET := 36.0   # river centre, east of the road's centre line
const RIVER_HALF := 22.0     # half the width of the water
const BANK := 6.0            # width of the sloping bank
const WATER_Y := -0.35
const BED_Y := -1.4
const Z_START := 16.0
const Z_END := -352.0
const X_WEST := -64.0
const X_EAST := 120.0
const GHAT_Z := -42.0
const CAMP := Vector3(15, 0, -326)
const FAR_RANGE := 160.0

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
	env_root.name = "SarayuRoad"
	body = StaticBody3D.new()
	body.name = "Collision"
	env_root.add_child(body)
	_bake_path()
	_terrain()
	_road()
	_river()
	_ghat()
	_boats()
	_camp()
	_city()
	_fields()
	_flush()
	_trees()
	_reeds_and_rocks()
	_atmosphere()
	_bounds()
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


## Instances split into cells along z so each cell culls on its own.
func multimesh_cells(name: String, mesh: Mesh, xforms: Array, cell: float, shadows: bool, range_end: float) -> void:
	var cells := {}
	for t in xforms:
		var o := (t as Transform3D).origin
		var key := "%d_%d" % [int(floor(o.x / 60.0)), int(floor(o.z / cell))]
		if not cells.has(key):
			cells[key] = []
		cells[key].append(t)
	for key: String in cells:
		var mmi := multimesh("%s_%s" % [name, key], mesh, cells[key], shadows)
		mmi.visibility_range_end = range_end


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


## The coarsest LOD of a tree: a cheap stand-in for distance and shadows.
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
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, mat(key))
	inst.free()
	return out


func rand_xf(pos: Vector3, scale_range: Vector2, tilt := 0.0) -> Transform3D:
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	if tilt > 0.0:
		b = Basis(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized(), rng.randf() * tilt) * b
	return Transform3D(b.scaled(Vector3.ONE * rng.randf_range(scale_range.x, scale_range.y)), pos)


func _own(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_own(c, owner_node)


# --- Geography -------------------------------------------------------------------------

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


## The road's centre x at `z` (clamped to the road's ends).
func road_x(z: float) -> float:
	if z >= path_poly[0].z:
		return path_poly[0].x
	for i in path_poly.size() - 1:
		var a := path_poly[i]
		var b := path_poly[i + 1]
		if z <= a.z and z >= b.z:
			return lerpf(a.x, b.x, (a.z - z) / maxf(a.z - b.z, 0.0001))
	return path_poly[path_poly.size() - 1].x


## The river's centre x at `z`: it follows the road, swinging a little wider
## where the meadow opens.
func river_x(z: float) -> float:
	return road_x(z) + RIVER_OFFSET + sin(z * 0.012) * 4.0


## Distance across from the river's centre line (unsigned).
func river_d(x: float, z: float) -> float:
	return absf(x - river_x(z))


## Ground height: flat land, a bank sloping into the river bed.
func height(x: float, z: float) -> float:
	var d := river_d(x, z)
	var edge := RIVER_HALF + BANK
	if d >= edge:
		# Gentle swells away from the road, so the land is not a table top.
		var away := clampf((x - road_x(z) + 14.0) / -40.0, 0.0, 1.0) if x < road_x(z) else 0.0
		var far := clampf((d - edge - 20.0) / 30.0, 0.0, 1.0) if x > river_x(z) else 0.0
		return (sin(x * 0.07) * cos(z * 0.05) * 0.8 + 0.6) * maxf(away, far)
	var t := clampf((edge - d) / BANK, 0.0, 1.0)
	return lerpf(0.0, BED_Y, t * t * (3.0 - 2.0 * t))


## How sandy the ground is (0 meadow .. 1 sand): the banks, sandbanks and the camp.
func sandiness(x: float, z: float) -> float:
	var d := river_d(x, z)
	var s := 1.0 - smoothstep(RIVER_HALF + BANK, RIVER_HALF + BANK + 5.0, d)
	# Sandbanks on the near side through act 2.
	if z < -110.0 and z > -250.0:
		s = maxf(s, 1.0 - smoothstep(RIVER_HALF + BANK + 3.0, RIVER_HALF + BANK + 12.0, d) * (0.6 + 0.4 * sin(z * 0.05)))
	s = maxf(s, 1.0 - smoothstep(12.0, 20.0, Vector2(x - CAMP.x, z - CAMP.z).length()))
	return clampf(s, 0.0, 1.0)


func _terrain() -> void:
	# Chunked grid so far chunks cull; collision from the walkable side only.
	var step := 2.0
	var chunk_z := 92.0
	var z0 := Z_START
	var faces := PackedVector3Array()
	while z0 > Z_END:
		var z1 := maxf(z0 - chunk_z, Z_END)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var nx := int((X_EAST - X_WEST) / step)
		var nz := int(ceil((z0 - z1) / step))
		for iz in nz + 1:
			for ix in nx + 1:
				var x := X_WEST + ix * step
				var z := maxf(z0 - iz * step, z1)
				var h := height(x, z)
				var n := Vector3(height(x - 0.5, z) - height(x + 0.5, z), 1.0, height(x, z + 0.5) - height(x, z - 0.5)).normalized()
				st.set_normal(n)
				st.set_color(Color(sandiness(x, z), 0, 0))
				st.set_uv(Vector2(x, z))
				st.add_vertex(Vector3(x, h, z))
		for iz in nz:
			for ix in nx:
				var i := iz * (nx + 1) + ix
				st.add_index(i)
				st.add_index(i + nx + 1)
				st.add_index(i + 1)
				st.add_index(i + 1)
				st.add_index(i + nx + 1)
				st.add_index(i + nx + 2)
		st.generate_tangents()
		var mi := MeshInstance3D.new()
		mi.name = "Ground_%d" % int(-z0)
		mi.mesh = st.commit()
		mi.material_override = mat("riverbank")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		env_root.add_child(mi)
		# Walkable collision: the near (west) side up to just into the shallows.
		var arrays := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, idx.size(), 3):
			var a := v[idx[t]]
			var c := (a + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
			if c.x < river_x(c.z) - RIVER_HALF + 1.0 and c.x > X_WEST + 2.0:
				faces.append_array([v[idx[t]], v[idx[t + 1]], v[idx[t + 2]]])
		z0 = z1
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.name = "Terrain"
	cs.shape = shape
	body.add_child(cs)


func _road() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := 2.2
	for i in path_poly.size() - 1:
		var a := path_poly[i]
		var b := path_poly[i + 1]
		var d := b - a
		d.y = 0.0
		if d.length() < 0.01:
			continue
		var side := d.normalized().cross(Vector3.UP) * half
		var quad := [[a - side, 0.0], [a + side, 1.0], [b + side, 1.0], [b - side, 0.0]]
		for idx in [0, 1, 2, 0, 2, 3]:
			var p: Vector3 = quad[idx][0]
			p.y = height(p.x, p.z) + 0.03
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(quad[idx][1], 0.0))
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.name = "Road"
	mi.mesh = st.commit()
	mi.material_override = mat("forest_path")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env_root.add_child(mi)


## The water: a ribbon along the river's course. UV in metres (x across,
## y along the flow); vertex alpha marks the foam line at each bank.
func _river() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var across := 24
	var z := Z_START + 30.0
	var rows := []
	while z >= Z_END - 40.0:
		var row := []
		for j in across + 1:
			var u := float(j) / across
			var x := river_x(z) + lerpf(-RIVER_HALF - BANK * 0.5, RIVER_HALF + BANK * 0.5, u)
			var edge := 1.0 - smoothstep(0.0, 0.035, minf(u, 1.0 - u))
			row.append([Vector3(x, WATER_Y, z), Vector2((u - 0.5) * (RIVER_HALF * 2.0 + BANK), -z), edge])
		rows.append(row)
		z -= 4.0
	for i in rows.size() - 1:
		for j in across:
			var q := [rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]]
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_normal(Vector3.UP)
				st.set_uv(q[k][1])
				st.set_color(Color(1, 1, 1, q[k][2]))
				st.add_vertex(q[k][0])
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = "River"
	mi.mesh = st.commit()
	mi.material_override = mat("river")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env_root.add_child(mi)


# --- Places -----------------------------------------------------------------------------

## The ghat: broad sandstone steps down into the water, a small shrine above.
func _ghat() -> void:
	var z := GHAT_Z
	var top_x := river_x(z) - RIVER_HALF - BANK - 0.5
	var width := 14.0
	for i in 9:
		var x := top_x + 0.9 * i
		var y := height(x, z) - 0.05
		var h := maxf(0.4 + 0.18 * i, 0.3)
		put(MeshKit.box(Vector3(0.95, h, width)), at(x + 0.45, y + 0.2 - h * 0.5 + 0.12, z), "sandstone")
	# Landings and side walls.
	for side in [-1.0, 1.0]:
		put(MeshKit.box(Vector3(9.0, 1.1, 0.8)), at(top_x + 4.0, -0.2, z + side * (width * 0.5 + 0.4)), "red_sandstone")
		put(MeshKit.cyl(0.22, 0.28, 1.6, 10), at(top_x - 0.3, 0.8, z + side * (width * 0.5 + 0.4)), "sandstone")
		put(MeshKit.sphere(0.24, 10), at(top_x - 0.3, 1.7, z + side * (width * 0.5 + 0.4)), "red_sandstone")
	put(MeshKit.box(Vector3(4.0, 0.25, width + 1.6)), at(top_x - 2.0, 0.1, z), "sandstone")
	# Walkable: a ramp over the steps, so the descent is smooth.
	var ramp_len := 9.0 * 0.9
	var drop := 0.0 - (height(top_x + ramp_len, z) + 0.1)
	var ang := atan2(drop, ramp_len)
	collider_box(Vector3(sqrt(ramp_len * ramp_len + drop * drop), 0.3, width),
		Transform3D(Basis(Vector3.BACK, -ang), Vector3(top_x + ramp_len * 0.5, -drop * 0.5 - 0.1, z)))
	# Shrine (a small mandapa with a curved shikhara) at the head of the steps.
	var sx := top_x - 6.0
	var sz := z - 9.0
	put(MeshKit.box(Vector3(4.2, 0.5, 4.2)), at(sx, 0.25, sz), "red_sandstone")
	for cx in [-1.6, 1.6]:
		for cz in [-1.6, 1.6]:
			put(MeshKit.cyl(0.16, 0.2, 2.3, 10), at(sx + cx, 1.65, sz + cz), "sandstone")
			collider_cyl(Vector3(sx + cx, 0, sz + cz), 0.25, 2.8)
	put(MeshKit.box(Vector3(4.4, 0.35, 4.4)), at(sx, 2.95, sz), "red_sandstone")
	for k in 5:
		var r := 1.9 - k * 0.36
		put(MeshKit.cyl(r * 0.85, r, 0.5, 12), at(sx, 3.35 + k * 0.48, sz), "sandstone")
	put(MeshKit.sphere(0.32, 10), at(sx, 5.95, sz), "red_sandstone")
	put(MeshKit.cyl(0.0, 0.08, 0.5, 8), at(sx, 6.4, sz), "gold")
	collider_box(Vector3(4.2, 0.5, 4.2), at(sx, 0.25, sz))
	# A shivalinga on its yoni inside.
	put(MeshKit.cyl(0.42, 0.42, 0.25, 16), at(sx, 0.62, sz), "dark_stone")
	put(MeshKit.cyl(0.15, 0.17, 0.45, 14), at(sx, 0.95, sz), "dark_stone")
	put(MeshKit.sphere(0.15, 12), at(sx, 1.17, sz), "dark_stone")
	# Bells on a beam.
	for k in 3:
		put(MeshKit.cyl(0.04, 0.11, 0.18, 10), at(sx - 0.6 + k * 0.6, 2.55, sz + 1.6), "gold")


## Ferry boats tied at the ghat, rocking in the level.
func _boats() -> void:
	var specs := [[GHAT_Z + 10.0, 0.25], [GHAT_Z + 13.5, -0.15], [GHAT_Z - 9.0, 0.4]]
	for i in specs.size():
		var z: float = specs[i][0]
		var x := river_x(z) - RIVER_HALF + 2.5
		var boat := Node3D.new()
		boat.name = "Boat%d" % i
		boat.position = Vector3(x, WATER_Y, z)
		boat.rotation.y = PI * 0.5 + specs[i][1]
		env_root.add_child(boat)
		var wood: Material = mat("wood")
		var hull := MeshInstance3D.new()
		hull.mesh = MeshKit.sphere(1.0, 18)
		hull.scale = Vector3(0.75, 0.38, 3.0)
		hull.material_override = wood
		boat.add_child(hull)
		var inner := MeshInstance3D.new()
		inner.mesh = MeshKit.box(Vector3(1.0, 0.04, 4.2))
		inner.position.y = 0.2
		inner.material_override = mat("dark_stone")
		boat.add_child(inner)
		for k in 3:
			var seat := MeshInstance3D.new()
			seat.mesh = MeshKit.box(Vector3(1.3, 0.06, 0.25))
			seat.position = Vector3(0, 0.3, -1.2 + k * 1.2)
			seat.material_override = wood
			boat.add_child(seat)
		boat.add_to_group(&"boats", true)
		# A mooring post on the bank with its rope.
		var post := Vector3(x - 4.0, height(x - 4.0, z), z)
		put(MeshKit.cyl(0.09, 0.11, 1.4, 8), at(post.x, post.y + 0.7, post.z), "wood")


## The sandbank camp: fire, grass beds, the sage's seat.
func _camp() -> void:
	var c := CAMP
	for k in 9:
		var a := TAU * k / 9.0
		put(MeshKit.sphere(0.16, 8), Transform3D(Basis().scaled(Vector3(1, 0.7, 1)), c + Vector3(cos(a) * 0.6, 0.08, sin(a) * 0.6)), "dark_stone")
	for k in 4:
		put(MeshKit.cyl(0.06, 0.07, 0.9, 6), Transform3D(Basis(Vector3.UP, k * 0.8) * Basis(Vector3.BACK, PI / 2 - 0.35), c + Vector3(0, 0.18, 0)), "wood")
	# Kusha-grass beds for the princes, a deer-skin seat for the sage.
	for spec in [[Vector3(-2.6, 0, 1.4), 0.5], [Vector3(-2.4, 0, -1.6), -0.4]]:
		put(MeshKit.box(Vector3(0.9, 0.08, 2.0)), Transform3D(Basis(Vector3.UP, spec[1]), c + spec[0] + Vector3.UP * 0.04), "straw")
	# Seat stones (river boulders) for the sage and Rama, set back from the fire.
	for spec in [[Vector3(2.45, 0, 0.2), "SageSeat"], [Vector3(-2.35, 0, 1.45), "RamaSeat"], [Vector3(-2.25, 0, -1.7), "LakshmanaSeat"]]:
		var p: Vector3 = c + spec[0]
		var away: Vector3 = (p - c).normalized()
		var stone := p + away * 0.12
		put(MeshKit.sphere(0.5, 12), Transform3D(Basis(Vector3.UP, away.x).scaled(Vector3(0.95, 0.44, 0.75)), stone + Vector3.UP * 0.2), "dark_stone")
		if spec[1] == "SageSeat":
			put(MeshKit.box(Vector3(0.7, 0.03, 0.6)), Transform3D(Basis(Vector3.UP, 0.3), stone + Vector3.UP * 0.42), "cloth_red")
		collider_cyl(stone, 0.4, 0.42)


## Ayodhya behind them: walls and towers in the haze to the south.
func _city() -> void:
	var z := 70.0
	put(MeshKit.box(Vector3(150, 9, 4)), at(-10, 4.5, z), "sandstone")
	for i in 12:
		var x := -80.0 + i * 13.0
		put(MeshKit.cyl(2.6, 3.0, 13.0, 10), at(x, 6.5, z - 1.0), "red_sandstone")
		put(MeshKit.cyl(0.0, 2.8, 3.5, 10), at(x, 14.7, z - 1.0), "sandstone")
	# Palace towers rising behind the walls.
	for spec in [[-30.0, 26.0, 7.0], [-6.0, 32.0, 9.0], [18.0, 24.0, 6.5], [-48.0, 20.0, 5.0]]:
		var x: float = spec[0]
		var h: float = spec[1]
		var r: float = spec[2]
		for k in 5:
			put(MeshKit.cyl(r * (1.0 - k * 0.16) * 0.85, r * (1.0 - k * 0.16), h / 5.0, 12), at(x, h / 10.0 + k * h / 5.0, z + 18.0), "sandstone")
		put(MeshKit.sphere(r * 0.25, 10), at(x, h + r * 0.2, z + 18.0), "gold")
	# The city gate the party leaves through.
	put(MeshKit.box(Vector3(10, 12, 5)), at(0, 6, z - 2.0), "red_sandstone")
	put(MeshKit.box(Vector3(5, 7, 5.4)), at(0, 3.5, z - 2.0), "dark_stone")


## Fields west of the road in act 1: crop rows with low earthen bunds.
func _fields() -> void:
	var crops := []
	for f in [[Vector2(-34, -8), Vector2(22, 26)], [Vector2(-36, -48), Vector2(24, 30)], [Vector2(-30, -84), Vector2(18, 20)]]:
		var c: Vector2 = f[0]
		var size: Vector2 = f[1]
		var row := 0.0
		while row < size.x:
			var z := c.y - size.y * 0.5
			while z < c.y + size.y * 0.5:
				var x := c.x - size.x * 0.5 + row + rng.randf_range(-0.2, 0.2)
				crops.append(rand_xf(Vector3(x, height(x, z), z), Vector2(1.0, 1.35)))
				z += 0.9
			row += 1.2
		for side in [-1.0, 1.0]:
			put(MeshKit.box(Vector3(size.x + 1.0, 0.3, 0.6)), at(c.x, 0.1, c.y + side * (size.y * 0.5 + 0.4)), "forest_path")
			put(MeshKit.box(Vector3(0.6, 0.3, size.y + 1.0)), at(c.x + side * (size.x * 0.5 + 0.4), 0.1, c.y), "forest_path")
	multimesh_cells("Crops", nature_mesh("Grass_Common_Short"), crops, 40.0, false, 70.0)


# --- Vegetation --------------------------------------------------------------------------

func _trees() -> void:
	var specs := {"a": "CommonTree_3", "b": "CommonTree_5"}
	var near := {"a": [], "b": []}
	var far := {"a": [], "b": []}
	var z := Z_START
	while z > Z_END:
		var x := X_WEST + 3.0
		while x < X_EAST - 3.0:
			var p := Vector3(x + rng.randf_range(-3, 3), 0, z + rng.randf_range(-3, 3))
			var d_road := absf(p.x - road_x(p.z))
			var d_river := river_d(p.x, p.z)
			var west := p.x < road_x(p.z)
			var in_field := p.z > -100.0 and west and p.x > -52.0
			var in_meadow := p.z < -150.0 and p.z > -215.0 and west and p.x > road_x(p.z) - 40.0
			var near_camp := Vector2(p.x - CAMP.x, p.z - CAMP.z).length() < 22.0
			var near_ghat := absf(p.z - GHAT_Z) < 20.0 and not west and d_river > RIVER_HALF
			var ok := d_road > 7.0 and d_river > RIVER_HALF + BANK + 4.0 and not in_field and not in_meadow and not near_camp and not near_ghat
			# Groves, not a forest: thin out on the near side, thicker on the far bank.
			var keep := 0.55 if p.x > river_x(p.z) else (0.32 if d_road < 25.0 else 0.6)
			if ok and rng.randf() < keep:
				var key := "a" if rng.randf() < 0.55 else "b"
				p.y = height(p.x, p.z)
				var xf := rand_xf(p, Vector2(1.5, 2.3))
				if d_road < 30.0 and p.x < river_x(p.z):
					near[key].append(xf)
					collider_cyl(p, 0.6, 6.0)
				else:
					far[key].append(xf)
			x += 8.0
		z -= 8.0
	for key in ["a", "b"]:
		var detail := nature_mesh(specs[key])
		var proxy := far_mesh(specs[key])
		# Near: full detail close, proxy beyond; a proxy casts the shadows.
		var cells := {}
		for t in near[key]:
			var o := (t as Transform3D).origin
			var ck := "%d" % int(floor(o.z / 24.0))
			if not cells.has(ck):
				cells[ck] = []
			cells[ck].append(t)
		for ck: String in cells:
			var d := multimesh("Trees_%s_%s" % [key, ck], detail, cells[ck], false)
			d.visibility_range_end = 40.0
			var f := multimesh("Trees_%s_%s_Far" % [key, ck], proxy, cells[ck], false)
			f.visibility_range_begin = 40.0
			f.visibility_range_end = FAR_RANGE
			var sh := multimesh("Trees_%s_%s_Shadow" % [key, ck], proxy, cells[ck], true)
			sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			sh.visibility_range_end = 50.0
		multimesh_cells("TreesFar_" + key, proxy, far[key], 48.0, false, FAR_RANGE)


func _reeds_and_rocks() -> void:
	var reed := _reed_clump()
	var reeds := []
	var bushes := []
	var flowers := []
	var rocks := []
	var z := Z_START
	while z > Z_END:
		for side in [-1.0, 1.0]:
			# Reeds at the waterline on both banks, but not on the ghat or at the camp's beach.
			if absf(z - GHAT_Z) < 12.0 and side < 0.0:
				continue
			if absf(z - CAMP.z) < 14.0 and side < 0.0:
				continue
			var x: float = river_x(z) + side * (RIVER_HALF + rng.randf_range(0.5, 3.0))
			if rng.randf() < 0.85:
				reeds.append(rand_xf(Vector3(x, height(x, z), z), Vector2(0.8, 1.4), 0.15))
		var xr := road_x(z)
		var near_camp := absf(z - CAMP.z) < 18.0
		for side in [-1.0, 1.0]:
			if near_camp:
				continue  # the camp stays open, for the close-ups
			if rng.randf() < 0.3:
				var x2: float = xr + side * rng.randf_range(4.0, 12.0)
				if river_d(x2, z) > RIVER_HALF + BANK + 1.0:
					bushes.append(rand_xf(Vector3(x2, height(x2, z), z), Vector2(0.8, 1.3)))
			if rng.randf() < 0.35:
				var x3: float = xr + side * rng.randf_range(3.0, 9.0)
				if river_d(x3, z) > RIVER_HALF + BANK:
					flowers.append(rand_xf(Vector3(x3, height(x3, z), z), Vector2(0.7, 1.0)))
		if rng.randf() < 0.18 and not near_camp:
			var x4 := river_x(z) - RIVER_HALF - rng.randf_range(1.0, 5.0)
			rocks.append(rand_xf(Vector3(x4, height(x4, z) - 0.1, z), Vector2(0.6, 1.4), 0.4))
		z -= 1.6
	multimesh_cells("Reeds", reed, reeds, 40.0, false, 80.0)
	var grass := []
	for i in 5200:
		var z2 := rng.randf_range(Z_END + 4.0, Z_START - 4.0)
		var x5 := road_x(z2) + rng.randf_range(-34.0, 26.0)
		if absf(x5 - road_x(z2)) < 2.6 or river_d(x5, z2) < RIVER_HALF + BANK + 2.0 or sandiness(x5, z2) > 0.5:
			continue
		grass.append(rand_xf(Vector3(x5, height(x5, z2), z2), Vector2(0.5, 0.9)))
	multimesh_cells("Grass", nature_mesh("Grass_Common_Short"), grass, 30.0, false, 45.0)
	multimesh_cells("Bushes", nature_mesh("Bush_Common_Flowers"), bushes, 40.0, true, 70.0)
	multimesh_cells("Flowers", nature_mesh("Flower_3_Group"), flowers, 40.0, false, 45.0)
	multimesh_cells("Rocks", nature_mesh("Rock_Medium_3"), rocks, 60.0, true, 90.0)


## A clump of reeds: tapered blades leaning out from a common root.
func _reed_clump() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for k in 14:
		var a := r.randf() * TAU
		var lean := r.randf_range(0.05, 0.35)
		var h := r.randf_range(1.2, 2.2)
		var w := r.randf_range(0.06, 0.1)
		var base := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.0, 0.3)
		var top := base + Vector3(cos(a) * lean * h, h, sin(a) * lean * h)
		var side := Vector3(-sin(a), 0, cos(a)) * w
		var n := Vector3(cos(a) * 0.4, 1.0, sin(a) * 0.4).normalized()
		var tip_col := Color(0.72, 0.6, 0.4) if k % 4 == 0 else Color(0.62, 0.7, 0.4)
		var root_col := Color(0.42, 0.5, 0.28)
		var pts := [[base - side, root_col], [base + side, root_col], [top, tip_col]]
		for p in pts:
			st.set_normal(n)
			st.set_color(p[1])
			st.set_uv(Vector2(0.5, 1.0 - (p[0] as Vector3).y / h))
			st.add_vertex(p[0])
	var m := st.commit()
	var reed_mat := StandardMaterial3D.new()
	reed_mat.vertex_color_use_as_albedo = true
	reed_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	reed_mat.roughness = 0.9
	m.surface_set_material(0, reed_mat)
	return m


func _atmosphere() -> void:
	# Low river mist, thickening toward the camp (seen at dusk).
	for i in 5:
		var p := CPUParticles3D.new()
		p.name = "RiverMist%d" % i
		p.amount = 12
		p.lifetime = 14.0
		p.preprocess = 14.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(16, 0.3, 26)
		p.direction = Vector3(0, 0, 1)
		p.spread = 30.0
		p.gravity = Vector3.ZERO
		p.initial_velocity_min = 0.2
		p.initial_velocity_max = 0.4
		var q := QuadMesh.new()
		q.size = Vector2(9, 2.5)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(0.95, 0.85, 0.78, 0.13)
		m.albedo_texture = FX._soft_dot()
		q.material = m
		p.mesh = q
		var z := -60.0 - i * 60.0
		p.position = Vector3(river_x(z), WATER_Y + 0.6, z)
		env_root.add_child(p)


func _bounds() -> void:
	# West edge, south (the city road) and north end.
	collider_box(Vector3(1, 12, Z_START - Z_END), at(X_WEST + 4.0, 6, (Z_START + Z_END) * 0.5))
	collider_box(Vector3(X_EAST - X_WEST, 12, 1), at((X_WEST + X_EAST) * 0.5, 6, Z_START - 4.0))
	collider_box(Vector3(X_EAST - X_WEST, 12, 1), at((X_WEST + X_EAST) * 0.5, 6, Z_END + 6.0))
	# The river: one cannot wade beyond the shallows.
	var z := Z_START
	while z > Z_END:
		var z2 := z - 8.0
		var a := Vector3(river_x(z) - RIVER_HALF + 0.5, 0, z)
		var b := Vector3(river_x(z2) - RIVER_HALF + 0.5, 0, z2)
		var mid := (a + b) * 0.5
		var dir := b - a
		collider_box(Vector3(0.6, 6, dir.length() + 0.6), Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), mid + Vector3.UP * 2.0))
		z = z2


func _markers() -> void:
	var specs := [
		["Start", Vector3(0, 0, 2)],
		["CityLook", Vector3(0, 0, 40)],
		["Ghat", Vector3(river_x(GHAT_Z) - RIVER_HALF - BANK - 1.5, 0, GHAT_Z)],
		["GhatWater", Vector3(river_x(GHAT_Z) - RIVER_HALF - 1.0, 0, GHAT_Z)],
		["Shrine", Vector3(river_x(GHAT_Z) - RIVER_HALF - BANK - 6.5, 0, GHAT_Z - 9.0)],
		["Widow", Vector3(river_x(GHAT_Z) - RIVER_HALF - BANK - 3.0, 0, GHAT_Z - 4.0)],
		["Boatman", Vector3(river_x(GHAT_Z + 11.0) - RIVER_HALF - 2.5, 0, GHAT_Z + 11.0)],
		["Oar", Vector3(river_x(-128.0) - RIVER_HALF - 1.0, 0, -128.0)],
		["HerdSpot", Vector3(road_x(-182.0) - 22.0, 0, -182.0)],
		["StampedeFrom", Vector3(road_x(-150.0) - 40.0, 0, -150.0)],
		["StampedeCross", Vector3(road_x(-196.0), 0, -196.0)],
		["StampedeTo", Vector3(river_x(-230.0) - RIVER_HALF - 2.0, 0, -230.0)],
		["CampCenter", CAMP],
		["SageSeat", CAMP + Vector3(2.3, 0, 0.2)],
		["RamaSeat", CAMP + Vector3(-2.2, 0, 1.4)],
		["LakshmanaSeat", CAMP + Vector3(-2.1, 0, -1.6)],
		["CampWater", Vector3(river_x(CAMP.z) - RIVER_HALF - 2.2, 0, CAMP.z)],
		["End", Vector3(road_x(-338.0), 0, -338.0)],
	]
	# Talk points along the road and the lamps for the side quest.
	for i in 6:
		var z := -25.0 - i * 50.0
		specs.append(["Talk%d" % (i + 1), Vector3(road_x(z), 0, z)])
	var lamp_z := [-70.0, -112.0, -160.0, -214.0, -268.0]
	for i in lamp_z.size():
		var z: float = lamp_z[i]
		var side := 1.0 if i % 2 == 0 else -1.0
		specs.append(["Lamp%d" % (i + 1), Vector3(road_x(z) + side * 5.5, 0, z)])
	for spec in specs:
		var m := Marker3D.new()
		m.name = spec[0]
		var p: Vector3 = spec[1]
		p.y = height(p.x, p.z)
		m.position = p
		env_root.add_child(m)
