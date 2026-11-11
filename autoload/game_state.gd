extends Node
## Global, serialisable progress for the current playthrough.

signal kanda_changed(index: int)
signal part_changed(number: int)
signal part_completed(id: StringName)
signal dharma_changed(value: int)
signal punya_changed(total: int)
signal astra_unlocked(astra_id: StringName)
signal skills_changed
signal quests_changed

const KANDAS: Array[String] = [
	"Bala Kanda",
	"Ayodhya Kanda",
	"Aranya Kanda",
	"Kishkindha Kanda",
	"Sundara Kanda",
	"Yuddha Kanda",
	"Uttara Kanda",
]

## Number of kandas playable without any purchase (legacy helper; the game is
## organised in Parts, see PartCatalog).
const FREE_KANDAS := 1

## v2: progress is tracked per Part (current_part, completed_parts).
## v3: skills, mission stars, checkpoints, quests and lore.
const SAVE_VERSION := 3

## Runtime only (not saved): true when a Part was launched from the Journey
## menu, so levels play their story (narration, cutscenes, mission hand-off).
var story_session := false
## The trial being played (Trials: "gauntlet", "tataka", "sky"), "" in the story.
## Not saved: a trial is always started from the Trials list.
var trial := ""

var current_part := 1
var completed_parts: Array[StringName] = []
var current_kanda := 0
var current_mission := 0
var punya := 0
## 0..100: rises with acts of restraint and protection (sparing the fleeing, ...).
var dharma := 0
var unlocked_astras: Array[StringName] = []
var flags: Dictionary = {}
## Skill ids bought with Punya.
var skills: Array[StringName] = []
## "part:mission" -> best stars (0..3).
var mission_stars: Dictionary = {}
## Mid-mission checkpoint (e.g. which night at Siddhashrama); "" = none.
var checkpoint := ""
## Quest id -> {"state": "active"/"done", "progress": {...}}.
var quests: Dictionary = {}
## Palm-leaf lore entries found.
var lore: Array[StringName] = []


func reset() -> void:
	trial = ""
	current_part = 1
	completed_parts.clear()
	current_kanda = 0
	current_mission = 0
	punya = 0
	dharma = 0
	unlocked_astras.clear()
	flags.clear()
	skills.clear()
	mission_stars.clear()
	checkpoint = ""
	quests.clear()
	lore.clear()


func is_kanda_playable(index: int, owns_full_game: bool = _store_owns_full_game()) -> bool:
	if index < 0 or index >= KANDAS.size():
		return false
	return index < FREE_KANDAS or owns_full_game


# --- Parts ------------------------------------------------------------------

## A Part is unlocked when it is free, bought on its own, or covered by the
## Full Journey bundle.
func is_part_unlocked(part: PartResource, store: Node = null) -> bool:
	if part == null:
		return false
	if part.free:
		return true
	if store == null:
		store = get_node_or_null("/root/Store")
	return store != null and (store.owns_full_journey() or store.owns_product(part.product_id))


func set_part(number: int) -> void:
	var n := clampi(number, 1, maxi(PartCatalog.all().size(), 1))
	if n != current_part:
		current_mission = 0
	current_part = n
	part_changed.emit(current_part)


func add_dharma(amount: int) -> void:
	dharma = clampi(dharma + amount, 0, 100)
	dharma_changed.emit(dharma)


func complete_part(id: StringName) -> void:
	if id in completed_parts:
		return
	completed_parts.append(id)
	part_completed.emit(id)


func is_part_completed(id: StringName) -> bool:
	return id in completed_parts


func set_kanda(index: int) -> void:
	current_kanda = clampi(index, 0, KANDAS.size() - 1)
	current_mission = 0
	kanda_changed.emit(current_kanda)


func add_punya(amount: int) -> void:
	punya += maxi(amount, 0)
	punya_changed.emit(punya)


func spend_punya(amount: int) -> bool:
	if amount > punya:
		return false
	punya -= amount
	punya_changed.emit(punya)
	return true


## Records stars for a mission, keeping the best. Returns the best.
func record_stars(part: int, mission: int, stars: int) -> int:
	var k := "%d:%d" % [part, mission]
	var best := maxi(int(mission_stars.get(k, 0)), stars)
	mission_stars[k] = best
	# Stars won on Maharathi are remembered apart (shown as a red seal).
	var settings := get_node_or_null("/root/Settings")
	if settings and settings.difficulty == 2:
		var hard: Dictionary = flags.get("hard_stars", {})
		hard[k] = maxi(int(hard.get(k, 0)), stars)
		flags["hard_stars"] = hard
	return best


func hard_stars_for(part: int, mission: int) -> int:
	return int((flags.get("hard_stars", {}) as Dictionary).get("%d:%d" % [part, mission], 0))


func stars_for(part: int, mission: int) -> int:
	return int(mission_stars.get("%d:%d" % [part, mission], 0))


func find_lore(id: StringName) -> bool:
	if id in lore:
		return false
	lore.append(id)
	return true


func unlock_astra(astra_id: StringName) -> void:
	if astra_id in unlocked_astras:
		return
	unlocked_astras.append(astra_id)
	astra_unlocked.emit(astra_id)


func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value


func get_flag(key: String, default: Variant = false) -> Variant:
	return flags.get(key, default)


func to_dict() -> Dictionary:
	var astras: Array[String] = []
	for a in unlocked_astras:
		astras.append(String(a))
	var completed: Array[String] = []
	for c in completed_parts:
		completed.append(String(c))
	return {
		"version": SAVE_VERSION,
		"current_part": current_part,
		"completed_parts": completed,
		"current_kanda": current_kanda,
		"current_mission": current_mission,
		"punya": punya,
		"dharma": dharma,
		"unlocked_astras": astras,
		"flags": flags.duplicate(true),
		"skills": skills.map(func(x: StringName) -> String: return String(x)),
		"mission_stars": mission_stars.duplicate(),
		"checkpoint": checkpoint,
		"quests": quests.duplicate(true),
		"lore": lore.map(func(x: StringName) -> String: return String(x)),
	}


func from_dict(data: Dictionary) -> void:
	reset()
	current_kanda = int(data.get("current_kanda", 0))
	current_mission = int(data.get("current_mission", 0))
	punya = int(data.get("punya", 0))
	dharma = int(data.get("dharma", 0))
	for a in data.get("unlocked_astras", []):
		unlocked_astras.append(StringName(a))
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	# v3 fields (absent in older saves: start empty).
	for k in data.get("skills", []):
		skills.append(StringName(k))
	mission_stars = (data.get("mission_stars", {}) as Dictionary).duplicate()
	checkpoint = String(data.get("checkpoint", ""))
	quests = (data.get("quests", {}) as Dictionary).duplicate(true)
	for k in data.get("lore", []):
		lore.append(StringName(k))
	if int(data.get("version", 1)) < 2 or not data.has("current_part"):
		# v1 saves tracked kandas only.
		current_part = PartCatalog.part_number_for_kanda(current_kanda)
	else:
		current_part = int(data.get("current_part", 1))
		for c in data.get("completed_parts", []):
			completed_parts.append(StringName(c))
	# Saves from before the Sarayu road: anyone past mission 2 has walked it.
	if current_part == 1 and current_mission >= 3 and not flags.has("bala_atibala"):
		flags["bala_atibala"] = true


func _store_owns_full_game() -> bool:
	return _store_owns_full_journey()


func _store_owns_full_journey() -> bool:
	var store := get_node_or_null("/root/Store")
	return store != null and store.owns_full_journey()
