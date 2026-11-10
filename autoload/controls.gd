extends Node
## Registers gameplay input actions at startup so they work with keyboard,
## gamepad and the on-screen touch controls (which press these same actions).

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"shoot": [KEY_J, KEY_SPACE],
	"dodge": [KEY_K, KEY_SHIFT],
	"astra_1": [KEY_L, KEY_1],
	"astra_2": [KEY_2],
	"astra_3": [KEY_3],
	"astra_4": [KEY_4],
	"companion": [KEY_Q],
	"interact": [KEY_E],
}

const PAD_BUTTONS := {
	"shoot": JOY_BUTTON_RIGHT_SHOULDER,
	"dodge": JOY_BUTTON_A,
	"astra_1": JOY_BUTTON_Y,
	"astra_2": JOY_BUTTON_X,
	"astra_3": JOY_BUTTON_LEFT_SHOULDER,
	"astra_4": JOY_BUTTON_DPAD_UP,
	"companion": JOY_BUTTON_B,
	"interact": JOY_BUTTON_DPAD_DOWN,
}

const PAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
}


func _enter_tree() -> void:
	register_actions()


static func register_actions() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for keycode: Key in ACTIONS[action]:
			var key := InputEventKey.new()
			key.physical_keycode = keycode
			InputMap.action_add_event(action, key)
		if PAD_BUTTONS.has(action):
			var btn := InputEventJoypadButton.new()
			btn.button_index = PAD_BUTTONS[action]
			InputMap.action_add_event(action, btn)
		if PAD_AXES.has(action):
			var axis := InputEventJoypadMotion.new()
			axis.axis = PAD_AXES[action][0]
			axis.axis_value = PAD_AXES[action][1]
			InputMap.action_add_event(action, axis)
