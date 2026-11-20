class_name LoreResource
extends Resource
## A palm-leaf lore entry (the codex): short, factual, respectful.

@export var id: StringName
@export var title := ""
@export_multiline var text := ""
## Where this comes from in the Valmiki Ramayana, e.g. "Griffith XX-XXIV" (see docs/canon).
@export var canon := ""
## True for content the game adds that Valmiki does not contain (docs/canon/ADDITIONS.md).
@export var invented := false
