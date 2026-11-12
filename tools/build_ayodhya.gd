extends SceneTree
## Builds the Ayodhya royal training grounds (Bala Kanda prologue arena).
##
##   godot -s res://tools/build_ayodhya.gd        (NOT --headless)
##
## It must run with a real renderer (on a server: xvfb-run ... --rendering-driver
## opengl3): MultiMesh instance data lives in the RenderingServer, and the
## headless dummy renderer would save every instance at the origin.
##
## Output:
##   res://kandas/01_bala/env/ayodhya_grounds.scn  (static environment)
##   res://assets/env/props/archery_butt.res       (straw target mesh)
##
## Everything is deterministic (seeded). Architecture is procedural (no free
## Indian-architecture packs exist); foliage comes from Quaternius' CC0
## Stylized Nature MegaKit (assets/env/nature). Geometry is merged per
## material per region, and repeated pieces are MultiMeshes, to stay within
## the mobile draw-call budget.
##
## Layout (metres; Rama starts at the origin facing -Z):
##   courtyard x ±28, z -46..+14; colonnades on the east, west and north sides;
##   gopuram gate at the north (z -50); torana gates east/west at z -22;
##   rangoli medallion at (0, -28); kalyani tank in the south-west corner.

const OUT_SCENE := "res://kandas/01_bala/env/ayodhya_grounds.scn"
const OUT_BUTT := "res://assets/env/props/archery_butt.res"
const M := "res://assets/materials/env/"
const NATURE := "res://assets/env/nature/"
const SEED := 1008

## Gate openings in the side colonnades (z range) and north wall (|x| <).
const SIDE_GATE_Z := Vector2(-26.0, -18.0)
const NORTH_GATE_HALF := 5.0

var rng := RandomNumberGenerator.new()
var env_root: Node3D
var body: StaticBody3D
var mats := {}
## Region -> {Material: SurfaceTool}
var _groups := {}

## Stone materials merged into one "arch" draw via 0/1 colour masks
## (see assets/materials/env/arch.tres region_* uniforms).
const ARCH_MASKS := {
	"sandstone": Color(0, 0, 0),
	"red_sandstone": Color(1, 0, 0),
	"marble": Color(0, 1, 0),
	"dark_stone": Color(0, 0, 1),
}


func _initialize() -> void:
	rng.seed = SEED
	env_root = Node3D.new()
	env_root.name = "AyodhyaGrounds"
	body = StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	env_root.add_child(body)

	_floor()
	_colonnades()
	_north_wall_and_gopuram()
	_side_gates()
	_south_balustrade()
	_kalyani_tank()
	_planters()
	_shooting_line_props()
	_palace_skyline()
	_distant_hills()
	_flush_all()
	_pillars()
	_finials()
	_lamps()
	_banners()
	_nature()
	_build_archery_butt()
	print("Lightmap UVs: %d meshes" % LightmapUV.unwrap_all(env_root, 0.3))

	_own(env_root, env_root)
	var packed := PackedScene.new()
	var err := packed.pack(env_root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_SCENE, ResourceSaver.FLAG_COMPRESS)
	print("Saved %s: %s" % [OUT_SCENE, error_string(err)])
	quit(0 if err == OK else 1)


# --- Helpers ----------------------------------------------------------------------

func mat(name: String) -> Material:
	if not mats.has(name):
		mats[name] = load(M + name + ".tres")
	return mats[name]


## Queues geometry into a merged mesh for (region, material).
func put(region: String, mesh: Mesh, xf: Transform3D, material: String) -> void:
	if ARCH_MASKS.has(material):
		mesh = _masked(mesh, ARCH_MASKS[material])
		material = "arch"
	if not _groups.has(region):
		_groups[region] = {}
	var g: Dictionary = _groups[region]
	if not g.has(material):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		g[material] = st
	for s in mesh.get_surface_count():
		(g[material] as SurfaceTool).append_from(mesh, s, xf)


## Copy of `mesh` with every vertex coloured `mask`.
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


func box(region: String, size: Vector3, center: Vector3, material: String, basis := Basis(), collide := false) -> void:
	put(region, MeshKit.box(size), Transform3D(basis, center), material)
	if collide:
		collider(size, Transform3D(basis, center))


func collider(size: Vector3, xf: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)


func _flush_all() -> void:
	for region: String in _groups:
		var node := Node3D.new()
		node.name = region.capitalize().replace(" ", "")
		env_root.add_child(node)
		var g: Dictionary = _groups[region]
		for material: String in g:
			var mi := MeshInstance3D.new()
			mi.name = material.capitalize().replace(" ", "")
			mi.mesh = (g[material] as SurfaceTool).commit()
			mi.material_override = mat(material)
			if region in ["skyline", "hills"]:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(mi)
	_groups.clear()


