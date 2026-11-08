extends TestCase


func _make(max_hp: float = 100.0) -> Health:
	var h := Health.new()
	h.max_health = max_hp
	add_child(h)
	return h


func test_damage_and_death() -> void:
	var h := _make(30.0)
	var died := [false]
	h.died.connect(func(): died[0] = true)
	h.take_damage(10.0)
	assert_almost(h.current, 20.0)
	h.take_damage(50.0)
	assert_almost(h.current, 0.0)
	assert_true(died[0])
	assert_true(h.is_dead())


func test_invulnerable_ignores_damage() -> void:
	var h := _make()
	h.invulnerable = true
	h.take_damage(40.0)
	assert_almost(h.current, 100.0)


func test_heal_clamps_and_revive() -> void:
	var h := _make()
	h.take_damage(30.0)
	h.heal(100.0)
	assert_almost(h.current, 100.0)
	h.take_damage(200.0)
	h.heal(10.0)
	assert_almost(h.current, 0.0, 0.0001, "dead can't be healed")
	h.revive()
	assert_almost(h.current, 100.0)
