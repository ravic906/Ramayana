extends TestCase
## Loads the grey-box level and drives Rama with simulated input.

var level: Node


func before_each() -> void:
	level = load("res://kandas/01_bala/greybox.tscn").instantiate()
	level.get_node("WaveSpawner").auto_start = false
	add_child(level)


func after_each() -> void:
	for a in ["move_forward", "shoot", "dodge"]:
		Input.action_release(a)
	level.queue_free()
	TimeFX.clear_all()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Waits until cond() is true (or max_frames pass); returns whether it became true.
func _until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func test_rama_moves_forward() -> void:
	var rama: Rama = level.get_node("Rama")
	await _frames(10)
	var start_z := rama.global_position.z
	Input.action_press("move_forward")
	await _frames(40)
	assert_true(rama.state_machine.is_in(&"Move"), "should be in Move state")
	assert_true(rama.global_position.z < start_z - 1.0, "moved from %f to %f" % [start_z, rama.global_position.z])
	assert_true(rama.is_on_floor(), "should stand on the ground")
	assert_true(rama.model.get_locomotion() > 0.5, "run blend %f" % rama.model.get_locomotion())
	Input.action_release("move_forward")
	await _frames(40)
	assert_true(rama.model.get_locomotion() < 0.05, "back to idle blend %f" % rama.model.get_locomotion())


func test_shooting_damages_dummy() -> void:
	var rama: Rama = level.get_node("Rama")
	var dummy: TargetDummy = level.get_node("Dummy1")
	await _frames(5)
	# A quick tap is a snap shot, fired on release.
	Input.action_press("shoot")
	await _frames(3)
	assert_true(rama.state_machine.is_in(&"Aim"), "pressing Bow starts a draw")
	Input.action_release("shoot")
	await _frames(3)
	assert_true(rama.model.is_playing(&"shoot"), "shoot one-shot should play")
	assert_false(rama.cam.is_aiming(), "a tap never engages the aim camera")
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
	await _frames(1)
	assert_true(rama.model.is_playing(&"roll"), "roll one-shot should play")
	Input.action_release("dodge")
	await _frames(50)
	assert_false(rama.state_machine.is_in(&"Dodge"))
	assert_false(rama.health.invulnerable)


func test_rama_model_is_rigged_and_dressed() -> void:
	var rama: Rama = level.get_node("Rama")
	await _frames(2)
	assert_true(rama.model != null, "RamaModel present")
	assert_eq(rama.model.skeleton.get_bone_count(), 65)
	for clip in ["idle", "walk", "run", "roll", "shoot", "hit"]:
		assert_true(rama.model.anim_player.has_animation(clip), "missing clip " + clip)
	assert_true(rama.model.skeleton.find_child("Att_Head", false, false) != null, "crown attachment")
	assert_true(rama.model.bow != null and rama.model.bow.is_inside_tree(), "Kodanda bow")


func test_full_draw_perfect_shot_with_arrow_cam() -> void:
	var rama: Rama = level.get_node("Rama")
	var dummy: TargetDummy = level.get_node("Dummy1")
	await _frames(5)
	var results := []
	rama.released.connect(func(_a, power, perfect): results.append([power, perfect]))
	var damage := [0.0]
	dummy.health.damaged.connect(func(amount, _s): damage[0] += amount)

	Input.action_press("shoot")
	assert_true(await _until(func(): return rama.full_draw_time >= 0.05, 300), "reaches full draw")
	assert_true(rama.cam.is_aiming(), "over-the-shoulder aim camera")
	assert_true(rama.model.aim_weight > 0.9, "archery stance")
	assert_true(Engine.time_scale < 0.7, "focus slow-motion, got %f" % Engine.time_scale)
	assert_true(rama.is_in_perfect_window(), "in the golden window")
	assert_true(rama.aim_target == dummy, "aim assist locks the dummy ahead")
	assert_true(rama.model.string_hand_error() < 0.12, "string hand at the anchor, error %f" % rama.model.string_hand_error())

	Input.action_release("shoot")
	await _frames(2)
	assert_eq(results.size(), 1)
	if results.size() == 1:
		assert_almost(results[0][0], 1.0, 0.001, "full power")
		assert_true(results[0][1], "perfect release")
	assert_true(rama.cam.arrow_cam_active, "arrow cam follows a perfect shot")
	assert_true(await _until(func(): return damage[0] > 0.0, 900), "arrow lands")
	assert_true(damage[0] >= rama.max_damage * rama.perfect_multiplier - 0.01, "perfect damage %f" % damage[0])
	assert_true(await _until(func(): return Engine.time_scale == 1.0 and not rama.cam.arrow_cam_active, 900),
		"time and camera return to normal (scale %f)" % Engine.time_scale)


func test_holding_too_long_is_not_perfect() -> void:
	var rama: Rama = level.get_node("Rama")
	await _frames(5)
	var perfect_flags := []
	rama.released.connect(func(_a, _p, perfect): perfect_flags.append(perfect))
	Input.action_press("shoot")
	await _until(func(): return rama.full_draw_time > rama.perfect_window + 0.1, 400)
	Input.action_release("shoot")
	await _frames(2)
	assert_eq(perfect_flags, [false])
	assert_false(rama.cam.arrow_cam_active)


func test_dodge_cancels_draw() -> void:
	var rama: Rama = level.get_node("Rama")
	await _frames(5)
	Input.action_press("shoot")
	await _until(func(): return rama.draw_amount > 0.5, 200)
	Input.action_press("dodge")
	await _frames(2)
	assert_true(rama.state_machine.is_in(&"Dodge"))
	assert_false(rama.is_drawing, "draw abandoned")
	assert_false(TimeFX.has_layer(&"focus"), "focus slow-motion cleared")
	Input.action_release("dodge")
	Input.action_release("shoot")
