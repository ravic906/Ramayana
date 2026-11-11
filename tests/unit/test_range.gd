extends TestCase
## Mission 1's range chapter: moving targets, perfect releases, the long shot.

var level: Node


func after_each() -> void:
	if level:
		level.queue_free()
		level = null
	Music.stop()
	GameState.reset()
	SaveSystem.delete_save(SaveSystem.AUTOSAVE_SLOT)


func _wait_step(step: int) -> void:
	for i in 1200:
		if level.range_step >= step:
			return
		await get_tree().process_frame


func _dummies() -> Array:
	return level.get_children().filter(func(n: Node) -> bool: return n is TargetDummy and not String(n.name).begins_with("Dummy"))


func test_the_three_drills_lead_to_the_trials() -> void:
	GameState.story_session = false
	GameState.current_mission = 1
	level = load("res://kandas/01_bala/training_grounds.tscn").instantiate()
	level.get_node("WaveSpawner").auto_start = false
	add_child(level)
	await get_tree().process_frame
	level.range_chapter()
	await _wait_step(1)
	await get_tree().create_timer(6.0).timeout  # Vasishtha's line
	var movers := _dummies()
	assert_eq(movers.size(), 3, "three moving targets")
	var x0: float = movers[0].global_position.x
	await get_tree().create_timer(0.5).timeout
	assert_true(absf(movers[0].global_position.x - x0) > 0.05, "they move")
	for d in movers:
		d.health.take_damage(9999.0, level.rama)
	await _wait_step(2)
	assert_eq(level.range_step, 2)
	await get_tree().create_timer(6.0).timeout
	for i in 3:
		level.rama.released.emit(null, 1.0, true)
	await _wait_step(3)
	await get_tree().create_timer(6.0).timeout
	var far := _dummies()
	assert_eq(far.size(), 1, "the far target")
	assert_true(far[0].global_position.distance_to(level.rama.global_position) > 30.0, "a long shot")
	far[0].health.take_damage(9999.0, level.rama)
	await _wait_step(4)
	assert_true(GameState.get_flag("range_done", false), "not repeated on later plays")
