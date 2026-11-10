extends Node
## The skill tree: what Rama (and Lakshmana) have learned, bought with Punya.
## Gameplay code asks for modified values:
##   Skills.mult("draw_time")  -> product of every owned "draw_time_mult"
##   Skills.add("rama_health") -> sum of every owned "rama_health_add"
##   Skills.flag("pierce")     -> true if an owned skill grants it

const PATHS := [
	"res://data/skills/steady_draw.tres", "res://data/skills/long_breath.tres",
	"res://data/skills/piercing_shot.tres", "res://data/skills/twin_arrows.tres",
	"res://data/skills/quick_mantra.tres", "res://data/skills/agnis_wrath.tres",
	"res://data/skills/deep_waters.tres", "res://data/skills/gale.tres",
	"res://data/skills/steadfast.tres", "res://data/skills/brothers_shield.tres",
	"res://data/skills/lakshmanas_volley.tres", "res://data/skills/blessing.tres",
]

var all: Array[SkillResource] = []


func _ready() -> void:
	for p: String in PATHS:
		var s := load(p) as SkillResource
		if s:
			all.append(s)


func get_skill(id: StringName) -> SkillResource:
	for s in all:
		if s.id == id:
			return s
	return null


func by_branch(branch: int) -> Array[SkillResource]:
	var out: Array[SkillResource] = []
	for s in all:
		if s.branch == branch:
			out.append(s)
	out.sort_custom(func(a: SkillResource, b: SkillResource) -> bool: return a.tier < b.tier)
	return out


func has(id: StringName) -> bool:
	return id in GameState.skills


func is_available(s: SkillResource) -> bool:
	return not has(s.id) and (s.requires == &"" or has(s.requires))


func can_buy(s: SkillResource) -> bool:
	return is_available(s) and GameState.punya >= s.cost


func buy(id: StringName) -> bool:
	var s := get_skill(id)
	if s == null or not can_buy(s) or not GameState.spend_punya(s.cost):
		return false
	GameState.skills.append(id)
	GameState.skills_changed.emit()
	SaveSystem.save_game()
	return true


func mult(key: String) -> float:
	var v := 1.0
	for s in _owned():
		if s.effects.has(key + "_mult"):
			v *= float(s.effects[key + "_mult"])
	return v


func add(key: String) -> float:
	var v := 0.0
	for s in _owned():
		if s.effects.has(key + "_add"):
			v += float(s.effects[key + "_add"])
	return v


func flag(key: String) -> bool:
	for s in _owned():
		if s.effects.get(key, false):
			return true
	return false


func _owned() -> Array[SkillResource]:
	var out: Array[SkillResource] = []
	for s in all:
		if s.id in GameState.skills:
			out.append(s)
	return out
