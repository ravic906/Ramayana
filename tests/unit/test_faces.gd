extends TestCase
## The face rig (tools/face_rig_builder.gd) and FaceController: blinks, gaze,
## emotions, lip sync.

const FaceRig := preload("res://tools/face_rig_builder.gd")

var model: Node3D


func after_each() -> void:
	if model:
		model.queue_free()
		model = null
	Voice.speaking = false
	Voice.current_speaker = ""
	Voice._envelope = ""


func _rama() -> RamaModel:
	model = load("res://characters/rama/rama_model.tscn").instantiate()
	add_child(model)
	return model as RamaModel


func _step(face: FaceController, seconds: float, dt := 1.0 / 30.0) -> void:
	var t := 0.0
	while t < seconds:
		face._process(dt)
		t += dt


func test_rig_has_named_shapes_eyes_and_lids() -> void:
	var r := _rama()
	var head := r.skeleton.get_node("Head") as MeshInstance3D
	for s in FaceController.HEAD_SHAPES:
		assert_true(head.find_blend_shape_by_name(s) >= 0, "head shape " + s)
	var brows := r.skeleton.get_node("Eyebrows") as MeshInstance3D
	for s in FaceController.BROW_SHAPES:
		assert_true(brows.find_blend_shape_by_name(s) >= 0, "brow shape " + s)
	for side in ["EyeL", "EyeR"]:
		assert_true(r.skeleton.get_node_or_null("HeadAttachment/%s/Ball" % side) != null, side + " ball")
		assert_true(r.skeleton.get_node_or_null("HeadAttachment/%s/UpperLid" % side) != null, side + " lid")
	assert_true(r.face_rig != null, "Rama's face is driven")


func test_shapes_stay_on_the_face_and_are_subtle() -> void:
	# The back of the head never moves; nothing moves more than two centimetres (the jaw at the chin).
	for s in FaceRig.FACE_SHAPES:
		assert_eq(FaceRig._face_delta(s, Vector3(0.02, 1.62, -0.05), 1), Vector3.ZERO, s + " leaves the back of the head")
		for p in [Vector3(0, 1.6229, 0.09), Vector3(0.026, 1.624, 0.078), Vector3(0, 1.59, 0.08), Vector3(0.036, 1.65, 0.074)]:
			assert_true(FaceRig._face_delta(s, p, 1).length() < 0.02, s + " is subtle")
	assert_true(FaceRig._face_delta("jaw_open", Vector3(0, 1.60, 0.085), 1).y < -0.001, "the jaw drops")
	assert_true(FaceRig._face_delta("mouth_smile", Vector3(0.026, 1.6229, 0.0776), 0).y > 0.002, "smile lifts the corners")
	assert_eq(FaceRig._face_delta("jaw_open", Vector3(0, 1.63, 0.088), 0), Vector3.ZERO, "the upper lip stays")


func test_blinks_naturally() -> void:
	var face := _rama().face_rig
	var lid := model.skeleton.get_node("HeadAttachment/EyeL/UpperLid") as Node3D
	var blinks := 0
	var was_closed := false
	for i in 30 * 30:  # 30 s
		face._process(1.0 / 30.0)
		var closed := lid.rotation.x > deg_to_rad(-15.0)
		if closed and not was_closed:
			blinks += 1
		was_closed = closed
	assert_true(blinks >= 5 and blinks <= 16, "blinks in 30 s: %d" % blinks)


func test_emotions_ease_in() -> void:
	var face := _rama().face_rig
	face.set_emotion(&"grief")
	_step(face, 1.0)
	assert_true(face.weight("brow_sad") > 0.7, "grief shows in the brows")
	face.set_emotion(&"no_such_feeling")
	assert_eq(face.emotion, &"calm", "unknown emotions fall back to the default")
	face.wince()
	_step(face, 0.1)
	assert_true(face.weight("brow_furrow") > 0.3, "a wince")


func test_lip_sync_follows_the_speakers_voice() -> void:
	var face := _rama().face_rig
	Voice.speaking = true
	Voice.current_speaker = "Lakshmana"
	Voice._envelope = "f".repeat(30 * 600)  # whatever the player position, the voice is loud
	_step(face, 0.3)
	assert_true(face.weight("jaw_open") < 0.05, "Rama's mouth stays shut while Lakshmana speaks")
	Voice.current_speaker = "Rama"
	_step(face, 0.3)
	assert_true(face.weight("jaw_open") > 0.5, "Rama's mouth moves with his voice: %f lvl %f talk %s" % [face.weight("jaw_open"), Voice.mouth_level(), face.is_talking()])
	Voice.speaking = false
	_step(face, 0.5)
	assert_true(face.weight("jaw_open") < 0.05, "and closes after")


func test_gaze_turns_toward_a_target() -> void:
	var r := _rama()
	var face := r.face_rig
	var ball := r.skeleton.get_node("HeadAttachment/EyeL/Ball") as Node3D
	var head_pos := ball.global_position
	# Rama's model faces -Z in world (the body is turned 180 degrees): look to his left.
	var left: Vector3 = (ball.get_parent() as Node3D).global_transform.basis.x.normalized()
	var fwd: Vector3 = (ball.get_parent() as Node3D).global_transform.basis.z.normalized()
	face.look_target = head_pos + fwd * 2.0 + left * 1.5
	face._next_saccade = 99.0
	face._saccade = Vector2.ZERO
	_step(face, 0.5)
	assert_true(ball.rotation.y > 0.2, "eyes turn toward the target: %f" % ball.rotation.y)


func test_lipsync_data_covers_every_voice_line() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voice/lipsync.json"))
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/voice/manifest.json"))
	assert_true(data is Dictionary and manifest is Dictionary, "both files load")
	for k in manifest:
		assert_true(data.has(k), "lip sync for " + str(manifest[k]["text"]).left(40))