func multimesh(name: String, mesh: Mesh, xforms: Array, material: Material = null, shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	if material:
		mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env_root.add_child(mmi)
	return mmi


## Builds one mesh per material from a list of [mesh, xform, material].
func compose(parts: Array) -> Dictionary:
	var out := {}
	for p in parts:
		var key: String = p[2]
		if ARCH_MASKS.has(key):
			p = [_masked(p[0], ARCH_MASKS[key]), p[1], "arch"]
			key = "arch"
		if not out.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			out[key] = st
		for s in (p[0] as Mesh).get_surface_count():
			(out[key] as SurfaceTool).append_from(p[0], s, p[1])
	for key in out.keys():
		out[key] = (out[key] as SurfaceTool).commit()
	return out


func at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


func _own(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_own(c, owner_node)


# --- Ground -----------------------------------------------------------------------

## Tank opening in the paving (x0, z0, x1, z1).
const TANK_HOLE := Rect2(-25.0, 1.0, 10.0, 8.0)


func _floor() -> void:
	# Paving in four pieces around the kalyani tank opening.
	var h := TANK_HOLE
	var pieces := [
		Rect2(-80, -80, h.position.x + 80, 160),
		Rect2(h.end.x, -80, 80 - h.end.x, 160),
		Rect2(h.position.x, -80, h.size.x, h.position.y + 80),
		Rect2(h.position.x, h.end.y, h.size.x, 80 - h.end.y),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r: Rect2 in pieces:
		var plane := PlaneMesh.new()
		plane.size = r.size
		st.append_from(plane, 0, at(r.get_center().x, 0, r.get_center().y))
	var mi := MeshInstance3D.new()
	mi.name = "Paving"
	mi.mesh = st.commit()
	mi.material_override = mat("paving")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env_root.add_child(mi)
	collider(Vector3(160, 1, 160), at(0, -0.5, 0))


# --- Colonnades ---------------------------------------------------------------------

func _pillar_z_positions() -> Array:
	var zs := []
	var z := -44.0
	while z <= 12.0:
		if z < SIDE_GATE_Z.x - 0.5 or z > SIDE_GATE_Z.y + 0.5:
			zs.append(z)
		z += 4.0
	return zs


func _pillar_x_positions() -> Array:
	var xs := []
	var x := -26.0
	while x <= 26.0:
		if absf(x) > NORTH_GATE_HALF + 0.5:
			xs.append(x)
		x += 4.0
	return xs


func _colonnades() -> void:
	for side: float in [-1.0, 1.0]:
		var region := "east" if side > 0 else "west"
		var inner := 28.6 * side
		# Raised plinth (with gaps for the side gate).
		for span: Vector2 in [Vector2(-48.0, SIDE_GATE_Z.x), Vector2(SIDE_GATE_Z.y, 14.0)]:
			var length: float = span.y - span.x
			var cz: float = (span.x + span.y) * 0.5
			box(region, Vector3(5.6, 0.5, length), Vector3(31.3 * side, 0.25, cz), "sandstone", Basis(), true)
			box(region, Vector3(0.3, 0.12, length), Vector3(28.65 * side, 0.52, cz), "red_sandstone")
			# Roof slab, eave (chhajja), lintel and parapet.
			box(region, Vector3(6.0, 0.35, length), Vector3(31.2 * side, 4.95, cz), "sandstone")
			box(region, Vector3(1.2, 0.08, length), Vector3(inner - 0.35 * side, 4.62, cz), "red_sandstone",
				Basis(Vector3.BACK, deg_to_rad(18.0) * -side))
			box(region, Vector3(0.45, 0.4, length), Vector3(29.0 * side, 4.55, cz), "red_sandstone")
			box(region, Vector3(0.35, 0.55, length), Vector3(28.6 * side, 5.4, cz), "marble")
			# Back wall with carved niches.
			box(region, Vector3(0.6, 7.0, length), Vector3(34.0 * side, 3.5, cz), "sandstone", Basis(), true)
			var nz: float = span.x + 2.0
			while nz < span.y - 1.0:
				box(region, Vector3(0.12, 2.2, 1.3), Vector3(33.66 * side, 2.2, nz), "red_sandstone")
				box(region, Vector3(0.14, 0.25, 1.6), Vector3(33.64 * side, 3.45, nz), "marble")
				nz += 4.0
		# Chhatri pavilions on the colonnade corners.
		for cz in [-46.0, 12.0]:
			_chhatri(region, Vector3(31.0 * side, 5.1, cz), 1.6)
		# Invisible wall keeping the play area inside the pillars.
		for span: Vector2 in [Vector2(-48.0, SIDE_GATE_Z.x), Vector2(SIDE_GATE_Z.y, 14.0)]:
			collider(Vector3(0.6, 4.0, span.y - span.x), at(28.9 * side, 2.0, (span.x + span.y) * 0.5))


func _chhatri(region: String, base: Vector3, r: float) -> void:
	box(region, Vector3(r * 2.0, 0.2, r * 2.0), base + Vector3(0, 0.1, 0), "marble")
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		put(region, MeshKit.cyl(0.08, 0.1, 1.4, 8), at(base.x + c.x * r * 0.75, base.y + 0.9, base.z + c.y * r * 0.75), "red_sandstone")
	box(region, Vector3(r * 2.2, 0.15, r * 2.2), base + Vector3(0, 1.65, 0), "marble")
	var dome := SphereMesh.new()
	dome.radius = r * 0.85
	dome.height = r * 0.85
	dome.is_hemisphere = true
	dome.radial_segments = 16
	dome.rings = 5
	put(region, dome, at(base.x, base.y + 1.72, base.z), "marble")
	put(region, MeshKit.cyl(0.0, 0.08, 0.5, 8), at(base.x, base.y + 1.72 + r * 0.85 + 0.2, base.z), "gold")


# --- North wall and gopuram -------------------------------------------------------------

func _north_wall_and_gopuram() -> void:
	var region := "north"
	for side: float in [-1.0, 1.0]:
		var x0 := NORTH_GATE_HALF + 3.0
		var x1 := 34.0
		var cx := (x0 + x1) * 0.5 * side
		var w := x1 - x0
		box(region, Vector3(w, 0.5, 4.0), Vector3(cx, 0.25, -48.0), "sandstone", Basis(), true)
		box(region, Vector3(w, 0.35, 5.0), Vector3(cx, 4.95, -48.2), "sandstone")
		box(region, Vector3(w, 0.4, 0.45), Vector3(cx, 4.55, -46.6), "red_sandstone")
		box(region, Vector3(w, 0.55, 0.35), Vector3(cx, 5.4, -46.2), "marble")
		box(region, Vector3(w, 0.08, 1.2), Vector3(cx, 4.62, -45.9), "red_sandstone", Basis(Vector3.RIGHT, deg_to_rad(18.0)))
		box(region, Vector3(w, 7.0, 0.6), Vector3(cx, 3.5, -50.5), "sandstone", Basis(), true)
		collider(Vector3(w, 4.0, 0.6), at(cx, 2.0, -46.4))

	# Gopuram: gateway base plus five receding tiers and a barrel-vault crown.
	var gz := -52.0
	for side: float in [-1.0, 1.0]:
		box(region, Vector3(5.0, 7.0, 7.0), Vector3(5.5 * side, 3.5, gz), "sandstone", Basis(), true)
		for i in 3:
			box(region, Vector3(0.15, 1.6, 0.9), Vector3((3.05) * side, 1.6 + i * 1.9, gz + 3.55), "red_sandstone")
		_dvarapala(region, Vector3(4.2 * side, 0.0, gz + 3.8))
	box(region, Vector3(6.0, 1.6, 7.0), Vector3(0, 6.2, gz), "sandstone")
	box(region, Vector3(6.4, 0.3, 0.3), Vector3(0, 5.35, gz + 3.55), "gold")
	var w := 16.0
	var d := 8.0
	var y := 7.0
	for tier in 5:
		var h := 2.3 - tier * 0.15
		var stone := "sandstone" if tier % 2 == 0 else "red_sandstone"
		box(region, Vector3(w, h, d), Vector3(0, y + h * 0.5, gz), stone)
		box(region, Vector3(w + 0.4, 0.18, d + 0.4), Vector3(0, y + h, gz), "marble")
		# Rows of miniature shrines (kudu) along the front and back.
		var count := int(w / 1.6)
		for k in count:
			var kx := -w * 0.5 + 0.8 + k * (w - 1.6) / maxf(count - 1, 1)
			for face in [1.0, -1.0]:
				box(region, Vector3(0.7, h * 0.55, 0.2), Vector3(kx, y + h * 0.42, gz + face * (d * 0.5 + 0.08)), "red_sandstone" if tier % 2 == 0 else "sandstone")
				put(region, MeshKit.cyl(0.0, 0.32, 0.35, 6), at(kx, y + h + 0.27, gz + face * (d * 0.5 - 0.2)), "marble")
		y += h + 0.18
		w *= 0.82
		d *= 0.86
	var crown := MeshKit.cyl(1.3, 1.3, w + 1.0, 16)
	put(region, crown, Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(0, y + 0.6, gz)), "red_sandstone")
	for k in 5:
		var kx := lerpf(-w * 0.5, w * 0.5, k / 4.0)
		put(region, MeshKit.sphere(0.32, 10), at(kx, y + 2.1, gz), "gold")
		put(region, MeshKit.cyl(0.0, 0.14, 0.7, 8), at(kx, y + 2.65, gz), "gold")


## Simple guardian (dvarapala) statue silhouette beside the gate.
func _dvarapala(region: String, p: Vector3) -> void:
	box(region, Vector3(1.0, 0.6, 1.0), p + Vector3(0, 0.3, 0), "marble")
	put(region, MeshKit.cyl(0.28, 0.36, 1.6, 8), at(p.x, p.y + 1.4, p.z), "dark_stone")
	put(region, MeshKit.sphere(0.24, 10), at(p.x, p.y + 2.45, p.z), "dark_stone")
	put(region, MeshKit.cyl(0.0, 0.2, 0.4, 8), at(p.x, p.y + 2.85, p.z), "gold")
	put(region, MeshKit.cyl(0.05, 0.05, 2.2, 6), at(p.x + 0.45, p.y + 1.6, p.z + 0.1), "gold")


# --- Side torana gates ---------------------------------------------------------------------

func _side_gates() -> void:
	for side: float in [-1.0, 1.0]:
		var region := "east" if side > 0 else "west"
		var x := 30.0 * side
		for z: float in [SIDE_GATE_Z.x, SIDE_GATE_Z.y]:
			put(region, MeshKit.cyl(0.38, 0.45, 6.0, 10), at(x, 3.0, z), "red_sandstone")
			put(region, MeshKit.cyl(0.55, 0.5, 0.4, 10), at(x, 0.2, z), "marble")
			put(region, MeshKit.sphere(0.4, 10), at(x, 6.3, z), "gold")
			collider(Vector3(1.0, 6.0, 1.0), at(x, 3.0, z))
		# Arch made of short segments.
		var cz := (SIDE_GATE_Z.x + SIDE_GATE_Z.y) * 0.5
		var r := (SIDE_GATE_Z.y - SIDE_GATE_Z.x) * 0.5
		var segs := 12
		for i in segs:
			var a0 := PI * i / segs
			var a1 := PI * (i + 1) / segs
			var p0 := Vector3(x, 5.6 + sin(a0) * r * 0.5, cz - cos(a0) * r)
			var p1 := Vector3(x, 5.6 + sin(a1) * r * 0.5, cz - cos(a1) * r)
			put(region, MeshKit.cyl(0.22, 0.22, p0.distance_to(p1) + 0.05, 8),
				Transform3D(MeshKit.basis_along(p1 - p0), (p0 + p1) * 0.5), "gold" if i % 2 == 0 else "red_sandstone")
		box(region, Vector3(1.0, 0.5, r * 2.0 + 1.0), Vector3(x, 5.9, cz), "sandstone")


# --- South balustrade -----------------------------------------------------------------------

func _south_balustrade() -> void:
	var region := "south"
	for side: float in [-1.0, 1.0]:
		var x := 6.0
		while x <= 28.0:
			put(region, MeshKit.cyl(0.12, 0.15, 1.0, 8), at(x * side, 0.5, 14.0), "marble")
			x += 1.0
		var cx := 17.0 * side
		box(region, Vector3(22.4, 0.15, 0.4), Vector3(cx, 1.05, 14.0), "marble", Basis(), true)
		box(region, Vector3(22.4, 0.2, 0.5), Vector3(cx, 0.1, 14.0), "sandstone")
		collider(Vector3(22.4, 2.0, 0.4), at(cx, 1.0, 14.0))
	for side: float in [-1.0, 1.0]:
		box(region, Vector3(1.0, 2.0, 1.0), Vector3(5.5 * side, 1.0, 14.0), "red_sandstone", Basis(), true)
		put(region, MeshKit.sphere(0.35, 10), at(5.5 * side, 2.3, 14.0), "gold")
	collider(Vector3(10.0, 3.0, 0.5), at(0, 1.5, 15.0))


# --- Kalyani (stepped tank) -------------------------------------------------------------------

func _kalyani_tank() -> void:
	var region := "south"
	var c := Vector3(-20.0, 0.0, 5.0)
	var size := Vector2(10.0, 8.0)
	box(region, Vector3(size.x + 1.2, 0.35, 0.6), c + Vector3(0, 0.17, -size.y * 0.5 - 0.3), "marble")
	box(region, Vector3(size.x + 1.2, 0.35, 0.6), c + Vector3(0, 0.17, size.y * 0.5 + 0.3), "marble")
	box(region, Vector3(0.6, 0.35, size.y), c + Vector3(-size.x * 0.5 - 0.3, 0.17, 0), "marble")
	box(region, Vector3(0.6, 0.35, size.y), c + Vector3(size.x * 0.5 + 0.3, 0.17, 0), "marble")
	for step in 4:
		var inset := step * 0.6
		var y := -0.25 - step * 0.3
		var sx := size.x - inset * 2.0
		var sz := size.y - inset * 2.0
		for e in [[Vector3(sx, 0.3, 0.6), Vector3(0, y, -sz * 0.5 + 0.3)], [Vector3(sx, 0.3, 0.6), Vector3(0, y, sz * 0.5 - 0.3)],
				[Vector3(0.6, 0.3, sz), Vector3(-sx * 0.5 + 0.3, y, 0)], [Vector3(0.6, 0.3, sz), Vector3(sx * 0.5 - 0.3, y, 0)]]:
			box(region, e[0], c + e[1], "sandstone" if step % 2 == 0 else "red_sandstone")
	var water := PlaneMesh.new()
	water.size = Vector2(size.x - 4.2, size.y - 4.2)
	water.subdivide_width = 8
	water.subdivide_depth = 8
	var wi := MeshInstance3D.new()
	wi.name = "KalyaniWater"
	wi.mesh = water
	wi.material_override = mat("water")
	wi.position = c + Vector3(0, -1.1, 0)
	wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env_root.add_child(wi)
	# Flower bed along the north rim of the tank.
	box(region, Vector3(size.x + 1.2, 0.35, 0.9), c + Vector3(0, 0.17, -size.y * 0.5 - 1.05), "dark_stone")
	# Pit walls between the paving edge and the steps.
	var hc := TANK_HOLE.get_center()
	var hs := TANK_HOLE.size
	for e in [[Vector3(hs.x, 1.6, 0.2), Vector3(hc.x, -0.8, TANK_HOLE.position.y + 0.1)],
			[Vector3(hs.x, 1.6, 0.2), Vector3(hc.x, -0.8, TANK_HOLE.end.y - 0.1)],
			[Vector3(0.2, 1.6, hs.y), Vector3(TANK_HOLE.position.x + 0.1, -0.8, hc.y)],
			[Vector3(0.2, 1.6, hs.y), Vector3(TANK_HOLE.end.x - 0.1, -0.8, hc.y)]]:
		box(region, e[0], e[1], "sandstone")
	# Dark pit below the water so the tank reads deep.
	box(region, Vector3(size.x - 4.0, 0.1, size.y - 4.0), c + Vector3(0, -1.6, 0), "dark_stone")
	collider(Vector3(size.x + 1.2, 1.5, size.y + 1.2), Transform3D(Basis(), c + Vector3(0, 0.5, 0)))


# --- Planters, shooting line, props -------------------------------------------------------------

const PLANTERS := [Vector3(20, 0, -40), Vector3(-20, 0, -40), Vector3(21, 0, 6)]


func _planters() -> void:
	for p: Vector3 in PLANTERS:
		box("planters", Vector3(6.0, 0.6, 6.0), p + Vector3(0, 0.3, 0), "marble", Basis(), true)
		box("planters", Vector3(5.4, 0.05, 5.4), p + Vector3(0, 0.62, 0), "dark_stone")


func _shooting_line_props() -> void:
	var region := "range"
	box(region, Vector3(14.0, 0.03, 0.25), Vector3(0, 0.015, 1.2), "red_sandstone")
	# Weapon rack: frame with bows and spears.
	var rack := Vector3(-6.5, 0, 2.5)
	for dx: float in [-1.0, 1.0]:
		put(region, MeshKit.cyl(0.05, 0.05, 1.8, 6), at(rack.x + dx, 0.9, rack.z), "wood")
	for y: float in [0.5, 1.6]:
		put(region, MeshKit.cyl(0.04, 0.04, 2.2, 6), Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(rack.x, y, rack.z)), "wood")
	for i in 4:
		var bx := rack.x - 0.75 + i * 0.5
		put(region, MeshKit.cyl(0.015, 0.015, 1.9, 5), Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(bx, 1.05, rack.z + 0.08)), "wood" if i % 2 else "gold")
		put(region, MeshKit.cyl(0.0, 0.04, 0.18, 5), at(bx, 2.05, rack.z + 0.2), "dark_stone")
	collider(Vector3(2.4, 2.0, 0.4), at(rack.x, 1.0, rack.z))
	# Nagara drums beside the gopuram.
	for side: float in [-1.0, 1.0]:
		var p := Vector3(8.5 * side, 0, -43.0)
		put("north", MeshKit.cyl(0.55, 0.45, 0.9, 14), at(p.x, 0.45, p.z), "cloth_red")
		put("north", MeshKit.torus(0.5, 0.58, 14), at(p.x, 0.88, p.z), "gold")
		collider(Vector3(1.2, 1.0, 1.2), at(p.x, 0.5, p.z))


