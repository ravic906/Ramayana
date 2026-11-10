class_name MissionSummary
extends CanvasLayer
## End-of-mission card: stars against the mission's three goals, what Rama
## earned, and a door to the skill tree before moving on.

signal done

var mission: MissionResource
var stats: MissionStats
var stars := 0
var best := 0


static func open(host: Node, m: MissionResource, s: MissionStats) -> MissionSummary:
	var card := MissionSummary.new()
	card.mission = m
	card.stats = s
	card.stars = s.stars(m.star_goals)
	card.best = GameState.record_stars(1, m.number, card.stars)
	SaveSystem.save_game()
	host.add_child(card)
	return card


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.03, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", PartCard._style(Color(0.97, 0.91, 0.77), PartCard.GOLD, 6, 22))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = -400
	panel.offset_bottom = 400
	panel.modulate.a = 0.0
	add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 14)
	panel.add_child(box)
	box.add_child(PartCard._label("Mission complete", 28, Color(0.55, 0.3, 0.1), true))
	box.add_child(PartCard._label(mission.title, 46, PartCard.INK, true))
	var star_row := StarRow.new()
	star_row.name = "Stars"
	star_row.filled = stars
	star_row.custom_minimum_size = Vector2(0, 90)
	box.add_child(star_row)
	for g in mission.star_goals:
		var ok := stats.met(g)
		box.add_child(PartCard._label(("Done:  " if ok else "Missed:  ") + MissionStats.label(g), 26,
			Color(0.2, 0.45, 0.2) if ok else Color(0.45, 0.4, 0.35), false))
	box.add_child(PartCard._label("Punya +%d     Dharma +%d     Perfect shots %d" % [
		maxi(stats.punya_earned(), 0), stats.dharma_gained, stats.perfect_shots], 24, PartCard.INK, true))
	if best > stars:
		box.add_child(PartCard._label("Your best: %d of 3 stars" % best, 22, Color(0.5, 0.4, 0.3), true))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 24)
	box.add_child(row)
	var skills := _button("Skills", Color(0.35, 0.28, 0.12))
	skills.pressed.connect(func() -> void: SkillsScreen.open(self))
	row.add_child(skills)
	var go := _button("Continue", Color(0.85, 0.42, 0.1))
	go.name = "Continue"
	go.pressed.connect(func() -> void:
		done.emit()
		queue_free())
	row.add_child(go)
	var t := create_tween().set_parallel(true)
	t.tween_property(bg, "color:a", 0.75, 0.6)
	t.tween_property(panel, "modulate:a", 1.0, 0.6)


## Three drawn stars (no font glyphs needed), the first `filled` in gold.
class StarRow extends Control:
	var filled := 0
	var size_px := 38.0

	func _draw() -> void:
		var gap := size_px * 2.6
		var start := size.x * 0.5 - gap
		for i in 3:
			var c := Vector2(start + gap * i, size.y * 0.5)
			var pts := PackedVector2Array()
			for k in 10:
				var rr := size_px if k % 2 == 0 else size_px * 0.45
				var a := -PI / 2.0 + k * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, Color(0.95, 0.7, 0.15) if i < filled else Color(0.75, 0.7, 0.62))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.45, 0.28, 0.08), 3.0, true)


func _button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 84)
	b.add_theme_font_size_override(&"font_size", 30)
	for st in [&"normal", &"hover", &"pressed", &"focus"]:
		b.add_theme_stylebox_override(st, PartCard._style(color, PartCard.GOLD, 3, 14))
	b.add_theme_color_override(&"font_color", Color(1, 0.97, 0.9))
	return b
