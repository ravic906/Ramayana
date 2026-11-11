extends SceneTree
## Renders the top-down map image of each level's environment (once, at build
## time) to assets/maps/<id>.png and writes data/maps/<id>.tres.
##   xvfb-run godot --rendering-driver opengl3 -s res://tools/render_map.gd
## Lighting is neutral daylight so night levels read on the map too.

const MAPS := [
	["ayodhya", "Ayodhya, the palace grounds", "res://kandas/01_bala/env/ayodhya_grounds.scn", "res://kandas/01_bala/ayodhya_hub.tscn", Rect2(-48, -62, 96, 92)],
	["forest", "The Silent Forest", "res://kandas/01_bala/env/tataka_forest.scn", "res://kandas/01_bala/forest.tscn", Rect2(-40, -150, 80, 166)],
	["sarayu", "The Road along the Sarayu", "res://kandas/01_bala/env/sarayu_road.scn", "res://kandas/01_bala/sarayu_road.tscn", Rect2(-46, -346, 124, 360), 4.0],
	["siddhashrama", "Siddhashrama", "res://kandas/01_bala/env/siddhashrama.scn", "res://kandas/01_bala/siddhashrama.tscn", Rect2(-50, -50, 100, 72)],
]
const PX_PER_M := 10.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for spec in MAPS:
		await _render(spec[0], spec[1], spec[2], spec[3], spec[4], spec[5] if spec.size() > 5 else PX_PER_M)
	quit()


func _render(id: String, title: String, env_path: String, level: String, rect: Rect2, px_per_m: float = PX_PER_M) -> void:
	var size := Vector2i(int(rect.size.x * px_per_m), int(rect.size.y * px_per_m))
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := (load(env_path) as PackedScene).instantiate()
	vp.add_child(env)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.32, 0.36, 0.26)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.88, 0.8)
	e.ambient_light_energy = 0.8
	we.environment = e
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-60), deg_to_rad(30), 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = rect.size.y  # vertical extent (keep_aspect height)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 1.0
	cam.far = 400.0
	vp.add_child(cam)
	var c := rect.get_center()
	cam.global_position = Vector3(c.x, 45.0, c.y)  # low: tree cells cull by camera distance
	cam.rotation = Vector3(-PI / 2, 0, 0)  # straight down, -Z (north) up
	cam.current = true
	for i in 8:
		await process_frame
	var img := vp.get_texture().get_image()
	img.save_png("res://assets/maps/%s.png" % id)
	var m := MapResource.new()
	m.title = title
	m.level_scene = level
	m.world_rect = rect
	m.image_path = "res://assets/maps/%s.png" % id
	if id == "ayodhya":
		m.other_scenes = PackedStringArray(["res://kandas/01_bala/training_grounds.tscn"])
	ResourceSaver.save(m, "res://data/maps/%s.tres" % id)
	print("map %s: %dx%d" % [id, size.x, size.y])
	vp.queue_free()
	await process_frame
