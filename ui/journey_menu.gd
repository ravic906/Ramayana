extends Control
## Title screen: the journey as a row of Part cards (one per kanda; Yuddha
## Kanda is split in two). Part 1 is free; later Parts are bought singly or
## with the Full Journey bundle, then downloaded and played.

const BG_TOP := Color(0.2, 0.22, 0.45)
const BG_MID := Color(0.86, 0.48, 0.46)
const BG_LOW := Color(1.0, 0.72, 0.38)

var loader: PartLoader
var _cards := {}
var _message: Label
var _bundle_button: Button
var _downloads := {}


func _ready() -> void:
	get_tree().paused = false
	if SaveSystem.has_save(SaveSystem.AUTOSAVE_SLOT):
		SaveSystem.load_game(SaveSystem.AUTOSAVE_SLOT)
	loader = PartLoader.new()
	add_child(loader)
	loader.progress.connect(_on_download_progress)
	loader.finished.connect(_on_download_finished)
	Store.entitlements_changed.connect(refresh)
	Store.purchase_failed.connect(func(_id: String, reason: String) -> void: show_message(reason))
	_build()
	refresh()


## What a card should offer, given ownership and installation.
static func card_state(part: PartResource, unlocked: bool, installed: bool, completed: bool) -> int:
	if not part.released:
		return PartCard.State.COMING_SOON
	if not unlocked:
		return PartCard.State.BUY
	if not installed:
		return PartCard.State.DOWNLOAD
	return PartCard.State.REPLAY if completed else PartCard.State.PLAY


func refresh() -> void:
	for part: PartResource in PartCatalog.all():
		var card: PartCard = _cards[part.id]
		if _downloads.has(part.id):
			card.set_state(PartCard.State.DOWNLOADING, false, _downloads[part.id])
			continue
		var completed := GameState.is_part_completed(part.id)
		card.set_state(card_state(part, GameState.is_part_unlocked(part), PartLoader.is_installed(part), completed), completed)
	_bundle_button.visible = not Store.owns_full_journey()


func show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(3.5)
	t.tween_property(_message, "modulate:a", 0.0, 0.8)


func play(part: PartResource) -> void:
	if not PartLoader.mount(part):
		show_message("%s could not be loaded." % part.title)
		return
	GameState.set_part(part.number)
	SaveSystem.save_game()
	get_tree().change_scene_to_file(part.scene_path)


func _on_card_action(part: PartResource, state: int) -> void:
	match state:
		PartCard.State.PLAY, PartCard.State.REPLAY:
			play(part)
		PartCard.State.BUY:
			Store.purchase(part.product_id)
		PartCard.State.DOWNLOAD:
			_downloads[part.id] = 0.0
			loader.download(part)
			refresh()


func _on_download_progress(part: PartResource, ratio: float) -> void:
	_downloads[part.id] = ratio
	(_cards[part.id] as PartCard).set_state(PartCard.State.DOWNLOADING, false, ratio)


func _on_download_finished(part: PartResource, ok: bool, message: String) -> void:
	if part:
		_downloads.erase(part.id)
	if not ok:
		show_message(message)
	refresh()


# --- Layout -------------------------------------------------------------------

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, BG_TOP)
	grad.add_point(0.55, BG_MID)
	grad.set_color(grad.get_point_count() - 1, BG_LOW)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var sun := SunEmblem.new()
	sun.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sun)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 48
	root.offset_right = -48
	root.offset_top = 36
	root.offset_bottom = -28
	root.add_theme_constant_override(&"separation", 14)
	add_child(root)
	root.add_child(_title("RAMAYANA", 96, Color(1, 0.93, 0.75)))
	root.add_child(_title("The Journey of Rama", 36, Color(1, 0.88, 0.7)))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 28)
	scroll.add_child(row)
	for part: PartResource in PartCatalog.all():
		var card := PartCard.new()
		card.setup(part)
		card.action_pressed.connect(_on_card_action)
		row.add_child(card)
		_cards[part.id] = card

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override(&"separation", 24)
	root.add_child(bottom)
	_bundle_button = Button.new()
	_bundle_button.text = "Unlock the Full Journey: every Part, %s" % Store.FULL_JOURNEY_PRICE
	_bundle_button.custom_minimum_size = Vector2(0, 72)
	_bundle_button.add_theme_font_size_override(&"font_size", 26)
	for s in [&"normal", &"hover", &"pressed", &"focus"]:
		_bundle_button.add_theme_stylebox_override(s, PartCard._style(Color(0.55, 0.15, 0.12), PartCard.GOLD, 4, 16))
	_bundle_button.add_theme_color_override(&"font_color", Color(1, 0.93, 0.75))
	_bundle_button.pressed.connect(func() -> void: Store.purchase(Store.FULL_JOURNEY_PRODUCT_ID))
	bottom.add_child(_bundle_button)
	var look := Button.new()
	look.text = "Look: %s" % Settings.style_name()
	look.custom_minimum_size = Vector2(0, 72)
	look.add_theme_font_size_override(&"font_size", 26)
	for s in [&"normal", &"hover", &"pressed", &"focus"]:
		look.add_theme_stylebox_override(s, PartCard._style(Color(0.2, 0.22, 0.45), PartCard.GOLD, 4, 16))
	look.add_theme_color_override(&"font_color", Color(1, 0.93, 0.75))
	look.pressed.connect(func() -> void:
		Settings.toggle_visual_style()
		look.text = "Look: %s" % Settings.style_name())
	bottom.add_child(look)
	_message = _title("", 24, Color(1, 0.97, 0.9))
	_message.modulate.a = 0.0
	root.add_child(_message)


func _title(text: String, size: int, color: Color) -> Label:
	var l := PartCard._label(text, size, color, true)
	l.add_theme_color_override(&"font_outline_color", Color(0.3, 0.1, 0.05, 0.9))
	l.add_theme_constant_override(&"outline_size", maxi(size / 8, 6))
	return l


## Golden sun of the Suryavansha behind the title.
class SunEmblem extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 120)
		for i in 24:
			var a := TAU * i / 24.0
			var r := 150.0 if i % 2 == 0 else 120.0
			draw_line(c + Vector2.from_angle(a) * 95.0, c + Vector2.from_angle(a) * r, Color(1, 0.8, 0.35, 0.35), 6.0, true)
		draw_circle(c, 88.0, Color(1, 0.78, 0.35, 0.3))
