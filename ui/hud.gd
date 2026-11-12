extends CanvasLayer
## Grey-box HUD: health, punya counter and touch controls.

@export var player_path: NodePath
@export var spawner_path: NodePath

@onready var health_bar: ProgressBar = %HealthBar
@onready var punya_label: Label = %PunyaLabel
@onready var hint_label: Label = %HintLabel
@onready var reticle: Reticle = %Reticle
@onready var vignette: ColorRect = %Vignette
@onready var perfect_label: Label = %PerfectLabel
@onready var shoot_button: ActionButton = %ShootButton
@onready var agni_button: ActionButton = %AgniButton
@onready var banner: Label = %Banner

var _player: Node
var _draw := 0.0
var _perfect := false
var _aim_weight := 0.0
var _hurt := 0.0
var _fire := 0.0
var _pulse := 0.0


func _ready() -> void:
	var player := get_node_or_null(player_path)
	_player = player
	if player is Rama:
		player.draw_changed.connect(_on_draw_changed)
		player.released.connect(_on_released)
		player.hurt.connect(func(_a: float) -> void: _hurt = 1.0)
		player.astra_detonated.connect(func(_p: Vector3) -> void: _fire = 1.0)
		player.perfect_dodge.connect(func() -> void: show_banner("Perfect dodge!", Color(1, 0.85, 0.4), 0.8))
		player.rama_died.connect(func() -> void: show_banner("Rama has fallen...", Color(1, 0.4, 0.35), 2.5))
	var spawner := get_node_or_null(spawner_path) as WaveSpawner
	if spawner:
		spawner.wave_started.connect(func(i: int, n: int) -> void:
			show_banner("Maya trial %d of %d" % [i + 1, n], Color(1, 0.9, 0.7), 2.0))
		spawner.all_cleared.connect(func() -> void:
			show_banner("The illusions are vanquished!\nGuru Vasishtha is pleased.", Color(1, 0.85, 0.35), 4.0))
	if player != null:
		var health := player.get_node_or_null("Health") as Health
		if health != null:
			health.changed.connect(_on_health_changed)
			health_bar.max_value = health.max_health
			health_bar.value = health.max_health
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"hud")
	_build_pause()
	_build_subtitle()
	GameState.punya_changed.connect(_on_punya_changed)
	_on_punya_changed(GameState.punya)
	var tween := create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(hint_label, "modulate:a", 0.0, 1.0)


func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	var cam := get_viewport().get_camera_3d()
	var aiming: bool = _player is Rama and _player.is_drawing and _player.hold_time > _player.snap_shot_time
	_aim_weight = move_toward(_aim_weight, 1.0 if aiming else 0.0, real_delta * 6.0)
	reticle.weight = _aim_weight
	reticle.draw_amount = _draw
	reticle.perfect = _perfect
	var target: Node3D = _player.aim_target if _player is Rama else null
	reticle.has_lock = false
	if target != null and is_instance_valid(target) and cam != null:
		var p := AutoAim.aim_point_of(target)
		if not cam.is_position_behind(p):
			reticle.has_lock = true
			reticle.lock_position = cam.unproject_position(p) - reticle.global_position
	_hurt = move_toward(_hurt, 0.0, real_delta * 2.5)
	_fire = move_toward(_fire, 0.0, real_delta * 2.0)
	var mat := vignette.material as ShaderMaterial
	mat.set_shader_parameter(&"strength", _aim_weight * (0.45 + 0.35 * _draw))
	mat.set_shader_parameter(&"glow", 1.0 if _perfect else 0.0)
	mat.set_shader_parameter(&"hurt", _hurt)
	mat.set_shader_parameter(&"fire", _fire)
	_refresh_lookups(real_delta)
	_update_agni(real_delta)
	_update_command()
	_update_interact()
	shoot_button.progress = _draw if aiming else 0.0
	shoot_button.progress_color = Color(1.0, 0.95, 0.6) if _perfect else Color(1.0, 0.82, 0.3)


## One button per astra slot (Agni is in the scene; the others are created here).
var _astra_buttons: Array[ActionButton] = []


