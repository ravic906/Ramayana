extends "res://tools/build_kit.gd"
## Builds Vishala at evening (Bala Kanda, mission 6): the city of King Sumati,
## of the line of Ikshvaku's son Vishala. A street from the south gate past a
## market and houses, a temple and its garden to the east, the king's palace
## and forecourt to the north, the north gate to the west of it.
##
##   xvfb-run godot --rendering-driver opengl3 -s res://tools/build_vishala.gd
##
## Rama enters at the south gate (Start) facing north (-Z).

const STREET_HALF := 4.5
const PALACE_Z := -62.0
const TEMPLE := Vector3(20, 0, -14)
const GARDEN := Vector3(22, 0, 4)


func out_scene() -> String:
	return "res://kandas/01_bala/env/vishala.scn"


func build() -> void:
	rng.seed = 610
	_ground()
	_walls_and_gates()
	_houses()
	_market()
	_temple()
	_garden()
	_palace()
	lamps(_lamp_points(), 2)
	_trees()
	_markers()


func _ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 140)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = plane
	mi.position = Vector3(0, 0, -20)
	mi.material_override = mat("forest_path")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	env_root.add_child(mi)
	collider_box(Vector3(120, 1, 140), at(0, -0.5, -20))
	# The paved street and the forecourt.
	var paving := PlaneMesh.new()
	paving.size = Vector2(STREET_HALF * 2.0, 84)
	put(paving, at(0, 0.02, -13), "paving")
	var court := PlaneMesh.new()
	court.size = Vector2(44, 22)
	put(court, at(0, 0.025, PALACE_Z + 13), "paving")


func _walls_and_gates() -> void:
	# The city wall's south and west runs, with the gates.
	for x: float in [-30.0, -18.0, -8.5, 8.5, 18.0, 30.0]:
		if absf(x) < 8.0:
			continue
		box(Vector3(10.0 if absf(x) > 20 else 8.0, 6.5, 1.6), Vector3(x, 3.25, 31), "red_sandstone", Basis(), true)
	# South gate: two towers and a lintel.
	for side: float in [-1.0, 1.0]:
		box(Vector3(3.0, 9.0, 3.0), Vector3(side * 6.0, 4.5, 31), "sandstone", Basis(), true)
		put(MeshKit.cyl(0.0, 1.9, 2.6, 8), at(side * 6.0, 10.3, 31), "red_sandstone")
	box(Vector3(9.0, 1.4, 2.6), Vector3(0, 8.0, 31), "sandstone")
	# Side walls of the street block (the city beyond).
	box(Vector3(1.6, 6.5, 100), Vector3(-34, 3.25, -20), "red_sandstone", Basis(), true)
	box(Vector3(1.6, 6.5, 100), Vector3(36, 3.25, -20), "red_sandstone", Basis(), true)
	box(Vector3(70, 6.5, 1.6), Vector3(0, 3.25, PALACE_Z - 9.5), "red_sandstone", Basis(), true)
	# The north gate, west of the palace, opening on the road to Mithila.
	var ng := Vector3(-26, 0, PALACE_Z + 4)
	box(Vector3(3.0, 8.0, 3.0), ng + Vector3(-3.2, 4.0, 0), "sandstone", Basis(), true)
	box(Vector3(3.0, 8.0, 3.0), ng + Vector3(3.2, 4.0, 0), "sandstone", Basis(), true)
	box(Vector3(9.4, 1.2, 3.0), ng + Vector3(0, 7.2, 0), "sandstone")
	box(Vector3(3.4, 5.6, 0.25), ng + Vector3(0, 2.8, -1.4), "wood")


## Two-storey houses with balconies and doorways, lining the street.
func _houses() -> void:
	var z := 24.0
	var i := 0
	while z > -44.0:
		for side: float in [-1.0, 1.0]:
			if side > 0 and z < -2 and z > -30:
				continue  # the temple's side
			var w := rng.randf_range(6.0, 8.5)
			var d := 7.0
			var h := rng.randf_range(5.5, 7.5)
			var c := Vector3(side * (STREET_HALF + 1.5 + d * 0.5), 0, z)
			var stone := "sandstone" if i % 3 != 0 else "red_sandstone"
			box(Vector3(d, h, w - 0.4), c + Vector3(0, h * 0.5, 0), stone, Basis(), true)
			# Door, windows, balcony toward the street.
			var face := c.x - side * d * 0.5
			box(Vector3(0.2, 2.2, 1.3), Vector3(face - side * 0.05, 1.1, z), "dark_stone")
			for wz: float in [-w * 0.28, w * 0.28]:
				box(Vector3(0.2, 0.9, 0.8), Vector3(face - side * 0.05, h * 0.7, z + wz), "dark_stone")
			box(Vector3(1.0, 0.18, w * 0.7), Vector3(face - side * 0.5, h * 0.55, z), "wood")
			for k in 4:
				box(Vector3(0.06, 0.7, 0.06), Vector3(face - side * 0.95, h * 0.55 + 0.38, z - w * 0.3 + k * w * 0.2), "wood")
			# A parapet and a small domed chhatri on some roofs.
			box(Vector3(d + 0.3, 0.5, w), c + Vector3(0, h + 0.25, 0), "marble")
			if i % 4 == 1:
				put(MeshKit.sphere(1.0, 12), Transform3D(Basis().scaled(Vector3(1, 0.7, 1)), c + Vector3(0, h + 1.2, 0)), "marble")
			i += 1
		z -= 9.0


