extends TestCase
## Shield-bearers, Mayavi illusionists and brutes.

var level: Node


func after_each() -> void:
	if level:
		level.queue_free()
		level = null
	Music.stop()
	GameState.reset()


func _ashram() -> Node:
	level = load("res://kandas/01_bala/siddhashrama.tscn").instantiate()
	level.auto_start = false
	add_child(level)
	return level


func test_shield_turns_frontal_arrows_but_not_flanks_or_astras() -> void:
	_ashram()
	await get_tree().physics_frame
	var r: Rakshasa = level.spawner.spawn_enemy("shield", Vector3(0, 0, 8))
	await get_tree().physics_frame
	r.set_physics_process(false)
	r.state_machine.set_physics_process(false)
	r.model.rotation.y = 0.0  # facing -Z
	var front := Node3D.new()
	level.add_child(front)
	front.global_position = r.global_position + Vector3(0, 0, -6)
	var hp := r.health.current
	r.health.take_damage(30.0, front)
	assert_almost(r.health.current, hp - 3.0, 0.01, "a frontal arrow is turned aside")
	front.global_position = r.global_position + Vector3(6, 0, 0)
	hp = r.health.current
	r.health.take_damage(30.0, front)
	assert_almost(r.health.current, hp - 30.0, 0.01, "from the flank it lands")
	front.global_position = r.global_position + Vector3(0, 0, -6)
	r.break_shield()
	hp = r.health.current
	r.health.take_damage(10.0, front)
	assert_almost(r.health.current, hp - 10.0, 0.01, "Lakshmana's shove opens the guard")
	front.queue_free()


func test_mayavi_blinks_and_conjures_decoys() -> void:
	_ashram()
	await get_tree().physics_frame
	var m: Rakshasa = level.spawner.spawn_enemy("mayavi", Vector3(0, 0, -10))
	await get_tree().physics_frame
	var before := get_tree().get_nodes_in_group(&"enemies").size()
	var pos := m.global_position
	m.blink()
	assert_true(m.global_position.distance_to(pos) > 0.5, "it moved")
	await get_tree().physics_frame
	var enemies := get_tree().get_nodes_in_group(&"enemies")
	assert_eq(enemies.size(), before + 2, "two decoys")
	var decoy: Rakshasa = null
	for e in enemies:
		if e is Rakshasa and (e as Rakshasa).is_decoy:
			decoy = e
	var punya := GameState.punya
	decoy.health.take_damage(5.0, level.rama)
	assert_true(decoy.health.is_dead(), "one hit")
	assert_eq(GameState.punya, punya, "illusions give nothing")


func test_brute_staggers_only_on_perfect_shots_or_astras() -> void:
	_ashram()
	await get_tree().physics_frame
	var b: Rakshasa = level.spawner.spawn_enemy("brute", Vector3(0, 0, -12))
	await get_tree().physics_frame
	b.health.take_damage(34.0, level.rama)  # a full draw
	await get_tree().physics_frame
	assert_false(b.state_machine.is_in(&"Stagger"), "shrugs off a normal arrow")
	b.health.take_damage(68.0, level.rama)  # a perfect shot
	await get_tree().physics_frame
	assert_true(b.state_machine.is_in(&"Stagger"))