func _ensure_astra_buttons(count: int) -> void:
	if _astra_buttons.is_empty():
		_astra_buttons.append(agni_button)
	var spots := [Rect2(-430, -462, 140, 140), Rect2(-575, -352, 130, 130), Rect2(-610, -520, 150, 150)]
	while _astra_buttons.size() < count:
		var i := _astra_buttons.size()
		var b := ActionButton.new()
		b.name = "AstraButton%d" % (i + 1)
		b.action = StringName("astra_%d" % (i + 1))
		var r: Rect2 = spots[mini(i - 1, spots.size() - 1)]
		b.anchor_left = 1.0
		b.anchor_top = 1.0
		b.anchor_right = 1.0
		b.anchor_bottom = 1.0
		b.offset_left = r.position.x
		b.offset_top = r.position.y
		b.offset_right = r.position.x + r.size.x
		b.offset_bottom = r.position.y + r.size.y
		$Root.add_child(b)
		_astra_buttons.append(b)


var _command_button: ActionButton
var _interact_button: ActionButton
var _interact_target: Interactable
var _tracker: Label


## Shows the Interact button (with its prompt) near something Rama can use.
func _update_interact() -> void:
	var rama := _player as Rama
	_interact_target = null
	if rama and not rama.controls_locked and not rama.health.is_dead():
		var best_d := INF
		for n in _interactables:
			var it := n as Interactable if is_instance_valid(n) else null
			if it == null or not it.enabled or not it.is_visible_in_tree():
				continue
			var d := it.global_position.distance_to(rama.global_position)
			if d <= it.radius and d < best_d:
				best_d = d
				_interact_target = it
	if _interact_target == null:
		if _interact_button:
			_interact_button.visible = false
		return
	if _interact_button == null:
		_interact_button = ActionButton.new()
		_interact_button.name = "InteractButton"
		_interact_button.action = &"interact"
		_interact_button.color = Color(0.25, 0.5, 0.45, 0.9)
		_interact_button.anchor_left = 1.0
		_interact_button.anchor_top = 1.0
		_interact_button.anchor_right = 1.0
		_interact_button.anchor_bottom = 1.0
		# Above the subtitles, clear of the astra buttons.
		_interact_button.offset_left = -780
		_interact_button.offset_top = -450
		_interact_button.offset_right = -620
		_interact_button.offset_bottom = -290
		$Root.add_child(_interact_button)
	_interact_button.visible = true
	_interact_button.label = _interact_target.prompt
	_interact_button.queue_redraw()
	if Input.is_action_just_pressed(&"interact"):
		_interact_target.interact()


var _objective_label: Label
var compass: Compass


func _build_compass() -> void:
	compass = Compass.new()
	compass.name = "Compass"
	compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass.offset_left = -420  # clear of the health bar and the Map/Log buttons
	compass.offset_right = 420
	compass.offset_top = 6
	compass.offset_bottom = 82
	$Root.add_child(compass)
	_objective_label = _outlined_label("", 26, Color(1, 0.88, 0.55))
	_objective_label.name = "ObjectiveLabel"
	_objective_label.offset_top = 84
	_objective_label.offset_bottom = 120
	$Root.add_child(_objective_label)
	_tracker = _outlined_label("", 22, Color(0.8, 0.88, 1.0))
	_tracker.name = "QuestTracker"
	_tracker.offset_top = 118
	_tracker.offset_bottom = 150
	$Root.add_child(_tracker)


