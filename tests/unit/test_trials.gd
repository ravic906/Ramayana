extends TestCase
## The Trial Arena: unlocks, medals and Punya, the Gauntlet, and the boss
## rematches (which never touch story progress).

var level: Node


func after_each() -> void:
	get_tree().paused = false
	if level:
		level.queue_free()
		level = null
	for n in get_tree().root.get_children():
		if n is TrialResult:
			n.queue_free()
	Music.stop()
	GameState.reset()
	SaveSystem.delete_save(SaveSystem.AUTOSAVE_SLOT)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _result() -> TrialResult:
	for n in level.get_children():
		if n is TrialResult:
			return n
	return null


func test_unlocks_medals_and_punya_once() -> void:
	var g := Trials.get_trial("gauntlet")
	var tat := Trials.get_trial("tataka")
	assert_false(Trials.is_unlocked(tat), "rematches open after the story fight")
	GameState.set_flag("tataka_defeated", true)
	assert_true(Trials.is_unlocked(tat))
	assert_eq(Trials.medal_for(g, 40), 2, "score: silver")
	assert_eq(Trials.medal_for(tat, 100), 2, "time: faster is better")
	var p0 := GameState.punya
	var r := Trials.record("gauntlet", 40)
	assert_eq(r["medal"], 2)
	assert_eq(GameState.punya - p0, Trials.MEDAL_PUNYA[1] + Trials.MEDAL_PUNYA[2], "bronze and silver at once")
	var p1 := GameState.punya
	Trials.record("gauntlet", 20)
	assert_eq(GameState.punya, p1, "no Punya for a medal already won")
	assert_eq(float(Trials.best("gauntlet")), 40.0, "the best is kept")


func test_the_gauntlet_scores_until_rama_falls() -> void:
	GameState.trial = "gauntlet"
	GameState.story_session = false
	level = load("res://kandas/01_bala/training_grounds.tscn").instantiate()
	add_child(level)
	await _frames(3)
	var spawner: WaveSpawner = level.spawner
	assert_eq(spawner.waves.size(), level.GAUNTLET_WAVES)
	spawner.spawn_wave(0)
	for r in spawner.alive.duplicate():
		r.health.take_damage(99999.0)
	await _frames(2)
	assert_true(level.gauntlet_score >= 4, "foes and the wave count: %d" % level.gauntlet_score)
	level.rama.rama_died.emit()
	await get_tree().create_timer(1.8).timeout
	assert_true(_result() != null, "the result card")
	assert_eq(float(Trials.best("gauntlet")), float(level.gauntlet_score))


func test_tataka_rematch_does_not_touch_the_story() -> void:
	GameState.set_flag("tataka_defeated", true)
	GameState.current_mission = 5
	GameState.trial = "tataka"
	GameState.story_session = false
	level = load("res://kandas/01_bala/forest.tscn").instantiate()
	add_child(level)
	await _frames(4)
	assert_true(level.boss_started, "the fight begins at once")
	assert_eq(GameState.current_mission, 5, "story progress untouched")
	level.tataka.health.take_damage(999999.0)
	await get_tree().create_timer(2.4).timeout
	assert_true(_result() != null, "timed result")
	assert_true(Trials.best("tataka") != null)


func test_sky_rematch_starts_on_the_last_night() -> void:
	GameState.set_flag("yagna_protected", true)
	GameState.trial = "sky"
	GameState.story_session = false
	GameState.checkpoint = "night_3"
	level = load("res://kandas/01_bala/siddhashrama.tscn").instantiate()
	add_child(level)
	await _frames(4)
	assert_true(level.bosses_started)
	assert_eq(GameState.checkpoint, "night_3", "the story checkpoint is untouched")
