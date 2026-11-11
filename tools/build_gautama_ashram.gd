extends "res://tools/build_kit.gd"
## Builds Gautama's ashram near Mithila (Bala Kanda, mission 6): a hermitage
## long untended. Kutirs with conical thatch, a fire altar, a well, a tulasi
## platform and a lotus pond, all overgrown. The level wakes three places
## (altar, well, tulasi), then the light gathers at the heart, where Ahalya
## has kept her unseen penance.
##
##   xvfb-run godot --rendering-driver opengl3 -s res://tools/build_gautama_ashram.gd

const HEART := Vector3(0, 0, -22)
const ALTAR := Vector3(-9, 0, -12)
const WELL := Vector3(10, 0, -10)
const TULASI := Vector3(2, 0, -32)
const POND := Vector3(-12, 0, -30)


func out_scene() -> String:
	return "res://kandas/01_bala/env/gautama_ashram.scn"


func build() -> void:
	rng.seed = 49
	_ground()
	_kutirs()
	_altar()
	_well()
	_tulasi()
	_pond()
	_paths()
	_trees()
	_overgrowth()
	_markers()


func _ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(110, 110)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = plane
	mi.position = Vector3(0, 0, -20)
	mi.material_override = mat("forest_floor")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env_root.add_child(mi)
	collider_box(Vector3(110, 1, 110), at(0, -0.5, -20))
	for spec in [[Vector3(1, 12, 110), at(-36, 6, -20)], [Vector3(1, 12, 110), at(36, 6, -20)],
			[Vector3(80, 12, 1), at(0, 6, 14)], [Vector3(80, 12, 1), at(0, 6, -56)]]:
		collider_box(spec[0], spec[1])
	# The swept earth of the ashram's heart.
	var disc := CylinderMesh.new()
	disc.top_radius = 9.0
	disc.bottom_radius = 9.0
	disc.height = 0.02
	disc.radial_segments = 32
	put(disc, at(HEART.x, 0.02, HEART.z), "forest_path")


## Round mud-walled huts with conical thatch roofs, doorways toward the heart.
func _kutirs() -> void:
	for spec in [[Vector3(-8, 0, -27), 3.0], [Vector3(8, 0, -26), 2.6], [Vector3(-2, 0, -40), 3.2]]:
		var c: Vector3 = spec[0]
		var r: float = spec[1]
		put(MeshKit.cyl(r + 0.25, r + 0.35, 0.3, 20), at(c.x, 0.15, c.z), "dark_stone")  # plinth
		put(MeshKit.cyl(r, r + 0.15, 2.4, 20), at(c.x, 1.2, c.z), "mud_plaster")
		collider_cyl(c, r + 0.1, 2.4)
		put(MeshKit.cyl(0.0, r + 0.9, 2.6, 20), at(c.x, 3.6, c.z), "thatch")
		var to := (HEART - c).normalized()
		var door := c + to * (r + 0.02)
		put(MeshKit.box(Vector3(1.0, 1.8, 0.1)), Transform3D(Basis(Vector3.UP, atan2(to.x, to.z)), door + Vector3.UP * 0.9), "dark_stone")


func _altar() -> void:
	var c := ALTAR
	for k in 3:
		var s := 2.6 - k * 0.6
		box(Vector3(s, 0.25, s), c + Vector3(0, 0.12 + k * 0.25, 0), "red_sandstone", Basis(), k == 0)
	box(Vector3(0.9, 0.12, 0.9), c + Vector3(0, 0.8, 0), "dark_stone")  # the cold hearth


func _well() -> void:
	var c := WELL
	for k in 16:
		var a := TAU * k / 16.0
		put(MeshKit.box(Vector3(0.55, 0.8, 0.35)), Transform3D(Basis(Vector3.UP, -a), c + Vector3(cos(a) * 1.3, 0.4, sin(a) * 1.3)), "sandstone")
	collider_cyl(c, 1.55, 0.8)
	for dx: float in [-1.3, 1.3]:
		put(MeshKit.box(Vector3(0.14, 2.0, 0.14)), at(c.x + dx, 1.0, c.z), "wood")
	put(MeshKit.box(Vector3(2.8, 0.14, 0.14)), at(c.x, 2.0, c.z), "wood")
	put(MeshKit.cyl(0.18, 0.15, 0.3, 10), at(c.x, 1.4, c.z), "red_sandstone")  # the pot on its rope


func _tulasi() -> void:
	var c := TULASI
	box(Vector3(1.4, 1.0, 1.4), c + Vector3(0, 0.5, 0), "sandstone", Basis(), true)
	box(Vector3(1.7, 0.15, 1.7), c + Vector3(0, 1.05, 0), "red_sandstone")
	multimesh("TulasiPlant", nature_mesh("Bush_Common"), [Transform3D(Basis().scaled(Vector3.ONE * 0.45), c + Vector3(0, 1.1, 0))], false)


