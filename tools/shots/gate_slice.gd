extends SceneTree
## A 12 s slice: golden-hour push-in on the Ayodhya gate (assets/arch/gate_slice.glb)
## with Rama in the foreground. Throwaway shot, not part of the game.
##   godot --rendering-driver vulkan --rendering-method mobile --write-movie out.avi \
##         --fixed-fps 30 --quit-after 360 -s res://tools/shots/gate_slice.gd
## FRAME=<n> saves a single still of that frame instead (STILL=path).

const FPS := 30.0
const LEN := 12.0
var cam: Camera3D
var frame := 0
var rama: Node3D


func _initialize() -> void:
	root.get_node("Settings").set_visual_style(0)
	if OS.get_environment("NOQ") != "1":
		root.get_node("Settings").quality = 2
		root.get_node("Settings").apply_quality()
	var w := Node3D.new()
	root.add_child(w)

	var sky_mat: ShaderMaterial = load("res://assets/materials/env/sky_illustrated.tres").duplicate()
	sky_mat.set_shader_parameter("sun_size", 0.06)
	sky_mat.set_shader_parameter("zenith_color", Color(0.07, 0.2, 0.6))
	sky_mat.set_shader_parameter("rose_color", Color(0.3, 0.56, 0.92))
	sky_mat.set_shader_parameter("cloud_light", Color(1.0, 1.0, 1.0))
	sky_mat.set_shader_parameter("cloud_shadow", Color(0.72, 0.8, 0.92))
	sky_mat.set_shader_parameter("horizon_color", Color(0.78, 0.9, 1.0))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY if OS.get_environment("NOSKY") != "1" else Environment.BG_COLOR
	if OS.get_environment("NOSKY") != "1":
		e.sky = sky
	else:
		e.background_color = Color(0.3, 0.5, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.62, 0.8)
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.88
	e.glow_enabled = OS.get_environment("NOGLOW") != "1"
	e.glow_intensity = 0.7
	e.glow_bloom = 0.14
	e.glow_hdr_threshold = 1.1
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.fog_enabled = OS.get_environment("NOFOG") != "1"
	e.fog_light_color = Color(0.72, 0.84, 0.96)
	e.fog_density = 0.0012
	e.fog_aerial_perspective = 0.8
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.2
	e.adjustment_saturation = 1.32
	if OS.get_environment("AMB") != "":
		e.ambient_light_energy = float(OS.get_environment("AMB"))
	if OS.get_environment("MINENV") == "1":
		e = Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.3, 0.5, 0.9)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_energy = 0.0
	var we := WorldEnvironment.new()
	we.environment = e
	w.add_child(we)

	# Low sun BEHIND the gate (light travels toward the camera): silhouettes and rim light.
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.light_energy = 0.85
	sun.shadow_enabled = (OS.get_environment("SHADOW") == "1")
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_bias = 0.2
	sun.shadow_normal_bias = 2.0
	w.add_child(sun)
	_aim(sun, Vector3(-34, 34, 52), Vector3(0, 3, 0))
	if OS.get_environment("SUNROT") == "1":
		sun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-50), deg_to_rad(30), 0)), Vector3.ZERO)
	# Soft cool-rose fill from the front so shadows keep colour.
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(1.0, 0.92, 0.78)
	fill.light_energy = 0.5
	fill.shadow_enabled = false
	fill.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	fill.directional_shadow_max_distance = 120.0
	fill.shadow_bias = 0.08
	fill.shadow_normal_bias = 1.5
	if OS.get_environment("FILL") == "1":  # a second directional light darkens the scene on this renderer; off
		w.add_child(fill)
	_aim(fill, Vector3(30, 20, -50), Vector3(0, 3, 0))

	var gate := (load("res://assets/arch/gate_slice.glb") as PackedScene).instantiate()
	w.add_child(gate)
	_use_vertex_colors(gate)
	if OS.get_environment("NONAT") != "1":
		_nature(w)
	# Rama (stylised road look) faces the gate.
	var m = Node3D.new() if OS.get_environment("NORAMA") == "1" else (load("res://characters/rama/rama_model.tscn") as PackedScene).instantiate()
	var lv := Node3D.new()
	lv.set_script(load("res://kandas/01_bala/story_level.gd"))
	w.add_child(lv)
	lv.princes_crowned = true  # a prince at his father's gate
	lv.add_child(m)
	rama = m
	rama.position = Vector3(0.9, 0.0, 33.0)
	rama.rotation.y = -0.1  # faces the gate (-Z)

	cam = Camera3D.new()
	cam.fov = 46.0
	cam.current = true
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 60.0
	attrs.dof_blur_far_transition = 40.0
	attrs.dof_blur_amount = 0.03
	w.add_child(cam)
	_place(0.0)


