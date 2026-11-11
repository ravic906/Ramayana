extends TestCase
## Any mission, and any of its chapters, can be chosen at will.

var level: Node


func after_each() -> void:
	if level:
		level.queue_free()
		level = null
	Music.stop()
	GameState.reset()
	SaveSystem.delete_save(SaveSystem.AUTOSAVE_SLOT)


func test_every_chapter_names_a_scene() -> void:
	for n in PartFlow.CHAPTERS:
		for c in PartFlow.chapters(n).size():
			GameState.reset()
			var scene := PartFlow.start_at(n, c)
			assert_true(ResourceLoader.exists(scene), "mission %d chapter %d -> %s" % [n, c, scene])
			assert_eq(GameState.current_mission, n)


func test_jumping_ahead_grants_what_the_story_would_have() -> void:
	assert_eq(PartFlow.start_at(5, 5), "res://kandas/01_bala/siddhashrama.tscn")
	assert_eq(GameState.checkpoint, "night_6", "straight to the sky battle")
	assert_true(&"agneyastra" in GameState.unlocked_astras, "Subahu needs the Agneyastra")
	assert_true(GameState.get_flag("bala_atibala", false))
	assert_eq(PartFlow.furthest(), 5, "counts as reached")


func test_chapter_starts() -> void:
	assert_eq(PartFlow.start_at(2, 1), "res://kandas/01_bala/training_grounds.tscn")
	assert_eq(PartFlow.start_at(2, 3), "res://kandas/01_bala/sarayu_road.tscn")
	assert_eq(GameState.checkpoint, "camp")
	PartFlow.start_at(1, 1)
	assert_true(GameState.get_flag("range_done", false), "the trials chapter skips the range")
	PartFlow.start_at(1, 0)
	assert_false(GameState.get_flag("range_done", false), "the range chapter plays it")
	assert_eq(PartFlow.start_at(3, 1), "res://kandas/01_bala/forest.tscn")
	assert_eq(GameState.checkpoint, "forest_c2")


func test_the_camp_chapter_starts_at_the_camp() -> void:
	PartFlow.start_at(2, 3)
	GameState.story_session = false
	level = load("res://kandas/01_bala/sarayu_road.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(level.at_camp and level.camp_seat.enabled, "ready to sit by the fire")
	assert_true(level.rama.global_position.distance_to(level.m("CampCenter")) < 8.0)
