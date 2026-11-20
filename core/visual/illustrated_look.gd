class_name IllustratedLook
extends Node
## The illustrated look (after the owner's reference clip): a violet dusk sky with a
## coral and gold horizon, golden stone with violet shadows, crimson, teal and gold
## accents, flat cel shading with hand-painted texture, ink lines and drifting petals.
##
## Add as a child of a level (StoryLevel does it when `illustrated` is set). It restyles
## the level's own geometry and environment in place, so layout, collisions, baked light
## and cutscene shots are unchanged. Characters keep their stylised bodies (the level sets
## Settings.style_override) and get a warmer rim, violet shadows and a firmer ink line.
## tools/shots/gate_slice.gd uses the same palette and shaders.

const TOON := "res://assets/shaders/toon_painted.gdshader"
const TEX := "res://assets/textures/painted/paint_%s.png"
const SHADOW_TINT := Color(0.58, 0.42, 0.8)
const RIM := Color(1.0, 0.8, 0.55)
const INK_SHADER := "res://assets/shaders/ink_edges.gdshader"
const SKY_SHADER := "res://assets/shaders/sky_painted.gdshader"

## Level materials (by resource path) -> [colour, painted texture, tiles per metre, paint strength, extras].
const LOOK := {
	"res://assets/materials/env/arch.tres": [Color(1, 1, 1), "stone", 0.25, 0.1, {"use_regions": 1.0,
		"region_base": Color(1.0, 0.8, 0.5), "region_r": Color(0.72, 0.1, 0.22),
		"region_g": Color(1.0, 0.9, 0.7), "region_b": Color(0.34, 0.2, 0.26)}],
	"res://assets/materials/env/red_sandstone.tres": [Color(0.74, 0.18, 0.2), "carving", 0.9, 0.2, {"vertex_shade": 0.0}],
	"res://assets/materials/env/sandstone.tres": [Color(1.0, 0.8, 0.5), "stone", 0.25, 0.1, {"vertex_shade": 0.0}],
	"res://assets/materials/env/marble.tres": [Color(1.0, 0.88, 0.64), "stone", 0.3, 0.08, {"vertex_shade": 0.0}],
	"res://assets/materials/env/dark_stone.tres": [Color(0.36, 0.22, 0.28), "stone", 0.3, 0.15, {"vertex_shade": 0.0}],
	"res://assets/materials/env/gold.tres": [Color(1.0, 0.74, 0.2), "gold", 1.0, 0.25, {"spec_strength": 1.4,
		"spec_size": 0.9, "rim_strength": 0.7, "vertex_shade": 0.0}],
	"res://assets/materials/env/cloth_red.tres": [Color(0.72, 0.1, 0.22), "cloth", 0.8, 0.35, {"vertex_shade": 0.0}],
	"res://assets/materials/env/wood.tres": [Color(0.45, 0.22, 0.12), "wood", 0.5, 0.35, {"vertex_shade": 0.0}],
	"res://assets/materials/env/hills.tres": [Color(0.32, 0.2, 0.4), "ground", 0.05, 0.2, {"vertex_shade": 0.0,
		"rim_strength": 0.0}],
}
## Paving keeps its own tile-and-medallion shader, recoloured.
const PAVING := {
	"stone_a": Color(0.9, 0.68, 0.48), "stone_b": Color(0.84, 0.62, 0.44), "grout": Color(0.82, 0.6, 0.43),
	"inlay_saffron": Color(1.0, 0.62, 0.12), "inlay_red": Color(0.72, 0.1, 0.22),
	"inlay_white": Color(1.0, 0.92, 0.74), "inlay_blue": Color(0.08, 0.42, 0.56),
}
## Foliage keeps its alpha-cut, wind-swayed shader, recoloured toward the dusk palette.
const FOLIAGE := {"tint": Color(0.62, 0.78, 0.6), "shadow_tint": Color(0.5, 0.38, 0.72),
	"rim_color": Color(1.0, 0.72, 0.42), "rim_strength": 0.45}

var _toon_cache := {}
var _ink: MeshInstance3D


func _ready() -> void:
	# After StyleSwitcher has applied the stylised look (it defers its first apply).
	await get_tree().process_frame
	await get_tree().process_frame
	var level := get_parent()
	_restyle_tree(level)
	_environment(level)
	_add_ink(level)
	_add_petals(level)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	# Characters, enemies and props that spawn later (waves, cutscene actors).
	if is_inside_tree() and node is GeometryInstance3D and get_parent().is_ancestor_of(node):
		_restyle_node.call_deferred(node)


func _restyle_tree(root: Node) -> void:
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		_restyle_node(gi)


func _restyle_node(node: Node) -> void:
	if not is_instance_valid(node) or node == _ink:
		return
	var gi := node as GeometryInstance3D
	if gi.material_override:
		var m := _swap(gi.material_override)
		if m != gi.material_override:
			gi.material_override = m
	var mi := node as MeshInstance3D
	if mi and mi.mesh:
		for s in mi.mesh.get_surface_count():
			var cur := mi.get_active_material(s)
			var m := _swap(cur)
			if m != cur:
				mi.set_surface_override_material(s, m)
	var mmi := node as MultiMeshInstance3D
	if mmi and mmi.multimesh and mmi.multimesh.mesh:
		var mesh := mmi.multimesh.mesh
		var changed := false
		var swapped: Array[Material] = []
		for s in mesh.get_surface_count():
			var cur := mesh.surface_get_material(s)
			var m := _swap(cur)
			swapped.append(m)
			changed = changed or m != cur
		if changed:
			# Copy the multimesh and mesh so the shared resources stay untouched for other levels.
			var mm := mmi.multimesh.duplicate() as MultiMesh
			mm.mesh = mesh.duplicate()
			for s in swapped.size():
				mm.mesh.surface_set_material(s, swapped[s])
			mmi.multimesh = mm