func _outlined_label(text: String, size: int, color: Color) -> Label:
	var l := PartCard._label(text, size, color, true)
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -700
	l.offset_right = 700
	l.add_theme_color_override(&"font_outline_color", Color(0.08, 0.04, 0.02))
	l.add_theme_constant_override(&"outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The story objective line under the compass.
func set_objective(text: String) -> void:
	if _objective_label == null:
		_build_compass()
	_objective_label.text = text
	_objective_label.visible = text != ""


## A second, smaller line (the tracked side quest, or a timer).
func set_tracker(text: String) -> void:
	if _tracker == null:
		_build_compass()
	_tracker.text = text
	_tracker.visible = text != ""


func _update_side_tracker() -> void:
	if _tracker == null or _tracker_override:
		return
	var q := Quests.tracked
	# Only where the quest can be pursued (its markers are in this level).
	var here := false
	if q != &"" and Quests.is_active(q):
		for n in get_tree().get_nodes_in_group(&"nav_markers"):
			if (n as NavMarker) and (n as NavMarker).quest_id == q:
				here = true
				break
	_tracker.text = Quests.tracker_text(q) if here else ""
	_tracker.visible = _tracker.text != ""


var _tracker_override := false


## The Command button toggles Lakshmana between Attack and Guard.
var _lookup_left := 0.0
var _companion: Lakshmana
var _interactables: Array[Node] = []


## Group lookups are refreshed a few times a second, not every frame.
func _refresh_lookups(delta: float) -> void:
	_lookup_left -= delta
	if _lookup_left > 0.0:
		return
	_lookup_left = 0.15
	_companion = get_tree().get_first_node_in_group(&"companions") as Lakshmana
	_interactables = get_tree().get_nodes_in_group(&"interactables")
	if compass == null and _player is Rama:
		_build_compass()
	_update_side_tracker()


## Draws the eye to the Command button (Lakshmana's Guard tutorial).
func highlight_command(seconds: float = 6.0) -> void:
	_update_command()
	if _command_button == null:
		return
	_command_button.pivot_offset = _command_button.size * 0.5
	var t := create_tween().set_loops(int(seconds / 0.8))
	t.tween_property(_command_button, "scale", Vector2.ONE * 1.18, 0.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(_command_button, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE)


func _update_command() -> void:
	var l := _companion if is_instance_valid(_companion) else null
	var show := l != null and l.command != Lakshmana.Command.FOLLOW and _player is Rama \
		and not (_player as Rama).controls_locked
	if _command_button == null:
		if not show:
			return
		_command_button = ActionButton.new()
		_command_button.name = "CommandButton"
		_command_button.action = &"companion"
		_command_button.anchor_left = 1.0
		_command_button.anchor_top = 1.0
		_command_button.anchor_right = 1.0
		_command_button.anchor_bottom = 1.0
		_command_button.offset_left = -215
		_command_button.offset_top = -585
		_command_button.offset_right = -95
		_command_button.offset_bottom = -465
		$Root.add_child(_command_button)
	_command_button.visible = show
	if show:
		var guarding := l.command == Lakshmana.Command.GUARD
		_command_button.label = "Guard" if guarding else "Attack"
		_command_button.color = Color(0.25, 0.45, 0.3, 0.85) if guarding else Color(0.7, 0.35, 0.15, 0.85)
		_command_button.progress = 0.0 if not l.is_downed else 1.0
		_command_button.queue_redraw()


func _update_agni(real_delta: float) -> void:
	if not (_player is Rama) or _player.astras.is_empty():
		agni_button.visible = false
		return
	var rama := _player as Rama
	_ensure_astra_buttons(rama.astras.size())
	_pulse += real_delta
	for slot in rama.astras.size():
		var astra: AstraResource = rama.astras[slot]
		var button := _astra_buttons[slot]
		button.label = astra.short_name
		button.visible = rama.is_astra_unlocked(astra) and not rama.controls_locked
		var base := astra.color.darkened(0.15)
		var left := rama.astra_cooldown_left(astra)
		if rama.armed_astra == astra:
			button.color = Color(astra.color.lightened(0.15 * sin(_pulse * 10.0)), 0.95)
			button.progress = 1.0
			button.progress_color = Color(astra.glow_color, 1.0)
		elif left > 0.0:
			button.color = Color(0.3, 0.26, 0.24, 0.7)
			button.progress = 1.0 - left / astra.cooldown
			button.progress_color = Color(astra.color, 0.8)
		else:
			button.color = Color(base, 0.85)
			button.progress = 0.0


func show_banner(text: String, color: Color = Color.WHITE, hold: float = 2.0) -> void:
	banner.text = text
	banner.add_theme_color_override(&"font_color", color)
	banner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(banner, "modulate:a", 1.0, 0.25)
	tween.tween_interval(hold)
	tween.tween_property(banner, "modulate:a", 0.0, 0.6)


func _on_draw_changed(amount: float, perfect: bool) -> void:
	_draw = amount
	_perfect = perfect


func _on_released(_arrow: Node, _power: float, perfect: bool) -> void:
	if not perfect:
		return
	perfect_label.modulate.a = 1.0
	perfect_label.scale = Vector2(1.4, 1.4)
	var tween := create_tween()
	tween.tween_property(perfect_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.6)
	tween.tween_property(perfect_label, "modulate:a", 0.0, 0.5)


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_punya_changed(total: int) -> void:
	punya_label.text = "Punya: %d" % total


# --- Pause ------------------------------------------------------------------

var _pause_panel: Control


func _build_pause() -> void:
	var button := Button.new()
	button.name = "PauseButton"
	button.text = "II"
	button.add_theme_font_size_override(&"font_size", 34)
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -130
	button.offset_top = 30
	button.offset_right = -40
	button.offset_bottom = 120
	button.add_theme_stylebox_override(&"normal", PartCard._style(Color(0.2, 0.12, 0.08, 0.6), PartCard.GOLD, 3, 45))
	button.pressed.connect(set_paused.bind(true))
	$Root.add_child(button)
	var log_button := Button.new()
	log_button.name = "LogButton"
	log_button.text = "Log"
	log_button.add_theme_font_size_override(&"font_size", 26)
	log_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	log_button.offset_left = -270
	log_button.offset_top = 30
	log_button.offset_right = -150
	log_button.offset_bottom = 120
	log_button.add_theme_stylebox_override(&"normal", PartCard._style(Color(0.2, 0.12, 0.08, 0.6), PartCard.GOLD, 3, 45))
	log_button.pressed.connect(func() -> void:
		get_tree().paused = true
		var j := JournalScreen.open(self)
		j.tree_exited.connect(func() -> void:
			if is_inside_tree() and not _pause_panel.visible:
				get_tree().paused = false))
	$Root.add_child(log_button)
	var map_button := Button.new()
	map_button.name = "MapButton"
	map_button.text = "Map"
	map_button.add_theme_font_size_override(&"font_size", 26)
	map_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	map_button.offset_left = -400
	map_button.offset_top = 30
	map_button.offset_right = -280
	map_button.offset_bottom = 120
	map_button.add_theme_stylebox_override(&"normal", PartCard._style(Color(0.2, 0.12, 0.08, 0.6), PartCard.GOLD, 3, 45))
	map_button.pressed.connect(open_map)
	map_button.visible = MapResource.for_level(_scene_path()) != null
	$Root.add_child(map_button)

	_pause_panel = PanelContainer.new()
	_pause_panel.name = "PausePanel"
	_pause_panel.add_theme_stylebox_override(&"panel", PartCard._style(Color(0.97, 0.91, 0.77), PartCard.GOLD, 6, 18))
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.offset_left = -260
	_pause_panel.offset_right = 260
	_pause_panel.offset_top = -500
	_pause_panel.offset_bottom = 500
	_pause_panel.visible = false
	$Root.add_child(_pause_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_panel.add_child(box)
	var part := PartCatalog.by_number(GameState.current_part)
	box.add_child(PartCard._label("Part %d: %s" % [part.number, part.title] if part else "Paused", 30, PartCard.INK, true))
	var look := ["Look: %s" % Settings.style_name(), func() -> void: pass]
	var mode := ["Mode: %s" % Settings.mode_name(), func() -> void: pass]
	var quality := ["Quality: %s" % Settings.quality_name(), func() -> void: pass]
	var jump := func() -> void:
		var ms := MissionsScreen.open(self, 1)
		ms.process_mode = Node.PROCESS_MODE_ALWAYS
		ms.mission_chosen.connect(func(n: int, c: int) -> void:
			load("res://ui/journey_menu.gd").launch(get_tree(), n, c))
	for entry in [["Resume", set_paused.bind(false)], ["Missions", jump], ["Skills", func() -> void: SkillsScreen.open(self)], ["Log", func() -> void: JournalScreen.open(self)], ["Map", open_map], mode, quality, look, ["Back to the Journey", back_to_journey]]:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(0, 80)
		b.add_theme_font_size_override(&"font_size", 30)
		b.add_theme_stylebox_override(&"normal", PartCard._style(Color(0.85, 0.42, 0.1), PartCard.GOLD, 3, 14))
		b.add_theme_color_override(&"font_color", Color(1, 0.97, 0.9))
		if entry == quality:
			b.pressed.connect(func() -> void:
				Settings.cycle_quality()
				b.text = "Quality: %s" % Settings.quality_name())
		elif entry == mode:
			b.pressed.connect(func() -> void:
				Settings.set_difficulty(Settings.next_difficulty())
				b.text = "Mode: %s" % Settings.mode_name())
		elif entry == look:
			b.pressed.connect(func() -> void:
				Settings.toggle_visual_style()
				b.text = "Look: %s" % Settings.style_name())
		else:
			b.pressed.connect(entry[1])
		box.add_child(b)
	box.add_child(_volume_row("Music", Settings.music_volume, Settings.set_music_volume))
	box.add_child(_volume_row("Sound", Settings.sfx_volume, Settings.set_sfx_volume))
	box.add_child(_volume_row("Voices", Settings.voice_volume, Settings.set_voice_volume))


func _volume_row(label: String, value: float, setter: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = label + "Volume"
	row.add_theme_constant_override(&"separation", 16)
	var l := PartCard._label(label, 28, PartCard.INK, false)
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 64)  # thumb-sized
	slider.value_changed.connect(setter)
	row.add_child(slider)
	return row


func _scene_path() -> String:
	# The level this HUD belongs to (its parent), else the current scene.
	var level := get_parent()
	if level and level.scene_file_path != "":
		return level.scene_file_path
	var s := get_tree().current_scene if is_inside_tree() else null
	return s.scene_file_path if s else ""


## The parchment map of this level (paused while open).
func open_map() -> void:
	get_tree().paused = true
	var m := MapScreen.open(self, _scene_path())
	if m == null:
		get_tree().paused = false
		return
	m.tree_exited.connect(func() -> void:
		if is_inside_tree() and not _pause_panel.visible:
			get_tree().paused = false)


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_pause_panel.visible = paused


func back_to_journey() -> void:
	get_tree().paused = false
	TimeFX.clear_all()
	SaveSystem.save_game()
	get_tree().change_scene_to_file("res://ui/journey_menu.tscn")


# --- In-game subtitles and boss bar ----------------------------------------------

var _subtitle: PanelContainer
var _subtitle_speaker: Label
var _subtitle_text: Label
var _subtitle_tween: Tween
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _boss_name: Label
var _boss_health: Health


func _build_subtitle() -> void:
	_subtitle = PanelContainer.new()
	_subtitle.add_theme_stylebox_override(&"panel", PartCard._style(Color(0.08, 0.05, 0.04, 0.7), PartCard.GOLD, 2, 14))
	_subtitle.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.offset_left = -430  # clear of the joystick and the action buttons on 4:3 too
	_subtitle.offset_right = 430
	_subtitle.offset_top = -250
	_subtitle.offset_bottom = -150
	_subtitle.modulate.a = 0.0
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_subtitle)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	_subtitle.add_child(row)
	_subtitle_speaker = PartCard._label("", 28, Color.WHITE, false)
	row.add_child(_subtitle_speaker)
	_subtitle_text = PartCard._label("", 28, Color(1, 0.97, 0.9), false)
	_subtitle_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_subtitle_text)

	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# A slim strip along the top edge, clear of the arena where the boss stands.
	_boss_box.offset_left = -420
	_boss_box.offset_right = 420
	_boss_box.offset_top = 14
	_boss_box.offset_bottom = 80
	_boss_box.add_theme_constant_override(&"separation", 2)
	_boss_box.visible = false
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_boss_box)
	_boss_name = PartCard._label("", 28, Color(1, 0.85, 0.8), true)
	_boss_name.add_theme_color_override(&"font_outline_color", Color(0.15, 0.03, 0.05))
	_boss_name.add_theme_constant_override(&"outline_size", 10)
	_boss_box.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(0, 16)
	_boss_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.7, 0.12, 0.2)
	fill.set_corner_radius_all(6)
	_boss_bar.add_theme_stylebox_override(&"fill", fill)
	_boss_box.add_child(_boss_bar)