func _place(t: float) -> void:
	var k := smoothstep(0.0, 1.0, t / LEN)
	cam.global_position = Vector3(lerpf(-6.0, -2.0, k), lerpf(1.8, 2.4, k), lerpf(68.0, 44.0, k))
	cam.look_at(Vector3(lerpf(0.0, 0.4, k), lerpf(13.0, 11.0, k), -4.0))


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 3:
		for l in root.find_children("*", "DirectionalLight3D", true, false):
			print("LIGHT ", l.name, " fwd=", -l.global_transform.basis.z, " e=", l.light_energy, " col=", l.light_color, " cull=", l.light_cull_mask, " shadow=", l.shadow_enabled)
	_place(frame / FPS)
	var still := OS.get_environment("FRAME")
	if still != "" and frame == int(still):
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("STILL"))
		quit()
	return false


## Trees behind and beside the walls, grass, rocks and drifting dust: the gate is old and lived-in.
func _nature(w: Node3D) -> void:
	var N := "res://assets/env/nature/"
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var place := func(file: String, p: Vector3, s: float, ry: float) -> void:
		var n := (load(N + file + ".gltf") as PackedScene).instantiate() as Node3D
		n.position = p
		n.scale = Vector3.ONE * s
		n.rotation.y = ry
		w.add_child(n)
		_light_foliage(n)
	for spec in [["CommonTree_5", Vector3(-62, 0, 20), 9.0], ["CommonTree_3", Vector3(64, 0, 18), 9.0]]:
		place.call(spec[0], spec[1], spec[2], rng.randf() * TAU)
	for i in 0:
		var x := rng.randf_range(-16, 16)
		var z := rng.randf_range(5.5, 28)
		if abs(x) < 1.5 and z < 14:
			continue
		place.call(["Grass_Common_Short", "Fern_1", "Flower_3_Group", "Grass_Common_Short"][i % 4],
			Vector3(x, 0.0, z), rng.randf_range(0.5, 0.9), rng.randf() * TAU)
	for i in 0:
		place.call(["Rock_Medium_1", "Rock_Medium_2", "Pebble_Round_2"][i % 3],
			Vector3(rng.randf_range(-16, 16), 0.0, rng.randf_range(8, 24)), rng.randf_range(0.3, 0.6), rng.randf() * TAU)
	# Dust and pollen drifting in the low sun.
	var dust := CPUParticles3D.new()
	dust.amount = 90
	dust.lifetime = 8.0
	dust.preprocess = 8.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(24, 5, 22)
	dust.position = Vector3(0, 5, 22)
	dust.direction = Vector3(0.3, 0.1, -0.2)
	dust.spread = 180.0
	dust.initial_velocity_min = 0.1
	dust.initial_velocity_max = 0.35
	dust.gravity = Vector3.ZERO
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(1.0, 0.85, 0.55, 0.8)
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = dm
	dust.mesh = q
	w.add_child(dust)


## Backlit foliage: leaves glow warmly instead of going black against the low sun.
func _light_foliage(n: Node) -> void:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			var nm := src.resource_name
			if not (nm.contains("Leaves") or nm.contains("Grass") or nm.contains("Flowers") or nm.contains("Plant") or nm.contains("Bark")):
				continue
			var m := src.duplicate() as BaseMaterial3D
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.backlight_enabled = true
			m.albedo_color = Color(0.2, 0.38, 0.14) if not nm.contains("Bark") else Color(0.32, 0.2, 0.14)
			m.backlight = Color(0.3, 0.4, 0.15)
			m.emission_enabled = true
			m.emission = Color(0.05, 0.1, 0.04)
			m.emission_energy_multiplier = 0.55 if not nm.contains("Bark") else 0.9
			mi.set_surface_override_material(s, m)


## The imported glTF materials do not take diffuse light correctly here; rebuild plain
## StandardMaterial3D copies carrying the same colour, gloss and glow.
func _rebuild_materials(n: Node) -> void:
	var cache := {}
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			if not cache.has(src):
				var m := StandardMaterial3D.new()
				m.albedo_color = src.albedo_color
				m.metallic = src.metallic
				m.roughness = src.roughness
				m.clearcoat_enabled = src.clearcoat_enabled
				m.clearcoat = src.clearcoat
				m.clearcoat_roughness = src.clearcoat_roughness
				m.emission_enabled = src.emission_enabled
				m.emission = src.emission
				m.emission_energy_multiplier = src.emission_energy_multiplier
				cache[src] = m
			mi.set_surface_override_material(s, cache[src])


## look_at_from_position needs the node inside the tree, which it is not yet in _initialize.
func _aim(n: Node3D, from: Vector3, to: Vector3) -> void:
	n.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)


## The baked form shading and marble veining live in the vertex colours; switch them on.
func _use_vertex_colors(n: Node) -> void:
	var cache := {}
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			if not cache.has(src):
				var m := src.duplicate() as BaseMaterial3D
				m.vertex_color_use_as_albedo = true
				cache[src] = m
			mi.set_surface_override_material(s, cache[src])
