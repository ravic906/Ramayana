class_name PartLoader
extends Node
## Installs and mounts downloadable Parts. Part 1 ships inside the app; later
## Parts are separate .pck content packs saved under user://parts/ and mounted
## with ProjectSettings.load_resource_pack(). (On the stores this maps to Play
## Asset Delivery / iOS On-Demand Resources.)
##
## The download host is the project setting "ramayana/parts/base_url"; while it
## is empty, downloads report themselves unavailable.

signal progress(part: PartResource, ratio: float)
signal finished(part: PartResource, ok: bool, message: String)

const PARTS_DIR := "user://parts"

var _http: HTTPRequest
var _part: PartResource


static func base_url() -> String:
	return str(ProjectSettings.get_setting("ramayana/parts/base_url", ""))


static func pack_path(part: PartResource) -> String:
	return PARTS_DIR.path_join(part.pack_file)


## True when the Part's content is on the device (built in or downloaded).
static func is_installed(part: PartResource) -> bool:
	return part.is_shipped_in_app() or FileAccess.file_exists(pack_path(part))


## Mounts a downloaded Part so its scene can load. Returns whether the
## Part's scene is now available.
static func mount(part: PartResource) -> bool:
	if not part.is_shipped_in_app():
		if not FileAccess.file_exists(pack_path(part)):
			return false
		if not ProjectSettings.load_resource_pack(pack_path(part), false):
			return false
	return not part.scene_path.is_empty() and ResourceLoader.exists(part.scene_path)


static func can_download() -> bool:
	return not base_url().is_empty()


## Starts downloading a Part's pack; emits progress() and finished().
func download(part: PartResource) -> void:
	if _http != null:
		finished.emit(part, false, "Another download is in progress.")
		return
	if not can_download() or part.is_shipped_in_app():
		finished.emit(part, false, "Downloads are not available yet.")
		return
	DirAccess.make_dir_recursive_absolute(PARTS_DIR)
	_part = part
	_http = HTTPRequest.new()
	_http.download_file = pack_path(part) + ".download"
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_on_completed)
	var err := _http.request(base_url().path_join(part.pack_file))
	if err != OK:
		_finish(false, "Could not start the download (%s)." % error_string(err))


func _process(_delta: float) -> void:
	if _http != null and _http.get_body_size() > 0:
		progress.emit(_part, float(_http.get_downloaded_bytes()) / _http.get_body_size())


func _on_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	var tmp := pack_path(_part) + ".download"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(tmp)
		_finish(false, "Download failed (result %d, HTTP %d)." % [result, code])
		return
	if not verify(tmp, _part):
		DirAccess.remove_absolute(tmp)
		_finish(false, "The download was corrupted. Please try again.")
		return
	DirAccess.rename_absolute(tmp, pack_path(_part))
	_finish(true, "")


## Checks size and SHA-256 when the Part declares them.
static func verify(path: String, part: PartResource) -> bool:
	if not FileAccess.file_exists(path):
		return false
	if part.pack_size > 0:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null or f.get_length() != part.pack_size:
			return false
	if not part.pack_sha256.is_empty():
		return FileAccess.get_sha256(path) == part.pack_sha256
	return true


func _finish(ok: bool, message: String) -> void:
	var part := _part
	if _http:
		_http.queue_free()
	_http = null
	_part = null
	finished.emit(part, ok, message)
