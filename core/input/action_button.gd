class_name ActionButton
extends Control
## Round multitouch on-screen button that presses an input action while held.

signal pressed
signal released

@export var action := &"shoot"
@export var label := "Bow"
@export var color := Color(0.95, 0.55, 0.16, 0.8)
@export var pressed_color := Color(1.0, 0.8, 0.35, 0.95)

var is_held := false
## 0..1 ring drawn around the button (e.g. bow draw).
var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()
var progress_color := Color(1.0, 0.82, 0.3, 1.0)
var _touch_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and _hit(touch.position):
			_touch_index = touch.index
			_set_held(true)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			_set_held(false)
			get_viewport().set_input_as_handled()


func _hit(screen_pos: Vector2) -> bool:
	var center := global_position + size * 0.5
	return screen_pos.distance_to(center) <= minf(size.x, size.y) * 0.5


func _set_held(value: bool) -> void:
	is_held = value
	if InputMap.has_action(action):
		if value:
			Input.action_press(action)
		else:
			Input.action_release(action)
	if value:
		pressed.emit()
	else:
		released.emit()
	queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	draw_circle(c, r, pressed_color if is_held else color)
	draw_arc(c, r - 2.0, 0.0, TAU, 48, Color(1, 1, 1, 0.6), 3.0, true)
	if progress > 0.0:
		draw_arc(c, r + 8.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 64, progress_color, 7.0, true)
	var font := get_theme_default_font()
	var font_size := int(r * 0.42)
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, c - Vector2(text_size.x * 0.5, -font_size * 0.35), label,
		HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
