extends TestCase
## Lakshmana fights beside Rama; rakshasas choose targets by mode.

var level: Node


func after_each() -> void:
	if level:
		level.queue_free()
		level = null
	Music.stop()
	GameState.reset()


func _forest() -> Node:
	GameState.story_session = false
	GameState.current_mission = 3
	level = load("res://kandas/01_bala/forest.tscn").instantiate()
	add_child(level)
	return level


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_lakshmana_shoots_the_nearest_rakshasa() -> void:
	_forest()
	await _frames(3)
	var l: Lakshmana = level.lakshmana
	assert_eq(l.command, Lakshmana.Command.ATTACK)
	var r: Rakshasa = level.encounter1.spawn_enemy("grunt", l.global_position + Vector3(0, 0, -10))
	r.set_physics_process(false)
	r.state_machine.set_physics_process(false)
	var before := r.health.current
	await get_tree().create_timer(3.5).timeout
	assert_true(r.health.current < before, "his arrows land")


func test_he_never_shoots_a_fleeing_rakshasa() -> void:
	_forest()
	await _frames(3)
	var l: Lakshmana = level.lakshmana
	var r: Rakshasa = level.encounter1.spawn_enemy("grunt", l.global_position + Vector3(0, 0, -10))
	r.flee_below = 0.9
	r.health.take_damage(r.health.max_health * 0.2, null)
	assert_true(r.is_fleeing())
	assert_true(l._pick_foe() != r, "sparing is Rama's choice")


func test_command_toggles_and_downed_recovers() -> void:
	_forest()
	await _frames(3)
	var l: Lakshmana = level.lakshmana
	l.toggle_command()
	assert_eq(l.command, Lakshmana.Command.GUARD)
	l.toggle_command()
	assert_eq(l.command, Lakshmana.Command.ATTACK)
	l.health.take_damage(9999.0, null)
	assert_true(l.is_downed, "knocked down, not killed")
	assert_false(l.can_be_targeted())
	l._downed_left = 0.05
	await _frames(6)
	assert_false(l.is_downed, "he gets back up")
	assert_almost(l.health.current, l.health.max_health, 0.01)


func test_target_modes() -> void:
	_forest()
	await _frames(3)
	var l: Lakshmana = level.lakshmana
	var r: Rakshasa = level.encounter1.spawn_enemy("grunt", l.global_position + Vector3(2, 0, 0))
	r.target_mode = Rakshasa.TargetMode.NEAREST
	r.target = null
	assert_eq(r.find_target(), l, "NEAREST picks whoever is closer")
	var fire := Node3D.new()
	fire.add_to_group(&"objective")
	level.add_child(fire)
	fire.global_position = r.global_position + Vector3(0, 0, -5)
	r.target_mode = Rakshasa.TargetMode.OBJECTIVE
	r.target = null
	assert_eq(r.find_target(), fire, "OBJECTIVE heads for the objective")
	r.health.take_damage(1.0, level.rama)
	assert_eq(r.target, level.rama, "and turns on whoever strikes it")
	fire.queue_free()
