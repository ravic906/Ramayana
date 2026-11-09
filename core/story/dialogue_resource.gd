class_name DialogueResource
extends Resource
## A scripted conversation. Each line is "Speaker|shot|action|Text":
##   Speaker  who talks (sets the name colour); "Narration" shows a full-screen
##            sung-narration card (Lava and Kusha, the game's framing).
##   shot     optional camera shot id provided by the level.
##   action   optional event emitted when the line starts (e.g. grant_astras,
##            bloom, wait:1.5). Lines with an action and no text run instantly.

@export var lines: PackedStringArray = []


func line_count() -> int:
	return lines.size()


func get_line(i: int) -> Dictionary:
	var parts := lines[i].split("|", true, 3)
	while parts.size() < 4:
		parts.append("")
	return {"speaker": parts[0].strip_edges(), "shot": StringName(parts[1].strip_edges()),
		"action": StringName(parts[2].strip_edges()), "text": parts[3].strip_edges().replace("\\n", "\n")}
