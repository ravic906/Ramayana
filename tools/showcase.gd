extends SceneTree
## Character showcase for the trailer: each generated character in turn, in front of the Gemini
## gate, playing its idle, turning slowly, with its name. Record with
##   godot --write-movie out.avi --fixed-fps 30 -s res://tools/showcase.gd
const CAST := [
	["rama_g", "Rama", "prince of Ayodhya"], ["lakshmana_g", "Lakshmana", "his brother"],
	["dasharatha_g", "Dasharatha", "king of Ayodhya"], ["vasishtha_g", "Vasishtha", "the royal preceptor"],
	["vishvamitra_g", "Vishvamitra", "the sage who asks for Rama"], ["guard_g", "Palace guard", ""],
	["townsman_g", "Townsman", ""], ["townswoman_g", "Townswoman", ""],
	["maricha_g", "Maricha", "rakshasa"], ["subahu_g", "Subahu", "rakshasa"],
	["sumati_g", "Sumati", "king of Vishala"], ["gautama_g", "Gautama", "the sage"],
	["ahalya_g", "Ahalya", "his wife"], ["janaka_g", "Janaka", "king of Mithila"],
	["sita_g", "Sita", "daughter of Janaka"], ["rama_crowned_g", "Rama", "at court"],
]
const SECS := 3.0
var frame := 0
var idx := -1
var body: Node3D
var cam: Camera3D
var title: Label
var sub: Label
var font: Font


func _initialize() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.12, 0.3, 0.68)
	sm.sky_horizon_color = Color(0.55, 0.72, 0.92)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 1.0)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.95, 0.85)
	root.add_child(sun)
	# Backdrop: the Gemini gate, far behind.
	var gate := MeshInstance3D.new()
	var q := QuadMesh.new()
	var tex: Texture2D = load("res://assets/art/gemini/gate_front.png")
	q.size = Vector2(16.0, 16.0 * tex.get_height() / tex.get_width())
	gate.mesh = q
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = tex
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	gate.material_override = gm
	gate.position = Vector3(0, q.size.y * 0.5 - 0.6, -9.0)
	root.add_child(gate)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = load("res://assets/art/gemini/marble.png")
	fm.uv1_scale = Vector3(12, 12, 1)
	fm.roughness = 0.6
	fm.albedo_color = Color(0.86, 0.8, 0.7)
	floor.material_override = fm
	root.add_child(floor)
	cam = Camera3D.new()
	cam.fov = 32
	root.add_child(cam)
	cam.make_current()
	font = load("res://assets/fonts/TiroDevanagariSanskrit-Regular.ttf")
	var ui := CanvasLayer.new()
	root.add_child(ui)
	title = _label(ui, 60, Color(1.0, 0.9, 0.68), 0.06)
	sub = _label(ui, 30, Color(1, 1, 1), 0.15)


func _label(ui: CanvasLayer, size: int, color: Color, y: float) -> Label:
	var l := Label.new()
	l.add_theme_font_override(&"font", font)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color(0.22, 0.1, 0.04))
	l.add_theme_constant_override(&"outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = y
	l.anchor_bottom = y
	ui.add_child(l)
	return l


func _next() -> bool:
	idx += 1
	while idx < CAST.size() and not ResourceLoader.exists("res://characters/people/%s/%s_body.scn" % [CAST[idx][0], CAST[idx][0]]):
		idx += 1
	if idx >= CAST.size():
		return false
	if body:
		body.queue_free()
	body = (load("res://characters/people/%s/%s_body.scn" % [CAST[idx][0], CAST[idx][0]]) as PackedScene).instantiate()
	root.add_child(body)
	var ap := body.get_node("AnimationPlayer") as AnimationPlayer
	ap.play(&"idle")
	title.text = CAST[idx][1]
	sub.text = CAST[idx][2]
	return true


func _process(_d: float) -> bool:
	var per := int(SECS * 30)
	if frame % per == 0 and not _next():
		quit()
		return true
	var t := float(frame % per) / per
	var a := lerpf(-0.5, 0.5, t)
	var dist := lerpf(5.6, 4.9, t)
	cam.position = Vector3(sin(a) * dist, 1.05, cos(a) * dist)
	cam.look_at(Vector3(0, 0.88, 0))
	var fade := clampf(minf(t, 1.0 - t) * 6.0, 0.0, 1.0)
	title.modulate.a = fade
	sub.modulate.a = fade
	frame += 1
	return false