## Returns the illustrated replacement for a material, or the same material if none applies.
func _swap(m: Material) -> Material:
	if m == null:
		return m
	if _toon_cache.has(m):
		return _toon_cache[m]
	var out := m
	var path := m.resource_path
	var sm := m as ShaderMaterial
	var shader_path := sm.shader.resource_path if sm and sm.shader else ""
	if LOOK.has(path):
		var spec: Array = LOOK[path]
		out = make_toon(spec[0], spec[1], spec[2], spec[3], spec[4])
	elif shader_path.ends_with("paving.gdshader"):
		out = _recolour(sm, PAVING)
	elif shader_path.ends_with("toon_foliage.gdshader"):
		out = _recolour(sm, FOLIAGE)
	elif shader_path.ends_with("/toon.gdshader"):
		# Characters, enemies and small props on the toon shader: dusk rim, violet shadows, firm ink.
		out = sm.duplicate()
		out.set_shader_parameter("rim_strength", 0.7)
		out.set_shader_parameter("rim_color", RIM)
		out.set_shader_parameter("shadow_tint", SHADOW_TINT)
		var o := (out as ShaderMaterial).next_pass as ShaderMaterial
		if o:
			o = o.duplicate()
			o.set_shader_parameter("outline_width", 0.012)
			o.set_shader_parameter("outline_color", Color(0.2, 0.08, 0.18))
			(out as ShaderMaterial).next_pass = o
	_toon_cache[m] = out
	_toon_cache[out] = out
	return out


func _recolour(sm: ShaderMaterial, params: Dictionary) -> ShaderMaterial:
	var out := sm.duplicate() as ShaderMaterial
	for k in params:
		out.set_shader_parameter(k, params[k])
	return out


## A painted toon material in the illustrated palette (also used by the gate slice).
static func make_toon(colour: Color, tex: String, scale: float, strength: float, extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(TOON)
	m.set_shader_parameter("albedo", colour)
	m.set_shader_parameter("paint_tex", load(TEX % tex))
	m.set_shader_parameter("paint_scale", scale)
	m.set_shader_parameter("paint_strength", strength)
	m.set_shader_parameter("vertex_shade", 0.4)
	m.set_shader_parameter("band_softness", 0.02)
	m.set_shader_parameter("shadow_tint", SHADOW_TINT)
	m.set_shader_parameter("shadow_floor", 0.6)
	m.set_shader_parameter("rim_color", RIM)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	return m


## The painted dusk sky, violet ambient, coral haze and a low golden sun.
static func sky_material() -> ShaderMaterial:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SKY_SHADER)
	for kv in [["zenith", Color(0.1, 0.08, 0.3)], ["mid", Color(0.4, 0.24, 0.52)], ["horizon", Color(1.0, 0.6, 0.4)],
			["haze_warm", Color(1.0, 0.8, 0.42)], ["cloud_lit", Color(1.0, 0.72, 0.56)], ["cloud_shade", Color(0.48, 0.32, 0.56)],
			["hill_near", Color(0.2, 0.14, 0.3)], ["hill_far", Color(0.48, 0.3, 0.5)], ["cloud_cover", 0.36],
			["sun_dir", Vector3(-0.42, 0.1, -1.0)], ["sun_col", Color(1.0, 0.9, 0.62)], ["sun_size", 0.06], ["glow_amount", 0.85]]:
		sky_mat.set_shader_parameter(kv[0], kv[1])
	return sky_mat


static func apply_environment(e: Environment) -> void:
	var sky := Sky.new()
	sky.sky_material = sky_material()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.48, 0.8)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.76
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


func _environment(level: Node) -> void:
	var we := level.find_child("WorldEnvironment", false, false) as WorldEnvironment
	var sun := level.find_child("Sun", false, false) as DirectionalLight3D
	var switcher := level.find_child("StyleSwitcher", false, false)
	if we:
		var e := (we.environment.duplicate() if we.environment else Environment.new()) as Environment
		apply_environment(e)
		we.environment = e
		if switcher and "_stylised_env" in switcher:
			switcher._stylised_env = e
	if sun:
		sun.light_color = Color(1.0, 0.74, 0.42)
		sun.light_energy = 1.1
		if switcher and "_stylised_sun" in switcher and not switcher._stylised_sun.is_empty():
			switcher._stylised_sun["color"] = sun.light_color
			switcher._stylised_sun["energy"] = sun.light_energy


## Screen-space ink lines: one full-screen quad, drawn for whichever camera is current.
## Off on the Battery preset (one extra full-screen pass).
func _add_ink(level: Node) -> void:
	if Settings.quality == Settings.Quality.BATTERY:
		return
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	_ink = MeshInstance3D.new()
	_ink.name = "InkLines"
	_ink.mesh = q
	_ink.extra_cull_margin = 16384.0
	_ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = load(INK_SHADER)
	_ink.material_override = m
	level.add_child(_ink)


## Marigold and rose petals drifting over the courtyard, and fine gold motes.
func _add_petals(level: Node) -> void:
	var p := CPUParticles3D.new()
	p.name = "Petals"
	p.amount = 90 if Settings.quality == Settings.Quality.BATTERY else 140
	p.lifetime = 11.0
	p.preprocess = 11.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(26, 1, 30)
	p.position = Vector3(0, 13, -16)
	p.direction = Vector3(0.4, -1, 0.1)
	p.spread = 25.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0.12, -0.35, 0.05)
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
	level.add_child(p)
