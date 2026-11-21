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
## All pictures come from Gemini art made for this game (assets/art/gemini, sources in art_source/gemini).

const TOON := "res://assets/shaders/toon_painted.gdshader"
const TEX := "res://assets/art/gemini/%s.png"
## Mean brightness of each texture, so only its light/dark detail is applied.
const TEX_MEAN := {"marble": 0.919, "gold": 0.642, "cloth": 0.53}
const SHADOW_TINT := Color(0.66, 0.52, 0.56)  # warm mauve shade, golden hour
const RIM := Color(1.0, 0.86, 0.62)
const CHAR_SHADER := "res://assets/shaders/toon_character.gdshader"
const INK_SHADER := "res://assets/shaders/ink_edges.gdshader"
const SKY_SHADER := "res://assets/shaders/sky_painted.gdshader"

## Level materials (by resource path) -> [colour, painted texture, tiles per metre, paint strength, extras].
## Paint strength is 0 everywhere: clean flat colour, no grain.
const MAROON := Color(0.36, 0.09, 0.1)
const IVORY := Color(0.85, 0.78, 0.66)
const SANDSTONE := Color(0.84, 0.73, 0.59)
const ANTIQUE_GOLD := Color(0.74, 0.55, 0.24)
const TEAL := Color(0.1, 0.33, 0.36)
const SAFFRON := Color(0.86, 0.5, 0.18)
const LOOK := {
	"res://assets/materials/env/arch.tres": [Color(1, 1, 1), "marble", 0.25, 0.3, {"use_regions": 1.0,
		"region_base": IVORY, "region_r": MAROON, "region_g": ANTIQUE_GOLD, "region_b": TEAL}],
	"res://assets/materials/env/red_sandstone.tres": [MAROON, "marble", 0.9, 0.3, {"vertex_shade": 0.0}],
	"res://assets/materials/env/sandstone.tres": [SANDSTONE, "marble", 0.25, 0.3, {"vertex_shade": 0.0}],
	"res://assets/materials/env/marble.tres": [IVORY, "marble", 0.3, 0.3, {"vertex_shade": 0.0}],
	"res://assets/materials/env/dark_stone.tres": [Color(0.32, 0.25, 0.24), "marble", 0.3, 0.3, {"vertex_shade": 0.0}],
	"res://assets/materials/env/gold.tres": [ANTIQUE_GOLD, "gold", 1.0, 0.45, {"spec_strength": 1.6,
		"spec_size": 0.9, "rim_strength": 0.5, "vertex_shade": 0.0, "glow": Color(0.95, 0.7, 0.3), "glow_energy": 0.9}],
	"res://assets/materials/env/cloth_red.tres": [MAROON, "cloth", 0.8, 0.45, {"vertex_shade": 0.0}],
	"res://assets/materials/env/wood.tres": [Color(0.42, 0.26, 0.17), "marble", 0.5, 0.3, {"vertex_shade": 0.0}],
	"res://assets/materials/env/hills.tres": [Color(0.7, 0.62, 0.52), "marble", 0.05, 0.3, {"vertex_shade": 0.0,
		"rim_strength": 0.0}],
}
## Paving keeps its own tile-and-medallion shader, recoloured with clear grout lines.
const PAVING := {
	# Desaturated sandstone: close tones, thin low-contrast grout, soft variation and a faint polish.
	"stone_a": Color(0.64, 0.55, 0.44), "stone_b": Color(0.58, 0.5, 0.4), "grout": Color(0.47, 0.4, 0.32),
	"grout_width": 0.007, "grout_soft": 0.014, "tile_variation": 0.1, "mottle": 0.06, "sheen": 0.12,
	"inlay_saffron": Color(0.86, 0.52, 0.2), "inlay_red": Color(0.48, 0.13, 0.14),
	"inlay_white": Color(0.93, 0.89, 0.8), "inlay_blue": Color(0.1, 0.36, 0.4),
	"shadow_tint": Color(0.62, 0.52, 0.56),
	"medallion_radius": 0.01,  # the Gemini medallion is laid over the old procedural one
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
	# No painted backdrop: the level's own 3D gate stands, ringed by 3D temple silhouettes that
	# fade into the warm haze of a gradient sky.
	_hide_old_horizon(level)
	_remove_placeholders(level)
	_add_distant_temples(level)
	_add_prop_cutouts(level)
	_batch_cutouts(level)
	UiSkin.apply(level.get_node_or_null("HUD"))
	_add_medallion(level)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is TargetDummy and is_inside_tree():
		_dress_target.call_deferred(node)
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
			var m := _swap_character(cur) if mi.skin != null else _swap(cur)
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


## A generated character's painted texture on the shared two-band cel shader with a soft rim.
func _swap_character(m: Material) -> Material:
	var st := m as StandardMaterial3D
	if st == null or st.albedo_texture == null:
		return _swap(m)
	if _toon_cache.has(m):
		return _toon_cache[m]
	var out := ShaderMaterial.new()
	out.shader = load(CHAR_SHADER)
	out.set_shader_parameter("albedo_tex", st.albedo_texture)
	if st.normal_enabled and st.normal_texture:
		out.set_shader_parameter("normal_tex", st.normal_texture)
		out.set_shader_parameter("use_normal", true)
	out.set_shader_parameter("shadow_tint", SHADOW_TINT)
	out.set_shader_parameter("rim_color", RIM)
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
	m.set_shader_parameter("tex_mean_lum", TEX_MEAN.get(tex, 0.5))
	m.set_shader_parameter("paint_scale", scale)
	m.set_shader_parameter("paint_strength", strength)
	m.set_shader_parameter("vertex_shade", 0.4)
	m.set_shader_parameter("band_softness", 0.06)
	m.set_shader_parameter("two_band", 1.0)
	m.set_shader_parameter("rim_strength", 0.3)
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
	# Golden hour: deep teal-blue overhead warming to ivory and saffron at the horizon, a few soft
	# clouds; the painted hills are kept faint (the 3D temples carry the horizon).
	for kv in [["zenith", Color(0.15, 0.33, 0.52)], ["mid", Color(0.46, 0.6, 0.7)], ["horizon", Color(0.95, 0.84, 0.67)],
			["haze_warm", Color(0.99, 0.8, 0.58)], ["cloud_lit", Color(1.0, 0.9, 0.78)], ["cloud_shade", Color(0.74, 0.66, 0.68)],
			["hill_near", Color(0.86, 0.74, 0.62)], ["hill_far", Color(0.92, 0.82, 0.68)], ["cloud_cover", 0.16],
			["sun_dir", Vector3(-0.5, 0.57, 0.6)], ["sun_col", Color(1.0, 0.88, 0.62)], ["sun_size", 0.04], ["glow_amount", 0.55]]:
		sky_mat.set_shader_parameter(kv[0], kv[1])
	return sky_mat


## Golden hour: a warm low sun, filmic (ACES) tone, a light warm haze in the distance, glow only on
## what is brighter than white (the gold, whose emission lifts it there). No SSAO: the Mobile renderer
## has none; the level's baked lightmap carries the ambient occlusion.
static func apply_environment(e: Environment) -> void:
	var sky := Sky.new()
	sky.sky_material = sky_material()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.7, 0.62)
	e.ambient_light_energy = 0.42
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.0
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.glow_strength = 0.9
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.15
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.fog_enabled = true
	e.fog_light_color = Color(0.95, 0.84, 0.67)  # the sky's horizon colour: no hard edge
	e.fog_light_energy = 1.0
	e.fog_density = 0.002
	e.fog_aerial_perspective = 0.25
	e.fog_sky_affect = 0.25
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.05
	e.adjustment_saturation = 1.08


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
		# Golden hour: warm, about 35 degrees above the horizon, from the front-left of the gate,
		# with soft shadows.
		sun.rotation_degrees = Vector3(-35.0, 40.0, 0.0)
		sun.light_color = Color(1.0, 0.8, 0.58)
		sun.light_energy = 1.25
		sun.shadow_enabled = true
		sun.shadow_blur = 2.0
		# Shadows only near the action (cheaper on phones; distant buildings keep their baked shade).
		sun.directional_shadow_max_distance = 40.0 if Settings.quality == Settings.Quality.HIGH else 25.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		if we and we.environment and we.environment.sky:
			(we.environment.sky.sky_material as ShaderMaterial).set_shader_parameter("sun_dir", sun.global_basis.z)
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


