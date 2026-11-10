class_name MapResource
extends Resource
## A level's map: a top-down image rendered by tools/render_map.gd and the
## world rectangle (X/Z) it covers.

@export var title := ""
@export_file("*.tscn") var level_scene := ""
## Other levels built on the same ground (e.g. the trials in the same courtyard).
@export var other_scenes: PackedStringArray = []
@export_file("*.png") var image_path := ""
var image: Texture2D:
	get:
		return load(image_path) as Texture2D if image_path != "" else null
## World X/Z covered by the image: position = (min x, min z), size = extent.
@export var world_rect := Rect2()


## World point -> 0..1 image coordinates (u along X, v along Z).
func to_uv(p: Vector3) -> Vector2:
	return Vector2((p.x - world_rect.position.x) / world_rect.size.x, (p.z - world_rect.position.y) / world_rect.size.y)


static func for_level(scene_path: String) -> MapResource:
	for f in DirAccess.get_files_at("res://data/maps"):
		if f.ends_with(".tres") or f.ends_with(".tres.remap"):
			var m := load("res://data/maps/" + f.trim_suffix(".remap")) as MapResource
			if m and (m.level_scene == scene_path or scene_path in m.other_scenes):
				return m
	return null
