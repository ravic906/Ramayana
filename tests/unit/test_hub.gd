extends TestCase
## Ayodhya hub: side quests, the journal, and the way to the gate.

var level: Node


func after_each() -> void:
	if level:
		level.queue_free()
		level = null
	Music.stop()
	GameState.reset()
	SaveSystem.delete_save(SaveSystem.AUTOSAVE_SLOT)


func _hub() -> Node:
	GameState.story_session = false
	level = load("res://kandas/01_bala/ayodhya_hub.tscn").instantiate()
	add_child(level)
	return level


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_the_hub_has_people_and_things_to_find() -> void:
	_hub()
	await _frames(3)
	for k in ["scribe", "sumantra", "grandfather", "gardener", "vasishtha", "child"]:
		assert_true(level.npcs.has(k), k)
	assert_eq(Quests.all.size(), 4)
	var leaves := 0
	for n in get_tree().get_nodes_in_group(&"interactables"):
		if String(n.name).begins_with("Leaf_"):
			leaves += 1
	assert_eq(leaves, 5)
	assert_eq(level.dummies.size(), 6)
	assert_eq(level.dummies[0].punya_reward, 0, "no Punya farming in the palace")
	assert_eq(PartFlow.get_mission(1, 2).scene_path, "res://kandas/01_bala/ayodhya_hub.tscn")


func test_leaves_quest_unlocks_lore_and_rewards() -> void:
	_hub()
	await _frames(3)
	var punya := GameState.punya
	for n in get_tree().get_nodes_in_group(&"interactables"):
		if String(n.name).begins_with("Leaf_"):
			(n as Interactable).interact()
	assert_true(Quests.is_done(&"leaves_of_old"))
	assert_eq(GameState.lore.size(), 5, "every leaf is a codex entry")
	assert_eq(GameState.punya, punya + 80)


func test_lost_child_follows_rama_home() -> void:
	_hub()
	await _frames(3)
	var dharma := GameState.dharma
	level._talk_child()
	assert_true(level.child_following)
	assert_true(Quests.is_active(&"lost_child"))
	level.rama.global_position = level.npcs["grandfather"].global_position + Vector3(1, 0, 1)
	await get_tree().create_timer(3.5).timeout
	assert_true(Quests.is_done(&"lost_child"), "brought home")
	assert_eq(GameState.dharma, dharma + 8)


func test_lotuses_go_to_the_guru() -> void:
	_hub()
	await _frames(3)
	level._talk_gardener()
	assert_true(Quests.is_active(&"lotus_for_guru"))
	for i in 3:
		(level.get_node("Lotus%d" % i) as Interactable).interact()
	assert_true(Quests.goal_reached(&"lotus_for_guru"))
	assert_false(Quests.is_done(&"lotus_for_guru"), "not until they reach Vasishtha")
	level._talk_vasishtha()
	assert_true(Quests.is_done(&"lotus_for_guru"))


func test_archers_challenge_win_and_lose() -> void:
	_hub()
	await _frames(3)
	Quests.start(&"archers_challenge")
	level.start_challenge()
	for i in 3:
		level.dummies[i].health.take_damage(999.0)
	level.challenge_left = 0.01
	await _frames(3)
	assert_false(Quests.is_done(&"archers_challenge"), "the sand ran out")
	assert_eq(level.challenge_left, -1.0)
	level.start_challenge()
	for d in level.dummies:
		d.health.take_damage(999.0)
	assert_true(Quests.is_done(&"archers_challenge"))


func test_quests_and_lore_are_saved_and_shown() -> void:
	Quests.start(&"lost_child")
	GameState.find_lore(&"sarayu")
	SaveSystem.save_game()
	GameState.reset()
	SaveSystem.load_game()
	assert_true(Quests.is_active(&"lost_child"))
	assert_true(&"sarayu" in GameState.lore)
	var j: JournalScreen = JournalScreen.open(self, JournalScreen.Tab.QUESTS)
	await get_tree().process_frame
	assert_true(j.find_child("Quest_lost_child", true, false) != null)
	j.queue_free()


func test_interact_button_appears_near_people() -> void:
	_hub()
	await _frames(3)
	level.rama.global_position = level.npcs["scribe"].global_position + Vector3(0, 0, 1.5)
	for i in 4:
		await get_tree().process_frame  # the HUD updates on process frames
	var b := level.hud.find_child("InteractButton", true, false) as Control
	assert_true(b != null and b.visible)
	assert_eq(b.label, "Talk")