## The Gemini-made palace gate (assets/art/gemini/gate_front.png) as a painted backdrop far behind the
## courtyard's north wall: a flat cut-out, drawn unlit so its own painted light stays as made.
func _add_backdrop(level: Node) -> void:
	var tex := load("res://assets/art/gemini/gate_front.png") as Texture2D
	if tex == null:
		return
	var width := 118.0
	var q := QuadMesh.new()
	q.size = Vector2(width, width * tex.get_height() / tex.get_width())
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.fog_disabled = true
	q.material = m
	var mi := MeshInstance3D.new()
	mi.name = "PalaceBackdrop"
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, q.size.y * 0.5 - 1.0, -88.0)
	level.add_child(mi)


## The Gemini-made city panorama (assets/art/gemini/skyline.png) on a curved wall far behind the
## palace gate, so the horizon is Ayodhya instead of empty sky. Unlit, as painted.
func _add_skyline(level: Node) -> void:
	var tex := load("res://assets/art/gemini/skyline.png") as Texture2D
	if tex == null:
		return
	var radius := 330.0
	var arc := deg_to_rad(230.0)
	var repeats := 2  # the picture is mirrored side by side so its edges meet
	var height := radius * arc * float(tex.get_height()) / float(tex.get_width()) / repeats
	var seg := 96
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in seg + 1:
		var f := float(i) / seg
		var a := -arc * 0.5 + arc * f  # centred on north (-Z)
		var x := sin(a) * radius
		var z := -cos(a) * radius
		verts.append(Vector3(x, -2.0, z))
		verts.append(Vector3(x, height - 2.0, z))
		var u := absf(fposmod(f * repeats, 2.0) - 1.0)
		uvs.append(Vector2(u, 1.0))
		uvs.append(Vector2(u, 0.0))
	for i in seg:
		var b := i * 2
		idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.fog_disabled = true
	var mi := MeshInstance3D.new()
	mi.name = "CitySkyline"
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(mi)


