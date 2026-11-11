extends TestCase
## Mission 6: Vishala at evening (welcome, two kindnesses, the night, the
## north gate) and Gautama's ashram (three places wake; Ahalya; the end).

var level: Node


func after_each() -> void:
	get_tree().paused = false
	if level:
		level.queue_free()
		level = null
	Music.stop()
	GameState.reset()
	SaveSystem.delete_save(SaveSystem.AUTOSAVE_SLOT)


func _load(scene: String) -> Node:
	GameState.story_session = false
	GameState.current_part = 1
	GameState.current_mission = 6
	level = load(scene).instantiate()
	add_child(level)
	return level


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func test_vishala_people_quests_and_the_night() -> void:
	_load("res://kandas/01_bala/vishala.tscn")
	await _frames(3)
	assert_eq(GameState.checkpoint, "vishala")
	assert_true(level.king != null and level.weaver != null and level.priest != null)
	assert_eq(level.folk.size(), 6, "townsfolk about their evening")
	# The weaver's flowers.
	Quests.start(&"weavers_thread")
	for n in get_tree().get_nodes_in_group(&"interactables").duplicate():
		if String(n.name).begins_with("Flower"):
			(n as Interactable).interacted.emit()
	assert_true(Quests.goal_reached(&"weavers_thread"))
	level._talk_weaver()
	assert_true(Quests.is_done(&"weavers_thread"))
	# The temple lamp.
	level._talk_priest()
	level._talk_oil_seller()
	assert_true(level.oil_carried)
	level._talk_priest()
	assert_true(Quests.is_done(&"temple_lamp"))
	# The night, then the north gate.
	assert_true(level.guest_house.enabled)
	await level.night_scene()
	assert_true(level.north_gate.enabled, "the road north opens in the morning")
	assert_true(&"churning_ocean" in GameState.lore)


func test_the_ashram_wakes_and_ahalya_is_seen() -> void:
	_load("res://kandas/01_bala/gautama_ashram.tscn")
	await _frames(3)
	assert_eq(GameState.checkpoint, "ashram")
	for key in ["altar", "well", "tulasi"]:
		await level.wake(key)
	assert_eq(level.woken.size(), 3)
	assert_true(level._heart_open, "the light gathers at the heart")
	level._scene_played = true
	level.ahalya_scene()
	await _frames(3)
	assert_true(level.ahalya != null and level.ahalya.visible, "she is seen")
	assert_true(level.gautama != null, "Gautama returns")
	assert_true(level.ahalya.find_child("Garment", true, false) != null, "in a sari")


func test_mission_six_is_playable_with_chapters() -> void:
	var m := PartFlow.get_mission(1, 6)
	assert_true(m.available)
	assert_eq(m.star_goals.size(), 3)
	assert_eq(PartFlow.start_at(6, 1), "res://kandas/01_bala/gautama_ashram.tscn")
