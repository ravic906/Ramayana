class_name SkillResource
extends Resource
## One upgrade in the skill tree, bought with Punya.
## Effects are read through the Skills autoload:
##   "<key>_mult": multiplies a base value (several multiply together)
##   "<key>_add":  adds to a base value
##   anything else: a flag (true when owned)

enum Branch { ARCHERY, ASTRAS, DHARMA }

@export var id: StringName
@export var branch := Branch.ARCHERY
@export var tier := 1
@export var cost := 100
## Must be owned first (the previous tier of the branch).
@export var requires: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var effects := {}
