extends "res://tools/build_forest.gd"
## Builds Siddhashrama, Vishvamitra's hermitage (Bala Kanda, mission 5): a
## forest clearing with thatched huts round the yagna altar, at night.
## Reuses the forest builder's helpers (materials, merging, tree cells, proxies).
##
##   xvfb-run godot --rendering-driver opengl3 -s res://tools/build_ashram.gd
##
## Output: res://kandas/01_bala/env/siddhashrama.scn
## Layout: the altar is at the origin; Rama arrives from the south (+Z); the
## rakshasas come down three lanes from the north, west and east.

const ASHRAM_SCENE := "res://kandas/01_bala/env/siddhashrama.scn"
const CLEAR_R := 24.0
const LANES := {
	"N": [Vector3(0, 0, -62), Vector3(0, 0, -21)],
	"W": [Vector3(-62, 0, -6), Vector3(-21, 0, -2)],
	"E": [Vector3(62, 0, 8), Vector3(21, 0, 3)],
}
const LANE_HALF := 3.6
const HUT_ANGLES := [35.0, 62.0, 122.0, 152.0, -35.0, -62.0, -122.0, -152.0]  # degrees from +Z
const SAGE_ANGLES := [40.0, 100.0, 160.0, -40.0, -100.0, -160.0]


func _initialize() -> void:
	rng.seed = 5105
	env_root = Node3D.new()
	env_root.name = "Siddhashrama"
	body = StaticBody3D.new()
	body.name = "Collision"
	env_root.add_child(body)
	_ashram_ground()
	_altar()
	_huts()
	_flush()
	_ashram_trees()
	_ashram_undergrowth()
	_night_life()
	_ashram_markers()
	print("Lightmap UVs: %d meshes" % LightmapUV.unwrap_all(env_root, 0.4))
	_own(env_root, env_root)
	var packed := PackedScene.new()
	var err := packed.pack(env_root)
	if err == OK:
		err = ResourceSaver.save(packed, ASHRAM_SCENE, ResourceSaver.FLAG_COMPRESS)
	print("Saved %s: %s" % [ASHRAM_SCENE, error_string(err)])
	quit(0 if err == OK else 1)