# --- Distance: palace skyline and hills ------------------------------------------------------------

func _palace_skyline() -> void:
	var region := "skyline"
	# South: Rama's palace façade with chhatris.
	box(region, Vector3(70.0, 12.0, 6.0), Vector3(0, 6.0, 36.0), "sandstone")
	box(region, Vector3(72.0, 0.6, 7.0), Vector3(0, 12.2, 36.0), "red_sandstone")
	var x := -30.0
	while x <= 30.0:
		box(region, Vector3(2.2, 3.0, 0.5), Vector3(x, 7.0, 32.8), "red_sandstone")
		box(region, Vector3(2.8, 0.3, 1.0), Vector3(x, 8.6, 32.6), "marble")
		x += 6.0
	for cx: float in [-24.0, -8.0, 8.0, 24.0]:
		_chhatri(region, Vector3(cx, 12.5, 36.0), 2.2)
	_chhatri(region, Vector3(0, 12.5, 36.0), 3.2)
	# City towers beyond the walls (east, west, north).
	for i in 14:
		var a := rng.randf_range(-PI * 0.9, PI * 0.1)
		var r := rng.randf_range(55.0, 80.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r - 15.0)
		if absf(p.x) < 36.0 and p.z > -60.0:
			continue
		var h := rng.randf_range(8.0, 16.0)
		box(region, Vector3(6.0, h, 6.0), p + Vector3(0, h * 0.5, 0), "sandstone" if i % 2 else "marble")
		_chhatri(region, p + Vector3(0, h, 0), 2.0)


