extends SceneTree
## A 12 s slice in the illustrated look: a push-in on the Ayodhya gate
## (assets/arch/gate_slice.glb) with Rama in the foreground. Throwaway shot, not part of the game.
##   godot --rendering-driver vulkan --rendering-method mobile --write-movie out.avi \
##         --fixed-fps 30 --quit-after 372 -s res://tools/shots/gate_slice.gd
## FRAME=<n> saves a single still of that frame instead (STILL=path).
##
## Look: painted toon shading with world-projected hand-painted textures
## (assets/shaders/toon_painted.gdshader, tools/gen_painted_textures.py), screen-space ink
## lines (ink_edges.gdshader), a painted sky with hills (sky_painted.gdshader), falling petals.
## Lighting note: one directional light and no shadow map. On the software renderer used for
## these recordings a shadow map or a second directional light darkened the whole scene.

const FPS := 30.0
const LEN := 12.0
const TEX := "res://assets/textures/painted/paint_%s.png"
const TOON := "res://assets/shaders/toon_painted.gdshader"

## Per glTF material name: colour, painted texture, tiles per metre, paint strength, extras.
const LOOK := {
	"stone": [Color(1.0, 0.8, 0.5), "stone", 0.22, 0.08, {}],
	"marble": [Color(1.0, 0.86, 0.62), "stone", 0.3, 0.06, {}],
	"plaster": [Color(1.0, 0.84, 0.56), "carving", 0.9, 0.35, {}],
	"paving": [Color(0.94, 0.74, 0.52), "stone", 0.35, 0.1, {}],
	"paving2": [Color(0.86, 0.64, 0.46), "stone", 0.35, 0.1, {}],
	"mortar": [Color(0.6, 0.56, 0.52), "stone", 0.3, 0.2, {}],
	"red": [Color(0.72, 0.1, 0.22), "carving", 1.1, 0.12, {"rim_strength": 0.4}],
	"teal": [Color(0.08, 0.42, 0.56), "cloth", 0.9, 0.25, {}],
	"gold": [Color(1.0, 0.74, 0.2), "gold", 1.0, 0.25, {"spec_strength": 1.4, "spec_size": 0.9, "rim_strength": 0.7, "vertex_shade": 0.0}],
	"dark": [Color(0.32, 0.17, 0.1), "wood", 0.6, 0.3, {"vertex_shade": 0.3}],
	"wood": [Color(0.42, 0.2, 0.1), "wood", 0.5, 0.35, {}],
	"saffron": [Color(1.0, 0.5, 0.08), "cloth", 0.8, 0.35, {"vertex_shade": 0.0}],
	"carpet": [Color(0.95, 0.42, 0.08), "cloth", 0.6, 0.35, {"vertex_shade": 0.0}],
	"flame": [Color(1.0, 0.85, 0.4), "gold", 1.0, 0.0, {"glow": Color(1.0, 0.7, 0.25), "glow_energy": 2.4, "vertex_shade": 0.0}],
	"glow": [Color(1.0, 0.8, 0.4), "gold", 1.0, 0.0, {"glow": Color(1.0, 0.62, 0.2), "glow_energy": 1.4, "vertex_shade": 0.0}],
}

var cam: Camera3D
var frame := 0
var rama: Node3D
var _actors: Array[Node3D] = []