func show_subtitle(speaker: String, text: String, seconds := 3.5) -> void:
	# Spoken when a voice line exists; a line already playing is not cut off.
	var spoken := Voice.say(speaker, text, false)
	seconds = maxf(seconds, spoken + 0.4)
	_subtitle_speaker.text = speaker
	_subtitle_speaker.add_theme_color_override(&"font_color", Cutscene.SPEAKER_COLORS.get(speaker, Color.WHITE))
	_subtitle_text.text = text
	if _subtitle_tween:
		_subtitle_tween.kill()
	_subtitle_tween = create_tween()
	_subtitle_tween.tween_property(_subtitle, "modulate:a", 1.0, 0.2)
	_subtitle_tween.tween_interval(seconds)
	_subtitle_tween.tween_property(_subtitle, "modulate:a", 0.0, 0.5)


## Adds a second (third...) boss bar under the first: Maricha and Subahu fight together.
func add_boss_bar(boss_name: String, health: Health) -> void:
	_boss_box.visible = true
	_boss_box.offset_bottom += 62
	var label := PartCard._label(boss_name, 24, Color(1, 0.85, 0.8), true)
	label.add_theme_color_override(&"font_outline_color", Color(0.15, 0.03, 0.05))
	label.add_theme_constant_override(&"outline_size", 8)
	label.add_to_group(&"extra_boss_bar")
	_boss_box.add_child(label)
	var bar := _make_bar(Color(0.55, 0.1, 0.45), 14)
	bar.add_to_group(&"extra_boss_bar")
	bar.max_value = health.max_health
	bar.value = health.current
	health.changed.connect(func(c: float, m: float) -> void:
		if is_instance_valid(bar):
			bar.max_value = m
			bar.value = c)
	_boss_box.add_child(bar)


