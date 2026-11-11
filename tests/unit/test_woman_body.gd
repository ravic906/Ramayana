extends TestCase
## The woman's body: the same face rig on her landmarks, a sari as geometry,
## gathered hair, jewellery.

var w: NpcModel


func after_each() -> void:
	if w:
		w.queue_free()
		w = null


func test_she_has_a_face_clothes_and_hair() -> void:
	w = (load("res://characters/npc/npc_woman.tscn") as PackedScene).instantiate() as NpcModel
	add_child(w)
	await get_tree().process_frame
	var sk := w.skeleton
	var head := sk.get_node("Head") as MeshInstance3D
	for s in FaceController.HEAD_SHAPES:
		assert_true(head.find_blend_shape_by_name(s) >= 0, "shape " + s)
	assert_true(w.face_rig != null, "her face is driven")
	var garment := sk.get_node_or_null("Garment") as MeshInstance3D
	assert_true(garment != null and garment.mesh.get_surface_count() == 2, "blouse and pallu, and the skirt")
	assert_true(garment.material_override != null, "the palette reaches her clothes")
	assert_true(sk.get_node_or_null("Scalp") != null, "hair over the whole scalp")
	assert_true((sk.find_child("Hair", true, false) as Node3D).visible, "gathered hair")
	assert_true(ShotFramer.face_of(w).size() == 2, "close-ups can frame her")


func test_her_lips_part_cleanly() -> void:
	var FaceRig := load("res://tools/face_rig_builder.gd")
	FaceRig.L = FaceRig.FEMALE
	var lip: float = FaceRig.FEMALE["lip_y"]
	assert_true(FaceRig._face_delta("jaw_open", Vector3(0, lip - 0.01, 0.09), 1).y < -0.001, "the jaw drops")
	assert_eq(FaceRig._face_delta("jaw_open", Vector3(0, lip + 0.006, 0.092), 0), Vector3.ZERO, "the upper lip stays")
	FaceRig.L = FaceRig.MALE
