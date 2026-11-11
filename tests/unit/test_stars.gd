extends TestCase
## Mission goals, stars, the summary card and the Missions list.


func after_each() -> void:
	GameState.reset()
	SaveSystem.delete_save(SaveSystem.AUTOSAVE_SLOT)


func test_goals_are_scored_from_what_happened() -> void:
	var s := MissionStats.new()
	var goals := PackedStringArray(["finish|Finish", "perfect:3|3 perfect", "fact:spared|Spare"])
	assert_eq(s.stars(goals), 1)
	s.perfect_shots = 3
	assert_eq(s.stars(goals), 2)
	s.facts["spared"] = true
	assert_eq(s.stars(goals), 3)
	assert_true(s.met("no_fall"))
	s.falls = 1
	assert_false(s.met("no_fall"))
	s.facts["fire_min"] = 0.74
	assert_false(s.met("fire:75"))
	assert_true(s.met("damage_under:10"))
	assert_eq(MissionStats.label("perfect:3|Loose 3 perfect shots"), "Loose 3 perfect shots")


func test_every_playable_mission_has_three_goals_or_none() -> void:
	for m in PartFlow.missions(1):
		if m.available:
			assert_true(m.star_goals.size() in [0, 3], "%s goals" % m.title)


func test_best_stars_are_kept() -> void:
	assert_eq(GameState.record_stars(1, 3, 2), 2)
	assert_eq(GameState.record_stars(1, 3, 1), 2, "a worse run doesn't lower it")
	assert_eq(GameState.record_stars(1, 3, 3), 3)


func test_summary_card_records_and_continues() -> void:
	var m := PartFlow.get_mission(1, 4)
	var s := MissionStats.new()
	s.facts["boulder_shot"] = true
	var card: MissionSummary = MissionSummary.open(self, m, s)
	await get_tree().process_frame
	assert_eq(card.stars, 3)
	assert_eq(GameState.stars_for(1, 4), 3)
	var done := [false]
	card.done.connect(func() -> void: done[0] = true)
	(card.find_child("Continue", true, false) as Button).pressed.emit()
	assert_true(done[0])


func test_missions_list_offers_what_was_reached() -> void:
	PartFlow.advance_to(4)
	GameState.record_stars(1, 3, 2)
	var screen: MissionsScreen = MissionsScreen.open(self, 1)
	await get_tree().process_frame
	var row3 := screen.find_child("Mission3", true, false)
	var row5 := screen.find_child("Mission5", true, false)
	assert_false((row3.find_child("Play", true, false) as Button).disabled)
	assert_false((row5.find_child("Play", true, false) as Button).disabled, "any mission can be chosen at will")
	var chosen := [0]
	screen.mission_chosen.connect(func(n: int, _c: int) -> void: chosen[0] = n)
	(row3.find_child("Play", true, false) as Button).pressed.emit()
	assert_eq(chosen[0], 3)
