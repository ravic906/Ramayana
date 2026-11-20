class_name IllustratedLook
extends Node
## The "premium clear" look for the trial level: a clean bright day (deep blue sky, soft
## clouds), warm ivory stone with crimson, teal and gold accents, saturated flat colour with
## soft cel shading, glossy gold, real soft shadows, full-resolution render and no ink lines,
## texture grain or haze, so everything reads crystal clear.
##
## Add as a child of a level (StoryLevel does it when `illustrated` is set). It restyles
## the level's own geometry and environment in place, so layout, collisions, baked light
## and cutscene shots are unchanged. Characters keep their stylised bodies (the level sets
## Settings.style_override) and get a warmer rim, violet shadows and a firmer ink line.
## tools/shots/gate_slice.gd uses the same palette and shaders.

const TOON := "res://assets/shaders/toon_painted.gdshader"
const TEX := "res://assets/textures/painted/paint_%s.png"
const SHADOW_TINT := Color(0.56, 0.6, 0.88)
const RIM := Color(1.0, 0.95, 0.82)
const INK_SHADER := "res://assets/shaders/ink_edges.gdshader"
const SKY_SHADER := "res://assets/shaders/sky_painted.gdshader"

## Level materials (by resource path) -> [colour, painted texture, tiles per metre, paint strength, extras].
## Paint strength is 0 everywhere: clean flat colour, no grain.
const LOOK := {
	"res://assets/materials/env/arch.tres": [Color(1, 1, 1), "stone", 0.25, 0.0, {"use_regions": 1.0,
		"region_base": Color(0.96, 0.86, 0.68), "region_r": Color(0.78, 0.1, 0.18),
		"region_g": Color(1.0, 0.97, 0.9), "region_b": Color(0.1, 0.45, 0.55)}],
	"res://assets/materials/env/red_sandstone.tres": [Color(0.8, 0.14, 0.18), "stone", 0.9, 0.0, {"vertex_shade": 0.0}],
	"res://assets/materials/env/sandstone.tres": [Color(0.98, 0.93, 0.84), "stone", 0.25, 0.0, {"vertex_shade": 0.0}],
	"res://assets/materials/env/marble.tres": [Color(1.0, 0.98, 0.94), "stone", 0.3, 0.0, {"vertex_shade": 0.0}],
	"res://assets/materials/env/dark_stone.tres": [Color(0.3, 0.26, 0.34), "stone", 0.3, 0.0, {"vertex_shade": 0.0}],
	"res://assets/materials/env/gold.tres": [Color(1.0, 0.76, 0.2), "gold", 1.0, 0.0, {"spec_strength": 1.6,
		"spec_size": 0.9, "rim_strength": 0.5, "vertex_shade": 0.0}],
	"res://assets/materials/env/cloth_red.tres": [Color(0.8, 0.1, 0.2), "cloth", 0.8, 0.0, {"vertex_shade": 0.0}],
	"res://assets/materials/env/wood.tres": [Color(0.5, 0.26, 0.14), "wood", 0.5, 0.0, {"vertex_shade": 0.0}],
	"res://assets/materials/env/hills.tres": [Color(0.46, 0.62, 0.7), "ground", 0.05, 0.0, {"vertex_shade": 0.0,
		"rim_strength": 0.0}],
}
## Paving keeps its own tile-and-medallion shader, recoloured with clear grout lines.
const PAVING := {
	"stone_a": Color(0.92, 0.76, 0.52), "stone_b": Color(0.86, 0.68, 0.46), "grout": Color(0.52, 0.38, 0.3),
	"inlay_saffron": Color(1.0, 0.6, 0.1), "inlay_red": Color(0.8, 0.1, 0.18),
	"inlay_white": Color(1.0, 0.97, 0.88), "inlay_blue": Color(0.06, 0.45, 0.6),
}
## Foliage keeps its alpha-cut, wind-swayed shader, recoloured toward the dusk palette.
const FOLIAGE := {"tint": Color(0.8, 1.0, 0.7), "shadow_tint": Color(0.45, 0.55, 0.75),
	"rim_color": Color(1.0, 0.95, 0.7), "rim_strength": 0.3}

var _toon_cache := {}


func _ready() -> void:
	# After StyleSwitcher has applied the stylised look (it defers its first apply).
	await get_tree().process_frame
	await get_tree().process_frame
	var level := get_parent()
	_restyle_tree(level)
	_environment(level)
	_crisp_render()
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	# Characters, enemies and props that spawn later (waves, cutscene actors).
	if is_inside_tree() and node is GeometryInstance3D and get_parent().is_ancestor_of(node):
		_restyle_node.call_deferred(node)


func _restyle_tree(root: Node) -> void:
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		_restyle_node(gi)


func _restyle_node(node: Node) -> void:
	if not is_instance_valid(node):
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
		# Characters, enemies and small props on the toon shader: clean rim and cool shadows, outline unchanged.
		out = sm.duplicate()
		out.set_shader_parameter("rim_strength", 0.45)
		out.set_shader_parameter("rim_color", RIM)
		out.set_shader_parameter("shadow_tint", SHADOW_TINT)
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
	for kv in [["zenith", Color(0.06, 0.26, 0.74)], ["mid", Color(0.22, 0.54, 0.95)], ["horizon", Color(0.78, 0.92, 1.0)],
			["haze_warm", Color(1.0, 0.95, 0.8)], ["cloud_lit", Color(1.0, 1.0, 1.0)], ["cloud_shade", Color(0.72, 0.8, 0.95)],
			["hill_near", Color(0.34, 0.55, 0.52)], ["hill_far", Color(0.62, 0.78, 0.9)], ["cloud_cover", 0.3],
			["sun_dir", Vector3(-0.35, 0.45, -1.0)], ["sun_col", Color(1.0, 0.97, 0.85)], ["sun_size", 0.05], ["glow_amount", 0.4]]:
		sky_mat.set_shader_parameter(kv[0], kv[1])
	return sky_mat


static func apply_environment(e: Environment) -> void:
	var sky := Sky.new()
	sky.sky_material = sky_material()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.7, 0.92)
	e.ambient_light_energy = 0.32
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.72
	e.glow_enabled = false
	e.fog_enabled = true
	e.fog_light_color = Color(0.8, 0.9, 1.0)
	e.fog_density = 0.0004
	e.fog_aerial_perspective = 0.0
	e.fog_sky_affect = 0.0
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.1
	e.adjustment_saturation = 1.2


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
		sun.light_color = Color(1.0, 0.95, 0.82)
		sun.light_energy = 0.95
		if switcher and "_stylised_sun" in switcher and not switcher._stylised_sun.is_empty():
			switcher._stylised_sun["color"] = sun.light_color
			switcher._stylised_sun["energy"] = sun.light_energy


## Full-resolution, smooth edges for this level (a clear picture beats a few frames per second here).
## Battery keeps its cheaper settings. Settings.apply_quality() restores the preset when the level closes.
func _crisp_render() -> void:
	if Settings.quality == Settings.Quality.BATTERY:
		return
	var vp := get_tree().root
	vp.scaling_3d_scale = 1.0
	vp.msaa_3d = Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA


func _exit_tree() -> void:
	if is_inside_tree() or get_tree() != null:
		Settings.apply_quality()
