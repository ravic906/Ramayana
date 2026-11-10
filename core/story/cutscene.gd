class_name Cutscene
extends CanvasLayer
## Plays a DialogueResource: letterbox bars, subtitle card with the speaker's
## name in their colour (typewriter text), full-screen narration cards, camera
## shots supplied by the level, tap to advance and a Skip button. Story actions
## still fire when skipped, so progress is never lost.

signal finished
signal action(name: StringName)

const SPEAKER_COLORS := {
	"Rama": Color(0.45, 0.65, 1.0),
	"Lakshmana": Color(1.0, 0.78, 0.35),
	"Vishvamitra": Color(1.0, 0.55, 0.2),
	"Vasishtha": Color(0.95, 0.92, 0.8),
	"Dasharatha": Color(1.0, 0.85, 0.45),
	"Tataka": Color(0.85, 0.4, 0.75),
	"Herald": Color(0.85, 0.85, 0.85),
	"The Astras": Color(1.0, 0.92, 0.6),
	"Subahu": Color(1.0, 0.35, 0.2),
	"Maricha": Color(0.75, 0.55, 1.0),
}
const CHARS_PER_SECOND := 45.0

var dialogue: DialogueResource
## shot id -> [camera position, look-at point]
var shots := {}
var index := -1

var _cam: Camera3D
var _prev_cam: Camera3D
var _look := Vector3.ZERO
var _done := false
var _typing: Tween
var _waiting := false
var _speaker: Label
var _text: Label
var _panel: PanelContainer
var _narration: ColorRect
var _narration_text: Label
var _bars: Array[ColorRect] = []
var _line_token := 0
## Seconds to wait after a spoken line before moving on by itself.
const AUTO_ADVANCE_PAUSE := 0.6


## Starts a cutscene under `host` (usually the level root).
static func play(host: Node, d: DialogueResource, shot_map: Dictionary = {}) -> Cutscene:
	var c := Cutscene.new()
	c.dialogue = d
	c.shots = shot_map
	host.add_child(c)
	return c


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	if not shots.is_empty():
		_prev_cam = get_viewport().get_camera_3d()
		_cam = Camera3D.new()
		_cam.fov = 50.0
		var host3d := get_parent() as Node3D
		(host3d if host3d else get_tree().current_scene).add_child(_cam)
		_cam.current = true
	for i in _bars.size():
		var bar := _bars[i]
		var t := create_tween()
		t.tween_property(bar, "custom_minimum_size:y", 110.0, 0.4)
	advance.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	# On phones each touch also arrives as an emulated mouse click: count it once.
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION) \
		or event.is_action_pressed(&"ui_accept")
	if tapped:
		get_viewport().set_input_as_handled()
		if _typing and _typing.is_running():
			_typing.kill()
			_text.visible_ratio = 1.0
			_narration_text.visible_ratio = 1.0
		elif not _waiting:
			Voice.stop()
			advance()


## Shows the next line (or finishes).
func advance() -> void:
	if _done:
		return
	index += 1
	if dialogue == null or index >= dialogue.line_count():
		_finish()
		return
	var line := dialogue.get_line(index)
	if line["shot"] != &"" and shots.has(line["shot"]):
		_move_camera(shots[line["shot"]], index > 0)
	var act: StringName = line["action"]
	if act != &"":
		if String(act).begins_with("wait:"):
			_waiting = true
			get_tree().create_timer(float(String(act).substr(5)), true, false, true).timeout.connect(func() -> void:
				_waiting = false
				if line["text"] == "":
					advance())
		else:
			action.emit(act)
	if line["text"] == "":
		if not _waiting:
			advance.call_deferred()
		_panel.visible = false
		return
	_show_line(line["speaker"], line["text"])


## Skips to the end, still emitting every remaining story action.
func skip() -> void:
	if _done:
		return
	for i in range(index + 1, dialogue.line_count()):
		var act: StringName = dialogue.get_line(i)["action"]
		if act != &"" and not String(act).begins_with("wait:"):
			action.emit(act)
	index = dialogue.line_count()
	_finish()


