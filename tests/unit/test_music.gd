extends TestCase
## Music: generated stems, adaptive blending, volume settings and SFX routing.

var level: Node


func after_each() -> void:
	if level:
		level.queue_free()
		level = null
	Music.stop()
	Music.duck(false)
	GameState.reset()


func test_every_stem_exists_loops_and_matches_its_track() -> void:
	for track: String in Music.TRACKS:
		var length := -1.0
		for stem: String in Music.TRACKS[track]:
			var s := load(Music.DIR + "%s_%s.ogg" % [track, stem]) as AudioStreamOggVorbis
			assert_true(s != null, "%s_%s loads" % [track, stem])
			if s == null:
				continue
			if length < 0.0:
				length = s.get_length()
			assert_almost(s.get_length(), length, 0.05, "stems of %s share one length" % track)
		assert_almost(length, 48.0, 0.1, "%s loops every 48 s" % track)


func test_intensity_blends_explore_and_combat() -> void:
	Music.play("forest")
	assert_eq(Music.current, "forest")
	assert_true(Music.player("explore") != null and Music.player("combat") != null)
	assert_true((Music.player("explore").stream as AudioStreamOggVorbis).loop, "stems loop")
	assert_eq(Music.target_db("explore"), 0.0)
	assert_true(Music.target_db("combat") <= -59.0, "combat layer silent while exploring")
	Music.set_intensity(1.0)
	assert_eq(Music.target_db("combat"), 0.0)
	assert_almost(Music.target_db("explore"), Music.EXPLORE_AT_COMBAT_DB, 0.01, "explore steps back, still audible")
	Music.duck(true)
	assert_almost(Music.target_db("combat"), Music.DUCK_DB, 0.01, "dialogue ducks the music")


func test_switching_tracks_and_layers() -> void:
	Music.play("tataka")
	assert_true(Music.target_db("maya") <= -59.0)
	Music.set_layer("maya", true)
	assert_eq(Music.target_db("maya"), 0.0, "Tataka's maya layer joins in phase 2")
	Music.play("bloom")
	assert_eq(Music.current, "bloom")
	assert_true(Music.player("boss") == null, "the old track's players are released")
	Music.play("nonexistent")
	assert_eq(Music.current, "bloom", "unknown tracks are ignored")


func test_volumes_persist_and_drive_the_buses() -> void:
	var old_path := Settings.config_path
	var old := [Settings.music_volume, Settings.sfx_volume]
	Settings.config_path = "user://test_settings.cfg"
	Settings.set_music_volume(0.5)
	Settings.set_sfx_volume(0.0)
	assert_almost(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.5), 0.01)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "zero mutes")
	Settings.music_volume = 1.0
	Settings.load_settings()
	assert_almost(Settings.music_volume, 0.5, 0.001, "saved and loaded")
	DirAccess.remove_absolute(Settings.config_path)
	Settings.config_path = old_path
	Settings.music_volume = old[0]
	Settings.sfx_volume = old[1]
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
	level._start_boss()
	assert_eq(Music.current, "tataka", "the boss brings her own theme")