## Stalls with awnings: cloth, pots, grain, flowers.
func _market() -> void:
	var cloths := ["cloth_red", "banner", "cloth_red", "banner"]
	var k := 0
	for z: float in [14.0, 6.0, -2.0, -10.0]:
		for side: float in [-1.0, 1.0]:
			if side > 0 and z < -2:
				continue
			var c := Vector3(side * (STREET_HALF - 0.6), 0, z)
			box(Vector3(1.4, 0.8, 3.0), c + Vector3(0, 0.4, 0), "wood", Basis(), true)
			for dz: float in [-1.4, 1.4]:
				box(Vector3(0.1, 2.4, 0.1), c + Vector3(side * 0.6, 1.2, dz), "wood")
			box(Vector3(2.0, 0.05, 3.4), c + Vector3(-side * 0.1, 2.4, 0), cloths[k % cloths.size()], Basis(Vector3.BACK, side * 0.18))
			# Wares.
			for w in 3:
				var p := c + Vector3(0, 0.85, -1.0 + w)
				match (k + w) % 3:
					0: put(MeshKit.sphere(0.22, 10), Transform3D(Basis().scaled(Vector3(1, 0.9, 1)), p + Vector3.UP * 0.18), "red_sandstone")
					1: put(MeshKit.cyl(0.0, 0.3, 0.3, 10), Transform3D(Basis(), p + Vector3.UP * 0.15), "straw")
					2: put(MeshKit.cyl(0.18, 0.15, 0.25, 10), Transform3D(Basis(), p + Vector3.UP * 0.12), "wood")
			k += 1


## A temple of the city: a raised plinth, a pillared hall, a tall shikhara.
func _temple() -> void:
	var c := TEMPLE
	box(Vector3(12, 1.0, 14), c + Vector3(0, 0.5, 0), "sandstone", Basis(), true)
	for s in 3:
		box(Vector3(4, 0.33, 1.0), c + Vector3(-6.5 - s * 0.0, 0.17 + 0.33 * s - 0.33, 0) + Vector3(-s * 0.0, 0, 0), "sandstone")
	box(Vector3(2.0, 1.0, 4.0), c + Vector3(-6.8, 0.25, 0), "sandstone", Basis(), true)
	# Hall (mandapa) facing the street.
	for x: float in [-4.5, -1.5]:
		for zz: float in [-3.0, 0.0, 3.0]:
			put(MeshKit.cyl(0.25, 0.3, 3.2, 10), at(c.x + x, 2.6, c.z + zz), "red_sandstone")
	box(Vector3(5.0, 0.4, 8.0), c + Vector3(-3.0, 4.4, 0), "sandstone")
	# Sanctum with the shikhara.
	box(Vector3(5.0, 3.6, 5.0), c + Vector3(2.5, 2.8, 0), "red_sandstone", Basis(), true)
	for k in 7:
		var s := 5.4 - k * 0.65
		box(Vector3(s, 0.75, s), c + Vector3(2.5, 5.0 + k * 0.75, 0), "sandstone")
	put(MeshKit.sphere(0.7, 12), Transform3D(Basis().scaled(Vector3(1, 0.6, 1)), c + Vector3(2.5, 10.6, 0)), "sandstone")
	put(MeshKit.cyl(0.0, 0.18, 0.9, 8), at(c.x + 2.5, 11.4, c.z), "gold")
	box(Vector3(0.2, 2.2, 1.4), c + Vector3(0.0, 2.1, 0), "dark_stone")  # the sanctum door
	# Bells at the entrance.
	for zz: float in [-1.2, 1.2]:
		put(MeshKit.cyl(0.04, 0.12, 0.2, 10), at(c.x - 4.5, 3.6, c.z + zz), "gold")


func _garden() -> void:
	var c := GARDEN
	box(Vector3(12, 0.4, 10), c + Vector3(0, 0.2, 0), "dark_stone")
	var beds := []
	for i in 30:
		beds.append(rand_xf(c + Vector3(rng.randf_range(-5, 5), 0.4, rng.randf_range(-4, 4)), Vector2(0.8, 1.2)))
	multimesh("GardenFlowers", nature_mesh("Flower_4_Group"), beds, false, 60.0)
	put(MeshKit.cyl(0.6, 0.7, 0.9, 12), Transform3D(Basis(), c + Vector3(0, 0.85, 0)), "sandstone")  # a tulasi platform
	multimesh("Tulasi", nature_mesh("Bush_Common"), [Transform3D(Basis().scaled(Vector3.ONE * 0.5), c + Vector3(0, 1.3, 0))], false)


