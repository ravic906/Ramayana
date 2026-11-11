extends TestCase
## Mission 2's road along the Sarayu: hand-off and resume, the stampede (Guard
## turns the bulls, arrows startle animals, nothing is harmed), the side
## quests and leaves, and the Bala and Atibala blessing.

const SARAYU := "res://kandas/01_bala/sarayu_road.tscn"

var level: Node
var stage: Node3D


func after_each() -> void:
	for n in [level, stage]:
		if n:
			n.queue_free()
	level = null
	stage = null
	Music.stop()
	GameState.reset()
	SaveSystem.delete_save(SaveSystem.AUTOSAVE_SLOT)


func _road() -> Node:
	GameState.story_session = false
	GameState.current_part = 1
	GameState.current_mission = 2
	level = load(SARAYU).instantiate()
	add_child(level)
	return level


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _stage() -> Node3D:
	stage = Node3D.new()
	add_child(stage)
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	cs.shape = box
	cs.position.y = -0.5
	floor_body.add_child(cs)
	stage.add_child(floor_body)
	return stage


func _fake_guard(pos: Vector3) -> Node3D:
	var s := GDScript.new()
	s.source_code = "extends Node3D\nvar command := 2\n"
	s.reload()
	var g := Node3D.new()
	g.set_script(s)
	g.add_to_group(&"companions")
	stage.add_child(g)
	g.global_position = pos
	return g


func test_the_gate_leads_to_the_road_and_resume_returns_there() -> void:
	var src := FileAccess.get_file_as_string("res://kandas/01_bala/training_grounds.gd")
	assert_true(src.contains("go_to_scene(SARAYU)"), "the gate scene hands off to the road")
	var part := PartCatalog.by_number(1)
	GameState.current_part = 1
	GameState.current_mission = 2
	GameState.checkpoint = "sarayu"
	assert_eq(PartFlow.scene_for(part), SARAYU, "quitting on the road resumes on the road")
	GameState.checkpoint = ""
	assert_eq(PartFlow.scene_for(part), "res://kandas/01_bala/ayodhya_hub.tscn")
	GameState.current_mission = 3
	GameState.checkpoint = "sarayu"
	assert_eq(PartFlow.scene_for(part), "res://kandas/01_bala/forest.tscn", "only within mission 2")


func test_the_road_sets_its_checkpoint_and_has_its_people() -> void:
	_road()
	await _frames(3)
	assert_eq(GameState.checkpoint, "sarayu")
	assert_true(level.sage != null and level.widow != null and level.boatman != null)
	assert_eq(level.herd.size(), 8, "a herd grazes in the meadow")
	var lamps := 0
	var leaves := 0
	for n in get_tree().get_nodes_in_group(&"interactables"):
		if String(n.name).begins_with("Lamp"):
			lamps += 1
		if String(n.name).begins_with("Leaf_"):
			leaves += 1
	assert_eq(lamps, 5)
	assert_eq(leaves, 3)
	var map := load("res://data/maps/sarayu.tres") as MapResource
	assert_true(map != null and map.level_scene == SARAYU and map.image != null, "the road has a map")


func test_bala_atibala_quickens_the_dodge_and_steadies_the_bow() -> void:
	_road()
	await _frames(2)
	var rama: Rama = level.rama
	rama.start_dodge_cooldown()
	var plain: float = rama._dodge_timer
	level.grant_bala_atibala()
	assert_true(GameState.get_flag("bala_atibala", false))
	assert_true(&"bala_atibala" in GameState.lore, "the blessing is written in the Journal")
	rama.start_dodge_cooldown()
	assert_almost(rama._dodge_timer, plain * Rama.BALA_DODGE, 0.001)


func test_older_saves_past_the_road_have_the_blessing() -> void:
	GameState.from_dict({"version": 3, "current_part": 1, "current_mission": 4, "flags": {}})
	assert_true(GameState.get_flag("bala_atibala", false))
	GameState.from_dict({"version": 3, "current_part": 1, "current_mission": 2, "flags": {}})
	assert_false(GameState.get_flag("bala_atibala", false))


func test_animals_are_never_struck_and_bolt_from_a_near_arrow() -> void:
	_stage()
	var deer := Animal.spawn(stage, "deer", Vector3(0, 0, 0))
	await _frames(2)
	assert_eq(deer.collision_layer & 5, 0, "arrows (world + enemies) pass animals by")
	assert_null(deer.get_node_or_null("Health"), "nothing to wound")
	deer.on_arrow_near(Vector3(2, 0, 0))
	assert_eq(deer.state, Animal.Mode.FLEE)
	var start := deer.global_position
	await _frames(30)
	assert_true(deer.global_position.x < start.x - 1.0, "runs away from where the arrow fell")
	var stag := Animal.spawn(stage, "stag", Vector3(20, 0, 0))
	await _frames(1)
	stag.on_arrow_near(Vector3(0, 0, 0))
	assert_eq(stag.state, Animal.Mode.GRAZE, "far arrows don't startle")


func test_a_guard_turns_a_charging_bull() -> void:
	_stage()
	var sage := Node3D.new()
	stage.add_child(sage)
	var guard := _fake_guard(Vector3(0, 0, -2.0))
	var bull := Animal.spawn(stage, "bull", Vector3(0, 0, -16))
	var log := {"struck": false, "turned": null}
	bull.struck.connect(func(_t: Node3D) -> void: log["struck"] = true)
	bull.turned.connect(func(by: Node) -> void: log["turned"] = by)
	await _frames(1)
	bull.charge(sage)
	await _frames(180)
	assert_false(log["struck"], "the sage is safe")
	assert_eq(log["turned"], guard, "turned by the guard")


func test_an_unguarded_bull_reaches_the_sage() -> void:
	_stage()
	var sage := Node3D.new()
	stage.add_child(sage)
	var bull := Animal.spawn(stage, "bull", Vector3(0, 0, -12))
	var log := {"struck": false}
	bull.struck.connect(func(_t: Node3D) -> void: log["struck"] = true)
	await _frames(1)
	bull.charge(sage)
	await _frames(180)
	assert_true(log["struck"])
	assert_false(bull.is_charging(), "and runs on")


func test_lamps_float_at_the_camp_and_the_oar_goes_home() -> void:
	_road()
	await _frames(2)
	Quests.start(&"river_lamps")
	for n in get_tree().get_nodes_in_group(&"interactables").duplicate():
		if String(n.name).begins_with("Lamp"):
			level._take_lamp(n)
	assert_true(Quests.goal_reached(&"river_lamps"))
	level.at_camp = true
	level._float_lamps()
	assert_true(Quests.is_done(&"river_lamps"))
	assert_eq(level._lamps_afloat.size(), 5, "five lamps on the water")
	Quests.start(&"boatmans_oar")
	level.oar_carried = true
	level._talk_boatman()
	assert_true(Quests.is_done(&"boatmans_oar"))


func test_the_stampede_rewards_a_sage_kept_safe() -> void:
	_road()
	await _frames(2)
	var before := GameState.dharma
	level.stats.facts["sage_unharmed"] = true
	level._end_stampede()
	assert_eq(GameState.dharma, before + 5)
	assert_eq(level.lakshmana.command, Lakshmana.Command.FOLLOW, "Lakshmana back at Rama's side")


func test_mission_two_has_three_stars() -> void:
	var m := PartFlow.get_mission(1, 2)
	assert_eq(m.star_goals.size(), 3)
	assert_true(String(m.star_goals[1]).begins_with("fact:sage_unharmed"))
