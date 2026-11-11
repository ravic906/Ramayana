extends TestCase
## Story / Warrior / Maharathi: scales, the Maharathi unlock, migration from
## the old story_mode setting, and stars won on Maharathi.

var _was: int
var _path: String


func before_each() -> void:
	_was = Settings.difficulty
	_path = Settings.config_path
	Settings.config_path = "user://test_difficulty.cfg"


func after_each() -> void:
	Settings.difficulty = _was
	Settings.config_path = _path
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_difficulty.cfg"))
	GameState.reset()


func test_each_mode_scales_the_fight() -> void:
	GameState.set_flag("tataka_defeated", true)
	var damage := []
	var health := []
	for d in [Settings.Difficulty.STORY, Settings.Difficulty.WARRIOR, Settings.Difficulty.MAHARATHI]:
		Settings.set_difficulty(d)
		assert_eq(Settings.difficulty, d)
		damage.append(Settings.incoming_damage_scale())
		health.append(Settings.enemy_health_scale())
	assert_true(damage[0] < damage[1] and damage[1] < damage[2], "harder hits harder: %s" % [damage])
	assert_true(health[0] < health[1] and health[1] < health[2], "and foes last longer: %s" % [health])
	assert_true(Settings.telegraph_scale() < 1.0, "Maharathi foes wind up faster")
	assert_eq(Settings.mode_name(), "Maharathi")


func test_maharathi_opens_after_tataka() -> void:
	Settings.difficulty = Settings.Difficulty.WARRIOR
	assert_false(Settings.maharathi_unlocked())
	assert_eq(Settings.next_difficulty(), Settings.Difficulty.STORY, "the toggle skips the locked mode")
	Settings.set_difficulty(Settings.Difficulty.MAHARATHI)
	assert_eq(Settings.difficulty, Settings.Difficulty.WARRIOR, "can't choose it yet")
	GameState.set_flag("tataka_defeated", true)
	assert_eq(Settings.next_difficulty(), Settings.Difficulty.MAHARATHI)


func test_old_story_mode_settings_migrate() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("gameplay", "story_mode", true)
	cfg.save(Settings.config_path)
	Settings.load_settings()
	assert_eq(Settings.difficulty, Settings.Difficulty.STORY)
	assert_true(Settings.story_mode, "old code still reads story_mode")
	Settings.story_mode = false
	assert_eq(Settings.difficulty, Settings.Difficulty.WARRIOR)


func test_maharathi_stars_are_kept_apart() -> void:
	GameState.set_flag("tataka_defeated", true)
	Settings.set_difficulty(Settings.Difficulty.WARRIOR)
	GameState.record_stars(1, 3, 3)
	assert_eq(GameState.hard_stars_for(1, 3), 0)
	Settings.set_difficulty(Settings.Difficulty.MAHARATHI)
	GameState.record_stars(1, 3, 2)
	assert_eq(GameState.hard_stars_for(1, 3), 2)
	assert_eq(GameState.stars_for(1, 3), 3, "best overall stays")
