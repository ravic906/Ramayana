class_name TrialResult
extends CanvasLayer
## The end of a trial: the result, the medal, the best so far; Try again or
## back to the Journey.

var trial_id := ""
var value := 0.0
var won := true
var _rec := {}


static func open(host: Node, id: String, result: float, finished := true) -> TrialResult:
	var r := TrialResult.new()
	r.trial_id = id
	r.value = result
	r.won = finished
	host.add_child(r)
	return r


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var t := Trials.get_trial(trial_id)
	if won:
		_rec = Trials.record(trial_id, value)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.035, 0.025, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -480
	panel.offset_right = 480
	panel.offset_top = -330
	panel.offset_bottom = 330
	panel.add_theme_stylebox_override(&"panel", PartCard._style(Color(0.96, 0.9, 0.76), PartCard.GOLD, 4, 18))
	add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 18)
	panel.add_child(box)
	box.add_child(PartCard._label(String(t.get("title", "Trial")), 40, PartCard.INK, true))
	box.add_child(PartCard._label("Difficulty: %s" % Settings.mode_name(), 24, Color(0.4, 0.3, 0.2), true))
	if won:
		var what := "Time" if t["kind"] == "time" else "Score"
		box.add_child(PartCard._label("%s: %s" % [what, Trials.format_value(t, value)], 34, PartCard.INK, true))
		var medal: int = _rec.get("medal", 0)
		var medal_text := "%s medal" % Trials.MEDALS[medal] if medal > 0 else "No medal yet"
		var medal_label := PartCard._label(medal_text, 34, [Color(0.4, 0.35, 0.3), Color(0.6, 0.35, 0.15), Color(0.45, 0.47, 0.52), Color(0.75, 0.55, 0.05)][medal], true)
		medal_label.name = "Medal"
		box.add_child(medal_label)
		var b = Trials.best(trial_id)
		box.add_child(PartCard._label("Best: %s%s" % [Trials.format_value(t, float(b)) if b != null else "-", "  (new best!)" if _rec.get("new_best", false) else ""], 26, Color(0.35, 0.28, 0.2), true))
		if int(_rec.get("punya", 0)) > 0:
			box.add_child(PartCard._label("+%d Punya" % _rec["punya"], 28, Color(0.7, 0.45, 0.05), true))
	else:
		box.add_child(PartCard._label("The trial is not won this time.", 30, PartCard.INK, true))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 30)
	box.add_child(row)
	for spec in [["Try again", _retry], ["Back to the Journey", _back]]:
		var btn := Button.new()
		btn.name = String(spec[0]).replace(" ", "")
		btn.text = spec[0]
		btn.custom_minimum_size = Vector2(320, 84)
		btn.add_theme_font_size_override(&"font_size", 28)
		btn.pressed.connect(spec[1])
		row.add_child(btn)
	get_tree().paused = true


func _retry() -> void:
	get_tree().paused = false
	Trials.start(get_tree(), trial_id)


func _back() -> void:
	get_tree().paused = false
	GameState.trial = ""
	SaveSystem.save_game()
	get_tree().change_scene_to_file("res://ui/journey_menu.tscn")
