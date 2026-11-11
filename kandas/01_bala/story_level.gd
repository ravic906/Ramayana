class_name StoryLevel
extends Node3D
## Shared helpers for story levels: playing cutscenes (HUD hidden, Rama's
## controls locked), staging characters and handing off to the next mission.

const LAKSHMANA := preload("res://characters/companions/lakshmana/lakshmana.tscn")

@onready var rama: Rama = $Rama
@onready var hud: CanvasLayer = $HUD

## Camera shots for cutscenes: id -> [position, look_at].
var shots := {}
## Speaker name -> actor (Rama, Lakshmana, spawned NPCs): cutscenes frame and
## animate their faces automatically (see Cutscene, ShotFramer).
var actors := {}
## What happens during the current mission (stars, summary).
var stats: MissionStats
## The current story objective (shown on the HUD, in the Log, on the compass).
var objective_text := ""
var _objective_marker: NavMarker
var _beacon: WaypointBeacon


## States what to do now. `target` (optional) puts the gold marker and the
## light beacon on it; `beacon` false keeps the marker without the beacon
## (e.g. a boss in plain sight).
func set_objective(text: String, target: Node3D = null, beacon := true) -> void:
	objective_text = text
	if hud and hud.has_method("set_objective"):
		hud.set_objective(text)
	if _objective_marker == null:
		_objective_marker = NavMarker.new()
		_objective_marker.name = "ObjectiveMarker"
		_objective_marker.kind = NavMarker.Kind.MAIN
		add_child(_objective_marker)
		_beacon = WaypointBeacon.new()
		_beacon.name = "ObjectiveBeacon"
		add_child(_beacon)
	_objective_marker.label = text
	_objective_marker.follow = target
	_objective_marker.active = target != null
	if target:
		_objective_marker.global_position = target.global_position
	_beacon.target = _objective_marker if (target != null and beacon) else null


func _enter_tree() -> void:
	Settings.set_fps_context("game")
	_begin_stats.call_deferred()


func _begin_stats() -> void:
	if stats == null and is_instance_valid(rama):
		stats = MissionStats.new()
		stats.track(rama)


## A mission is over: record its stars and, in story play, show the summary
## card (stars, Punya, Dharma, the way to the skill tree). Awaitable.
func complete_mission(number: int) -> void:
	_begin_stats()
	var m := PartFlow.get_mission(1, number)
	if m == null or stats == null:
		return
	PartFlow.reach(number + 1)
	GameState.checkpoint = ""
	if story_enabled() and not m.star_goals.is_empty():
		hud.set_cinematic(true)
		rama.controls_locked = true
		var card := MissionSummary.open(self, m, stats)
		await card.done
		if is_inside_tree():
			hud.set_cinematic(false)
			rama.controls_locked = false
	else:
		GameState.record_stars(1, number, stats.stars(m.star_goals))
	stats = MissionStats.new()
	stats.track(rama)


func story_enabled() -> bool:
	return GameState.story_session


## Plays a dialogue and waits for it to finish. Actions go to _on_story_action().
func cutscene(path: String) -> void:
	var dialogue := load(path) as DialogueResource
	if dialogue == null or dialogue.line_count() == 0:
		push_error("Cutscene %s has no lines; skipping it." % path)
		return
	hud.set_cinematic(true)
	rama.controls_locked = true
	_cinematic = true
	Settings.set_fps_context("cinematic")
	Music.duck(true)
	_register_party()
	var c := Cutscene.play(self, dialogue, shots, actors)
	c.action.connect(_on_story_action)
	if not c.is_done():
		await c.finished
	if is_inside_tree():
		_end_cinematic()


var _cinematic := false
var _orphan_time := 0.0


func _end_cinematic() -> void:
	_cinematic = false
	Settings.set_fps_context("game")
	Music.duck(false)
	_orphan_time = 0.0
	hud.set_cinematic(false)
	rama.controls_locked = false


