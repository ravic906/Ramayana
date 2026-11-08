extends Node
## Global, serialisable progress for the current playthrough.

signal kanda_changed(index: int)
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

## Number of kandas playable without the "Full Journey" purchase.
const FREE_KANDAS := 1

const SAVE_VERSION := 1

var current_kanda := 0
var current_mission := 0
var punya := 0
var unlocked_astras: Array[StringName] = []
var flags: Dictionary = {}


func reset() -> void:
	current_kanda = 0
	current_mission = 0
	punya = 0
	unlocked_astras.clear()
	flags.clear()


func is_kanda_playable(index: int, owns_full_game: bool = _store_owns_full_game()) -> bool:
	if index < 0 or index >= KANDAS.size():
		return false
	return index < FREE_KANDAS or owns_full_game


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
	return {
		"version": SAVE_VERSION,
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


func _store_owns_full_game() -> bool:
	var store := get_node_or_null("/root/Store")
	return store != null and store.owns_full_game()
