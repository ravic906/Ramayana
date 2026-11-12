class_name TouchJoystick
extends Control
## Floating multitouch joystick. A touch that starts inside this control's
## rect spawns the stick at the finger and drives the four move actions.

@export var radius := 110.0
@export var dead_zone := 0.15
@export var action_left := &"move_left"
@export var action_right := &"move_right"
@export var action_up := &"move_forward"
@export var action_down := &"move_back"
@export var base_color := Color(1, 1, 1, 0.18)
@export var knob_color := Color(0.83, 0.65, 0.23, 0.75)

var output := Vector2.ZERO
var _touch_index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_origin()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and get_global_rect().has_point(touch.position):
			_touch_index = touch.index
			_origin = touch.position - global_position
			_update_knob(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_knob(drag.position)
			get_viewport().set_input_as_handled()


func _update_knob(screen_pos: Vector2) -> void:
	var offset := (screen_pos - global_position) - _origin
	offset = offset.limit_length(radius)
	_knob = _origin + offset
	output = offset / radius
	if output.length() < dead_zone:
		output = Vector2.ZERO
	_apply_actions()
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	output = Vector2.ZERO
	_apply_actions()
	_reset_origin()
	queue_redraw()


func _reset_origin() -> void:
	_origin = Vector2(radius * 1.4, size.y - radius * 1.4)
	_knob = _origin


func _apply_actions() -> void:
	_set_action(action_left, maxf(-output.x, 0.0))
	_set_action(action_right, maxf(output.x, 0.0))
	_set_action(action_up, maxf(-output.y, 0.0))
	_set_action(action_down, maxf(output.y, 0.0))


func _set_action(action: StringName, strength: float) -> void:
	if not InputMap.has_action(action):
		return
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _touch_index == -1:
		_reset_origin()
		queue_redraw()


func _draw() -> void:
	draw_circle(_origin, radius, base_color)
	draw_arc(_origin, radius, 0.0, TAU, 48, Color(knob_color, 0.5), 3.0, true)
	draw_circle(_knob, radius * 0.42, knob_color)