func _distant_hills() -> void:
	# Low rolling hills of the Sarayu plain, fading into the haze.
	for i in 40:
		var a := TAU * i / 40.0 + rng.randf_range(-0.06, 0.06)
		var r := rng.randf_range(230.0, 300.0)
		var h := rng.randf_range(10.0, 26.0)
		var hill := SphereMesh.new()
		hill.radius = rng.randf_range(35.0, 60.0)
		hill.height = h * 2.0
		hill.is_hemisphere = true
		hill.radial_segments = 12
		hill.rings = 4
		put("hills", hill, at(cos(a) * r, -1.0, sin(a) * r), "hills")


# --- Instanced pieces ----------------------------------------------------------------------------

func _pillar_xforms() -> Array:
	var xf := []
	for side: float in [-1.0, 1.0]:
		for z: float in _pillar_z_positions():
			xf.append(at(29.0 * side, 0.5, z))
	for x: float in _pillar_x_positions():
		xf.append(at(x, 0.5, -46.6))
	return xf


func _pillars() -> void:
	var parts := [
		[MeshKit.box(Vector3(0.8, 0.3, 0.8)), at(0, 0.15, 0), "marble"],
		[MeshKit.box(Vector3(0.62, 0.3, 0.62)), at(0, 0.45, 0), "red_sandstone"],
		[MeshKit.cyl(0.2, 0.24, 2.7, 8), at(0, 1.95, 0), "red_sandstone"],
		[MeshKit.cyl(0.27, 0.27, 0.12, 8), at(0, 1.3, 0), "marble"],
		[MeshKit.cyl(0.25, 0.25, 0.1, 8), at(0, 2.75, 0), "gold"],
		[MeshKit.cyl(0.36, 0.22, 0.3, 8), at(0, 3.45, 0), "red_sandstone"],
		[MeshKit.box(Vector3(0.75, 0.18, 0.75)), at(0, 3.68, 0), "marble"],
		[MeshKit.box(Vector3(1.3, 0.18, 0.42)), at(0, 3.86, 0), "red_sandstone"],
	]
	var meshes := compose(parts)
	var xf := _pillar_xforms()
	for key: String in meshes:
		multimesh("Pillars_" + key, meshes[key], xf, mat(key))
	for t in xf:
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.4
		shape.height = 4.0
		cs.shape = shape
		cs.transform = (t as Transform3D) * at(0, 2.0, 0)
		body.add_child(cs)


