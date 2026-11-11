class_name PartFlow
extends RefCounted
## Runs a Part's missions in order and resumes from GameState.current_mission.

const MISSIONS := {
	1: [
		"res://data/missions/part01/m1_maya_trials.tres",
		"res://data/missions/part01/m2_sage_at_gate.tres",
		"res://data/missions/part01/m3_silent_forest.tres",
		"res://data/missions/part01/m4_tataka.tres",
		"res://data/missions/part01/m5_siddhashrama.tres",
		"res://data/missions/part01/m6_stone_and_dawn.tres",
	],
}


static func missions(part_number: int) -> Array[MissionResource]:
	var out: Array[MissionResource] = []
	for path: String in MISSIONS.get(part_number, []):
		var m := load(path) as MissionResource
		if m:
			out.append(m)
	return out


static func get_mission(part_number: int, mission_number: int) -> MissionResource:
	for m in missions(part_number):
		if m.number == mission_number:
			return m
	return null


## The mission to play when the player taps Play on this Part.
static func current(part: PartResource) -> MissionResource:
	var n := maxi(GameState.current_mission, 1) if GameState.current_part == part.number else 1
	var m := get_mission(part.number, n)
	if m == null or not m.available:
		m = get_mission(part.number, 1)  # finished what exists: replay from the start
	return m


## Mid-mission places to resume (GameState.checkpoint) that live in another
## scene than the mission's own: checkpoint -> [mission number, scene].
const CHECKPOINT_SCENES := {
	"gate": [2, "res://kandas/01_bala/training_grounds.tscn"],
	"sarayu": [2, "res://kandas/01_bala/sarayu_road.tscn"],
	"camp": [2, "res://kandas/01_bala/sarayu_road.tscn"],
}

## Chapters that can be started directly (Missions screen): mission -> [[title,
## checkpoint]]. An empty checkpoint is the mission's own start. "range" and
## "trials" are mission 1's two halves (the range is played or skipped).
const CHAPTERS := {
	1: [["The Range", "range"], ["The Maya Trials", "trials"]],
	2: [["The Palace Grounds", ""], ["The Sage at the Gate", "gate"], ["The Sarayu Road", "sarayu"], ["The Camp", "camp"]],
	3: [["The Empty Fields", ""], ["The Deep Wood", "forest_c2"]],
	4: [["Tataka's Grove", ""]],
	5: [["Night 1", "night_1"], ["Night 2", "night_2"], ["Night 3", "night_3"], ["Night 4", "night_4"], ["Night 5", "night_5"],
		["Maricha and Subahu", "night_6"]],
}


static func chapters(mission_number: int) -> Array:
	return CHAPTERS.get(mission_number, [])


## Prepares any mission (and chapter) of Part 1 to be played at will, granting
## what the story would have given by then, and returns the scene to load.
static func start_at(mission_number: int, chapter := 0) -> String:
	var m := get_mission(1, mission_number)
	if m == null or not m.available:
		return ""
	ensure_story_state(mission_number)
	GameState.set_part(1)
	GameState.current_mission = mission_number
	GameState.checkpoint = ""
	var list := chapters(mission_number)
	var cp := ""
	if chapter > 0 and chapter < list.size():
		cp = list[chapter][1]
	elif not list.is_empty():
		cp = list[0][1]
	match cp:
		"range":
			GameState.set_flag("range_done", false)
			cp = ""
		"trials":
			GameState.set_flag("range_done", true)
			cp = ""
	GameState.checkpoint = cp
	var hop: Array = CHECKPOINT_SCENES.get(cp, [])
	return hop[1] if not hop.is_empty() and hop[0] == mission_number else m.scene_path


## What the story has given by the start of `mission_number`, for players who
## jump ahead: the Bala and Atibala blessing (mission 3+), the astras and
## Tataka's defeat (5+), the yagna kept (6+). Never takes anything away.
static func ensure_story_state(mission_number: int) -> void:
	if mission_number >= 3:
		GameState.set_flag("bala_atibala", true)
	if mission_number >= 5:
		for id: StringName in [&"agneyastra", &"varunastra", &"vayavyastra"]:
			GameState.unlock_astra(id)
		GameState.set_flag("tataka_defeated", true)
	if mission_number >= 6:
		GameState.set_flag("yagna_protected", true)
	reach(mission_number)


static func scene_for(part: PartResource) -> String:
	var m := current(part)
	var cp: Array = CHECKPOINT_SCENES.get(GameState.checkpoint, [])
	if m and not cp.is_empty() and m.number == cp[0]:
		return cp[1]
	return m.scene_path if m else part.scene_path


## Moves the player on to `mission_number` and autosaves.
static func advance_to(mission_number: int) -> void:
	GameState.current_mission = mission_number
	reach(mission_number)
	SaveSystem.save_game()


## The furthest mission reached in Part 1 (what the Missions list offers).
static func reach(mission_number: int) -> void:
	GameState.set_flag("furthest_1", maxi(furthest(), mission_number))


static func furthest() -> int:
	return int(GameState.get_flag("furthest_1", maxi(GameState.current_mission, 1)))


static func next_available(part_number: int, mission_number: int) -> MissionResource:
	var m := get_mission(part_number, mission_number)
	return m if m and m.available else null
