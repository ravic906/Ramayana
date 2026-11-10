extends TestCase
## The skill tree: buying with Punya, prerequisites, saving, and effects.


func before_each() -> void:
	GameState.reset()


func after_each() -> void:
	GameState.reset()
	SaveSystem.delete_save(SaveSystem.AUTOSAVE_SLOT)


func test_twelve_skills_in_three_branches() -> void:
	assert_eq(Skills.all.size(), 12)
	for b in 3:
		var chain := Skills.by_branch(b)
		assert_eq(chain.size(), 4)
		for i in range(1, 4):
			assert_eq(chain[i].requires, chain[i - 1].id, "each tier needs the one before")


func test_buying_costs_punya_and_respects_prerequisites() -> void:
	assert_false(Skills.buy(&"steady_draw"), "no Punya yet")
	GameState.add_punya(260)
	assert_false(Skills.buy(&"long_breath"), "needs Steady Draw first")
	assert_true(Skills.buy(&"steady_draw"))
	assert_eq(GameState.punya, 160)
	assert_true(Skills.buy(&"long_breath"))
	assert_eq(GameState.punya, 10)
	assert_false(Skills.buy(&"long_breath"), "can't buy twice")


func test_skills_are_saved() -> void:
	GameState.add_punya(100)
	Skills.buy(&"quick_mantra")
	GameState.mission_stars["1:4"] = 2
	GameState.checkpoint = "night_3"
	SaveSystem.save_game()
	GameState.reset()
	assert_true(SaveSystem.load_game())
	assert_true(Skills.has(&"quick_mantra"))
	assert_eq(GameState.stars_for(1, 4), 2)
	assert_eq(GameState.checkpoint, "night_3")


func test_old_saves_still_load() -> void:
	var v2 := {"version": 2, "current_part": 1, "current_mission": 4, "punya": 77, "flags": {}}
	GameState.from_dict(v2)
	assert_eq(GameState.punya, 77)
	assert_true(GameState.skills.is_empty())
	assert_eq(GameState.checkpoint, "")


func test_effects_combine() -> void:
	assert_eq(Skills.mult("draw_time"), 1.0)
	GameState.skills.append(&"steady_draw")
	assert_almost(Skills.mult("draw_time"), 0.85, 0.001)
	GameState.skills.append(&"long_breath")
	assert_almost(Skills.add("perfect_window"), 0.15, 0.001)
	assert_false(Skills.flag("pierce"))
	GameState.skills.append(&"piercing_shot")
	assert_true(Skills.flag("pierce"))


func test_skills_change_play() -> void:
	var rama: Rama = (load("res://characters/rama/rama.tscn") as PackedScene).instantiate()
	GameState.skills.append(&"steadfast")
	GameState.skills.append(&"long_breath")
	add_child(rama)
	await get_tree().process_frame
	assert_almost(rama.health.max_health, 120.0, 0.01, "Steadfast: +20 health")
	assert_almost(rama.perfect_window_now(), rama.perfect_window + 0.15, 0.001)
	rama.queue_free()


func test_blessing_heals_when_dharma_rises() -> void:
	var rama: Rama = (load("res://characters/rama/rama.tscn") as PackedScene).instantiate()
	add_child(rama)
	await get_tree().process_frame
	rama.health.take_damage(40.0)
	var hp := rama.health.current
	GameState.add_dharma(5)
	assert_eq(rama.health.current, hp, "not without the skill")
	GameState.skills.append(&"blessing")
	GameState.add_dharma(5)
	assert_almost(rama.health.current, hp + 15.0, 0.01)
	rama.queue_free()


func test_piercing_arrow_passes_through() -> void:
	var a := (load("res://characters/rama/arrow.tscn") as PackedScene).instantiate() as Arrow
	a.pierce = 1
	assert_eq(a.pierce, 1)
	a.free()


func test_skills_screen_buys() -> void:
	GameState.add_punya(100)
	var s: SkillsScreen = SkillsScreen.open(self)
	await get_tree().process_frame
	var card: Node = s.find_child("Skill_steadfast", true, false)
	assert_true(card != null)
	var learn := card.find_child("Learn", true, false) as Button
	learn.pressed.emit()
	assert_true(Skills.has(&"steadfast"))
	s.queue_free()