func _finials() -> void:
	var xf := []
	for side: float in [-1.0, 1.0]:
		var z := -46.0
		while z <= 13.0:
			if z < SIDE_GATE_Z.x or z > SIDE_GATE_Z.y:
				xf.append(at(28.6 * side, 5.7, z))
			z += 2.0
	var x := -32.0
	while x <= 32.0:
		if absf(x) > NORTH_GATE_HALF + 3.0:
			xf.append(at(x, 5.7, -46.2))
		x += 2.0
	var meshes := compose([
		[MeshKit.sphere(0.16, 6), at(0, 0.12, 0), "gold"],
		[MeshKit.cyl(0.0, 0.07, 0.3, 5), at(0, 0.38, 0), "gold"],
	])
	multimesh("Kalashas", meshes["gold"], xf, mat("gold"), false)


func _lamp_positions() -> Array:
	var ps := []
	for side: float in [-1.0, 1.0]:
		var z := -42.0
		while z <= 10.0:
			if z < SIDE_GATE_Z.x - 1.0 or z > SIDE_GATE_Z.y + 1.0:
				ps.append(Vector3(27.6 * side, 0, z))
			z += 8.0
		ps.append(Vector3(6.5 * side, 0, -44.5))
		ps.append(Vector3(7.5 * side, 0, 1.2))
	return ps