func clear_boss_bars() -> void:
	for n in get_tree().get_nodes_in_group(&"extra_boss_bar"):
		n.queue_free()
	_boss_box.offset_bottom = 80
	show_boss("", null)


var _objective_box: VBoxContainer


## A bar for what Rama must protect (e.g. the sacred fire); null hides it.
func show_objective(label: String, health: Health) -> void:
	if _objective_box == null:
		_objective_box = VBoxContainer.new()
		_objective_box.name = "ObjectiveBox"
		_objective_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_objective_box.offset_left = 40
		_objective_box.offset_top = 128
		_objective_box.offset_right = 460
		_objective_box.offset_bottom = 190
		_objective_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Root.add_child(_objective_box)
	for c in _objective_box.get_children():
		c.queue_free()
	_objective_box.visible = health != null
	if health == null:
		return
	_objective_box.add_child(PartCard._label(label, 24, Color(1, 0.8, 0.45), false))
	var bar := _make_bar(Color(1.0, 0.55, 0.15), 14)
	bar.name = "ObjectiveBar"
	bar.max_value = health.max_health
	bar.value = health.current
	health.changed.connect(func(c: float, m: float) -> void:
		if is_instance_valid(bar):
			bar.max_value = m
			bar.value = c)
	_objective_box.add_child(bar)


