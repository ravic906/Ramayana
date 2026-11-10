extends TestCase
## Objectives, markers, the compass, the beacon, the map and quest tracking.

var level: Node


func after_each() -> void:
	if level:
		level.queue_free()
		level = null
	get_tree().paused = false
	Music.stop()
	GameState.reset()


func _hub() -> Node:
	GameState.story_session = false
	level = load("res://kandas/01_bala/ayodhya_hub.tscn").instantiate()
	add_child(level)
	return level


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func test_compass_places_markers_by_bearing() -> void:
	var xf := Transform3D(Basis(), Vector3.ZERO)  # looking along -Z
	assert_almost(Compass.bar_position(xf, Vector3(0, 0, -10)), 0.5, 0.001, "straight ahead: centre")
	assert_true(Compass.bar_position(xf, Vector3(10, 0, -10)) > 0.5, "to the right")
	assert_true(Compass.bar_position(xf, Vector3(-10, 0, -10)) < 0.5, "to the left")
	assert_true(Compass.bar_position(xf, Vector3(0, 0, 10)) < 0.0 or Compass.bar_position(xf, Vector3(0, 0, 10)) > 1.0, "behind: off the bar")


func test_every_level_states_an_objective_with_markers() -> void:
	_hub()
	await _frames(4)
	assert_true(level.objective_text != "", "the hub says what to do")
	var kinds := {}
	for n in get_tree().get_nodes_in_group(&"nav_markers"):
		kinds[(n as NavMarker).kind] = true
	assert_true(kinds.has(NavMarker.Kind.SIDE), "quest givers are marked")
	assert_true(kinds.has(NavMarker.Kind.EXIT), "the gate is marked")
	assert_true(level.hud.find_child("Compass", true, false) != null)


func test_objective_moves_the_marker_and_beacon() -> void:
	_hub()
	await _frames(3)
	var target := Node3D.new()
	level.add_child(target)
	target.global_position = Vector3(10, 0, -20)
	level.set_objective("Test goal", target)
	await _frames(2)
	var marker: NavMarker = level.get_node("ObjectiveMarker")
	assert_eq(marker.kind, NavMarker.Kind.MAIN)
	assert_almost(marker.global_position.distance_to(target.global_position), 0.0, 0.01)
	assert_eq((level.get_node("ObjectiveBeacon") as WaypointBeacon).target, marker)
	assert_eq((level.hud.find_child("ObjectiveLabel", true, false) as Label).text, "Test goal")


func test_pickups_show_when_near_or_tracked() -> void:
	_hub()
	await _frames(3)
	var leaf: NavMarker = null
	for n in get_tree().get_nodes_in_group(&"nav_markers"):
		if (n as NavMarker).kind == NavMarker.Kind.PICKUP and (n as NavMarker).quest_id == &"leaves_of_old":
			leaf = n
			break
	assert_true(leaf != null)
	assert_false(leaf.is_shown(leaf.global_position + Vector3(200, 0, 0)), "far and untracked: hidden")
	assert_true(leaf.is_shown(leaf.global_position + Vector3(5, 0, 0)), "near: shown")
	Quests.start(&"leaves_of_old")
	Quests.tracked = &"leaves_of_old"
	assert_true(leaf.is_shown(leaf.global_position + Vector3(200, 0, 0)), "tracked: shown from afar")


func test_tracking_follows_new_and_finished_quests() -> void:
	Quests.start(&"lost_child")
	assert_eq(Quests.tracked, &"lost_child", "a first quest is tracked")
	Quests.start(&"lotus_for_guru")
	assert_eq(Quests.tracked, &"lost_child", "not stolen by the next")
	Quests.complete(&"lost_child")
	assert_eq(Quests.tracked, &"lotus_for_guru", "moves on when done")


func test_map_maps_world_to_image_and_opens() -> void:
	var m := MapResource.for_level("res://kandas/01_bala/forest.tscn")
	assert_true(m != null and m.image != null)
	var r := m.world_rect
	assert_true(m.to_uv(Vector3(r.position.x, 0, r.position.y)).is_equal_approx(Vector2.ZERO))
	assert_true(m.to_uv(Vector3(r.end.x, 0, r.end.y)).is_equal_approx(Vector2.ONE))
	assert_true(MapResource.for_level("res://kandas/01_bala/training_grounds.tscn") != null, "the trials share Ayodhya's map")
	_hub()
	await _frames(3)
	level.hud.open_map()
	await _frames(2)
	var screen: MapScreen = null
	for c in level.hud.get_children():
		if c is MapScreen:
			screen = c
	assert_true(screen != null, "the map opens")
	assert_true(get_tree().paused, "the game pauses under it")
	screen.queue_free()


func test_log_has_three_tabs_and_shows_the_objective() -> void:
	_hub()
	await _frames(3)
	GameState.current_mission = 2
	var j: JournalScreen = JournalScreen.open(level.hud)
	await _frames(2)
	assert_true(j.find_child("CurrentObjective", true, false) != null, "the story tab shows what to do now")
	j.show_tab(JournalScreen.Tab.CODEX)
	await _frames(1)
	j.queue_free()