func _lamps() -> void:
	var ps := _lamp_positions()
	var xf := []
	var flame_xf := []
	for p: Vector3 in ps:
		xf.append(Transform3D(Basis(), p))
		flame_xf.append(Transform3D(Basis(), p + Vector3(0, 1.62, 0)))
	var meshes := compose([
		[MeshKit.cyl(0.25, 0.3, 0.12, 10), at(0, 0.06, 0), "gold"],
		[MeshKit.cyl(0.04, 0.06, 1.4, 6), at(0, 0.8, 0), "gold"],
		[MeshKit.cyl(0.2, 0.06, 0.12, 10), at(0, 1.52, 0), "gold"],
	])
	multimesh("LampStands", meshes["gold"], xf, mat("gold"), false)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.42)
	multimesh("LampFlames", quad, flame_xf, mat("flame"), false)
	# A few real lights for warmth near the gates and the shooting line.
	var lit := 0
	for p: Vector3 in ps:
		if absf(p.x) < 10.0:
			var light := OmniLight3D.new()
			light.name = "LampLight%d" % lit
			light.light_color = Color(1.0, 0.65, 0.3)
			light.light_energy = 1.2
			light.omni_range = 5.0
			light.position = p + Vector3(0, 1.7, 0)
			env_root.add_child(light)
			lit += 1