## Failsafe: never leave the player locked out with no cutscene on screen.
func _process(delta: float) -> void:
	if not _cinematic:
		return
	for child in get_children():
		if child is Cutscene and not (child as Cutscene).is_done():
			_orphan_time = 0.0
			return
	_orphan_time += delta
	if _orphan_time > 1.0:
		push_warning("Cinematic mode with no cutscene; restoring controls.")
		_end_cinematic()


func _register_party() -> void:
	if is_instance_valid(rama) and not actors.has("Rama"):
		actors["Rama"] = rama.model
	for c in get_tree().get_nodes_in_group(&"companions"):
		if c.name == "Lakshmana" and is_instance_valid(c) and "model" in c:
			actors["Lakshmana"] = c.model


func _on_story_action(_name: StringName) -> void:
	pass


func spawn_npc(scene: String, pos: Vector3, look_at_point: Vector3) -> Node3D:
	var npc := (load(scene) as PackedScene).instantiate() as Node3D
	npc.position = pos
	var speaker_name := String(npc.name)
	add_child(npc)
	actors[speaker_name] = npc
	if npc.has_method("face"):
		npc.face(look_at_point)
	return npc


## Speaks lines one after another during play (subtitles + voices), without
## locking controls. lines: [[speaker, text], ...]
func say_lines(lines: Array) -> void:
	for line in lines:
		if not is_inside_tree():
			return
		var spoken := Voice.say(line[0], line[1])
		var seconds := maxf(spoken, 1.2 + String(line[1]).length() / 18.0)
		hud.show_subtitle(line[0], line[1], seconds)
		await get_tree().create_timer(seconds + 0.4).timeout


## Fades out, then loads the scene for `mission_number` of Part 1. If that
## mission isn't released yet, shows a "coming soon" card instead.
func go_to_mission(mission_number: int) -> void:
	PartFlow.advance_to(mission_number)
	var m := PartFlow.next_available(1, mission_number)
	if m == null:
		show_end_card(mission_number)
		return
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 40
	layer.add_child(fade)
	add_child(layer)
	var t := create_tween()
	t.tween_property(fade, "color:a", 1.0, 0.8)
	await t.finished
	get_tree().change_scene_to_file(m.scene_path)


var end_card: CanvasLayer


## "Part 1 continues..." with the next mission's title, and the way back.
func show_end_card(next_mission: int) -> void:
	var next := PartFlow.get_mission(1, next_mission)
	end_card = CanvasLayer.new()
	end_card.name = "EndCard"
	end_card.layer = 45
	add_child(end_card)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.03, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_card.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -640
	box.offset_right = 640
	box.offset_top = -260
	box.offset_bottom = 260
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 26)
	box.modulate.a = 0.0
	end_card.add_child(box)
	box.add_child(PartCard._label("Part 1 continues", 34, Color(1, 0.8, 0.45), true))
	box.add_child(PartCard._label(next.title if next else "The journey goes on", 58, Color(1, 0.95, 0.85), true))
	box.add_child(PartCard._label("Coming soon", 30, Color(0.85, 0.8, 0.7), true))
	for entry in [["Back to the Journey", func() -> void: get_tree().change_scene_to_file("res://ui/journey_menu.tscn")],
			["Play this mission again", func() -> void: get_tree().reload_current_scene()]]:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(560, 84)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override(&"font_size", 30)
		b.add_theme_stylebox_override(&"normal", PartCard._style(Color(0.85, 0.42, 0.1), PartCard.GOLD, 3, 14))
		b.add_theme_color_override(&"font_color", Color(1, 0.97, 0.9))
		b.pressed.connect(entry[1])
		box.add_child(b)
	hud.set_cinematic(true)
	rama.controls_locked = true
	var t := create_tween().set_parallel(true)
	t.tween_property(bg, "color:a", 0.88, 1.2)
	t.tween_property(box, "modulate:a", 1.0, 1.2).set_delay(0.6)

