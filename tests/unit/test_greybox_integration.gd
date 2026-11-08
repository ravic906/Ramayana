extends TestCase
## Loads the grey-box level and drives Rama with simulated input.

var level: Node


func before_each() -> void:
	level = load("res://kandas/01_bala/greybox.tscn").instantiate()
	add_child(level)


func after_each() -> void:
	for a in ["move_forward", "shoot", "dodge"]:
		Input.action_release(a)
	level.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_rama_moves_forward() -> void:
	var rama: Rama = level.get_node("Rama")
	await _frames(10)
	var start_z := rama.global_position.z
	Input.action_press("move_forward")
	await _frames(40)
	assert_true(rama.state_machine.is_in(&"Move"), "should be in Move state")
	assert_true(rama.global_position.z < start_z - 1.0, "moved from %f to %f" % [start_z, rama.global_position.z])
	assert_true(rama.is_on_floor(), "should stand on the ground")


func test_shooting_damages_dummy() -> void:
	var rama: Rama = level.get_node("Rama")
	var dummy: TargetDummy = level.get_node("Dummy1")
	await _frames(5)
	Input.action_press("shoot")
	await _frames(2)
	Input.action_release("shoot")
	await _frames(45)
	assert_true(dummy.health.current < dummy.health.max_health,
		"dummy health %f" % dummy.health.current)


func test_dodge_grants_invulnerability() -> void:
	var rama: Rama = level.get_node("Rama")
	await _frames(5)
	Input.action_press("dodge")
	await _frames(2)
	assert_true(rama.state_machine.is_in(&"Dodge"))
	assert_true(rama.health.invulnerable)
	Input.action_release("dodge")
	await _frames(40)
	assert_false(rama.state_machine.is_in(&"Dodge"))
	assert_false(rama.health.invulnerable)
