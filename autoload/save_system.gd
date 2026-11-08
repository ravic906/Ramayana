extends Node
## Slot-based JSON saves protected by a SHA-256 checksum.
##
## File layout: { "version": 1, "checksum": "<sha256>", "payload": "<json string>" }
## The checksum is computed over the raw payload string so that JSON number
## round-tripping (ints become floats) can never break verification.

signal saved(slot: int)
signal loaded(slot: int)

const FORMAT_VERSION := 1
const MAX_SLOTS := 3
const AUTOSAVE_SLOT := 0

var save_dir := "user://saves"


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [save_dir, slot]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func save_data(slot: int, data: Dictionary) -> Error:
	if slot < 0 or slot > MAX_SLOTS:
		return ERR_PARAMETER_RANGE_ERROR
	var err := DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK and err != ERR_ALREADY_EXISTS:
		return err
	var payload := JSON.stringify(data)
	var envelope := {
		"version": FORMAT_VERSION,
		"checksum": payload.sha256_text(),
		"payload": payload,
	}
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(envelope))
	file.close()
	saved.emit(slot)
	return OK


## Returns the saved dictionary, or an empty dictionary if missing/corrupt.
func load_data(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var text := FileAccess.get_file_as_string(slot_path(slot))
	var envelope: Variant = JSON.parse_string(text)
	if typeof(envelope) != TYPE_DICTIONARY:
		push_warning("Save slot %d is not valid JSON." % slot)
		return {}
	var payload: String = envelope.get("payload", "")
	if payload.sha256_text() != envelope.get("checksum", ""):
		push_warning("Save slot %d failed checksum verification." % slot)
		return {}
	var data: Variant = JSON.parse_string(payload)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	loaded.emit(slot)
	return data


func delete_save(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(slot_path(slot))


## Convenience wrappers around the GameState autoload.
func save_game(slot: int = AUTOSAVE_SLOT) -> Error:
	return save_data(slot, GameState.to_dict())


func load_game(slot: int = AUTOSAVE_SLOT) -> bool:
	var data := load_data(slot)
	if data.is_empty():
		return false
	GameState.from_dict(data)
	return true
