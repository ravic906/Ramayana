class_name MissionResource
extends Resource
## One mission inside a Part (e.g. Part 1: Maya Trials, The Sage at the Gate,
## The Silent Forest, Tataka).

@export var number := 1
@export var id := &"m1"
@export var title := ""
## Shown on the Lava-Kusha narration card when the mission starts.
@export_multiline var narration := ""
@export_file("*.tscn") var scene_path := ""
## Where in the scene the mission starts (level-specific).
@export var checkpoint := &""
@export var available := true
## Up to three goals, each "kind[:param]|label". Kinds:
##   finish, no_fall, perfect:N, damage_under:N, fact:key, fire:P (percent)
## Missions without goals (pure cutscenes) show no summary.
@export var star_goals: PackedStringArray = []
