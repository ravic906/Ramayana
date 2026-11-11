extends TestCase
## Close-ups, over-the-shoulder and two-shots (ShotFramer), the 5-field
## dialogue format, and actors' faces during a cutscene.

var stage: Node3D


func after_each() -> void:
	if stage:
		stage.queue_free()
		stage = null
	Voice.stop()


func _actor(scene: String, pos: Vector3, look: Vector3) -> NpcModel:
	var n := (load(scene) as PackedScene).instantiate() as NpcModel
	n.position = pos
	stage.add_child(n)
	n.face(look)
	return n


func _stage() -> Array:
	stage = Node3D.new()
	add_child(stage)
	var a := _actor("res://characters/npc/vishvamitra.tscn", Vector3(0, 0, 0), Vector3(0, 0, 2))
	var b := _actor("res://characters/npc/dasharatha.tscn", Vector3(0, 0, 2), Vector3(0, 0, 0))
	await get_tree().process_frame
	return [a, b]


func _screen(cam_pos: Vector3, look: Vector3, fov: float, point: Vector3) -> Vector2:
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.fov = fov
	cam.global_position = cam_pos
	cam.look_at(look)
	var size := Vector2(1280, 720)
	# Project by hand (the test viewport may be tiny): normalised device coords.
	var local := cam.global_transform.affine_inverse() * point
	var f := 1.0 / tan(deg_to_rad(fov) * 0.5)
	var ndc := Vector2(local.x / -local.z * f * size.y / size.x, local.y / -local.z * f)
	cam.queue_free()
	return Vector2((ndc.x + 1.0) * 0.5, (1.0 - ndc.y) * 0.5)


func test_five_field_lines_parse_and_four_still_do() -> void:
	var d := DialogueResource.new()
	d.text = "Rama|close|bloom|I will.|resolve\nSita|||Hello"
	assert_eq(d.get_line(0)["emotion"], &"resolve")
	assert_eq(d.get_line(0)["text"], "I will.")
	assert_eq(d.get_line(1)["text"], "Hello")
	assert_eq(d.get_line(1)["emotion"], &"")


func test_close_up_puts_the_eyes_in_the_upper_third() -> void:
	var ab: Array = await _stage()
	var face := ShotFramer.face_of(ab[0])
	assert_false(face.is_empty(), "the actor has a face")
	var shot := ShotFramer.frame(ShotFramer.Kind.CLOSE, ab[0], ab[1])
	assert_true((shot["position"] as Vector3).distance_to(face[0]) < 1.3, "close")
	var eyes: Vector2 = _screen(shot["position"], shot["look"], shot["fov"], face[0])
	assert_true(eyes.y > 0.22 and eyes.y < 0.45, "eyes near the upper third: %f" % eyes.y)
	assert_true(eyes.x > 0.3 and eyes.x < 0.7, "and near the middle")
	# In front of the face, not behind the head.
	assert_true(((shot["position"] as Vector3) - face[0]).dot(face[1]) > 0.5, "sees the face")


func test_over_the_shoulder_and_two_shot_see_both() -> void:
	var ab: Array = await _stage()
	var sp: Vector3 = ShotFramer.face_of(ab[0])[0]
	var li: Vector3 = ShotFramer.face_of(ab[1])[0]
	var ots := ShotFramer.frame(ShotFramer.Kind.OTS, ab[0], ab[1])
	assert_true((ots["position"] as Vector3).distance_to(li) < 1.0, "beside the listener")
	var s := _screen(ots["position"], ots["look"], ots["fov"], sp)
	assert_true(s.x > 0.2 and s.x < 0.8 and s.y > 0.15 and s.y < 0.6, "speaker in frame: %s" % s)
	var two := ShotFramer.frame(ShotFramer.Kind.TWO, ab[0], ab[1])
	for p in [sp, li]:
		var q := _screen(two["position"], two["look"], two["fov"], p)
		assert_true(q.x > 0.1 and q.x < 0.9 and q.y > 0.1 and q.y < 0.7, "both in the two-shot: %s" % q)


func test_cutscene_frames_registered_speakers_and_directs_faces() -> void:
	var ab: Array = await _stage()
	var d := DialogueResource.new()
	d.text = "Vishvamitra|||Give me Rama.|resolve\nDasharatha|||Not my son.|grief"
	var c := Cutscene.play(stage, d, {}, {"Vishvamitra": ab[0], "Dasharatha": ab[1]})
	await get_tree().process_frame
	await get_tree().process_frame
	var cam := get_viewport().get_camera_3d()
	assert_true(cam != null and cam.get_parent() == stage, "the cutscene has its own camera")
	var sage := ab[0] as NpcModel
	assert_eq(sage.face_rig.emotion, &"resolve", "the speaker wears the line's emotion")
	assert_true(sage.face_rig.look_target is Vector3, "and looks at the listener")
	assert_true((ab[1] as NpcModel).face_rig.look_target is Vector3, "the listener looks back")
	c.advance()
	await get_tree().process_frame
	assert_eq((ab[1] as NpcModel).face_rig.emotion, &"grief")
	var king_eyes: Vector3 = ShotFramer.face_of(ab[1])[0]
	assert_true(cam.global_position.distance_to(king_eyes) < 1.6, "a close shot of the king")
	c.skip()
	await get_tree().process_frame
	assert_eq(sage.face_rig.look_target, null, "faces are released after the scene")


func test_close_up_avoids_an_actor_in_the_way() -> void:
	var ab: Array = await _stage()
	var sp: Array = ShotFramer.face_of(ab[0])
	# A third actor standing right where the plain close-up camera would be.
	var plain := ShotFramer.frame(ShotFramer.Kind.CLOSE, ab[0], ab[1])
	var blocker := _actor("res://characters/npc/vasishtha.tscn", Vector3.ZERO, Vector3.ZERO)
	var between: Vector3 = ((plain["position"] as Vector3) + (sp[0] as Vector3)) * 0.5
	blocker.global_position = Vector3(between.x, 0, between.z) - (ShotFramer.face_of(blocker)[0] as Vector3 - blocker.global_position) * Vector3(1, 0, 1)
	await get_tree().process_frame
	assert_true(ShotFramer._blocked(plain["position"], sp[0], [blocker], ab[0]), "the plain view is blocked")
	var shot := ShotFramer.frame(ShotFramer.Kind.CLOSE, ab[0], ab[1], 1.0, [ab[0], ab[1], blocker])
	if not shot.is_empty():
		assert_false(ShotFramer._blocked(shot["position"], sp[0], [blocker], ab[0]), "the chosen view is clear")