func is_done() -> bool:
	return _done


func _show_line(speaker: String, text: String) -> void:
	var narration := speaker == "Narration"
	_narration.visible = narration
	_panel.visible = not narration
	var label := _narration_text if narration else _text
	if not narration:
		_speaker.text = speaker
		_speaker.add_theme_color_override(&"font_color", SPEAKER_COLORS.get(speaker, Color.WHITE))
	label.text = text
	label.visible_ratio = 0.0
	if _typing:
		_typing.kill()
	_line_token += 1
	var spoken := Voice.say(speaker, text)
	var type_time := maxf(text.length() / CHARS_PER_SECOND, 0.2)
	if spoken > 0.0:
		type_time = minf(type_time, spoken * 0.8)  # the text keeps pace with the voice
		var token := _line_token
		get_tree().create_timer(spoken + AUTO_ADVANCE_PAUSE, true, false, true).timeout.connect(func() -> void:
			if token == _line_token and not _done and not _waiting:
				advance())
	_typing = create_tween()
	_typing.tween_property(label, "visible_ratio", 1.0, type_time)


func _move_camera(shot: Array, smooth: bool) -> void:
	if _cam == null:
		return
	var pos: Vector3 = shot[0]
	var look: Vector3 = shot[1]
	if not smooth:
		_cam.global_position = pos
		_look = look
		_cam.look_at(_look)
		return
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_cam, "global_position", pos, 1.2)
	t.tween_method(func(v: Vector3) -> void:
		_look = v
		if is_instance_valid(_cam):
			_cam.look_at(v), _look, look, 1.2)


func _finish() -> void:
	if _done:
		return
	_done = true
	_line_token += 1
	Voice.stop()
	if _typing:
		_typing.kill()
	if _cam:
		if is_instance_valid(_prev_cam):
			_prev_cam.current = true
		_cam.queue_free()
	# Deferred, so a listener that starts awaiting right after play() still hears it.
	finished.emit.call_deferred()
	queue_free.call_deferred()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0.03, 0.02, 0.02, 1)
		bar.custom_minimum_size = Vector2(0, 0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bars.append(bar)
		if i == 1:
			var spacer := Control.new()
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(spacer)
		col.add_child(bar)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", PartCard._style(Color(0.08, 0.05, 0.04, 0.82), PartCard.GOLD, 3, 16))
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -760
	_panel.offset_right = 760
	_panel.offset_top = -330
	_panel.offset_bottom = -130
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_speaker = PartCard._label("", 34, Color.WHITE, false)
	box.add_child(_speaker)
	_text = PartCard._label("", 36, Color(1, 0.97, 0.9), false)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)

	_narration = ColorRect.new()
	_narration.color = Color(0.1, 0.06, 0.04, 0.92)
	_narration.set_anchors_preset(Control.PRESET_FULL_RECT)
	_narration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narration.visible = false
	root.add_child(_narration)
	var sung := PartCard._label("Lava and Kusha sing", 30, Color(1, 0.8, 0.45), true)
	sung.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sung.offset_top = 260
	sung.offset_left = -600
	sung.offset_right = 600
	_narration.add_child(sung)
	_narration_text = PartCard._label("", 46, Color(1, 0.95, 0.85), true)
	_narration_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narration_text.set_anchors_preset(Control.PRESET_CENTER)
	_narration_text.offset_left = -700
	_narration_text.offset_right = 700
	_narration_text.offset_top = -120
	_narration_text.offset_bottom = 200
	_narration.add_child(_narration_text)

	var skip_btn := Button.new()
	skip_btn.text = "Skip"
	skip_btn.add_theme_font_size_override(&"font_size", 30)
	skip_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_btn.offset_left = -220
	skip_btn.offset_top = 20
	skip_btn.offset_right = -36
	skip_btn.offset_bottom = 110  # >= 64 px touch target on phones
	skip_btn.add_theme_stylebox_override(&"normal", PartCard._style(Color(0.15, 0.1, 0.08, 0.7), PartCard.GOLD, 2, 14))
	skip_btn.pressed.connect(skip)
	root.add_child(skip_btn)
