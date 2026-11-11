extends Node
## Side quests and the palm-leaf codex. Progress is saved in GameState.quests:
##   id -> {"state": "active" | "done", "count": n}

signal changed
signal completed(quest: QuestResource)

const QUEST_PATHS := [
	"res://data/quests/leaves_of_old.tres", "res://data/quests/archers_challenge.tres",
	"res://data/quests/lost_child.tres", "res://data/quests/lotus_for_guru.tres",
	"res://data/quests/river_lamps.tres", "res://data/quests/boatmans_oar.tres",
	"res://data/quests/weavers_thread.tres", "res://data/quests/temple_lamp.tres",
]
const LORE_PATHS := [
	"res://data/lore/ikshvaku.tres", "res://data/lore/sarayu.tres", "res://data/lore/vasishtha.tres",
	"res://data/lore/kodanda.tres", "res://data/lore/ayodhya.tres",
	"res://data/lore/kaushika.tres", "res://data/lore/bala_atibala.tres", "res://data/lore/confluence.tres",
	"res://data/lore/kama_ashrama.tres", "res://data/lore/karusha_shrine.tres",
	"res://data/lore/churning_ocean.tres", "res://data/lore/vishala_founding.tres", "res://data/lore/gangas_descent.tres",
	"res://data/lore/king_sumati.tres", "res://data/lore/ahalya.tres", "res://data/lore/gautama.tres",
	"res://data/lore/mithila_road.tres",
]

var all: Array[QuestResource] = []
## The side quest the compass and beacon follow (saved in GameState flags).
var tracked: StringName:
	get:
		return StringName(GameState.get_flag("tracked_quest", ""))
	set(value):
		GameState.set_flag("tracked_quest", String(value))
		changed.emit()
var lore_entries: Array[LoreResource] = []


func _ready() -> void:
	for p: String in QUEST_PATHS:
		var q := load(p) as QuestResource
		if q:
			all.append(q)
	for p: String in LORE_PATHS:
		var l := load(p) as LoreResource
		if l:
			lore_entries.append(l)


func get_quest(id: StringName) -> QuestResource:
	for q in all:
		if q.id == id:
			return q
	return null


func get_lore(id: StringName) -> LoreResource:
	for l in lore_entries:
		if l.id == id:
			return l
	return null


func state(id: StringName) -> String:
	return String((GameState.quests.get(String(id), {}) as Dictionary).get("state", ""))


func is_active(id: StringName) -> bool:
	return state(id) == "active"


func is_done(id: StringName) -> bool:
	return state(id) == "done"


func count(id: StringName) -> int:
	return int((GameState.quests.get(String(id), {}) as Dictionary).get("count", 0))


func start(id: StringName) -> void:
	if state(id) != "":
		return
	GameState.quests[String(id)] = {"state": "active", "count": 0}
	if tracked == &"" or is_done(tracked):
		tracked = id  # follow the newest quest unless one is already tracked
	GameState.quests_changed.emit()
	changed.emit()


## Adds progress; completes the quest when its goal is reached (unless
## `auto_complete` is false: then the player must return to the giver).
func progress(id: StringName, amount := 1, auto_complete := true) -> int:
	if not is_active(id):
		return count(id)
	var q := get_quest(id)
	var n := mini(count(id) + amount, q.goal_count if q else 999)
	(GameState.quests[String(id)] as Dictionary)["count"] = n
	changed.emit()
	if auto_complete and q and n >= q.goal_count:
		complete(id)
	return n


func goal_reached(id: StringName) -> bool:
	var q := get_quest(id)
	return q != null and count(id) >= q.goal_count


func complete(id: StringName) -> void:
	if not is_active(id):
		return
	var q := get_quest(id)
	(GameState.quests[String(id)] as Dictionary)["state"] = "done"
	if tracked == id:
		tracked = &""
		for other in all:
			if is_active(other.id):
				tracked = other.id
				break
	if q:
		GameState.add_punya(q.reward_punya)
		if q.reward_dharma > 0:
			GameState.add_dharma(q.reward_dharma)
	SaveSystem.save_game()
	changed.emit()
	if q:
		completed.emit(q)


## The HUD tracker line for an active quest.
func tracker_text(id: StringName) -> String:
	var q := get_quest(id)
	if q == null:
		return ""
	if q.return_text != "" and goal_reached(id):
		return q.return_text
	if q.goal_count > 1:
		return "%s  (%d/%d)" % [q.objective, count(id), q.goal_count]
	return q.objective
