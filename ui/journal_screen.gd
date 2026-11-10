class_name JournalScreen
extends CanvasLayer
## The journal: side quests (active and done) and the palm-leaf codex.

var _list: VBoxContainer


static func open(host: Node) -> JournalScreen:
	var j := JournalScreen.new()
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
	root.offset_left = 140
	root.offset_right = -140
	root.offset_top = 30
	root.offset_bottom = -30
	root.add_theme_constant_override(&"separation", 12)
	add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var title := PartCard._label("Journal", 46, Color(1, 0.85, 0.5), false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(200, 72)
	close.add_theme_font_size_override(&"font_size", 28)
	close.pressed.connect(queue_free)
	top.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 10)
	scroll.add_child(_list)
	_fill()


func _fill() -> void:
	_list.add_child(PartCard._label("Side quests", 34, Color(1, 0.8, 0.45), false))
	var any := false
	for q in Quests.all:
		var st := Quests.state(q.id)
		if st == "":
			continue
		any = true
		var done := st == "done"
		var line := "%s  (%s)" % [q.title, q.giver]
		var row := PartCard._label(("Done:  " if done else "") + line, 28,
			Color(0.6, 0.85, 0.55) if done else Color(1, 0.95, 0.85), false)
		row.name = "Quest_" + String(q.id)
		_list.add_child(row)
		var detail := q.summary if done else "%s\n%s" % [q.summary, Quests.tracker_text(q.id)]
		var d := PartCard._label(detail, 22, Color(0.85, 0.8, 0.7), false)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(d)
	if not any:
		_list.add_child(PartCard._label("No side quests yet. Talk to the people of Ayodhya.", 24, Color(0.75, 0.7, 0.62), false))
	_list.add_child(PartCard._label("\nPalm leaves (%d/%d)" % [GameState.lore.size(), Quests.lore_entries.size()], 34, Color(1, 0.8, 0.45), false))
	for l in Quests.lore_entries:
		if l.id in GameState.lore:
			_list.add_child(PartCard._label(l.title, 28, Color(1, 0.95, 0.85), false))
			var t := PartCard._label(l.text, 22, Color(0.85, 0.8, 0.7), false)
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_list.add_child(t)
		else:
			_list.add_child(PartCard._label("A palm leaf not yet found", 24, Color(0.5, 0.46, 0.4), false))
