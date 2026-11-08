extends TestCase

var saves: Node
var state: Node


func before_each() -> void:
	saves = load("res://autoload/save_system.gd").new()
	saves.save_dir = "user://test_saves"
	add_child(saves)
	state = load("res://autoload/game_state.gd").new()
	add_child(state)


func after_each() -> void:
	for slot in range(saves.MAX_SLOTS + 1):
		saves.delete_save(slot)


func test_round_trip() -> void:
	state.set_kanda(0)
	state.add_punya(120)
	state.unlock_astra(&"agneyastra")
	state.set_flag("tataka_defeated")
	assert_eq(saves.save_data(1, state.to_dict()), OK)

	var restored: Node = load("res://autoload/game_state.gd").new()
	add_child(restored)
	restored.from_dict(saves.load_data(1))
	assert_eq(restored.punya, 120)
	assert_eq(restored.current_kanda, 0)
	assert_true(&"agneyastra" in restored.unlocked_astras)
	assert_true(restored.get_flag("tataka_defeated"))


func test_tampered_save_rejected() -> void:
	saves.save_data(2, {"punya": 5})
	var path: String = saves.slot_path(2)
	var text := FileAccess.get_file_as_string(path).replace("5", "9999")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	assert_true(saves.load_data(2).is_empty())


func test_missing_slot_returns_empty() -> void:
	assert_true(saves.load_data(3).is_empty())
	assert_false(saves.has_save(3))


func test_invalid_slot_rejected() -> void:
	assert_eq(saves.save_data(99, {}), ERR_PARAMETER_RANGE_ERROR)


func test_kanda_gating() -> void:
	assert_true(state.is_kanda_playable(0, false))
	assert_false(state.is_kanda_playable(1, false))
	assert_true(state.is_kanda_playable(6, true))
	assert_false(state.is_kanda_playable(7, true))
