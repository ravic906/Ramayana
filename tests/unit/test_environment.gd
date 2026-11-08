extends TestCase
## The Ayodhya training grounds: playable space stays clear, spawns can reach Rama.

var level: Node3D


func before_each() -> void:
	level = load("res://kandas/01_bala/training_grounds.tscn").instantiate()
	level.get_node("WaveSpawner").auto_start = false
	add_child(level)


func after_each() -> void:
	level.queue_free()
	TimeFX.clear_all()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)  # world only
	return level.get_world_3d().direct_space_state.intersect_ray(q)


func test_environment_is_built() -> void:
	await get_tree().physics_frame
	var env := level.get_node("Environment")
	assert_true(env.get_node_or_null("Collision") != null, "collision present")
	assert_true(env.find_children("Pillars_*", "MultiMeshInstance3D", false, false).size() >= 2, "pillars")
	assert_true(env.find_children("Trees_*", "MultiMeshInstance3D", false, false).size() >= 3, "trees")
	assert_true(env.get_node_or_null("KalyaniWater") != null, "kalyani tank")


func test_arena_centre_is_clear() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var c := Vector3(0, 1.0, -18.0)
	for i in 16:
		var a := TAU * i / 16.0
		var hit := _ray(c, c + Vector3(cos(a), 0, sin(a)) * 15.0)
		assert_true(hit.is_empty(), "obstacle within 15 m of the centre at %d deg: %s" % [i * 22, str(hit.get("position"))])


func test_spawns_have_clear_paths_to_rama() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var rama: Node3D = level.get_node("Rama")
	for marker in level.get_node("WaveSpawner").get_children():
		if marker is Marker3D:
			var hit := _ray(marker.global_position + Vector3.UP, rama.global_position + Vector3.UP)
			assert_true(hit.is_empty(), "%s blocked at %s" % [marker.name, str(hit.get("position"))])


func test_rama_stands_on_the_paving() -> void:
	for i in 20:
		await get_tree().physics_frame
	var rama: CharacterBody3D = level.get_node("Rama")
	assert_true(rama.is_on_floor())
	assert_almost(rama.global_position.y, 0.0, 0.05)