func _banners() -> void:
	var spots := [
		[Vector3(-9.2, 18.0, -52.0), 1.0], [Vector3(9.2, 18.0, -52.0), -1.0],
		[Vector3(-28.6, 5.6, -10.0), 1.0], [Vector3(28.6, 5.6, -10.0), -1.0],
		[Vector3(-28.6, 5.6, -36.0), 1.0], [Vector3(28.6, 5.6, -36.0), -1.0],
		[Vector3(-10.0, 0.0, 3.0), 1.0], [Vector3(10.0, 0.0, 3.0), -1.0],
	]
	var pole_xf := []
	var flag_xf := []
	for s in spots:
		var p: Vector3 = s[0]
		var dir: float = s[1]
		var pole_h := 4.5
		pole_xf.append(Transform3D(Basis(), p + Vector3(0, pole_h * 0.5, 0)))
		# Banner hangs from the pole top, flying toward +x*dir.
		flag_xf.append(Transform3D(Basis().scaled(Vector3(dir, 1, 1)), p + Vector3(0.9 * dir, pole_h - 0.65, 0)))
	multimesh("BannerPoles", MeshKit.cyl(0.05, 0.06, 4.5, 6), pole_xf, mat("gold"))
	var cloth := PlaneMesh.new()
	cloth.size = Vector2(1.8, 1.1)
	cloth.orientation = PlaneMesh.FACE_Z
	cloth.subdivide_width = 10
	cloth.subdivide_depth = 2
	multimesh("Banners", cloth, flag_xf, mat("banner"))


# --- Nature (CC0 Stylized Nature MegaKit) ----------------------------------------------------------

const MATERIAL_MAP := {
	"Bark_NormalTree": "bark",
	"Leaves_NormalTree": "leaves",
	"Leaves_TwistedTree": "leaves_b",
	"Leaves": "plant",
	"Flowers": "flowers",
	"Grass": "grass",
	"Rocks": "rock",
}


## Loads an imported nature model and returns its mesh with our toon foliage
## materials assigned per surface.
func nature_mesh(file: String) -> Mesh:
	var scene := load(NATURE + file + ".gltf") as PackedScene
	var inst := scene.instantiate()
	var mi := inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var src_mesh := mi.mesh as ArrayMesh
	# Rebuild with our materials and fresh LODs (distant trees get cheap).
	var im := ImporterMesh.new()
	for s in src_mesh.get_surface_count():
		var src := src_mesh.surface_get_material(s)
		var key: String = MATERIAL_MAP.get(src.resource_name if src else "", "plant")
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, src_mesh.surface_get_arrays(s), [], {}, mat(key))
	im.generate_lods(25.0, 60.0, [])
	inst.free()
	return im.get_mesh()


func _scatter(center: Vector3, radius: float, count: int, scale: Vector2, min_r := 0.0) -> Array:
	var xf := []
	for i in count:
		var a := rng.randf() * TAU
		var r := lerpf(min_r, radius, sqrt(rng.randf()))
		var s := rng.randf_range(scale.x, scale.y)
		xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), center + Vector3(cos(a) * r, 0, sin(a) * r)))
	return xf


