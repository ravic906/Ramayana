extends TestCase
## Part 1 story: cutscenes, mission flow, the forest, Dharma, Tataka, astras.

var level: Node


func after_each() -> void:
	if level:
		level.queue_free()
		level = null
	GameState.reset()
	GameState.story_session = false
	TimeFX.clear_all()
	SaveSystem.delete_save(SaveSystem.AUTOSAVE_SLOT)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func _forest() -> Node:
	level = load("res://kandas/01_bala/forest.tscn").instantiate()
	add_child(level)
	return level


# --- Cutscenes and missions ------------------------------------------------------

func test_dialogue_lines_parse() -> void:
	var d := load("res://data/dialogue/part01/tataka_bloom.tres") as DialogueResource
	assert_true(d.line_count() > 5)
	var first := d.get_line(0)
	assert_eq(first["action"], &"bloom")
	assert_eq(first["text"], "")
	var found_grant := false
	for i in d.line_count():
		found_grant = found_grant or d.get_line(i)["action"] == &"grant_astras"
	assert_true(found_grant, "the bloom scene grants the astras")


func test_cutscene_advances_and_skip_fires_actions() -> void:
	var d := DialogueResource.new()
	d.lines = PackedStringArray(["Rama|||One.", "|x|first_action|", "Lakshmana|||Two.", "|x|second_action|"])
	var actions := []
	var done := [false]
	var c := Cutscene.play(self, d)
	c.action.connect(func(a): actions.append(a))
	c.finished.connect(func(): done[0] = true)
	await get_tree().process_frame
	assert_eq(c.index, 0)
	c.advance()
	await get_tree().process_frame
	assert_eq(actions, [&"first_action"], "action lines run instantly")
	assert_eq(c.index, 2)
	c.skip()
	assert_eq(actions, [&"first_action", &"second_action"], "skip still fires remaining actions")
	await get_tree().process_frame
	assert_true(done[0], "finished arrives (deferred) after skip")


func test_exported_dialogues_have_lines() -> void:
	# Dialogue text is a plain String so it survives export (PackedStringArray didn't).
	for f in DirAccess.get_files_at("res://data/dialogue/part01"):
		if f.ends_with(".tres"):
			var d := load("res://data/dialogue/part01/" + f) as DialogueResource
			assert_true(d.line_count() > 0, f + " has lines")
	var d2 := DialogueResource.new()
	d2.text = "Rama|||One.\n\n  Lakshmana|||Two.  \n"
	assert_eq(d2.line_count(), 2, "blank rows are ignored")
	assert_eq(d2.get_line(1)["speaker"], "Lakshmana")


func test_cutscene_that_finishes_at_once_does_not_lock_the_game() -> void:
	GameState.story_session = false
	level = load("res://kandas/01_bala/forest.tscn").instantiate()
	add_child(level)
	await _frames(2)
	var d := DialogueResource.new()
	d.lines = PackedStringArray(["|x|only_an_action|"])
	var path := "user://test_instant_dialogue.tres"
	ResourceSaver.save(d, path)
	await level.cutscene(path)
	assert_false(level.rama.controls_locked, "controls come back")
	assert_true(level.hud.get_node("Root/Joystick").visible, "joystick is shown again")
	await level.cutscene("res://does/not/exist.tres")
	assert_false(level.rama.controls_locked, "a missing dialogue never locks the game")
	DirAccess.remove_absolute(path)


func test_failsafe_restores_controls_without_a_cutscene() -> void:
	level = load("res://kandas/01_bala/forest.tscn").instantiate()
	add_child(level)
	await _frames(2)
	level.hud.set_cinematic(true)
	level.rama.controls_locked = true
	level._cinematic = true
	await get_tree().create_timer(1.4).timeout
	assert_false(level.rama.controls_locked)
	assert_true(level.hud.get_node("Root/Joystick").visible)


