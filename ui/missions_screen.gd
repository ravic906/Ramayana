class_name MissionsScreen
extends CanvasLayer
## Part 1's missions with their best stars. Any mission, and any of its
## chapters, can be played at will (PartFlow.start_at grants what the story
## would have given by then). The Journey's Play still continues the story.

signal mission_chosen(number: int, chapter: int)

var part_number := 1


static func open(host: Node, part: int = 1) -> MissionsScreen:
	var s := MissionsScreen.new()
	s.part_number = part
	host.add_child(s)
	return s


func _ready() -> void:
	layer = 58
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.045, 0.03, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 200
	root.offset_right = -200
	root.offset_top = 40
	root.offset_bottom = -40
	root.add_theme_constant_override(&"separation", 14)
	add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var title := PartCard._label("Part %d: Missions" % part_number, 46, Color(1, 0.85, 0.5), false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var trials := Button.new()
	trials.name = "TrialsButton"
	trials.text = "Trials"
	trials.custom_minimum_size = Vector2(200, 72)
	trials.add_theme_font_size_override(&"font_size", 28)
	trials.pressed.connect(func() -> void: TrialsScreen.open(get_parent()))
	top.add_child(trials)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(200, 72)
	close.add_theme_font_size_override(&"font_size", 28)
	close.pressed.connect(queue_free)
	top.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 12)
	scroll.add_child(list)
	var furthest := PartFlow.furthest()
	for m in PartFlow.missions(part_number):
		if not m.available:
			continue
		var row := HBoxContainer.new()
		row.name = "Mission%d" % m.number
		row.add_theme_constant_override(&"separation", 18)
		list.add_child(row)
		var reached := m.number <= furthest
		var name_label := PartCard._label("%d.  %s" % [m.number, m.title], 32,
			Color(1, 0.94, 0.82) if reached else Color(0.5, 0.46, 0.4), false)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		if not m.star_goals.is_empty():
			var stars := MissionSummary.StarRow.new()
			stars.filled = GameState.stars_for(part_number, m.number)
			stars.size_px = 20.0
			stars.custom_minimum_size = Vector2(170, 64)
			row.add_child(stars)
			var hard := GameState.hard_stars_for(part_number, m.number)
			if hard > 0:
				var seal := PartCard._label("Maharathi %d/3" % hard, 20, Color(1.0, 0.45, 0.35), true)
				seal.name = "HardSeal"
				row.add_child(seal)
		if not reached:
			row.add_child(PartCard._label("ahead of your story", 20, Color(0.75, 0.68, 0.55), false))
		var play := Button.new()
		play.name = "Play"
		play.text = "Play"
		play.custom_minimum_size = Vector2(200, 64)
		play.add_theme_font_size_override(&"font_size", 26)
		play.add_theme_stylebox_override(&"normal", PartCard._style(Color(0.85, 0.42, 0.1), PartCard.GOLD, 3, 12))
		var n := m.number
		play.pressed.connect(func() -> void:
			mission_chosen.emit(n, 0)
			queue_free())
		row.add_child(play)
		# Chapters: start part-way through.
		var chapters := PartFlow.chapters(m.number)
		if chapters.size() > 1:
			var crow := HFlowContainer.new()
			crow.name = "Chapters%d" % m.number
			crow.add_theme_constant_override(&"h_separation", 12)
			list.add_child(crow)
			crow.add_child(PartCard._label("      Chapters:", 22, Color(0.85, 0.78, 0.65), false))
			for ci in chapters.size():
				var cb := Button.new()
				cb.name = "Chapter%d" % ci
				cb.text = chapters[ci][0]
				cb.custom_minimum_size = Vector2(0, 52)
				cb.add_theme_font_size_override(&"font_size", 22)
				var c := ci
				cb.pressed.connect(func() -> void:
					mission_chosen.emit(n, c)
					queue_free())
				crow.add_child(cb)
