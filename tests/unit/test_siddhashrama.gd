extends TestCase
## Mission 5: defending Vishvamitra's yagna; Maricha and Subahu.

var level: Node


func after_each() -> void:
	if level:
		level.queue_free()
		level = null
	Music.stop()
	GameState.reset()
	GameState.story_session = false


func _ashram() -> Node:
	GameState.story_session = false
	level = load("res://kandas/01_bala/siddhashrama.tscn").instantiate()
	level.auto_start = false
	add_child(level)
	return level


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_mission_five_is_playable_and_six_shows_the_end_card() -> void:
	var m := PartFlow.get_mission(1, 5)
	assert_true(m.available)
	assert_eq(m.scene_path, "res://kandas/01_bala/siddhashrama.tscn")
	_ashram()
	await _frames(2)
	level.go_to_mission(6)
	assert_eq(GameState.current_mission, 6, "progress saved")
	assert_true(level.end_card != null, "a 'coming soon' card, not a silent return to the menu")


func test_the_ashram_is_built_for_the_defence() -> void:
	_ashram()
	await _frames(3)
	assert_true(level.fire.is_in_group(&"objective"))
	assert_eq(level.sages.size(), 6, "six sages keep the fire")
	assert_eq(get_tree().get_nodes_in_group(&"huts").size(), 8)
	var space := (level as Node3D).get_world_3d().direct_space_state
	for marker in level.spawner.spawn_points():
		var from: Vector3 = marker.global_position + Vector3.UP
		var q := PhysicsRayQueryParameters3D.create(from, Vector3(0, 0.6, 0), 1)
		var hit := space.intersect_ray(q)
		assert_true(hit.is_empty() or (hit["position"] as Vector3).length() < 3.0,
			"%s has a clear lane to the altar" % marker.name)


func test_raiders_run_for_the_fire() -> void:
	_ashram()
	await _frames(3)
	var r: Rakshasa = level.spawner.spawn_enemy("raider", Vector3(0, 0, -9))
	assert_true(r.carries_torch)
	await _frames(2)
	assert_eq(r.find_target(), level.fire)
	level.rama.global_position = Vector3(0, 0, 40)  # out of the way
	level.lakshmana.follow = false
	var before: float = level.fire.health.current
	await get_tree().create_timer(6.0).timeout
	assert_true(level.fire.health.current < before, "the torch reaches the fire")


func test_fire_bolts_burn_the_altar_and_varuna_quenches_them() -> void:
	_ashram()
	await _frames(3)
	var patch := FirePatch.new()
	patch.hostile = true
	patch.radius = 2.0
	patch.dps = 10.0
	patch.duration = 10.0
	level.add_child(patch)
	patch.global_position = Vector3(0.5, 0, 0.5)
	var before: float = level.fire.health.current
	await get_tree().create_timer(1.2).timeout
	assert_true(level.fire.health.current < before, "the sacred fire is harmed")
	Explosion.detonate(level, Vector3(0.5, 1, 0.5), load("res://data/astras/varunastra.tres"), level.rama)
	await _frames(2)
	assert_false(is_instance_valid(patch), "Varunastra puts it out")


func test_only_the_agneyastra_ends_subahu() -> void:
	_ashram()
	await _frames(3)
	var s: SkyRakshasa = level.subahu
	s.awaken(Vector3.ZERO, Vector3(0, 14, -30))
	s.health.take_damage(s.health.max_health * 0.9, level.rama)
	assert_eq(s.state, SkyRakshasa.S.LAST_STAND)
	var hp := s.health.current
	s.health.take_damage(50.0, level.rama)
	assert_eq(s.health.current, hp, "arrows turn aside in the smoke")
	Explosion.detonate(level, s.get_aim_point(), load("res://data/astras/varunastra.tres"), level.rama)
	assert_false(s.health.is_dead(), "water does not end him")
	Explosion.detonate(level, s.get_aim_point(), load("res://data/astras/agneyastra.tres"), level.rama)
	assert_true(s.health.is_dead(), "Agni does")
	assert_true(level.subahu_down)


