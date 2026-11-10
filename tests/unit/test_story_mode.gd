extends TestCase
## Story difficulty: gentler battles for players here for the tale.

var _was := false
var _chosen := false
var _path := ""


func before_each() -> void:
	_was = Settings.story_mode
	_chosen = Settings.difficulty_chosen
	_path = Settings.config_path
	Settings.config_path = "user://test_mode_settings.cfg"


func after_each() -> void:
	Settings.story_mode = _was
	Settings.difficulty_chosen = _chosen
	DirAccess.remove_absolute(Settings.config_path)
	Settings.config_path = _path
	GameState.reset()


func test_story_mode_softens_battles() -> void:
	Settings.story_mode = false
	var rama: Rama = (load("res://characters/rama/rama.tscn") as PackedScene).instantiate()
	add_child(rama)
	await get_tree().process_frame
	var warrior_window := rama.perfect_window_now()
	rama.on_attacked(20.0, null)
	assert_almost(rama.health.current, rama.health.max_health - 20.0, 0.01)
	rama.health.revive()
	Settings.story_mode = true
	rama.on_attacked(20.0, null)
	assert_almost(rama.health.current, rama.health.max_health - 10.0, 0.01, "half damage")
	assert_true(rama.perfect_window_now() > warrior_window, "a longer perfect window")
	assert_almost(Settings.enemy_health_scale(), 0.8, 0.001)
	rama.queue_free()


func test_mode_is_saved_and_asked_once() -> void:
	Settings.difficulty_chosen = false
	Settings.set_story_mode(true)
	assert_true(Settings.difficulty_chosen)
	Settings.story_mode = false
	Settings.difficulty_chosen = false
	Settings.load_settings()
	assert_true(Settings.story_mode)
	assert_true(Settings.difficulty_chosen)


func test_first_play_asks_for_a_mode() -> void:
	Settings.difficulty_chosen = false
	var menu := (load("res://ui/journey_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	var started := [false]
	menu.choose_mode(func() -> void: started[0] = true)
	var story := menu.find_child("StoryChoice", true, false) as Button
	assert_true(story != null)
	story.pressed.emit()
	assert_true(started[0], "play continues after the choice")
	assert_true(Settings.story_mode)
	menu.queue_free()
