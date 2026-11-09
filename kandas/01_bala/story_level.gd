class_name StoryLevel
extends Node3D
## Shared helpers for story levels: playing cutscenes (HUD hidden, Rama's
## controls locked), staging characters and handing off to the next mission.

const LAKSHMANA := preload("res://characters/companions/lakshmana/lakshmana.tscn")

@onready var rama: Rama = $Rama
@onready var hud: CanvasLayer = $HUD

## Camera shots for cutscenes: id -> [position, look_at].
var shots := {}


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
	Music.duck(true)
	var c := Cutscene.play(self, dialogue, shots)
	c.action.connect(_on_story_action)
	if not c.is_done():
		await c.finished
	if is_inside_tree():
		_end_cinematic()


var _cinematic := false
var _orphan_time := 0.0


func _end_cinematic() -> void:
	_cinematic = false
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


func _on_story_action(_name: StringName) -> void:
	pass


func spawn_npc(scene: String, pos: Vector3, look_at_point: Vector3) -> Node3D:
	var npc := (load(scene) as PackedScene).instantiate() as Node3D
	npc.position = pos
	add_child(npc)
	if npc.has_method("face"):
		npc.face(look_at_point)
	return npc


## Fades out, then loads the scene for `mission_number` of Part 1.
func go_to_mission(mission_number: int) -> void:
	PartFlow.advance_to(mission_number)
	var m := PartFlow.next_available(1, mission_number)
	if m == null:
		get_tree().change_scene_to_file("res://ui/journey_menu.tscn")
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
