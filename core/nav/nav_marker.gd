class_name NavMarker
extends Node3D
## A place the player may want to find: shown on the compass, on the map and
## (for the main objective or a tracked quest) as a beacon in the world.
##   MAIN    the current story objective (gold)
##   SIDE    a side-quest person or place (silver); shown while its quest is open
##   PICKUP  something to collect for a quest; shown when near or when tracked
##   EXIT    a way onward (gate, path)

enum Kind { MAIN, SIDE, PICKUP, EXIT }

const PICKUP_NEAR := 25.0

@export var kind := Kind.SIDE
@export var label := ""
## The quest this marker belongs to (empty = always relevant).
@export var quest_id: StringName = &""
@export var active := true
## When set, the marker stays on this node (e.g. a moving boss, a person).
var follow: Node3D


func _ready() -> void:
	add_to_group(&"nav_markers")


func _process(_delta: float) -> void:
	if follow != null and is_instance_valid(follow) and follow.is_inside_tree():
		global_position = follow.global_position


## Should it appear on the compass and map right now?
func is_shown(from: Vector3 = Vector3.INF) -> bool:
	if not active or not is_inside_tree():
		return false
	if quest_id != &"" and Quests.is_done(quest_id):
		return false
	match kind:
		Kind.PICKUP:
			var tracked := quest_id != &"" and Quests.tracked == quest_id
			return tracked or (from != Vector3.INF and from.distance_to(global_position) <= PICKUP_NEAR)
	return true


func color() -> Color:
	match kind:
		Kind.MAIN:
			return Color(1.0, 0.78, 0.25)
		Kind.EXIT:
			return Color(0.95, 0.65, 0.35)
		Kind.PICKUP:
			return Color(0.85, 0.95, 0.75)
	return Color(0.82, 0.86, 0.95) if quest_id == &"" or Quests.tracked != quest_id else Color(0.6, 0.85, 1.0)


func is_tracked() -> bool:
	return kind == Kind.MAIN or (quest_id != &"" and Quests.tracked == quest_id)