## The Gemini-made inlaid medallion (assets/art/gemini/medallion.png) on the courtyard floor.
func _add_medallion(level: Node) -> void:
	var tex := load("res://assets/art/gemini/medallion.png") as Texture2D
	if tex == null:
		return
	var q := QuadMesh.new()
	q.size = Vector2(19.0, 19.0)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # keeps its painted colours, like the floor around it
	m.albedo_texture = tex
	m.albedo_color = Color(1.0, 0.96, 0.88)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var mi := MeshInstance3D.new()
	mi.name = "GeminiMedallion"
	mi.mesh = q
	mi.material_override = m
	mi.position = Vector3(0.0, 0.04, -28.0)
	level.add_child(mi)


## The Gemini gate replaces our own procedural gate tower, north wall and distant city blocks:
## hide them (visual only; their colliders stay, so the courtyard still ends at the same wall).
## Placeholder blocks: the red posts with yellow spheres at the south steps and the red strip on
## the floor at the shooting line. The spheres and the strip go; the posts are cut out of the south
## wall's merged mesh (the railing stays). Visual only: colliders are untouched.
func _remove_placeholders(level: Node) -> void:
	var env := level.get_node_or_null("Environment")
	if env == null:
		return
	var range_line := env.get_node_or_null("Range/Arch") as Node3D
	if range_line:
		range_line.visible = false
	var spheres := env.get_node_or_null("South/Gold") as MeshInstance3D
	var wall := env.get_node_or_null("South/Arch") as MeshInstance3D
	if spheres == null or wall == null or spheres.mesh == null:
		return
	spheres.visible = false
	# Each sphere sits on a post: remove the wall triangles in the column under each sphere.
	var centres := []
	for v: Vector3 in spheres.mesh.get_faces():
		var w := spheres.global_transform * v
		var found := false
		for c in centres:
			if Vector2(c.x - w.x, c.z - w.z).length() < 1.0:
				found = true
				break
		if not found:
			centres.append(w)
	var src := wall.mesh as ArrayMesh
	if src == null:
		return
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var a := src.surface_get_arrays(s)
		var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		var tri_count := idx.size() / 3 if idx.size() > 0 else verts.size() / 3
		for tri in tri_count:
			var ids := [idx[tri * 3], idx[tri * 3 + 1], idx[tri * 3 + 2]] if idx.size() > 0 else [tri * 3, tri * 3 + 1, tri * 3 + 2]
			var cen := wall.global_transform * ((verts[ids[0]] + verts[ids[1]] + verts[ids[2]]) / 3.0)
			var in_post := false
			for c in centres:
				if absf(cen.x - c.x) < 0.75 and absf(cen.z - c.z) < 0.75 and cen.y < c.y:
					in_post = true
					break
			if not in_post:
				keep.append_array(PackedInt32Array(ids))
		if idx.size() == 0:
			continue
		a[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		out.surface_set_material(out.get_surface_count() - 1, wall.get_active_material(s))
	if out.get_surface_count() > 0:
		wall.mesh = out


## The level's grey hill cones and box skyline give way to the temple ring (visual only).
func _hide_old_horizon(level: Node) -> void:
	var env := level.get_node_or_null("Environment")
	for n in ["Skyline", "Hills"]:
		var node := env.get_node_or_null(n) as Node3D if env else null
		if node:
			node.visible = false


func _hide_old_gate(level: Node) -> void:
	var env := level.get_node_or_null("Environment")
	if env == null:
		return
	for n in ["North", "Skyline", "Hills"]:
		var node := env.get_node_or_null(n) as Node3D
		if node:
			node.visible = false


## A ring of 3D temple silhouettes (tiered shikhara on a plinth, a gold kalasha) far beyond the
## walls, all merged into one mesh (one draw call); the distance fog fades them into the horizon.
func _add_distant_temples(level: Node) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := 34
	for i in n:
		var ang := TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / n
		var dist := rng.randf_range(120.0, 230.0)
		var centre := Vector3(sin(ang) * dist, 0.0, -cos(ang) * dist)
		var s := rng.randf_range(0.8, 1.6) * (1.3 if absf(ang - PI) > 2.4 else 1.0)
		var w := 7.0 * s
		var h := 18.0 * s
		_part(st, BoxMesh.new(), Vector3(w * 1.6, 5.0 * s, w * 1.6), Transform3D(Basis(), centre + Vector3(0, 2.5 * s, 0)))
		# Tiered spire: three tapering drums, then the amalaka and kalasha.
		var y := 5.0 * s
		for k in 3:
			var c := CylinderMesh.new()
			c.top_radius = w * (0.5 - k * 0.12)
			c.bottom_radius = w * (0.62 - k * 0.12)
			c.height = h * (0.38 - k * 0.07)
			c.radial_segments = 8
			_part(st, c, Vector3.ONE, Transform3D(Basis(), centre + Vector3(0, y + c.height * 0.5, 0)))
			y += c.height
		var tip := CylinderMesh.new()
		tip.top_radius = 0.0
		tip.bottom_radius = w * 0.2
		tip.height = h * 0.25
		tip.radial_segments = 8
		_part(st, tip, Vector3.ONE, Transform3D(Basis(), centre + Vector3(0, y + tip.height * 0.5, 0)))
		# Smaller corner spires (urushringa) on two sides.
		for side in [-1.0, 1.0]:
			var u := CylinderMesh.new()
			u.top_radius = 0.0
			u.bottom_radius = w * 0.28
			u.height = h * 0.45
			u.radial_segments = 8
			var off := Basis(Vector3.UP, ang) * Vector3(side * w * 0.75, 0, 0)
			_part(st, u, Vector3.ONE, Transform3D(Basis(), centre + off + Vector3(0, 5.0 * s + u.height * 0.5, 0)))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "DistantTemples"
	mi.mesh = st.commit()
	# Warm sandstone that melts into the horizon colour with distance (aerial perspective), lit softly.
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_back, fog_disabled;
uniform vec3 near_col : source_color = vec3(0.72, 0.6, 0.49);
uniform vec3 far_col : source_color = vec3(0.95, 0.84, 0.67);
varying float fade;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fade = smoothstep(90.0, 260.0, length(w.xz)) * 0.75 + 0.25 * smoothstep(0.0, 40.0, w.y);
}
void fragment() {
	float lit = 0.82 + 0.18 * clamp(dot(NORMAL, normalize(vec3(-0.5, 0.6, 0.4))), 0.0, 1.0);
	ALBEDO = vec3(0.0);
	EMISSION = mix(near_col * lit, far_col, clamp(fade, 0.0, 0.92));
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	level.add_child(mi)


static func _part(st: SurfaceTool, mesh: PrimitiveMesh, size: Vector3, xf: Transform3D) -> void:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	st.append_from(mesh, 0, xf)


# --- Gemini props: flat cut-outs that turn to face the camera but stay upright --------------------

const PROPS := "res://assets/art/gemini/props/%s.png"


## A Gemini picture standing on the ground at `base`, `height` metres tall, always facing the camera.
func _cutout(parent: Node, tex_name: String, base: Vector3, height: float) -> Sprite3D:
	var tex := load(PROPS % tex_name) as Texture2D
	var s := Sprite3D.new()
	s.name = "Gemini_" + tex_name
	s.texture = tex
	s.pixel_size = height / float(tex.get_height())
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.alpha_scissor_threshold = 0.5
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.fixed_size = false
	s.position = base + Vector3(0, height * 0.5, 0)
	parent.add_child(s)
	return s


## Identical cut-outs (lamps, banners, planters...) become one MultiMesh each: one draw call per
## picture instead of one per prop. Each quad turns to the camera about the vertical (as before).
func _batch_cutouts(level: Node) -> void:
	var groups := {}
	for s: Sprite3D in level.find_children("*", "Sprite3D", false, false):
		if s.texture == null or not s.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y:
			continue
		var key := s.texture.resource_path + "@%.5f" % s.pixel_size
		if not groups.has(key):
			groups[key] = []
		groups[key].append(s)
	for key in groups:
		var list: Array = groups[key]
		if list.size() < 2:
			continue
		var first := list[0] as Sprite3D
		var tex := first.texture
		var quad := QuadMesh.new()
		quad.size = Vector2(tex.get_width(), tex.get_height()) * first.pixel_size
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.billboard_keep_scale = true
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		quad.material = m
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = quad
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, Transform3D(Basis(), (list[i] as Sprite3D).global_position))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Cutouts_" + tex.resource_path.get_file().get_basename()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(mmi)
		for s in list:
			(s as Sprite3D).queue_free()


