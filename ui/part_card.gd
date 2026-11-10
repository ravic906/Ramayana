class_name PartCard
extends PanelContainer
## One Part on the Journey menu: parchment card with a coloured kanda band,
## title, synopsis and a single action button whose label follows the state.

signal action_pressed(part: PartResource, state: int)

enum State { PLAY, REPLAY, BUY, DOWNLOAD, DOWNLOADING, COMING_SOON }

const INK := Color(0.28, 0.16, 0.08)
const GOLD := Color(0.8, 0.58, 0.18)

var part: PartResource
var state := State.COMING_SOON

var _button: Button
var _status: Label
var _band: PanelContainer


func setup(p: PartResource) -> void:
	part = p
	custom_minimum_size = Vector2(360, 520)
	add_theme_stylebox_override(&"panel", _style(Color(0.97, 0.91, 0.77), GOLD, 6, 18))
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	add_child(box)

	_band = PanelContainer.new()
	_band.add_theme_stylebox_override(&"panel", _style(p.cover_color, p.cover_color.darkened(0.25), 0, 12))
	box.add_child(_band)
	var band_box := VBoxContainer.new()
	_band.add_child(band_box)
	band_box.add_child(_label("PART %d" % p.number, 22, Color(1, 0.97, 0.9), true))
	band_box.add_child(_label(p.kanda.to_upper(), 18, Color(1, 0.95, 0.85, 0.85), true))

	box.add_child(_label(p.title, 32, INK, true))
	var syn := _label(p.synopsis, 19, INK.lightened(0.15), false)
	syn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	syn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(syn)

	_status = _label("", 18, INK.lightened(0.3), true)
	box.add_child(_status)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(0, 76)
	_button.add_theme_font_size_override(&"font_size", 28)
	_button.pressed.connect(func() -> void: action_pressed.emit(part, state))
	box.add_child(_button)


func set_state(new_state: int, completed: bool = false, progress: float = -1.0) -> void:
	state = new_state
	var c := Color(0.85, 0.42, 0.1)
	match state:
		State.PLAY:
			_button.text = "Play"
		State.REPLAY:
			_button.text = "Play again"
		State.BUY:
			_button.text = "Unlock %s" % part.price_label
			c = Color(0.55, 0.15, 0.12)
		State.DOWNLOAD:
			_button.text = "Download"
			c = Color(0.2, 0.4, 0.6)
		State.DOWNLOADING:
			_button.text = "Downloading %d%%" % int(clampf(progress, 0.0, 1.0) * 100.0)
			c = Color(0.2, 0.4, 0.6)
		State.COMING_SOON:
			_button.text = "Coming soon"
			c = Color(0.55, 0.5, 0.45)
	_button.disabled = state in [State.COMING_SOON, State.DOWNLOADING]
	for s in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		var col := c.lightened(0.12) if s == &"hover" else (c.darkened(0.15) if s == &"pressed" else c)
		if s == &"disabled":
			col = c.lerp(Color(0.7, 0.66, 0.6), 0.4)
		_button.add_theme_stylebox_override(s, _style(col, GOLD, 3, 14))
	_button.add_theme_color_override(&"font_color", Color(1, 0.97, 0.9))
	_button.add_theme_color_override(&"font_disabled_color", Color(1, 0.97, 0.9, 0.8))
	if completed:
		_status.text = "Completed"
	elif state == State.BUY:
		_status.text = "Or unlock every Part with the Full Journey"
	elif state == State.COMING_SOON:
		_status.text = "In development"
	else:
		_status.text = ""
	modulate = Color(1, 1, 1, 0.82) if state == State.COMING_SOON else Color.WHITE


static func _style(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 6 if border_w >= 6 else 0
	return sb


## Display face for titles (Art Bible: Devanagari-inspired display + clean sans
## for body text, which is the project-wide default font).
const DISPLAY_FONT := preload("res://assets/fonts/TiroDevanagariSanskrit-Regular.ttf")
const TITLE_SIZE := 34


static func _label(text: String, size: int, color: Color, centered: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	if size >= TITLE_SIZE:
		l.add_theme_font_override(&"font", DISPLAY_FONT)
	l.add_theme_color_override(&"font_color", color)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
