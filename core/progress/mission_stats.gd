class_name MissionStats
extends RefCounted
## What happened during a mission, for its star goals and summary.

var perfect_shots := 0
var falls := 0
var damage_taken := 0.0
var dharma_gained := 0
var punya_start := 0
## Level-specific facts: e.g. "spared", "boulder_shot", "fire_min".
var facts := {}


func _init() -> void:
	punya_start = GameState.punya


func track(rama: Rama) -> void:
	rama.released.connect(func(_a: Arrow, _p: float, perfect: bool) -> void:
		if perfect:
			perfect_shots += 1)
	rama.rama_died.connect(func() -> void: falls += 1)
	rama.hurt.connect(func(amount: float) -> void: damage_taken += amount)
	var last := [GameState.dharma]
	GameState.dharma_changed.connect(func(v: int) -> void:
		dharma_gained += maxi(v - last[0], 0)
		last[0] = v)


func punya_earned() -> int:
	return GameState.punya - punya_start


## Is one goal ("kind[:param]|label") met?
func met(goal: String) -> bool:
	var spec := goal.split("|")[0]
	var kind := spec.split(":")[0]
	var param := spec.split(":")[1] if spec.contains(":") else ""
	match kind:
		"finish":
			return true
		"no_fall":
			return falls == 0
		"perfect":
			return perfect_shots >= int(param)
		"damage_under":
			return damage_taken < float(param)
		"fact":
			return bool(facts.get(param, false))
		"fire":
			return float(facts.get("fire_min", 0.0)) * 100.0 >= float(param)
	return false


func stars(goals: PackedStringArray) -> int:
	var n := 0
	for g in goals:
		if met(g):
			n += 1
	return n


static func label(goal: String) -> String:
	var parts := goal.split("|")
	return parts[1] if parts.size() > 1 else parts[0]