func _pond() -> void:
	var c := POND
	box(Vector3(8.0, 0.3, 6.0), c + Vector3(0, 0.15, 0), "dark_stone", Basis(), true)
	var water := MeshInstance3D.new()
	water.name = "PondWater"
	water.mesh = MeshKit.box(Vector3(7.2, 0.04, 5.2))
	water.position = c + Vector3(0, 0.3, 0)
	water.material_override = mat("water")
	env_root.add_child(water)
	var lotus := []
	for i in 9:
		lotus.append(Transform3D(Basis().scaled(Vector3(1, 0.4, 1)), c + Vector3(rng.randf_range(-3, 3), 0.33, rng.randf_range(-2.2, 2.2))))
	var pad := MeshKit.cyl(0.32, 0.32, 0.02, 10)
	var mmi := multimesh("LotusPads", pad, lotus, false)
	mmi.material_override = mat("leaves_jungle")


func _paths() -> void:
	var stones := []
	for target in [Vector3(0, 0, 6), ALTAR, WELL, TULASI, POND]:
		var a := HEART
		var b: Vector3 = target
		var n := int(a.distance_to(b) / 0.75)
		for i in n:
			var p := a.lerp(b, float(i) / n) + Vector3(rng.randf_range(-0.2, 0.2), 0.01, rng.randf_range(-0.2, 0.2))
			stones.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rng.randf_range(0.28, 0.4), 0.1, rng.randf_range(0.22, 0.34))), p))
	var mmi := multimesh("PathStones", MeshKit.sphere(1.0, 8), stones, false)
	mmi.material_override = mat("pathrocks")


func _trees() -> void:
	var trees := []
	var twisted := []
	for i in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(24.0, 34.0)
		var p := HEART + Vector3(cos(a) * r, 0, sin(a) * r)
		if p.z > 8.0:
			continue
		(twisted if i % 3 == 0 else trees).append(rand_xf(p, Vector2(1.5, 2.2)))
	multimesh("Trees", nature_mesh("CommonTree_5"), trees, true)
	multimesh("TreesOld", nature_mesh("TwistedTree_1"), twisted, true)


## Creepers and scrub over everything: the level shrinks each patch as the
## place nearest it wakes (group "overgrowth", meta "place"), and grows the
## flowers and short grass waiting under it (group "bloom", built hidden).
func _overgrowth() -> void:
	var places := {"altar": ALTAR, "well": WELL, "tulasi": TULASI, "heart": HEART}
	var fern := nature_mesh("Fern_1")
	var bush := nature_mesh("Bush_Common")
	var flowers := [nature_mesh("Flower_3_Group"), nature_mesh("Flower_4_Group"), nature_mesh("Grass_Common_Short")]
	for key: String in places:
		var c: Vector3 = places[key]
		var xf_f := []
		var xf_b := []
		for i in 26:
			var a := rng.randf() * TAU
			var r := rng.randf_range(1.6, 6.5)
			var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
			(xf_f if i % 2 == 0 else xf_b).append(rand_xf(p, Vector2(0.9, 1.6)))
		for spec in [["Fern", fern, xf_f], ["Scrub", bush, xf_b]]:
			var mmi := multimesh("Overgrowth_%s_%s" % [key, spec[0]], spec[1], spec[2], false)
			mmi.add_to_group(&"overgrowth", true)
			mmi.set_meta(&"place", key)
		for f in flowers.size():
			var xf := []
			for i in 18:
				var a := rng.randf() * TAU
				# Knee-high, and clear of the heart where the scene is played.
				var rr := rng.randf_range(6.5, 8.5) if key == "heart" else rng.randf_range(1.8, 5.5)
				var p := c + Vector3(cos(a), 0, sin(a)) * rr
				xf.append(rand_xf(p, Vector2(0.22, 0.34) if f < 2 else Vector2(0.5, 0.8)))
			var bloom := multimesh("Bloom_%s_%d" % [key, f], flowers[f], xf, false)
			bloom.add_to_group(&"bloom", true)
			bloom.set_meta(&"place", key)
			bloom.scale = Vector3(1, 0.02, 1)
			bloom.visible = false


func _markers() -> void:
	for spec in [["Start", Vector3(0, 0, 6)], ["Heart", HEART], ["AhalyaSpot", HEART + Vector3(0, 0, -2.5)],
			["Altar", ALTAR + Vector3(2.0, 0, 1.0)], ["Well", WELL + Vector3(-2.2, 0, 0.5)], ["Tulasi", TULASI + Vector3(0, 0, 2.0)],
			["RamaSpot", HEART + Vector3(-0.6, 0, 1.6)], ["LakshmanaSpot", HEART + Vector3(1.4, 0, 2.2)],
			["SageSpot", HEART + Vector3(-2.6, 0, 3.0)], ["GautamaEntry", Vector3(14, 0, -44)],
			["GautamaSpot", HEART + Vector3(2.2, 0, -2.0)],
			["Leaf1", POND + Vector3(4.5, 0, 2.5)], ["Leaf2", Vector3(-8, 0, -23.5)], ["Leaf3", WELL + Vector3(2.5, 0, -2.5)]]:
		marker(spec[0], spec[1])
