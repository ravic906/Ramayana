extends TestCase
## Hair: princes wear it gathered into the crown (face open); sages and the
## king keep the long hair; rakshasas keep it wild.

var nodes: Array[Node] = []


func after_each() -> void:
	for n in nodes:
		n.queue_free()
	nodes.clear()


func _add(path: String) -> Node:
	var n := (load(path) as PackedScene).instantiate()
	add_child(n)
	nodes.append(n)
	return n


func _hair(model: Node, name: String) -> MeshInstance3D:
	return model.find_child(name, true, false) as MeshInstance3D


func test_rama_wears_the_gathered_hair_with_the_face_open() -> void:
	var r := _add("res://characters/rama/rama_model.tscn")
	await get_tree().process_frame
	var hair := _hair(r, "Hair")
	assert_true(hair != null and hair.visible, "gathered hair shown")
	assert_false(_hair(r, "HairLong").visible, "long hair hidden")
	# Nothing in front of the face below the brow (rest pose, model space).
	var v: PackedVector3Array = (hair.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var over_face := 0
	for p in v:
		if p.z > 0.06 and p.y < 1.72 and absf(p.x) < 0.05:
			over_face += 1
	assert_eq(over_face, 0, "no strands over the face")


func test_sages_keep_long_hair_and_rakshasas_wild_hair() -> void:
	var sage := _add("res://characters/npc/vishvamitra.tscn")
	var raksha := _add("res://characters/enemies/rakshasa/rakshasa_grunt.tscn")
	await get_tree().process_frame
	if RealisticBody.is_realistic(sage.skeleton):
		# the realistic sage: his own long hair and a beard
		assert_true(_hair(sage, "Hair") != null and _hair(sage, "Beard") != null, "the sage's long hair and beard")
	else:
		assert_true(_hair(sage, "HairLong").visible and not _hair(sage, "Hair").visible, "the sage's long hair")
	assert_true(_hair(raksha, "HairLong").visible and not _hair(raksha, "Hair").visible, "the rakshasa's wild hair")