func _dist_to_lanes(p: Vector3) -> float:
	var best := INF
	for key: String in LANES:
		var a: Vector3 = LANES[key][0]
		var b: Vector3 = LANES[key][1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := a + ab * t
		best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
	return best


func _dir(deg: float) -> Vector3:
	return Vector3(sin(deg_to_rad(deg)), 0, cos(deg_to_rad(deg)))


# --- Ground --------------------------------------------------------------------------

func _ashram_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(220, 220)
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "ForestFloor"
	floor_mi.mesh = plane
	floor_mi.position = Vector3(0, 0, -10)
	floor_mi.material_override = mat("forest_floor")
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env_root.add_child(floor_mi)
	collider_box(Vector3(220, 1, 220), at(0, -0.5, -10))
	# Swept earth of the clearing.
	var disc := CylinderMesh.new()
	disc.top_radius = CLEAR_R
	disc.bottom_radius = CLEAR_R
	disc.height = 0.02
	disc.radial_segments = 40
	var earth := MeshInstance3D.new()
	earth.name = "AshramEarth"
	earth.mesh = disc
	earth.position = Vector3.UP * 0.02
	earth.material_override = mat("forest_path")
	earth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env_root.add_child(earth)
	# Lanes into the forest (and the path Rama arrives on, from the south).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lanes: Array = LANES.values() + [[Vector3(0, 0, 40), Vector3(0, 0, 20)]]
	for lane in lanes:
		var a: Vector3 = lane[0]
		var b: Vector3 = lane[1]
		var side := (b - a).normalized().cross(Vector3.UP) * LANE_HALF
		var y := Vector3.UP * 0.03
		var quad := [[a - side + y, 0.0], [a + side + y, 1.0], [b + side + y, 1.0], [b - side + y, 0.0]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(quad[idx][1], 0.0))
			st.add_vertex(quad[idx][0])
	var lane_mi := MeshInstance3D.new()
	lane_mi.name = "Lanes"
	lane_mi.mesh = st.commit()
	lane_mi.material_override = mat("forest_path")
	lane_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env_root.add_child(lane_mi)
	# Boundary.
	collider_box(Vector3(1, 12, 140), at(-66, 6, -10))
	collider_box(Vector3(1, 12, 140), at(66, 6, -10))
	collider_box(Vector3(140, 12, 1), at(0, 6, 44))
	collider_box(Vector3(140, 12, 1), at(0, 6, -66))


# --- The yagna altar -------------------------------------------------------------------

func _altar() -> void:
	# A stepped brick fire pit (kund).
	for step in [[3.4, 0.0], [2.7, 0.3], [2.0, 0.6]]:
		var box := BoxMesh.new()
		box.size = Vector3(step[0], 0.3, step[0])
		put(box, at(0, step[1] + 0.15, 0), "red_sandstone")
	var pit := BoxMesh.new()
	pit.size = Vector3(1.3, 0.04, 1.3)
	put(pit, at(0, 0.92, 0), "dark_stone")
	collider_box(Vector3(3.4, 0.9, 3.4), at(0, 0.45, 0))
	# Yupa posts at the corners, and offering pots.
	var post := CylinderMesh.new()
	post.top_radius = 0.09
	post.bottom_radius = 0.13
	post.height = 3.2
	post.radial_segments = 8
	for c in [Vector3(-3, 0, -3), Vector3(3, 0, -3), Vector3(-3, 0, 3), Vector3(3, 0, 3)]:
		put(post, at(c.x, 1.6, c.z), "bark")
		collider_cyl(c, 0.15, 3.2)
	var pot := SphereMesh.new()
	pot.radius = 0.24
	pot.height = 0.4
	pot.radial_segments = 10
	pot.rings = 6
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		put(pot, at(cos(a) * 2.3, 0.2, sin(a) * 2.3), "red_sandstone")
	# Kusha-grass mats where the sages sit.
	var mat_mesh := BoxMesh.new()
	mat_mesh.size = Vector3(1.0, 0.03, 0.7)
	for deg: float in SAGE_ANGLES:
		var p := _dir(deg) * 5.0
		put(mat_mesh, Transform3D(Basis(Vector3.UP, deg_to_rad(deg)), p + Vector3.UP * 0.02), "thatch")


# --- Huts ----------------------------------------------------------------------------

func _huts() -> void:
	var wall := CylinderMesh.new()
	wall.top_radius = 2.1
	wall.bottom_radius = 2.2
	wall.height = 2.0
	wall.radial_segments = 14
	var roof := CylinderMesh.new()
	roof.top_radius = 0.05
	roof.bottom_radius = 3.0
	roof.height = 2.3
	roof.radial_segments = 14
	var door := BoxMesh.new()
	door.size = Vector3(0.9, 1.5, 0.12)
	for i in HUT_ANGLES.size():
		var deg: float = HUT_ANGLES[i]
		var c := _dir(deg) * rng.randf_range(16.5, 19.0)
		var face := Basis(Vector3.UP, deg_to_rad(deg) + PI)  # door toward the altar
		put(wall, Transform3D(face, c + Vector3.UP * 1.0), "sandstone")
		put(roof, Transform3D(face, c + Vector3.UP * 3.1), "thatch")
		put(door, Transform3D(face, c + Vector3.UP * 0.75 + face * Vector3(0, 0, -2.12)), "dark_stone")
		collider_cyl(c, 2.25, 3.0)


# --- Forest round the clearing ----------------------------------------------------------

func _ashram_trees() -> void:
	var jungle := nature_mesh("CommonTree_5")
	var jungle_b := nature_mesh("CommonTree_3")
	var twisted := nature_mesh("CommonTree_5")
	var near := {"a": [], "b": []}
	var far := {"a": [], "b": []}
	var x := -64.0
	while x <= 64.0:
		var z := 40.0
		while z >= -64.0:
			var p := Vector3(x + rng.randf_range(-2.5, 2.5), 0, z + rng.randf_range(-2.5, 2.5))
			var d := Vector2(p.x, p.z).length()
			var south_path := absf(p.x) < LANE_HALF + 2.0 and p.z > CLEAR_R - 2.0
			if d > CLEAR_R + 3.0 and _dist_to_lanes(p) > LANE_HALF + 2.0 and not south_path:
				var key := "a" if rng.randf() < 0.5 else "b"
				if d < CLEAR_R + 16.0:
					near[key].append(rand_xf(p, Vector2(1.5, 2.1)))
					collider_cyl(p, 0.6, 6.0)
				else:
					far[key].append(rand_xf(p, Vector2(1.7, 2.3)))
			z -= 6.5
		x += 6.5
	var far_meshes := {"a": far_mesh("CommonTree_5"), "b": far_mesh("CommonTree_3")}
	tree_cells("Trees_Near_A", jungle, far_meshes["a"], near["a"])
	tree_cells("Trees_Near_B", jungle_b, far_meshes["b"], near["b"])
	for side in ["a", "b"]:
		var cells := _cells(far[side], FAR_CELL)
		for key: String in cells:
			var cell := multimesh("Trees_Far_%s_%s" % [side, key], far_meshes[side], cells[key], false)
			cell.visibility_range_end = FAR_FOG_RANGE
	twisted = null


func _ashram_undergrowth() -> void:
	var ferns := []
	var rocks := []
	for i in 70:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * (CLEAR_R + rng.randf_range(0.5, 3.5))
		if _dist_to_lanes(p) > LANE_HALF + 0.5 and not (absf(p.x) < LANE_HALF and p.z > 0):
			ferns.append(rand_xf(p, Vector2(0.9, 1.5)))
	for key: String in LANES:
		var a: Vector3 = LANES[key][0]
		var b: Vector3 = LANES[key][1]
		for t in range(1, 8):
			var p := a.lerp(b, t / 8.0)
			var side := (b - a).normalized().cross(Vector3.UP)
			for s in [-1.0, 1.0]:
				ferns.append(rand_xf(p + side * s * rng.randf_range(LANE_HALF + 0.3, LANE_HALF + 2.0), Vector2(0.9, 1.4)))
			if rng.randf() < 0.3:
				rocks.append(rand_xf(p + side * (LANE_HALF + 1.2) * (1 if rng.randf() < 0.5 else -1), Vector2(0.8, 1.5), 0.4))
	multimesh("Ferns", nature_mesh("Fern_1"), ferns, false).visibility_range_end = 60.0
	multimesh("Rocks", nature_mesh("Rock_Medium_2"), rocks)


func _night_life() -> void:
	# Fireflies over the clearing's edge.
	var flies := CPUParticles3D.new()
	flies.name = "Fireflies"
	flies.amount = 60
	flies.lifetime = 6.0
	flies.preprocess = 6.0
	flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	flies.emission_ring_axis = Vector3.UP
	flies.emission_ring_radius = CLEAR_R + 2.0
	flies.emission_ring_inner_radius = CLEAR_R - 6.0
	flies.emission_ring_height = 3.0
	flies.direction = Vector3.UP
	flies.spread = 180.0
	flies.gravity = Vector3.ZERO
	flies.initial_velocity_min = 0.1
	flies.initial_velocity_max = 0.4
	flies.mesh = FX.glow_quad(Color(0.85, 1.0, 0.45, 0.9), 0.05)
	flies.position = Vector3.UP * 1.5
	env_root.add_child(flies)
	# Low night mist in the forest beyond the huts.
	for i in 4:
		var p := CPUParticles3D.new()
		p.name = "Mist%d" % i
		p.amount = 10
		p.lifetime = 14.0
		p.preprocess = 14.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(14, 0.5, 14)
		p.direction = Vector3(1, 0, 0.2)
		p.gravity = Vector3.ZERO
		p.initial_velocity_min = 0.1
		p.initial_velocity_max = 0.3
		var q := QuadMesh.new()
		q.size = Vector2(8, 3)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(0.5, 0.56, 0.7, 0.14)
		m.albedo_texture = FX._soft_dot()
		q.material = m
		p.mesh = q
		p.position = _dir(45.0 + 90.0 * i) * (CLEAR_R + 12.0) + Vector3.UP * 0.6
		env_root.add_child(p)


func _ashram_markers() -> void:
	var specs := [
		["Altar", Vector3.ZERO],
		["RamaStart", Vector3(0, 0, 15)],
		["SpawnN", Vector3(0, 0, -42)],
		["SpawnW", Vector3(-42, 0, -4)],
		["SpawnE", Vector3(42, 0, 6)],
		["SkyEntry", Vector3(0, 14, -40)],
		["SeaDirection", Vector3(-420, 80, 360)],
	]
	for i in SAGE_ANGLES.size():
		specs.append(["Sage%d" % i, _dir(SAGE_ANGLES[i]) * 5.0])
	for i in HUT_ANGLES.size():
		specs.append(["Hut%d" % i, _dir(HUT_ANGLES[i]) * 17.5])
	for spec in specs:
		var m := Marker3D.new()
		m.name = spec[0]
		m.position = spec[1]
		env_root.add_child(m)
