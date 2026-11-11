class_name TrialsScreen
extends CanvasLayer
## The Trial Arena: the Gauntlet and rematches with bosses already beaten,
## each with its best result and medal. Opened from the Missions screen.

static func open(host: Node) -> TrialsScreen:
	var s := TrialsScreen.new()
	host.add_child(s)
	return s


func _ready() -> void:
	layer = 59
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.045, 0.03, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 200
	root.offset_right = -200
	root.offset_top = 40
	root.offset_bottom = -40
	root.add_theme_constant_override(&"separation", 18)
	add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var title := PartCard._label("Trials", 46, Color(1, 0.85, 0.5), false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(PartCard._label("Difficulty: %s" % Settings.mode_name(), 26, Color(0.9, 0.8, 0.65), false))
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(200, 72)
	close.add_theme_font_size_override(&"font_size", 28)
	close.pressed.connect(queue_free)
	top.add_child(close)
	for t: Dictionary in Trials.LIST:
		var row := HBoxContainer.new()
		row.name = "Trial_" + t["id"]
		row.add_theme_constant_override(&"separation", 20)
		root.add_child(row)
		var open := Trials.is_unlocked(t)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		text.add_child(PartCard._label(String(t["title"]), 32, Color(1, 0.94, 0.82) if open else Color(0.5, 0.46, 0.4), false))
		var sub := String(t["desc"]) if open else Trials.lock_reason(t)
		text.add_child(PartCard._label(sub, 22, Color(0.85, 0.78, 0.65) if open else Color(0.5, 0.46, 0.4), false))
		if open:
			var b = Trials.best(t["id"])
			var medal := Trials.best_medal(t["id"])
			var best_text := "Best %s%s" % [Trials.format_value(t, float(b)), ("  ·  " + Trials.MEDALS[medal]) if medal > 0 else ""] if b != null else "Not yet tried"
			row.add_child(PartCard._label(best_text, 24, Color(1.0, 0.8, 0.45), false))
			var play := Button.new()
			play.name = "Play"
			play.text = "Play"
			play.custom_minimum_size = Vector2(180, 72)
			play.add_theme_font_size_override(&"font_size", 28)
			var id: String = t["id"]
			play.pressed.connect(func() -> void: Trials.start(get_tree(), id))
			row.add_child(play)