## King Sumati's palace: steps, a pillared porch, upper storeys with domes.
func _palace() -> void:
	var c := Vector3(0, 0, PALACE_Z)
	box(Vector3(30, 1.4, 12), c + Vector3(0, 0.7, -1), "sandstone", Basis(), true)
	for s in 4:
		box(Vector3(12, 0.35, 0.9), c + Vector3(0, 0.17 + s * 0.35, 5.0 + (3 - s) * 0.9), "sandstone", Basis(), true)
	for x: float in [-9.0, -5.0, -1.5, 1.5, 5.0, 9.0]:
		put(MeshKit.cyl(0.32, 0.38, 4.6, 12), at(c.x + x, 3.7, c.z + 4.2), "marble")
	box(Vector3(22, 0.6, 3.0), c + Vector3(0, 6.3, 4.2), "red_sandstone")
	box(Vector3(26, 8.0, 8.0), c + Vector3(0, 5.4, -2), "red_sandstone", Basis(), true)
	box(Vector3(16, 4.0, 6.0), c + Vector3(0, 11.4, -2.5), "sandstone")
	for x: float in [-11.0, 0.0, 11.0]:
		put(MeshKit.sphere(2.2 if x == 0.0 else 1.6, 14), Transform3D(Basis().scaled(Vector3(1, 0.75, 1)), c + Vector3(x, 14.2 if x == 0.0 else 10.2, -2.5)), "marble")
		put(MeshKit.cyl(0.0, 0.15, 1.2, 8), at(c.x + x, 16.6 if x == 0.0 else 12.2, c.z - 2.5), "gold")
	box(Vector3(3.0, 4.0, 0.3), c + Vector3(0, 3.4, 2.05), "wood")  # the great door
	# A tank in the forecourt.
	var t := c + Vector3(0, 0, 15)
	box(Vector3(8.4, 0.5, 5.4), t + Vector3(0, 0.25, 0), "sandstone", Basis(), true)
	var water := MeshInstance3D.new()
	water.mesh = MeshKit.box(Vector3(7.6, 0.05, 4.6))
	water.position = t + Vector3(0, 0.48, 0)
	water.material_override = mat("water")
	env_root.add_child(water)


func _lamp_points() -> Array:
	var ps := []
	var z := 22.0
	while z > -48.0:
		for side: float in [-1.0, 1.0]:
			ps.append(Vector3(side * (STREET_HALF + 0.3), 0, z))
		z -= 12.0
	for x: float in [-6.5, 6.5]:
		ps.append(Vector3(x, 0, PALACE_Z + 7.0))
	ps.append(TEMPLE + Vector3(-7.5, 0, -2.5))
	ps.append(TEMPLE + Vector3(-7.5, 0, 2.5))
	return ps


func _trees() -> void:
	var trees := []
	for p in [Vector3(-14, 0, PALACE_Z + 14), Vector3(14, 0, PALACE_Z + 14), GARDEN + Vector3(6, 0, -6), GARDEN + Vector3(-5, 0, 6),
			Vector3(-28, 0, 20), Vector3(28, 0, 22), Vector3(-26, 0, -40), Vector3(30, 0, -40)]:
		trees.append(rand_xf(p, Vector2(1.6, 2.0)))
		collider_cyl(p, 0.6, 5.0)
	multimesh("Trees", nature_mesh("CommonTree_3"), trees, true)


func _markers() -> void:
	var t := TEMPLE
	for spec in [["Start", Vector3(0, 0, 27)], ["Welcome", Vector3(0, 0, PALACE_Z + 9)],
			["KingSpot", Vector3(0, 1.4, PALACE_Z + 5.5)], ["SageSpot", Vector3(-2.0, 0, PALACE_Z + 11)],
			["Weaver", Vector3(-STREET_HALF + 1.6, 0, 9.5)], ["OilSeller", Vector3(STREET_HALF - 1.6, 0, 4.0)],
			["Priest", t + Vector3(-5.6, 1.0, 0.0)], ["TempleLamp", t + Vector3(-4.6, 1.0, 2.2)],
			["Garden", GARDEN], ["GuestHouse", Vector3(-STREET_HALF - 1.2, 0, -26)],
			["NorthGate", Vector3(-26, 0, PALACE_Z + 7)],
			["Folk1", Vector3(-2.5, 0, 16)], ["Folk2", Vector3(2.8, 0, 2)], ["Folk3", Vector3(-1.5, 0, -18)],
			["Folk4", Vector3(3.0, 0, -32)], ["Folk5", Vector3(-6, 0, PALACE_Z + 16)], ["Folk6", GARDEN + Vector3(-3, 0, 4)],
			["Leaf1", t + Vector3(-6.5, 1.0, -3.2)], ["Leaf2", Vector3(-STREET_HALF - 0.4, 0, -36)],
			["Leaf3", Vector3(9, 0, PALACE_Z + 15)], ["Leaf4", GARDEN + Vector3(4.5, 0.4, 3.5)]]:
		marker(spec[0], spec[1])