func _nature() -> void:
	# Trees in the garden beds (cast shadows into the courtyard)...
	var bed_trees := []
	for p: Vector3 in PLANTERS:
		bed_trees.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 1.25), p + Vector3(0, 0.62, 0)))
	multimesh("Trees_Beds", nature_mesh("CommonTree_3"), bed_trees)
	# ...and rows outside the walls rising above them (no shadows needed).
	# One MultiMesh per side so each chunk is culled and LOD'd on its own.
	var tree_meshes := [nature_mesh("CommonTree_3"), nature_mesh("CommonTree_5")]
	var rows := {"West": [], "East": [], "North": []}
	for side in [-1.0, 1.0]:
		var z := -56.0
		while z <= 22.0:
			rows["West" if side < 0 else "East"].append(Transform3D(
				Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.6, 2.1)),
				Vector3(side * rng.randf_range(38.0, 44.0), 0, z + rng.randf_range(-2.0, 2.0))))
			z += 9.0
	var x := -32.0
	while x <= 32.0:
		if absf(x) > 12.0:
			rows["North"].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.7, 2.2)),
				Vector3(x + rng.randf_range(-2, 2), 0, rng.randf_range(-60.0, -57.0))))
		x += 8.0
	for row: String in rows:
		var split := [[], []]
		for i in rows[row].size():
			split[i % 2].append(rows[row][i])
		for k in 2:
			if not split[k].is_empty():
				multimesh("Trees_%s_%d" % [row, k], tree_meshes[k], split[k], null, false)

	# Garden beds: flowering bushes, flowers and grass inside each bed.
	var bushes := []
	var flower_bushes := []
	var flowers_a := []
	var flowers_b := []
	var grass := []
	for p: Vector3 in PLANTERS:
		var soil := p + Vector3(0, 0.62, 0)
		for t in _scatter(soil, 2.4, 4, Vector2(0.55, 0.75), 1.3):
			(bushes if rng.randf() < 0.4 else flower_bushes).append(t)
		for t in _scatter(soil, 2.4, 4, Vector2(0.6, 0.8), 1.0):
			(flowers_a if rng.randf() < 0.5 else flowers_b).append(t)
		for t in _scatter(soil, 2.5, 18, Vector2(0.7, 1.1), 0.8):
			grass.append(t)
	# Flowers around the tank rim and bushes at the colonnade steps.
	for i in 10:
		var t := float(i) / 10.0
		var hc := TANK_HOLE.get_center()
		flowers_b.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 0.55),
			Vector3(hc.x - 6.2 + t * 12.4, 0.35, TANK_HOLE.position.y - 0.9)))
	for side in [-1.0, 1.0]:
		var z := -42.0
		while z <= 10.0:
			if z < SIDE_GATE_Z.x - 2.0 or z > SIDE_GATE_Z.y + 2.0:
				bushes.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 0.6), Vector3(28.2 * side, 0, z + 4.0)))
			z += 16.0
	multimesh("Bushes", nature_mesh("Bush_Common"), bushes, null, false)
	multimesh("FlowerBushes", nature_mesh("Bush_Common_Flowers"), flower_bushes, null, false)
	multimesh("Flowers_A", nature_mesh("Flower_3_Group"), flowers_a, null, false)
	multimesh("Flowers_B", nature_mesh("Flower_4_Group"), flowers_b, null, false)
	var grass_mmi := multimesh("Grass", nature_mesh("Grass_Common_Short"), grass, null, false)
	grass_mmi.visibility_range_end = 45.0
	# Potted tulsi by the shooting line.
	var pots := [at(-9.0, 0, 2.6), at(9.0, 0, 2.6)]
	multimesh("TulsiPots", MeshKit.cyl(0.35, 0.25, 0.6, 10), [at(-9.0, 0.3, 2.6), at(9.0, 0.3, 2.6)], mat("red_sandstone"))
	var tulsi := []
	for p in pots:
		tulsi.append((p as Transform3D).translated(Vector3(0, 0.6, 0)).scaled_local(Vector3.ONE * 0.5))
	multimesh("Tulsi", nature_mesh("Plant_1_Big"), tulsi, null, false)



# --- Archery butt mesh -----------------------------------------------------------------------------

## Straw butt on an A-frame stand, painted rings facing +Z (toward Rama's
## shooting line). Origin at the base so it topples from the ground.
func _build_archery_butt() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var face := Basis(Vector3.RIGHT, PI / 2)
	var center := Vector3(0, 1.15, 0)
	var add := func(mesh: Mesh, xf: Transform3D, color: Color) -> void:
		var tmp := SurfaceTool.new()
		tmp.create_from(mesh, 0)
		var arrays := tmp.commit_to_arrays()
		var n: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var colors := PackedColorArray()
		colors.resize(n)
		colors.fill(color)
		arrays[Mesh.ARRAY_COLOR] = colors
		var colored := ArrayMesh.new()
		colored.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		st.append_from(colored, 0, xf)
	add.call(MeshKit.cyl(0.62, 0.62, 0.35, 20), Transform3D(face, center), Color(0.85, 0.7, 0.38))
	var rings := [[0.56, Color(0.95, 0.93, 0.86)], [0.45, Color(0.12, 0.1, 0.1)], [0.34, Color(0.2, 0.35, 0.75)],
		[0.23, Color(0.75, 0.12, 0.1)], [0.11, Color(0.95, 0.75, 0.2)]]
	for i in rings.size():
		var r: float = rings[i][0]
		add.call(MeshKit.cyl(r, r, 0.02, 20), Transform3D(face, center + Vector3(0, 0, 0.18 + i * 0.006)), rings[i][1])
	for dx: float in [-0.45, 0.45]:
		add.call(MeshKit.cyl(0.04, 0.04, 1.6, 6), Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(dx, 0.75, -0.25)), Color(0.4, 0.25, 0.12))
	add.call(MeshKit.cyl(0.035, 0.035, 1.1, 6), Transform3D(Basis(Vector3.BACK, PI / 2), Vector3(0, 0.55, -0.1)), Color(0.4, 0.25, 0.12))
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, load(M + "butt_face.tres"))
	var err := ResourceSaver.save(mesh, OUT_BUTT)
	print("Saved %s: %s" % [OUT_BUTT, error_string(err)])
