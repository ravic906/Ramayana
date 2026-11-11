class_name DialogueResource
extends Resource
## A scripted conversation. Each line is "Speaker|shot|action|Text|emotion":
##   Speaker  who talks (sets the name colour); "Narration" shows a full-screen
##            sung-narration card (Lava and Kusha, the game's framing).
##   shot     optional camera shot: an id provided by the level, or "close",
##            "ots" (over the listener's shoulder), "two" (two-shot); empty or
##            "auto" frames the speaker automatically when they are a
##            registered actor (StoryLevel.actors).
##   action   optional event emitted when the line starts (e.g. grant_astras,
##            bloom, wait:1.5). Lines with an action and no text run instantly.
##   emotion  optional face for the speaker (FaceController.EMOTIONS: calm,
##            resolve, concern, grief, anger, smile, reverence, wonder...).

##
## Stored as one multiline String, one line per row: Godot 4.3's export step
## (text resources converted to binary) drops PackedStringArray contents.
@export_multiline var text := "":
	set(value):
		text = value
		lines = PackedStringArray()
		for row in value.split("\n"):
			if not row.strip_edges().is_empty():
				lines.append(row.strip_edges())

## The parsed lines (filled from `text`; tests may also set them directly).
var lines: PackedStringArray = []


func line_count() -> int:
	return lines.size()


func get_line(i: int) -> Dictionary:
	var parts := lines[i].split("|", true, 4)
	while parts.size() < 5:
		parts.append("")
	return {"speaker": parts[0].strip_edges(), "shot": StringName(parts[1].strip_edges()),
		"action": StringName(parts[2].strip_edges()), "text": parts[3].strip_edges().replace("\\n", "\n"),
		"emotion": StringName(parts[4].strip_edges())}
