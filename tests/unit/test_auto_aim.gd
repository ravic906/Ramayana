extends TestCase

const FWD := Vector3(0, 0, -1)


func test_out_of_range_rejected() -> void:
	assert_eq(AutoAim.score(Vector3.ZERO, FWD, Vector3(0, 0, -30), 25.0, 120.0), -1.0)


func test_outside_cone_rejected() -> void:
	# Directly behind the player.
	assert_eq(AutoAim.score(Vector3.ZERO, FWD, Vector3(0, 0, 5), 25.0, 120.0), -1.0)


func test_closer_target_scores_higher() -> void:
	var near := AutoAim.score(Vector3.ZERO, FWD, Vector3(0, 0, -5), 25.0, 120.0)
	var far := AutoAim.score(Vector3.ZERO, FWD, Vector3(0, 0, -20), 25.0, 120.0)
	assert_true(near > far, "near=%f far=%f" % [near, far])


func test_aligned_target_scores_higher_at_same_distance() -> void:
	var ahead := AutoAim.score(Vector3.ZERO, FWD, Vector3(0, 0, -10), 25.0, 160.0)
	var side := AutoAim.score(Vector3.ZERO, FWD, Vector3(-7.07, 0, -7.07), 25.0, 160.0)
	assert_true(ahead > side)


func test_height_is_ignored() -> void:
	var flat := AutoAim.score(Vector3.ZERO, FWD, Vector3(0, 0, -10), 25.0, 120.0)
	var high := AutoAim.score(Vector3.ZERO, FWD, Vector3(0, 3, -10), 25.0, 120.0)
	assert_almost(flat, high)


func test_find_best_target_skips_dead() -> void:
	var near := _enemy(Vector3(0, 0, -4))
	var far := _enemy(Vector3(0, 0, -15))
	(near.get_node("Health") as Health).take_damage(1000.0)
	var best := AutoAim.find_best_target(Vector3.ZERO, FWD, [near, far], 25.0, 120.0)
	assert_eq(best, far)


func test_find_best_target_none_in_range() -> void:
	var e := _enemy(Vector3(0, 0, 40))
	assert_null(AutoAim.find_best_target(Vector3.ZERO, FWD, [e], 25.0, 120.0))


func _enemy(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	var h := Health.new()
	h.name = "Health"
	n.add_child(h)
	add_child(n)
	n.global_position = pos
	return n
