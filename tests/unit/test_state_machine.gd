extends TestCase

class CountingState:
	extends State
	var entered := 0
	var exited := 0
	var last_msg := {}

	func enter(msg: Dictionary = {}) -> void:
		entered += 1
		last_msg = msg

	func exit() -> void:
		exited += 1


func _make_machine() -> StateMachine:
	var actor := Node.new()
	var fsm := StateMachine.new()
	for n in ["A", "B"]:
		var s := CountingState.new()
		s.name = n
		fsm.add_child(s)
	actor.add_child(fsm)
	add_child(actor)
	return fsm


func test_enters_first_state_on_ready() -> void:
	var fsm := _make_machine()
	assert_true(fsm.is_in(&"A"))
	assert_eq(fsm.states["A"].entered, 1)


func test_transition_calls_exit_and_enter() -> void:
	var fsm := _make_machine()
	var changes := []
	fsm.state_changed.connect(func(from, to): changes.append([from, to]))
	fsm.transition_to(&"B", {"speed": 3})
	assert_true(fsm.is_in(&"B"))
	assert_eq(fsm.states["A"].exited, 1)
	assert_eq(fsm.states["B"].entered, 1)
	assert_eq(fsm.states["B"].last_msg, {"speed": 3})
	assert_eq(changes, [[&"A", &"B"]])


func test_unknown_state_is_ignored() -> void:
	var fsm := _make_machine()
	fsm.transition_to(&"Nope")
	assert_true(fsm.is_in(&"A"))


func test_states_get_actor() -> void:
	var fsm := _make_machine()
	assert_eq(fsm.states["A"].actor, fsm.get_parent())
	assert_eq(fsm.states["A"].machine, fsm)
