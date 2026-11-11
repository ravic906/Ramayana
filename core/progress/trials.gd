class_name Trials
extends RefCounted
## Replayable trials (the Trial Arena): the Gauntlet, and rematches with the
## bosses already beaten in the story. Each awards a medal (bronze, silver,
## gold) once, with Punya, and keeps the best result per difficulty.

const LIST := [
	{"id": "gauntlet", "title": "The Gauntlet",
		"desc": "Vasishtha's grounds at night. Wave after wave of maya rakshasas; how many can you stand?",
		"scene": "res://kandas/01_bala/training_grounds.tscn", "unlock_mission": 2, "kind": "score",
		"medals": [15, 35, 60]},
	{"id": "tataka", "title": "Rematch: Tataka",
		"desc": "Face Tataka again in her grove. The faster, the better.",
		"scene": "res://kandas/01_bala/forest.tscn", "unlock_flag": "tataka_defeated", "kind": "time",
		"medals": [240, 150, 95]},
	{"id": "sky", "title": "Rematch: Maricha and Subahu",
		"desc": "The last night at Siddhashrama: guard the fire and end the sky battle.",
		"scene": "res://kandas/01_bala/siddhashrama.tscn", "unlock_flag": "yagna_protected", "kind": "time",
		"medals": [300, 200, 130]},
]
const MEDALS := ["", "Bronze", "Silver", "Gold"]
const MEDAL_PUNYA := [0, 25, 50, 100]


static func get_trial(id: String) -> Dictionary:
	for t in LIST:
		if t["id"] == id:
			return t
	return {}


static func is_unlocked(t: Dictionary) -> bool:
	if t.has("unlock_flag"):
		return bool(GameState.get_flag(t["unlock_flag"], false))
	return PartFlow.furthest() >= int(t.get("unlock_mission", 1))


static func lock_reason(t: Dictionary) -> String:
	if t.has("unlock_flag"):
		return "Defeat this foe in the story first."
	return "Complete the maya trials first."


## 0 none .. 3 gold. Score trials: higher is better; time trials: lower.
static func medal_for(t: Dictionary, value: float) -> int:
	var th: Array = t["medals"]
	var m := 0
	for i in 3:
		if (t["kind"] == "score" and value >= th[i]) or (t["kind"] == "time" and value <= th[i]):
			m = i + 1
	return m


static func best(id: String) -> Variant:
	return GameState.get_flag("trial_best_" + id, null)


static func best_medal(id: String) -> int:
	return int(GameState.get_flag("trial_medal_" + id, 0))


## Records a finished run. Returns {medal, new_best, punya}: Punya for each
## medal tier reached for the first time.
static func record(id: String, value: float) -> Dictionary:
	var t := get_trial(id)
	var prev = best(id)
	var better: bool = prev == null or (t["kind"] == "score" and value > float(prev)) or (t["kind"] == "time" and value < float(prev))
	if better:
		GameState.set_flag("trial_best_" + id, value)
	var medal := medal_for(t, value)
	var old := best_medal(id)
	var punya := 0
	for tier in range(old + 1, medal + 1):
		punya += MEDAL_PUNYA[tier]
	if medal > old:
		GameState.set_flag("trial_medal_" + id, medal)
	if punya > 0:
		GameState.add_punya(punya)
	SaveSystem.save_game()
	return {"medal": medal, "new_best": better, "punya": punya}


## Starts a trial from the menus.
static func start(tree: SceneTree, id: String) -> void:
	var t := get_trial(id)
	if t.is_empty() or not is_unlocked(t):
		return
	GameState.trial = id
	GameState.story_session = false
	tree.paused = false
	tree.change_scene_to_file(t["scene"])


static func format_value(t: Dictionary, value: float) -> String:
	if t["kind"] == "time":
		return "%d:%02d" % [int(value) / 60, int(value) % 60]
	return "%d" % int(value)
