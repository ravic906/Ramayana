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


static func scene_for(part: PartResource) -> String:
	var m := current(part)
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
