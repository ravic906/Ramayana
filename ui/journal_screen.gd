class_name JournalScreen
extends CanvasLayer
## The Log: the story so far (missions, the current objective), side quests
## (track one to follow it on the compass) and the palm-leaf codex.
## Opened from the HUD's Log button and the pause menu.

enum Tab { STORY, QUESTS, CODEX }

var tab := Tab.STORY
var _list: VBoxContainer
var _tabs: Array[Button] = []


static func open(host: Node, start_tab := Tab.STORY) -> JournalScreen:
	var j := JournalScreen.new()
	j.tab = start_tab
	host.add_child(j)
	return j


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.045, 0.03, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 120
	root.offset_right = -120
	root.offset_top = 30
	root.offset_bottom = -30
	root.add_theme_constant_override(&"separation", 14)
	add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 14)
	root.add_child(top)
	var title := PartCard._label("Log", 46, Color(1, 0.85, 0.5), false)
	title.custom_minimum_size = Vector2(160, 0)
	top.add_child(title)
	for spec in [[Tab.STORY, "Story"], [Tab.QUESTS, "Side quests"], [Tab.CODEX, "Palm leaves"]]:
		var b := _button(spec[1], Color(0.35, 0.22, 0.12))
		b.name = "Tab_%s" % spec[1].replace(" ", "")
		var t: int = spec[0]
		b.pressed.connect(func() -> void: show_tab(t))
		top.add_child(b)
		_tabs.append(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var close := _button("Close", Color(0.25, 0.18, 0.12))
	close.pressed.connect(queue_free)
	top.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 10)
	scroll.add_child(_list)
	show_tab(tab)


func show_tab(t: int) -> void:
	tab = t
	for i in _tabs.size():
		_tabs[i].modulate = Color(1, 1, 1) if i == t else Color(0.6, 0.6, 0.6)
	for c in _list.get_children():
		c.queue_free()
	match t:
		Tab.STORY:
			_fill_story()
		Tab.QUESTS:
			_fill_quests()
		_:
			_fill_codex()


func _fill_story() -> void:
	var level := get_tree().current_scene as StoryLevel
	var current := GameState.current_mission
	for m in PartFlow.missions(1):
		var row := HBoxContainer.new()
		row.name = "Mission%d" % m.number
		row.add_theme_constant_override(&"separation", 16)
		_list.add_child(row)
		var is_current := m.number == current
		var reached := m.number <= PartFlow.furthest()
		var color := Color(1, 0.82, 0.4) if is_current else (Color(1, 0.95, 0.85) if reached else Color(0.5, 0.46, 0.4))
		var name_label := PartCard._label("%d.  %s%s" % [m.number, m.title, "   (now)" if is_current else ""], 30, color, false)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		if not m.available:
			row.add_child(PartCard._label("Coming soon", 22, Color(0.55, 0.5, 0.42), false))
		elif not m.star_goals.is_empty() and reached:
			var stars := MissionSummary.StarRow.new()
			stars.filled = GameState.stars_for(1, m.number)
			stars.size_px = 16.0
			stars.custom_minimum_size = Vector2(140, 44)
			row.add_child(stars)
		if is_current:
			var objective := level.objective_text if level and level.objective_text != "" else "Continue the journey from the Journey menu."
			var o := PartCard._label("Now:  " + objective, 24, Color(1, 0.9, 0.65), false)
			o.name = "CurrentObjective"
			o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_list.add_child(o)
			for g in m.star_goals:
				_list.add_child(PartCard._label("      Star goal:  " + MissionStats.label(g), 20, Color(0.75, 0.7, 0.6), false))


func _fill_quests() -> void:
	var any := false
	for q in Quests.all:
		var st := Quests.state(q.id)
		if st == "":
			continue
		any = true
		var done := st == "done"
		var row := HBoxContainer.new()
		row.name = "Quest_" + String(q.id)
		row.add_theme_constant_override(&"separation", 16)
		_list.add_child(row)
		var title := PartCard._label(("Done:  " if done else "") + q.title, 30,
			Color(0.6, 0.85, 0.55) if done else Color(1, 0.95, 0.85), false)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		if not done:
			var tracked := Quests.tracked == q.id
			var b := _button("Tracking" if tracked else "Track", Color(0.25, 0.4, 0.55) if tracked else Color(0.3, 0.26, 0.2))
			b.name = "Track"
			var id := q.id
			b.pressed.connect(func() -> void:
				Quests.tracked = id
				show_tab(Tab.QUESTS))
			row.add_child(b)
		var detail := "%s  ·  %s" % [q.giver, q.summary]
		if not done:
			detail += "\n%s     Reward: %d Punya%s" % [Quests.tracker_text(q.id), q.reward_punya,
				(", %d Dharma" % q.reward_dharma) if q.reward_dharma > 0 else ""]
		var d := PartCard._label(detail, 22, Color(0.85, 0.8, 0.7), false)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(d)
	if not any:
		_list.add_child(PartCard._label("No side quests yet. The people of Ayodhya may need your help.", 24, Color(0.75, 0.7, 0.62), false))


func _fill_codex() -> void:
	_list.add_child(PartCard._label("Palm leaves found: %d of %d" % [GameState.lore.size(), Quests.lore_entries.size()], 28, Color(1, 0.8, 0.45), false))
	for l in Quests.lore_entries:
		if l.id in GameState.lore:
			_list.add_child(PartCard._label(l.title, 28, Color(1, 0.95, 0.85), false))
			var t := PartCard._label(l.text, 22, Color(0.85, 0.8, 0.7), false)
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_list.add_child(t)
		else:
			_list.add_child(PartCard._label("A palm leaf not yet found", 24, Color(0.5, 0.46, 0.4), false))


func _button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 64)
	b.add_theme_font_size_override(&"font_size", 24)
	for st in [&"normal", &"hover", &"pressed", &"focus"]:
		b.add_theme_stylebox_override(st, PartCard._style(color, PartCard.GOLD, 3, 12))
	b.add_theme_color_override(&"font_color", Color(1, 0.96, 0.88))
	return b
