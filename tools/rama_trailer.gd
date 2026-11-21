extends SceneTree
## In-game trailer with Rama in focus, recorded from Mission 1 (training grounds):
##   godot --write-movie out.png --fixed-fps 30 -s res://tools/rama_trailer.gd
## The player's real controls drive Rama (walk, run, dodge roll, bow); cinematic cameras frame him
## between the gameplay shots.
const LOAD := 90
var frame := 0
var cam: Camera3D
var game_cam: Camera3D
var rama: Node3D
var hud: Node
var shot := -1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gs = root.get_node("GameState")
	gs.reset()
	gs.current_mission = 1
	gs.current_part = 1
	root.get_node("Settings").quality = 2
	root.get_node("Settings").apply_quality()
	change_scene_to_file("res://kandas/01_bala/training_grounds.tscn")


func _press(action: StringName, on: bool, strength := 1.0) -> void:
	if on:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _cinematic(on: bool) -> void:
	# Every on-screen layer (HUD, touch controls, prompts) off for the cinematic look.
	for layer in current_scene.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = not on
	if on:
		cam.make_current()
	elif game_cam:
		game_cam.make_current()


## Frames Rama: cut (snap) when the shot changes, otherwise glide.
func _frame(id: int, pos: Vector3, look: Vector3) -> void:
	if id != shot:
		shot = id
		cam.global_position = pos
	else:
		cam.global_position = cam.global_position.lerp(pos, 0.12)
	cam.look_at(look)


func _process(_d: float) -> bool:
	frame += 1
	var sc := current_scene
	if sc == null:
		return false
	if frame == LOAD:
		rama = sc.find_child("Rama", true, false) as Node3D
		hud = sc.get_node_or_null("HUD") as CanvasItem
		game_cam = root.get_viewport().get_camera_3d()
		cam = Camera3D.new()
		sc.add_child(cam)
		cam.fov = 35
	if rama == null:
		return false
	var t := float(frame - LOAD) / 30.0
	var p := rama.global_position
	var b: Basis = rama.get_node("Visual").global_basis if rama.has_node("Visual") else rama.global_basis
	var fwd: Vector3 = -b.z.normalized()
	var side: Vector3 = b.x.normalized()
	if t < 0.0:
		return false
	_cinematic(true)
	var health := rama.get_node_or_null("Health")
	if health:  # the trailer shows him fighting, not falling
		health.set("invulnerable", true)
		health.set("current", health.get("max_health"))
	var up := Vector3.UP
	if t < 5.0:  # 1. portrait: slow arc from his face down to the full figure
		var k := t / 5.0
		var a := lerpf(-0.6, 0.35, k)
		var d := lerpf(1.3, 3.6, k)
		var off: Vector3 = (fwd * cos(a) + side * sin(a)) * d
		_frame(1, p + off + up * lerpf(1.65, 1.35, k), p + up * lerpf(1.6, 1.05, k))
	elif t < 12.0:  # 2. over the shoulder as he walks, then runs, toward the trials
		_press(&"move_forward", true, 0.45 if t < 8.5 else 1.0)
		if t > 10.5 and t < 10.7:
			_press(&"dodge", true)
		else:
			_press(&"dodge", false)
		_frame(2, p + Vector3(0.9, 1.9, 3.4), p + Vector3(0, 1.2, -4.0))
	elif t < 18.0:  # 3. the fight: a low orbit while he dodges and looses arrows
		_press(&"move_forward", false)
		_press(&"shoot", fmod(t - 12.0, 1.2) < 0.15)
		if fmod(t - 12.0, 3.0) < 0.15:
			_press(&"dodge", true)
		else:
			_press(&"dodge", false)
		var ang := lerpf(0.4, 1.9, (t - 12.0) / 6.0)
		_frame(3, p + Vector3(cos(ang) * 4.6, 1.7, sin(ang) * 4.6), p + up * 1.0)
	elif t < 23.0:  # 4. low hero angle from the side as he walks on
		_press(&"shoot", false)
		_press(&"dodge", false)
		_press(&"move_forward", true, 0.4)
		_frame(4, p + Vector3(2.3, 0.5, -0.6), p + up * 1.3)
	elif t < 28.0:  # 5. rises behind him toward the Ayodhya gate
		_press(&"move_forward", false)
		var k := (t - 23.0) / 5.0
		_frame(5, p + Vector3(0.6, lerpf(1.7, 3.6, k), lerpf(2.2, 4.8, k)), p + Vector3(0, lerpf(1.3, 5.0, k), lerpf(-2.0, -30.0, k)))
	else:
		quit()
		return true
	return false
