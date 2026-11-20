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
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.8, 0.66)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.95
	e.glow_enabled = true
	e.glow_intensity = 1.0
	e.glow_bloom = 0.14
	e.glow_hdr_threshold = 0.9
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.fog_enabled = true
	e.fog_light_color = Color(0.96, 0.62, 0.5)
	e.fog_density = 0.008
	e.fog_aerial_perspective = 0.8
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.18
	e.adjustment_saturation = 1.05
	var we := WorldEnvironment.new()
	we.environment = e
	w.add_child(we)

	# Low sun BEHIND the gate (light travels toward the camera): silhouettes and rim light.
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.62, 0.3)
	sun.light_energy = 2.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	w.add_child(sun)
	sun.look_at_from_position(Vector3(-30, 7, -30), Vector3(0, 0, 0))
	# Soft cool-rose fill from the front so shadows keep colour.
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(1.0, 0.78, 0.62)
	fill.light_energy = 0.75
	w.add_child(fill)
	fill.look_at_from_position(Vector3(10, 9, 22), Vector3(0, 0, 0))

	var gate := (load("res://assets/arch/gate_slice.glb") as PackedScene).instantiate()
	w.add_child(gate)
	# Rama (stylised road look) faces the gate.
	var m = (load("res://characters/rama/rama_model.tscn") as PackedScene).instantiate()
	var lv := Node3D.new()
	lv.set_script(load("res://kandas/01_bala/story_level.gd"))
	w.add_child(lv)
	lv.princes_crowned = false
	lv.add_child(m)
	rama = m
	rama.position = Vector3(0.6, 0.0, 12.0)
	rama.rotation.y = -0.1  # faces the gate (-Z)

	cam = Camera3D.new()
	cam.fov = 42.0
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
	cam.global_position = Vector3(lerpf(-2.4, -0.9, k), lerpf(1.2, 1.9, k), lerpf(26.0, 16.0, k))
	cam.look_at(Vector3(lerpf(0.0, 0.3, k), lerpf(5.5, 5.0, k), -4.0))


func _process(_delta: float) -> bool:
	frame += 1
	_place(frame / FPS)
	var still := OS.get_environment("FRAME")
	if still != "" and frame == int(still):
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("STILL"))
		quit()
	return false
