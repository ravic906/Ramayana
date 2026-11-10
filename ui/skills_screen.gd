class_name SkillsScreen
extends CanvasLayer
## The skill tree: three branches (Archery, Astras, Dharma) of four skills,
## each tier unlocking the next. Bought with Punya. Usable over the Journey
## menu, the pause menu or the mission summary.

signal closed

const BRANCH_NAMES := ["Archery", "Astras", "Dharma"]
const BRANCH_COLORS := [Color(0.85, 0.42, 0.1), Color(0.3, 0.45, 0.85), Color(0.35, 0.6, 0.3)]

var _punya_label: Label
var _columns: HBoxContainer


static func open(host: Node) -> SkillsScreen:
	var s := SkillsScreen.new()
	host.add_child(s)
	return s


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.045, 0.03, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 60
	root.offset_right = -60
	root.offset_top = 30
	root.offset_bottom = -30
	root.add_theme_constant_override(&"separation", 16)
	add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var title := PartCard._label("Skills", 46, Color(1, 0.85, 0.5), false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_punya_label = PartCard._label("", 34, Color(1, 0.93, 0.75), false)
	top.add_child(_punya_label)
	var close := _button("Close", Color(0.45, 0.3, 0.2))
	close.custom_minimum_size = Vector2(200, 72)
	close.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	top.add_child(close)
	_columns = HBoxContainer.new()
	_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override(&"separation", 24)
	root.add_child(_columns)
	refresh()


func refresh() -> void:
	_punya_label.text = "Punya: %d    " % GameState.punya
	for c in _columns.get_children():
		c.queue_free()
	for branch in 3:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override(&"separation", 12)
		_columns.add_child(col)
		col.add_child(PartCard._label(BRANCH_NAMES[branch], 34, BRANCH_COLORS[branch].lightened(0.3), true))
		for s in Skills.by_branch(branch):
			col.add_child(_card(s, BRANCH_COLORS[branch]))


func _card(s: SkillResource, color: Color) -> Control:
	var owned := Skills.has(s.id)
	var available := Skills.is_available(s)
	var panel := PanelContainer.new()
	panel.name = "Skill_" + String(s.id)
	var fill := Color(0.97, 0.91, 0.77) if owned else (Color(0.9, 0.84, 0.7) if available else Color(0.5, 0.46, 0.4))
	panel.add_theme_stylebox_override(&"panel", PartCard._style(fill, color if owned else PartCard.GOLD, 4 if owned else 2, 14))
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 4)
	panel.add_child(box)
	box.add_child(PartCard._label(s.display_name, 28, PartCard.INK, false))
	var desc := PartCard._label(s.description, 20, PartCard.INK.lightened(0.15), false)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	if owned:
		box.add_child(PartCard._label("Learned", 22, color.darkened(0.2), false))
	elif not available:
		var req := Skills.get_skill(s.requires)
		box.add_child(PartCard._label("Learn %s first" % (req.display_name if req else "?"), 20, Color(0.25, 0.2, 0.15), false))
	else:
		var b := _button("Learn  (%d Punya)" % s.cost, color)
		b.name = "Learn"
		b.disabled = GameState.punya < s.cost
		b.pressed.connect(func() -> void:
			if Skills.buy(s.id):
				refresh())
		box.add_child(b)
	return panel


func _button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override(&"font_size", 24)
	for st in [&"normal", &"hover", &"pressed", &"focus"]:
		b.add_theme_stylebox_override(st, PartCard._style(color, PartCard.GOLD, 3, 12))
	b.add_theme_stylebox_override(&"disabled", PartCard._style(color.darkened(0.5), PartCard.GOLD, 2, 12))
	b.add_theme_color_override(&"font_color", Color(1, 0.97, 0.9))
	return b
