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
	root.get_node("Settings").quality = 2
	root.get_node("Settings").apply_quality()
	var w := Node3D.new()
	root.add_child(w)

	var sky_mat: ShaderMaterial = load("res://assets/materials/env/sky_illustrated.tres").duplicate()
	sky_mat.set_shader_parameter("sun_size", 0.06)
	sky_mat.set_shader_parameter("zenith_color", Color(0.16, 0.12, 0.38))
	sky_mat.set_shader_parameter("rose_color", Color(0.92, 0.5, 0.38))
	sky_mat.set_shader_parameter("horizon_color", Color(0.96, 0.7, 0.3))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.45, 0.5)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.78
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_bloom = 0.14
	e.glow_hdr_threshold = 1.1
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.fog_enabled = true
	e.fog_light_color = Color(0.9, 0.58, 0.42)
	e.fog_density = 0.0018
	e.fog_aerial_perspective = 0.8
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.22
	e.adjustment_saturation = 1.18
	var we := WorldEnvironment.new()
	we.environment = e
	w.add_child(we)

	# Low sun BEHIND the gate (light travels toward the camera): silhouettes and rim light.
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.68, 0.28)
	sun.light_energy = 3.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	w.add_child(sun)
	sun.look_at_from_position(Vector3(-40, 9, -50), Vector3(0, 0, 0))
	# Soft cool-rose fill from the front so shadows keep colour.
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(1.0, 0.7, 0.32)
	fill.light_energy = 2.1
	fill.shadow_enabled = true
	fill.directional_shadow_max_distance = 160.0
	w.add_child(fill)
	fill.look_at_from_position(Vector3(-30, 14, 50), Vector3(0, 3, 0))

	var gate := (load("res://assets/arch/gate_slice.glb") as PackedScene).instantiate()
	w.add_child(gate)
	_nature(w)
	# Rama (stylised road look) faces the gate.
	var m = (load("res://characters/rama/rama_model.tscn") as PackedScene).instantiate()
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
			m.albedo_color = Color(0.1, 0.15, 0.2) if not nm.contains("Bark") else Color(0.2, 0.12, 0.16)
			m.backlight = Color(0.5, 0.3, 0.25)
			m.emission_enabled = true
			m.emission = Color(0.35, 0.2, 0.3)
			m.emission_energy_multiplier = 0.55 if not nm.contains("Bark") else 0.9
			mi.set_surface_override_material(s, m)