func test_maricha_is_spared_by_the_manavastra() -> void:
	_ashram()
	await _frames(3)
	var m: SkyRakshasa = level.maricha
	m.awaken(Vector3.ZERO, Vector3(0, 14, -30))
	var manava: AstraResource = level.rama.astras[3]
	assert_eq(manava.id, &"manavastra")
	assert_false(level.rama.is_astra_unlocked(manava))
	m.health.take_damage(m.health.max_health * 0.8, level.rama)
	assert_eq(m.state, SkyRakshasa.S.YIELDING)
	assert_true(level.rama.is_astra_unlocked(manava), "the Manavastra is lent to Rama")
	m.health.take_damage(9999.0, level.rama)
	assert_false(m.health.is_dead(), "Rama does not take his life")
	var dharma := GameState.dharma
	Explosion.detonate(level, m.get_aim_point(), manava, level.rama)
	assert_eq(m.state, SkyRakshasa.S.BANISHED, "carried away over the sea")
	assert_false(m.health.is_dead())
	assert_eq(GameState.dharma, dharma + 20)
	assert_false(level.rama.is_astra_unlocked(manava), "and the astra is returned")


func test_a_struck_sage_costs_the_dharma_bonus() -> void:
	_ashram()
	await _frames(3)
	var sage: Node3D = level.sages[0]
	var b := (load("res://characters/bosses/tataka/boulder.tscn") as PackedScene).instantiate() as Boulder
	b.kind = &"shard"
	b.start = sage.global_position + Vector3(0, 6, 0)
	b.end = sage.global_position
	b.flight_time = 0.2
	level.add_child(b)
	await get_tree().create_timer(0.5).timeout
	assert_eq(level.sage_hits, 1, "the sage was struck")
	var before := GameState.dharma
	level.finish_yagna()
	assert_eq(GameState.dharma, before, "no unbroken-yagna bonus")
	assert_true(GameState.get_flag("yagna_protected"))


func test_an_unbroken_yagna_earns_dharma() -> void:
	_ashram()
	await _frames(3)
	var before := GameState.dharma
	level.finish_yagna()
	assert_eq(GameState.dharma, before + 15)


func test_lakshmana_guards_the_fire_here() -> void:
	_ashram()
	await _frames(3)
	assert_eq(level.lakshmana.guard_point, level.fire)
	level.lakshmana.toggle_command()
	assert_eq(level.lakshmana.command, Lakshmana.Command.GUARD)


func test_six_nights_each_bring_something_new() -> void:
	_ashram()
	await _frames(3)
	assert_eq(level.NIGHTS.size(), 5, "five nights of waves, then the sky battle")
	var kinds := {}
	for spec in level.NIGHTS:
		for w in spec["waves"]:
			for k in w:
				kinds[k] = true
	for k in ["grunt", "raider", "archer", "mayavi", "shield", "brute"]:
		assert_true(kinds.has(k), "%s appears" % k)
	level.start_night(2)
	await _frames(2)
	assert_eq(level.night, 2)
	assert_eq(GameState.checkpoint, "night_2", "checkpoint saved")
	assert_true("mayavi" in level.spawner.waves[0])


func test_resume_from_a_checkpoint_and_move_on() -> void:
	GameState.checkpoint = "night_4"
	level = load("res://kandas/01_bala/siddhashrama.tscn").instantiate()
	add_child(level)
	await _frames(4)
	assert_eq(level.night, 4, "picks up at the fourth night")
	level.spawner.finished = true
	level.spawner.all_cleared.emit()
	await get_tree().create_timer(4.6).timeout
	assert_eq(level.night, 5, "on to the fifth")


func test_on_the_fourth_night_they_go_for_the_sages() -> void:
	_ashram()
	await _frames(3)
	level.night = 4
	var r: Rakshasa = level.spawner.spawn_enemy("shield", Vector3(0, 0, -12))
	await _frames(2)
	assert_eq(r.target_mode, Rakshasa.TargetMode.OBJECTIVE)
	assert_true(r.find_target() in level.sages)