func _initialize() -> void:
	root.get_node("Settings").set_visual_style(0)
	root.get_node("Settings").quality = 2
	root.get_node("Settings").apply_quality()
	var w := Node3D.new()
	root.add_child(w)

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://assets/shaders/sky_painted.gdshader")
	for kv in [["zenith", Color(0.1, 0.08, 0.3)], ["mid", Color(0.4, 0.24, 0.52)], ["horizon", Color(1.0, 0.6, 0.4)],
			["haze_warm", Color(1.0, 0.8, 0.42)], ["cloud_lit", Color(1.0, 0.72, 0.56)], ["cloud_shade", Color(0.48, 0.32, 0.56)],
			["hill_near", Color(0.2, 0.14, 0.3)], ["hill_far", Color(0.48, 0.3, 0.5)], ["cloud_cover", 0.36],
			["sun_dir", Vector3(-0.42, 0.1, -1.0)], ["sun_col", Color(1.0, 0.9, 0.62)], ["sun_size", 0.06], ["glow_amount", 0.85]]:
		sky_mat.set_shader_parameter(kv[0], kv[1])
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.48, 0.8)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.85
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_bloom = 0.08
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.fog_enabled = true
	e.fog_light_color = Color(0.85, 0.55, 0.6)
	e.fog_density = 0.0016
	e.fog_aerial_perspective = 0.6
	e.fog_sky_affect = 0.0
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.08
	e.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = e
	w.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.74, 0.42)
	sun.light_energy = 1.35
	sun.shadow_enabled = false
	w.add_child(sun)
	_aim(sun, Vector3(-50, 16, 45), Vector3(0, 3, 0))  # low golden light on the faces

	var gate := (load("res://assets/arch/gate_slice.glb") as PackedScene).instantiate()
	w.add_child(gate)
	_paint(gate)
	_ground(w)
	_trees(w)
	_petals(w)
	_motes(w)

	# Rama, crowned at his father's gate, facing it (models face -Z).
	var lv := Node3D.new()
	lv.set_script(load("res://kandas/01_bala/story_level.gd"))
	w.add_child(lv)
	lv.princes_crowned = true
	rama = (load("res://characters/rama/rama_model.tscn") as PackedScene).instantiate()
	lv.add_child(rama)
	rama.position = Vector3(0.9, 0.0, 33.0)
	rama.rotation.y = -0.1
	_actors.append(rama)
	_people(w)

	cam = Camera3D.new()
	cam.fov = 46.0
	cam.current = true
	w.add_child(cam)
	_ink(cam)
	_place(0.0)


func _place(t: float) -> void:
	var k := smoothstep(0.0, 1.0, t / LEN)
	# A steady, tripod-like shot: a very slow straight push, no drift or tilt.
	cam.global_position = Vector3(-1.2, 2.3, lerpf(52.0, 48.0, k))
	if cam.is_inside_tree():
		cam.look_at(Vector3(0.2, 10.5, -4.0))


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 2:
		for a in _actors:
			_illustrate_character(a)
	_place(frame / FPS)
	var still := OS.get_environment("FRAME")
	if still != "" and frame == int(still):
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("STILL"))
		quit()
	return false


# --- Look -------------------------------------------------------------------

func _toon(colour: Color, tex: String, scale: float, strength: float, extra: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(TOON)
	m.set_shader_parameter("albedo", colour)
	m.set_shader_parameter("paint_tex", load(TEX % tex))
	m.set_shader_parameter("paint_scale", scale)
	m.set_shader_parameter("paint_strength", strength)
	m.set_shader_parameter("vertex_shade", 0.4)
	m.set_shader_parameter("band_softness", 0.02)
	m.set_shader_parameter("shadow_tint", Color(0.58, 0.42, 0.8))
	m.set_shader_parameter("shadow_floor", 0.6)
	m.set_shader_parameter("rim_color", Color(1.0, 0.8, 0.55))
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	return m


## Every surface of the Blender kit gets the painted toon material for its glTF material name.
func _paint(n: Node) -> void:
	var cache := {}
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var key: String = src.resource_name if src else ""
			if not LOOK.has(key):
				continue
			if not cache.has(key):
				var spec: Array = LOOK[key]
				cache[key] = _toon(spec[0], spec[1], spec[2], spec[3], spec[4])
			mi.set_surface_override_material(s, cache[key])


## Screen-space ink lines over everything the camera sees.
func _ink(c: Camera3D) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/ink_edges.gdshader")
	mi.material_override = m
	mi.position = Vector3(0, 0, -1)
	c.add_child(mi)


## Stylised characters: warmer rim, cool painted shadows and a firmer ink line.
func _illustrate_character(n: Node) -> void:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var mats: Array[Material] = []
		if mi.material_override:
			mats.append(mi.material_override)
		for s in mi.mesh.get_surface_count() if mi.mesh else 0:
			var sm := mi.get_active_material(s)
			if sm:
				mats.append(sm)
		for m in mats:
			var sm := m as ShaderMaterial
			if sm == null or sm.shader == null or not sm.shader.resource_path.ends_with("toon.gdshader"):
				continue
			sm.set_shader_parameter("rim_strength", 0.7)
			sm.set_shader_parameter("rim_color", Color(1.0, 0.94, 0.8))
			sm.set_shader_parameter("shadow_tint", Color(0.5, 0.58, 0.95))
			var o := sm.next_pass as ShaderMaterial
			if o:
				o.set_shader_parameter("outline_width", 0.012)
				o.set_shader_parameter("outline_color", Color(0.14, 0.07, 0.08))


# --- Set dressing -----------------------------------------------------------

func _ground(w: Node3D) -> void:
	var p := PlaneMesh.new()
	p.size = Vector2(700, 700)
	var mi := MeshInstance3D.new()
	mi.mesh = p
	mi.position = Vector3(0, -0.16, 0)
	mi.material_override = _toon(Color(0.42, 0.44, 0.26), "ground", 0.06, 0.25, {"vertex_shade": 0.0})
	w.add_child(mi)


func _trees(w: Node3D) -> void:
	var leaf := _toon(Color(0.12, 0.26, 0.28), "ground", 0.5, 0.3, {"vertex_shade": 0.0, "rim_strength": 0.6,
		"rim_color": Color(1.0, 0.7, 0.4)})
	var bark := _toon(Color(0.42, 0.28, 0.2), "wood", 0.4, 0.8, {"vertex_shade": 0.0})
	for spec in [["CommonTree_5", Vector3(-78, 0, -30), 8.0], ["CommonTree_3", Vector3(80, 0, -34), 8.0]]:
		var n := (load("res://assets/env/nature/" + spec[0] + ".gltf") as PackedScene).instantiate() as Node3D
		n.position = spec[1]
		n.scale = Vector3.ONE * spec[2]
		w.add_child(n)
		for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(s)
				var nm: String = src.resource_name if src else ""
				mi.set_surface_override_material(s, bark if nm.contains("Bark") else leaf)


## Marigold and rose petals drifting down over the courtyard.
func _petals(w: Node3D) -> void:
	var p := CPUParticles3D.new()
	p.amount = 110
	p.lifetime = 11.0
	p.preprocess = 11.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(22, 1, 18)
	p.position = Vector3(0, 13, 30)
	p.direction = Vector3(0.4, -1, 0.1)
	p.spread = 25.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0.12, -0.35, 0.05)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -35.0
	p.angular_velocity_max = 35.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.55, 0.05), Color(1.0, 0.75, 0.1), Color(0.95, 0.3, 0.4), Color(1.0, 0.92, 0.85)])
	p.color_initial_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.mesh = q
	w.add_child(p)


