extends Node
## Global, serialisable progress for the current playthrough.

signal kanda_changed(index: int)
signal part_changed(number: int)
signal part_completed(id: StringName)
signal punya_changed(total: int)
signal astra_unlocked(astra_id: StringName)

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
const SAVE_VERSION := 2

var current_part := 1
var completed_parts: Array[StringName] = []
var current_kanda := 0
var current_mission := 0
var punya := 0
var unlocked_astras: Array[StringName] = []
var flags: Dictionary = {}


func reset() -> void:
	current_part = 1
	completed_parts.clear()
	current_kanda = 0
	current_mission = 0
	punya = 0
	unlocked_astras.clear()
	flags.clear()


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
	current_part = clampi(number, 1, maxi(PartCatalog.all().size(), 1))
	current_mission = 0
	part_changed.emit(current_part)


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
		"unlocked_astras": astras,
		"flags": flags.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	reset()
	current_kanda = int(data.get("current_kanda", 0))
	current_mission = int(data.get("current_mission", 0))
	punya = int(data.get("punya", 0))
	for a in data.get("unlocked_astras", []):
		unlocked_astras.append(StringName(a))
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	if int(data.get("version", 1)) < 2 or not data.has("current_part"):
		# v1 saves tracked kandas only.
		current_part = PartCatalog.part_number_for_kanda(current_kanda)
	else:
		current_part = int(data.get("current_part", 1))
		for c in data.get("completed_parts", []):
			completed_parts.append(StringName(c))


func _store_owns_full_game() -> bool:
	return _store_owns_full_journey()


func _store_owns_full_journey() -> bool:
	var store := get_node_or_null("/root/Store")
	return store != null and store.owns_full_journey()
