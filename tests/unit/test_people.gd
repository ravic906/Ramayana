extends TestCase
## The realistic people (tools/mpfb_export.py + tools/build_person.gd): game
## skeleton, face units, materials, and the swap into the story characters.

const CAST := ["rama", "lakshmana", "vishvamitra", "vasishtha", "dasharatha"]
var nodes: Array[Node] = []


func after_each() -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
	nodes.clear()


func _body(person: String) -> Node3D:
	var path := "res://characters/people/%s/%s_body.scn" % [person, person]
	if not ResourceLoader.exists(path):
		return null
	var b := (load(path) as PackedScene).instantiate() as Node3D
	add_child(b)
	nodes.append(b)
	return b


func test_each_body_has_the_game_skeleton_and_face_units() -> void:
	for person: String in CAST:
		var b := _body(person)
		if b == null:
			continue
		var sk := b.get_node("Armature/Skeleton3D") as Skeleton3D
		assert_true(sk.has_meta(&"realistic"), "%s is marked realistic" % person)
		for bone in ["pelvis", "spine_03", "Head", "hand_r", "foot_l"]:
			assert_true(sk.find_bone(bone) >= 0, "%s has %s" % [person, bone])
		var face := sk.get_node("Face") as MeshInstance3D
		assert_true(face.find_blend_shape_by_name(&"jawOpen") >= 0 and face.find_blend_shape_by_name(&"eyeBlinkLeft") >= 0,
			"%s's face carries the face units" % person)
		assert_true((sk.get_node("Body") as MeshInstance3D).mesh.get_blend_shape_count() == 0, "%s's body carries none (size)" % person)
		assert_true(sk.has_node("HeadAttachment/EyeL") and sk.has_node("HeadAttachment/EyeR"), "%s has eye marks for close-ups" % person)
		assert_true(sk.has_node("Garment"), "%s is dressed" % person)
		for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", false, false):
			assert_true(mi.gi_mode == GeometryInstance3D.GI_MODE_DYNAMIC, "%s/%s is lit by the probes" % [person, mi.name])
			assert_true(mi.get_node_or_null(mi.skeleton) == sk, "%s/%s follows the skeleton" % [person, mi.name])


func test_the_animation_library_moves_the_body() -> void:
	var b := _body("rama")
	if b == null:
		return
	var sk := b.get_node("Armature/Skeleton3D") as Skeleton3D
	var ap := b.get_node("AnimationPlayer") as AnimationPlayer
	assert_true(ap.has_animation(&"idle") and ap.has_animation(&"walk") and ap.has_animation(&"kneel"), "clips copied")
	ap.play(&"walk")
	ap.seek(0.5, true)
	var thigh := sk.find_bone("thigh_l")
	assert_true(not sk.get_bone_pose_rotation(thigh).is_equal_approx(sk.get_bone_rest(thigh).basis.get_rotation_quaternion()), "the walk moves the legs")


func test_story_characters_wear_the_realistic_body_and_speak_with_it() -> void:
	if not ResourceLoader.exists("res://characters/people/vishvamitra/vishvamitra_body.scn") or not Settings.is_realistic():
		return
	var sage := (load("res://characters/npc/vishvamitra.tscn") as PackedScene).instantiate() as NpcModel
	add_child(sage)
	nodes.append(sage)
	await get_tree().process_frame
	assert_true(RealisticBody.is_realistic(sage.skeleton), "the sage's body was swapped")
	assert_true(sage.face_rig != null, "with a face")
	sage.face_rig.set_emotion(&"joy")
	for i in 30:
		await get_tree().process_frame
	assert_true(sage.face_rig.unit_value("mouthSmileLeft") > 0.2, "joy smiles with the face units")