## Fine gold motes in the sunlight.
func _motes(w: Node3D) -> void:
	var d := CPUParticles3D.new()
	d.amount = 70
	d.lifetime = 8.0
	d.preprocess = 8.0
	d.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	d.emission_box_extents = Vector3(24, 5, 22)
	d.position = Vector3(0, 5, 26)
	d.spread = 180.0
	d.initial_velocity_min = 0.05
	d.initial_velocity_max = 0.2
	d.gravity = Vector3.ZERO
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.9, 0.6, 0.85)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	d.mesh = q
	w.add_child(d)


## Gate guards in crimson and gold with spears, and two townswomen in the courtyard.
func _people(w: Node3D) -> void:
	var npc := load("res://characters/npc/npc_model.tscn") as PackedScene
	for spec in [[Vector3(-5.6, 0, 18.6)], [Vector3(5.6, 0, 18.6)], [Vector3(-8.6, 0, 18.2)], [Vector3(8.6, 0, 18.2)]]:
		var g = npc.instantiate()
		g.garment = Color(0.78, 0.1, 0.14)
		g.trim = Color(1.0, 0.74, 0.2)
		g.sash = Color(0.98, 0.95, 0.9)
		g.skin = Color(0.62, 0.42, 0.3)
		g.staff = true
		g.speaker = "Guard"
		g.position = spec[0]
		g.rotation.y = PI  # face the courtyard
		w.add_child(g)
		_actors.append(g)
	var woman := load("res://characters/npc/npc_woman.tscn") as PackedScene
	for spec in [[Vector3(-7.5, 0, 28.0), 0.6, Color(0.05, 0.5, 0.56)], [Vector3(8.0, 0, 26.5), -0.5, Color(0.95, 0.4, 0.55)]]:
		var t = woman.instantiate()
		if "garment" in t:
			t.garment = spec[2]
			t.trim = Color(1.0, 0.74, 0.2)
		t.position = spec[0]
		t.rotation.y = spec[1]
		w.add_child(t)
		_actors.append(t)


## look_at_from_position needs the node inside the tree, which it is not yet in _initialize.
func _aim(n: Node3D, from: Vector3, to: Vector3) -> void:
	n.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)