func _dress_target(node: Node) -> void:
	if not is_instance_valid(node) or node.get_node_or_null("Gemini_target") != null:
		return
	var mesh := node.get_node_or_null("Mesh") as Node3D
	if mesh:
		mesh.visible = false
	_cutout(node, "target", Vector3.ZERO, 2.6)


func _add_prop_cutouts(level: Node) -> void:
	var env := level.get_node_or_null("Environment")
	if env == null:
		return
	# Archery targets (the level's dummies keep their colliders, health and hit logic).
	for d in level.find_children("*", "TargetDummy", true, false):
		_dress_target(d)
	# Lamps: stand and flame hidden, the Gemini lamp on the same spot (the warm OmniLights stay).
	for n in ["LampStands", "LampFlames"]:
		var mm := env.get_node_or_null(n) as MultiMeshInstance3D
		if mm:
			mm.visible = false
	var stands := env.get_node_or_null("LampStands") as MultiMeshInstance3D
	if stands and stands.multimesh:
		for i in stands.multimesh.instance_count:
			_cutout(level, "lamp", stands.multimesh.get_instance_transform(i).origin, 2.4)
	# Banners: poles and cloth hidden, the Gemini banner where each pole stood (low ones only).
	var poles := env.get_node_or_null("BannerPoles") as MultiMeshInstance3D
	for n in ["BannerPoles", "Banners"]:
		var mm := env.get_node_or_null(n) as MultiMeshInstance3D
		if mm:
			mm.visible = false
	if poles and poles.multimesh:
		for i in poles.multimesh.instance_count:
			var o := poles.multimesh.get_instance_transform(i).origin
			if o.y < 8.0:
				_cutout(level, "banner", Vector3(o.x, o.y - 2.25, o.z), 4.8)
	# Two marble elephants flanking the way to the palace, where the courtyard narrows.
	for x in [-11.0, 11.0]:
		_cutout(level, "elephant", Vector3(x, 0.0, -40.0), 3.4)
	# Planters: the three marble beds become Gemini marigold planters.
	var planters := env.get_node_or_null("Planters") as Node3D
	if planters:
		planters.visible = false
	for p in [Vector3(20, 0, -40), Vector3(-20, 0, -40), Vector3(21, 0, 6)]:
		_cutout(level, "planter", p + Vector3(0, 0.3, 0), 3.6)
