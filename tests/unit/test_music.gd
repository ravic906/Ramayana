extends TestCase
## Music: licensed cinematic cues, adaptive switching, stingers, volumes.

var level: Node


func after_each() -> void:
	if level:
		level.queue_free()
		level = null
	Music.stop()
	Music.duck(false)
	Music.voice_duck(false)
	GameState.reset()


func _cues() -> Array:
	var out := []
	for track: String in Music.TRACKS:
		for c in (Music.TRACKS[track] as Dictionary).values():
			if c not in out:
				out.append(c)
	return out + Music.STINGERS


func test_every_cue_exists_and_is_credited() -> void:
	var credits: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Music.DIR + "credits.json"))
	for c: String in _cues():
		var s := load(Music.DIR + c + ".ogg") as AudioStreamOggVorbis
		assert_true(s != null, c + " loads")
		if s:
			assert_true(s.get_length() > (5.0 if c.begins_with("sting") else 30.0), c + " is long enough")
		assert_true(credits.has(c), c + " has a credit")
		if credits.has(c):
			assert_true(String(credits[c]["license"]).contains("Attribution"), c + " credit names the licence")


func test_intensity_switches_cues_with_hysteresis() -> void:
	Music.play("forest")
	assert_eq(Music.cue, "forest")
	assert_true((Music.player().stream as AudioStreamOggVorbis).loop, "cues loop")
	Music.set_intensity(1.0)
	assert_eq(Music.cue, "forest_combat", "a fight brings the action music")
	Music.set_intensity(0.35)
	assert_eq(Music.cue, "forest_combat", "no flapping between waves")
	Music.set_intensity(0.0)
	assert_eq(Music.cue, "forest")


func test_boss_phases_and_stingers() -> void:
	Music.play("tataka")
	assert_eq(Music.cue, "tataka")
	Music.set_layer("maya", true)
	assert_eq(Music.cue, "tataka_maya", "her maya phase changes the music")
	Music.stinger("sting_reveal")
	assert_almost(Music.target_db(), Music.STINGER_DUCK_DB, 0.01, "the music steps back for a stinger")
	assert_true(Music.get_node_or_null("stinger_sting_reveal") != null)
	Music.play("nonexistent")
	assert_eq(Music.current, "tataka", "unknown tracks are ignored")


func test_ducking_adds_up() -> void:
	Music.play("menu")
	Music.duck(true)
	Music.voice_duck(true)
	assert_almost(Music.target_db(), Music.DUCK_DB + Music.VOICE_DUCK_DB, 0.01)


func test_volumes_persist_and_drive_the_buses() -> void:
	var old_path := Settings.config_path
	var old := [Settings.music_volume, Settings.sfx_volume, Settings.voice_volume]
	Settings.config_path = "user://test_settings.cfg"
	Settings.set_music_volume(0.5)
	Settings.set_sfx_volume(0.0)
	Settings.set_voice_volume(0.7)
	assert_almost(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.5), 0.01)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "zero mutes")
	Settings.music_volume = 1.0
	Settings.voice_volume = 1.0
	Settings.load_settings()
	assert_almost(Settings.music_volume, 0.5, 0.001, "saved and loaded")
	assert_almost(Settings.voice_volume, 0.7, 0.001)
	DirAccess.remove_absolute(Settings.config_path)
	Settings.config_path = old_path
	Settings.music_volume = old[0]
	Settings.sfx_volume = old[1]
	Settings.voice_volume = old[2]
	Settings.apply_audio()


func test_sound_effects_go_to_the_sfx_bus() -> void:
	var p := AudioStreamPlayer.new()
	add_child(p)
	assert_eq(p.bus, &"SFX")
	p.queue_free()


func test_levels_pick_their_music() -> void:
	GameState.current_mission = 3
	level = load("res://kandas/01_bala/forest.tscn").instantiate()
	add_child(level)
	await get_tree().physics_frame
	assert_eq(Music.current, "forest")
	level.encounter1.spawn_wave(0)
	assert_eq(Music.cue, "forest_combat", "an ambush starts the action music")
	level._start_boss()
	assert_eq(Music.cue, "tataka", "the boss brings her own theme")


func test_credits_screen_lists_every_track() -> void:
	var text: String = load("res://ui/journey_menu.gd").credits_text()
	var credits: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Music.DIR + "credits.json"))
	for cue in credits:
		assert_true(text.contains(credits[cue]["title"]), credits[cue]["title"])
	assert_true(text.contains("Kevin MacLeod") and text.contains("Attribution 4.0"))