func test_one_touch_advances_one_line() -> void:
	var d := DialogueResource.new()
	d.lines = PackedStringArray(["Rama|||One.", "Lakshmana|||Two.", "Rama|||Three."])
	var c := Cutscene.play(self, d)
	await get_tree().process_frame
	c._text.visible_ratio = 1.0
	if c._typing:
		c._typing.kill()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	c._unhandled_input(touch)
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	c._unhandled_input(mouse)
	assert_eq(c.index, 1, "the emulated mouse click of the same tap is ignored")
	c.skip()


func test_part_flow_resumes_missions() -> void:
	var part := PartCatalog.by_number(1)
	GameState.set_part(1)
	GameState.current_mission = 0
	assert_eq(PartFlow.current(part).number, 1)
	PartFlow.advance_to(3)
	assert_eq(PartFlow.scene_for(part), "res://kandas/01_bala/forest.tscn")
	GameState.current_mission = 0
	assert_true(SaveSystem.load_game())
	assert_eq(GameState.current_mission, 3, "saved by advance_to")
	GameState.current_mission = 6  # The Stone and the Dawn: not yet available
	assert_eq(PartFlow.current(part).number, 1, "replays from the start")


# --- The forest ---------------------------------------------------------------------

func test_forest_path_is_walkable_to_the_grove() -> void:
	_forest()
	await _frames(3)
	var pts := [Vector3(0, 1, 4), Vector3(-5, 1, -16), Vector3(4, 1, -36), Vector3(-4, 1, -56), Vector3(3, 1, -76), Vector3(0, 1, -98), Vector3(0, 1, -120)]
	var space := (level as Node3D).get_world_3d().direct_space_state
	for i in pts.size() - 1:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pts[i], pts[i + 1], 1))
		assert_true(hit.is_empty(), "blocked between %s and %s at %s" % [pts[i], pts[i + 1], hit.get("position")])
	for enc in [level.get_node("Encounter1"), level.get_node("Encounter2")]:
		for m in enc.get_children():
			var q := PhysicsPointQueryParameters3D.new()
			q.position = m.global_position + Vector3.UP
			q.collision_mask = 1
			assert_true(space.intersect_point(q).is_empty(), "%s spawns inside scenery" % m.name)


func test_sparing_the_fleeing_raises_dharma() -> void:
	_forest()
	await _frames(3)
	var enc: WaveSpawner = level.get_node("Encounter2")
	var rama: Rama = level.get_node("Rama")
	rama.global_position = Vector3(-4, 0, -58)
	enc.spawn_wave(0)
	var runner: Rakshasa = enc.alive[0]
	assert_true(runner.flee_below > 0.0, "the first one may flee")
	runner.health.take_damage(runner.health.max_health * 0.7)
	assert_true(runner.is_fleeing())
	var before := GameState.dharma
	assert_true(await _until(func(): return not is_instance_valid(runner), 600), "escapes")
	assert_eq(GameState.dharma, before + 10)


func test_killing_the_fleeing_gives_no_dharma() -> void:
	_forest()
	await _frames(3)
	var enc: WaveSpawner = level.get_node("Encounter2")
	enc.spawn_wave(0)
	var runner: Rakshasa = enc.alive[0]
	runner.health.take_damage(runner.health.max_health * 0.7)
	assert_true(runner.is_fleeing())
	runner.health.take_damage(1000.0)
	await _frames(5)
	assert_eq(GameState.dharma, 0)


# --- Tataka -------------------------------------------------------------------------

func _boss() -> Tataka:
	_forest()
	await _frames(3)
	var rama: Rama = level.get_node("Rama")
	rama.global_position = Vector3(0, 0, -104)
	await _until(func(): return level.boss_started, 60)
	var t: Tataka = level.get_node("Tataka")
	return t


func test_entering_the_grove_wakes_tataka_and_seals_it() -> void:
	var t: Tataka = await _boss()
	assert_true(level.boss_started)
	assert_true(t.is_in_group(&"enemies"), "awake")
	assert_eq((level.get_node("Environment/GroveGate") as StaticBody3D).collision_layer, 1, "grove sealed")
	assert_eq(GameState.current_mission, 4, "checkpoint at the grove")