func _make_bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override(&"fill", fill)
	return bar


## Shows a boss health bar bound to `health` (null hides it).
func show_boss(boss_name: String, health: Health) -> void:
	_boss_health = health
	_boss_box.visible = health != null
	# The boss bar takes the top of the screen; the compass steps aside.
	for n in ["Compass", "ObjectiveLabel", "QuestTracker"]:
		var c := $Root.get_node_or_null(n) as CanvasItem
		if c:
			c.visible = health == null and (n == "Compass" or (c as Label).text != "")
	if health:
		_boss_name.text = boss_name
		_boss_bar.max_value = health.max_health
		_boss_bar.value = health.current
		health.changed.connect(func(c: float, m: float) -> void:
			_boss_bar.max_value = m
			_boss_bar.value = c)


## Hides gameplay controls during cutscenes.
func set_cinematic(on: bool) -> void:
	for n in ["Joystick", "ShootButton", "DodgeButton", "Reticle", "EnemyBars", "PauseButton", "HealthBar", "PunyaLabel", "ObjectiveBox", "CommandButton", "InteractButton", "QuestTracker", "Compass", "ObjectiveLabel", "LogButton", "MapButton"]:
		var c := $Root.get_node_or_null(n) as CanvasItem
		if c:
			c.visible = not on
	for b in _astra_buttons:
		b.visible = false if on else b.visible
	if on:
		_boss_box.visible = false
