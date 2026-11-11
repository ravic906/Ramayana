extends TestCase
## The Silent Forest in three chapters: the start in Malada, the chapter II
## checkpoint, and the shrine's bells that clear the thorns.

var level: Node


func after_each() -> void:
	if level:
		level.queue_free()
		level = null
	Music.stop()
	GameState.reset()
	SaveSystem.delete_save(SaveSystem.AUTOSAVE_SLOT)


func _forest(checkpoint := "") -> Node:
	GameState.story_session = false
	GameState.current_part = 1
	GameState.current_mission = 3
	GameState.checkpoint = checkpoint
	level = load("res://kandas/01_bala/forest.tscn").instantiate()
	add_child(level)
	return level


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_mission_three_starts_in_the_empty_fields() -> void:
	_forest()
	await _frames(3)
	assert_true(level.rama.global_position.distance_to(level.m("ForestStart")) < 1.5, "starts in chapter I")
	assert_eq(level.chapter, 1)
	assert_true(level.scouts != null and level.thorns != null)
	level.rama.global_position = level.m("Chapter2") + Vector3(0, 0, -2)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(level.chapter, 2)
	assert_eq(GameState.checkpoint, "forest_c2", "chapter II is a checkpoint")


func test_resuming_at_chapter_two() -> void:
	_forest("forest_c2")
	await _frames(3)
	assert_eq(level.chapter, 2)
	assert_true(level.rama.global_position.distance_to(level.m("Chapter2")) < 6.0)


func test_the_bells_in_the_carved_order_clear_the_thorns() -> void:
	_forest()
	await _frames(3)
	var s: ShrinePuzzle = level.shrine
	s.ring(2)  # the sun first: wrong
	assert_eq(s.progress, 0)
	for i in ShrinePuzzle.ORDER:
		s.ring(i)
	assert_true(s.is_solved)
	assert_true(GameState.get_flag("shrine_rung", false))
	assert_true(level.stats.facts.get("shrine", false))
	await get_tree().create_timer(2.8).timeout
	assert_false(is_instance_valid(level.thorns), "the thorns are gone")


func test_an_arrow_rings_a_bell() -> void:
	_forest()
	await _frames(3)
	var s: ShrinePuzzle = level.shrine
	var bell: StaticBody3D = s.bells[ShrinePuzzle.ORDER[0]]
	(bell.get_node("Health") as Health).take_damage(30.0, level.rama)
	assert_eq(s.progress, 1, "a hit counts as a ring")
	assert_false((bell.get_node("Health") as Health).is_dead(), "bells never break")