func test_tataka_phase_two_brings_maya() -> void:
	var t: Tataka = await _boss()
	var phases := []
	t.phase_changed.connect(func(p): phases.append(p))
	t.health.take_damage(t.max_health * 0.55)
	assert_eq(phases, [2])
	assert_eq(t.state, Tataka.S.VANISHED)
	assert_false(t.is_in_group(&"enemies"), "can't be targeted while vanished")
	assert_true(await _until(func(): return t.state == Tataka.S.REAPPEAR, 300), "reappears")
	assert_true(t.is_in_group(&"enemies"))


func test_stagger_and_boulders() -> void:
	var t: Tataka = await _boss()
	t._add_stagger(Tataka.STAGGER_FULL)
	assert_eq(t.state, Tataka.S.STAGGER)
	var hp := t.health.current
	t.health.take_damage(20.0)
	assert_almost(t.health.current, hp - 30.0, 0.01, "kneeling: 1.5x damage")
	var b := Tataka.BOULDER.instantiate() as Boulder
	b.start = t.global_position + Vector3.UP * 4
	b.end = t.global_position + Vector3(0, 0, 10)
	var shot := [false]
	b.shot_down.connect(func(_b): shot[0] = true)
	level.add_child(b)
	assert_true(b.is_in_group(&"enemies"), "aim assist can find boulders")
	b.health.take_damage(5.0)
	assert_true(shot[0])


func test_slam_can_be_dodged() -> void:
	var t: Tataka = await _boss()
	var rama: Rama = level.get_node("Rama")
	rama.global_position = t.global_position + Vector3(0, 0, 5)
	var dodged := [false]
	rama.perfect_dodge.connect(func(): dodged[0] = true)
	rama.health.invulnerable = true
	t._enter(Tataka.S.SLAM_WINDUP)
	await _until(func(): return t.state == Tataka.S.RECOVER, 200)
	rama.health.invulnerable = false
	assert_true(dodged[0], "the shockwave passes through the roll")
	assert_almost(rama.health.current, rama.health.max_health, 0.01)


func test_defeating_tataka_grants_the_astras() -> void:
	var t: Tataka = await _boss()
	var done := [false]
	t.defeated.connect(func(): done[0] = true)
	t.health.take_damage(100000.0)
	assert_true(done[0])
	assert_true(await _until(func(): return GameState.get_flag("tataka_defeated"), 400), "ceremony done")
	for id in [&"agneyastra", &"varunastra", &"vayavyastra"]:
		assert_true(id in GameState.unlocked_astras, "%s unlocked" % id)
	assert_true(GameState.is_part_completed(&"part_01"))
	var rama: Rama = level.get_node("Rama")
	for astra in rama.astras:
		if astra.id == &"manavastra":
			assert_false(rama.is_astra_unlocked(astra), "the Manavastra is only lent for Maricha")
		else:
			assert_true(rama.is_astra_unlocked(astra))


func test_varuna_and_vayu_effects() -> void:
	_forest()
	await _frames(3)
	var enc: WaveSpawner = level.get_node("Encounter1")
	var r := enc.spawn_enemy("grunt", Vector3(0, 0, -10))
	await _frames(2)
	var patch := FirePatch.new()
	level.add_child(patch)
	patch.global_position = Vector3(0, 0, -10)
	var varuna := load("res://data/astras/varunastra.tres") as AstraResource
	Explosion.detonate(level, Vector3(0.5, 1, -10), varuna, null)
	assert_true(r.health.current < r.health.max_health, "water hits")
	assert_true(patch.is_queued_for_deletion(), "water quenches fire")
	var vayu := load("res://data/astras/vayavyastra.tres") as AstraResource
	r.knockback = Vector3.ZERO
	Explosion.detonate(level, r.global_position + Vector3(1, 1, 0), vayu, null)
	assert_true(r.knockback.length() > 8.0, "wind hurls (%f)" % r.knockback.length())
