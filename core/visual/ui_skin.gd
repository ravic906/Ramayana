class_name UiSkin
extends RefCounted
## Dresses the HUD in the Gemini-made interface art (assets/art/gemini/ui): ivory-and-gold panels
## on the Map/Log/Pause buttons and the pause menu, ruby-gold action buttons, and the gold bar
## frame round the health. Applied by IllustratedLook; other levels keep the flat HUD.

const DIR := "res://assets/art/gemini/ui/%s.png"
const INK := Color(0.28, 0.16, 0.08)


static func _panel(margin: int) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(DIR % "panel")
	s.texture_margin_left = margin
	s.texture_margin_right = margin
	s.texture_margin_top = margin
	s.texture_margin_bottom = margin
	s.content_margin_left = margin * 0.6
	s.content_margin_right = margin * 0.6
	s.content_margin_top = margin * 0.4
	s.content_margin_bottom = margin * 0.4
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return s


static func apply(hud: Node) -> void:
	if hud == null:
		return
	var root := hud.get_node_or_null("Root")
	if root == null:
		return
	for n in ["PauseButton", "LogButton", "MapButton"]:
		var b := root.get_node_or_null(n) as Button
		if b:
			var st := _panel(26)
			for state in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(state, st)
			b.add_theme_color_override(&"font_color", INK)
			b.add_theme_color_override(&"font_pressed_color", INK)
			b.add_theme_color_override(&"font_hover_color", INK)
	var pause := root.get_node_or_null("PausePanel") as PanelContainer
	if pause:
		pause.add_theme_stylebox_override(&"panel", _panel(34))
	var bar := root.get_node_or_null("HealthBar") as ProgressBar
	if bar and root.get_node_or_null("HealthFrame") == null:
		# The gold frame (719x127 picture) sits over the bar; the bar is inset into its trough.
		var fx := 26.0
		var fy := 12.0
		var fw := 470.0
		var fh := fw * 127.0 / 720.0
		var frame := TextureRect.new()
		frame.name = "HealthFrame"
		frame.texture = load(DIR % "bar")
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.position = Vector2(fx, fy)
		frame.size = Vector2(fw, fh)
		root.add_child(frame)
		root.move_child(frame, bar.get_index() + 1)
		var empty := StyleBoxFlat.new()
		empty.bg_color = Color(0.16, 0.08, 0.06, 0.85)
		empty.set_corner_radius_all(8)
		bar.add_theme_stylebox_override(&"background", empty)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.9, 0.22, 0.18)
		fill.set_corner_radius_all(8)
		bar.add_theme_stylebox_override(&"fill", fill)
		bar.offset_left = fx + fw * 0.098
		bar.offset_right = fx + fw * 0.905
		bar.offset_top = fy + fh * 0.24
		bar.offset_bottom = fy + fh * 0.76
		var punya := root.get_node_or_null("PunyaLabel") as Label
		if punya:
			punya.offset_top = fy + fh + 6.0
			punya.offset_bottom = fy + fh + 46.0
	var skin := load(DIR % "button") as Texture2D
	for n in ["ShootButton", "DodgeButton", "AgniButton"]:
		var ab := root.find_child(n, true, false) as ActionButton
		if ab:
			ab.skin = skin
			ab.queue_redraw()
	for b in root.find_children("*", "ActionButton", true, false):
		(b as ActionButton).skin = skin
		(b as ActionButton).queue_redraw()
