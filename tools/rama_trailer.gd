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


## Archer's tactics: advance only to shooting distance, shoot whatever comes, never let them close:
## back away from anyone within 7 m and roll away from anyone within 3.5 m.
func _archer(p: Vector3) -> void:
	var nearest := INF
	for e in current_scene.get_tree().get_nodes_in_group(&"enemies"):
		if e is Node3D and is_instance_valid(e) and not (e.has_method("is_dead") and e.is_dead()):
			nearest = minf(nearest, (e as Node3D).global_position.distance_to(p))
	var targets := INF
	for d in current_scene.find_children("*", "TargetDummy", true, false):
		targets = minf(targets, (d as Node3D).global_position.distance_to(p))
	var retreat := nearest < 7.0
	_press(&"move_back", retreat, 1.0)
	_press(&"move_forward", not retreat and targets > 11.0 and nearest > 12.0, 0.7)
	_press(&"dodge", nearest < 3.5 and fmod(float(frame), 30.0) < 2.0)
	_press(&"shoot", nearest < 28.0 and frame % 12 < 2)


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
		# A hero's day: every arrow fells a maya rakshasa, he turns to any foe around him, and
		# shoots at an archer's pace.
		rama.set("arrow_damage", 1000.0)
		rama.set("aim_cone_degrees", 360.0)
		rama.set("aim_range", 30.0)
		rama.set("shoot_cooldown", 0.35)
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
	elif t < 18.0:  # 2-3. the fight, as an archer fights: from a distance
		_archer(p)
		if t < 11.0:  # over the shoulder while he advances and shoots
			_frame(2, p + Vector3(0.9, 1.9, 3.4), p + Vector3(0, 1.2, -4.0))
		else:  # a wide arc that shows the illusions falling before they reach him
			var ang := lerpf(0.5, 1.6, (t - 11.0) / 7.0)
			_frame(3, p + Vector3(cos(ang) * 6.0, 2.4, sin(ang) * 6.0), p + up * 0.9 + Vector3(0, 0, -2.5))
	elif t < 23.0:  # 4. low hero angle from the side: he holds his ground and keeps shooting
		_archer(p)
		_frame(4, p + Vector3(2.3, 0.5, -0.6), p + up * 1.3)
	elif t < 28.0:  # 5. rises behind him toward the Ayodhya gate
		_press(&"move_forward", false)
		var k := (t - 23.0) / 5.0
		_frame(5, p + Vector3(0.6, lerpf(1.7, 3.6, k), lerpf(2.2, 4.8, k)), p + Vector3(0, lerpf(1.3, 5.0, k), lerpf(-2.0, -30.0, k)))
	else:
		quit()
		return true
	return false
