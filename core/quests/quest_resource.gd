class_name QuestResource
extends Resource
## A side quest: who gives it, what to do, and the reward.

@export var id: StringName
@export var title := ""
@export var giver := ""
@export_multiline var summary := ""
## Shown on the HUD tracker, with "{n}/{goal}" progress when goal_count > 1.
@export var objective := ""
@export var goal_count := 1
## Once the goal is met, what remains (e.g. "Bring the lotuses to Guru
## Vasishtha"); empty when the quest completes on its own.
@export var return_text := ""
@export var reward_punya := 0
@export var reward_dharma := 0
