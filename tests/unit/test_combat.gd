extends TestCase
## Rakshasa AI, Rama taking damage, waves and the Agneyastra.

var level: Node
var rama: Rama
var spawner: WaveSpawner


func before_each() -> void:
	level = load("res://kandas/01_bala/training_grounds.tscn").instantiate()
	level.get_node("WaveSpawner").auto_start = false
	add_child(level)
	rama = level.get_node("Rama")
	spawner = level.get_node("WaveSpawner")


func after_each() -> void:
	for a in ["move_forward", "shoot", "dodge", "astra_1"]:
		Input.action_release(a)
	level.queue_free()
	TimeFX.clear_all()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func test_grunt_chases_and_hurts_rama() -> void:
	await _frames(3)
	var grunt := spawner.spawn_enemy("grunt", rama.global_position + Vector3(0, 0, -7))
	assert_true(await _until(func(): return grunt.state_machine.is_in(&"Telegraph"), 300), "grunt winds up")
	assert_true(grunt.flat_to_target().length() < 3.0, "grunt closed the distance")
	assert_true(await _until(func(): return rama.health.current < rama.health.max_health, 200), "club connects")
	assert_almost(rama.health.current, rama.health.max_health - grunt.data.damage, 0.01)


func test_dodge_roll_whiffs_the_blow() -> void:
	await _frames(3)
	var grunt := spawner.spawn_enemy("grunt", rama.global_position + Vector3(0, 0, -2.0))
	var dodged := [false]
	rama.perfect_dodge.connect(func(): dodged[0] = true)
	await _until(func(): return grunt.state_machine.is_in(&"Telegraph"), 300)
	var tele = grunt.state_machine.current
	await _until(func(): return tele._t >= grunt.data.telegraph_time - 0.3, 120)
	Input.action_press("dodge")
	await _frames(2)
	Input.action_release("dodge")
	await _until(func(): return grunt.state_machine.is_in(&"Recover"), 120)
	assert_true(dodged[0], "perfect dodge reported")
	assert_almost(rama.health.current, rama.health.max_health, 0.01, "no damage taken")


func test_archer_arrow_hurts_rama() -> void:
	await _frames(3)
	var archer := spawner.spawn_enemy("archer", rama.global_position + Vector3(0, 0, -12))
	assert_true(archer.is_ranged())
	assert_true(await _until(func(): return rama.health.current < rama.health.max_health, 900), "arrow hits Rama")


func test_arrows_kill_a_rakshasa() -> void:
	await _frames(3)
	var punya_before := GameState.punya
	var grunt := spawner.spawn_enemy("grunt", rama.global_position + Vector3(0, 0, -9))
	var died := [false]
	grunt.died.connect(func(_r): died[0] = true)
	for i in 12:
		if died[0]:
			break
		Input.action_press("shoot")
		await _frames(2)
		Input.action_release("shoot")
		await _frames(18)
	assert_true(died[0], "rakshasa slain")
	assert_false(grunt.is_in_group(&"enemies"), "no longer targetable")
	assert_true(grunt.state_machine.is_in(&"Dead"))
	assert_eq(GameState.punya, punya_before + grunt.data.punya_reward)


func test_waves_advance_when_cleared() -> void:
	spawner.break_time = 0.1
	spawner.spawn_wave(0)
	assert_eq(spawner.alive.size(), 3)
	for r in spawner.alive.duplicate():
		r.health.take_damage(10000.0)
	assert_true(await _until(func(): return spawner.current_wave == 1 and spawner.alive.size() == 3, 120), "wave 2 spawns")


func test_agneyastra_burns_a_group() -> void:
	await _frames(3)
	var agni: AstraResource = rama.astras[0]
	rama.grant_temporary_astra(0)  # the glimpse in Vasishtha's final trial
	assert_true(rama.is_astra_unlocked(agni), "available during the glimpse")
	var group := []
	for x in [-1.2, 0.0, 1.2]:
		var g := spawner.spawn_enemy("grunt", Vector3(x, 0, -14))
		group.append(g)
	await _frames(2)
	assert_true(rama.toggle_astra(0), "armed")
	assert_eq(rama.armed_astra, agni)
	var detonated := [false]
	rama.astra_detonated.connect(func(_p): detonated[0] = true)
	Input.action_press("shoot")
	await _until(func(): return rama.full_draw_time >= 0.05, 300)
	Input.action_release("shoot")
	await _frames(2)
	assert_null(rama.armed_astra, "astra consumed by the drawn shot")
	assert_true(rama.astra_cooldown_left(agni) > agni.cooldown - 1.0, "cooldown started")
	assert_false(rama.toggle_astra(0), "can't re-arm during cooldown")
	assert_true(await _until(func(): return detonated[0], 900), "detonates")
	await _frames(2)
	var scorched := 0
	for g in group:
		if is_instance_valid(g) and (g.health.current < g.health.max_health):
			scorched += 1
	assert_true(scorched >= 2, "area damage hit %d rakshasas" % scorched)
	var burning := group.filter(func(g): return is_instance_valid(g) and g.has_node("Burn"))
	assert_true(burning.size() >= 1, "burning applied")
	assert_true(await _until(func(): return Engine.time_scale == 1.0, 900), "time restored")


func test_rama_falls_and_rises() -> void:
	await _frames(3)
	rama.respawn_delay = 0.3
	var start := rama.spawn_point
	rama.global_position = start + Vector3(5, 0, 0)
	rama.health.take_damage(10000.0)
	await _frames(2)
	assert_true(rama.state_machine.is_in(&"Dead"))
	assert_true(await _until(func(): return rama.state_machine.is_in(&"Idle"), 120), "rises again")
	assert_almost(rama.health.current, rama.health.max_health, 0.01)
	assert_true(rama.global_position.distance_to(start) < 0.5, "back at the start")


func test_agneyastra_is_only_a_glimpse() -> void:
	await _frames(2)
	var agni: AstraResource = rama.astras[0]
	assert_false(rama.is_astra_unlocked(agni), "no astra before the final trial")
	assert_false(rama.toggle_astra(0), "can't arm it yet")
	spawner.break_time = 0.05
	spawner.spawn_wave(spawner.waves.size() - 1)
	assert_true(rama.is_astra_unlocked(agni), "granted for the final trial")
	assert_true(rama.toggle_astra(0), "armed")
	for r in spawner.alive.duplicate():
		r.health.take_damage(10000.0)
	assert_true(await _until(func(): return spawner.finished, 120), "trial complete")
	assert_false(rama.is_astra_unlocked(agni), "glimpse revoked")
	assert_null(rama.armed_astra, "disarmed")
	assert_false(agni.id in GameState.unlocked_astras, "never permanently unlocked")
	SaveSystem.delete_save(SaveSystem.AUTOSAVE_SLOT)
	GameState.completed_parts.clear()
