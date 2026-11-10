extends StoryLevel
## Ayodhya, between Vasishtha's trials and the sage at the gate: the palace
## grounds to walk freely, people to help, and the gate to go to when ready.
## Side quests: Leaves of the Old Tales, The Archer's Challenge, The Lost
## Child, Lotuses for the Guru.

const NPC := "res://characters/npc/npc_model.tscn"
const VASISHTHA := "res://characters/npc/vasishtha.tscn"
const DUMMY := "res://characters/enemies/target_dummy.tscn"
const GATE_SCENE := "res://kandas/01_bala/training_grounds.tscn"
const CHALLENGE_TIME := 45.0
const SCROLLS := [
	["ikshvaku", Vector3(-12, 0, -20)], ["sarayu", Vector3(14, 0, -12)], ["vasishtha", Vector3(-24, 0, -30)],
	["kodanda", Vector3(6, 0, -38)], ["ayodhya", Vector3(24, 0, 2)],
]
const LOTUSES := [Vector3(-18.0, -0.9, 1.7), Vector3(-22.5, -0.9, 1.7), Vector3(-15.8, -0.9, 5.5)]
const RANGE := [Vector3(-6, 0, -18), Vector3(-3.5, 0, -21), Vector3(0, 0, -19), Vector3(3.5, 0, -21), Vector3(6, 0, -18), Vector3(0, 0, -24)]

@onready var lakshmana: Lakshmana = $Lakshmana
@onready var sun: DirectionalLight3D = $Sun

var npcs := {}
var dummies: Array[TargetDummy] = []
var challenge_left := -1.0
var child: Node3D
var child_following := false
var _gate: Interactable


func _ready() -> void:
	var hint := hud.get_node_or_null("Root/HintLabel")
	if hint:
		hint.visible = false
	Settings.apply_to_sun(sun)
	lakshmana.command = Lakshmana.Command.FOLLOW  # no fighting in the palace
	Music.play("ayodhya")
	_build_people()
	_build_scrolls()
	_build_lotuses()
	_build_range()
	_build_gate()
	Quests.changed.connect(refresh_tracker)
	refresh_tracker()
	if story_enabled() and not GameState.get_flag("hub_intro"):
		GameState.set_flag("hub_intro", true)
		_intro.call_deferred()


func _intro() -> void:
	await say_lines([
		["Lakshmana", "A sage waits at the gate, brother. But the palace is full of people who could use our help."],
		["Rama", "Then let us walk through it first. We will go to the gate when it is time."],
	])


func _process(delta: float) -> void:
	if challenge_left >= 0.0:
		challenge_left -= delta
		refresh_tracker()
		if challenge_left < 0.0:
			_challenge_failed()
	if child_following and is_instance_valid(child):
		var goal := rama.global_position + rama.visual.global_basis * Vector3(1.2, 0, 1.8)
		var to := goal - child.global_position
		to.y = 0.0
		if to.length() > 0.8:
			child.global_position += to.normalized() * minf(5.0 * delta, to.length())
			child.look_at(child.global_position + to.normalized(), Vector3.UP, true)
			if (child as NpcModel).anim.current_animation != "walk":
				(child as NpcModel).anim.play(&"walk")
		elif (child as NpcModel).anim.current_animation != "idle":
			(child as NpcModel).anim.play(&"idle")
		if to.length() > 15.0:
			child.global_position = goal  # caught behind: catch up off-screen
		var grandfather: Node3D = npcs.get("grandfather")
		if grandfather and rama.global_position.distance_to(grandfather.global_position) < 3.5 \
				and child.global_position.distance_to(rama.global_position) < 8.0:
			_child_home()


## The HUD line: the first active quest, else a gentle pointer to the gate.
func refresh_tracker() -> void:
	if challenge_left >= 0.0:
		hud.set_tracker("Targets %d/6   %d s" % [Quests.count(&"archers_challenge"), ceili(challenge_left)])
		return
	if Quests.is_active(&"lotus_for_guru") and Quests.goal_reached(&"lotus_for_guru"):
		hud.set_tracker("Bring the lotuses to Guru Vasishtha")
		return
	for q in Quests.all:
		if Quests.is_active(q.id):
			hud.set_tracker(Quests.tracker_text(q.id))
			return
	hud.set_tracker("Help the people of Ayodhya, or go to the palace gate when ready")


# --- People ---------------------------------------------------------------------

func _person(key: String, pos: Vector3, face: Vector3, look: Dictionary, prompt := "Talk") -> Node3D:
	var n := (load(NPC) as PackedScene).instantiate() as NpcModel
	for k in look:
		n.set(k, look[k])
	n.position = pos
	add_child(n)
	n.face(face)
	var it := Interactable.new()
	it.name = "Talk"
	it.prompt = prompt
	n.add_child(it)
	npcs[key] = n
	return n


func _build_people() -> void:
	var scribe := _person("scribe", Vector3(-6, 0, -6), Vector3(0, 0, 4),
		{"garment": Color(0.95, 0.93, 0.85), "sash": Color(0.8, 0.7, 0.4), "beard": true, "topknot": true})
	(scribe.get_node("Talk") as Interactable).interacted.connect(_talk_scribe)
	var sumantra := _person("sumantra", Vector3(9, 0, -12), Vector3(0, 0, -18),
		{"garment": Color(0.25, 0.35, 0.65), "trim": Color(0.85, 0.65, 0.25), "beard": true})
	(sumantra.get_node("Talk") as Interactable).interacted.connect(_talk_sumantra)
	var grandfather := _person("grandfather", Vector3(-12, 0, -2), Vector3(0, 0, 4),
		{"garment": Color(0.7, 0.55, 0.35), "hair_color": Color(0.85, 0.85, 0.82), "beard": true, "staff": true})
	(grandfather.get_node("Talk") as Interactable).interacted.connect(_talk_grandfather)
	var gardener := _person("gardener", Vector3(-13, 0, 8), Vector3(-20, 0, 5),
		{"garment": Color(0.35, 0.55, 0.3), "hair_color": Color(0.8, 0.8, 0.78), "beard": true})
	(gardener.get_node("Talk") as Interactable).interacted.connect(_talk_gardener)
	var guru := spawn_npc(VASISHTHA, Vector3(0, 0, -28), Vector3(0, 0, 0))
	var it := Interactable.new()
	it.name = "Talk"
	guru.add_child(it)
	npcs["vasishtha"] = guru
	it.interacted.connect(_talk_vasishtha)
	# Little Chandu, hiding behind a planter.
	if not Quests.is_done(&"lost_child"):
		child = _person("child", Vector3(22.5, 0, -43.5), Vector3(20, 0, -40),
			{"model_scale": 0.6, "garment": Color(0.95, 0.75, 0.2), "hair_color": Color(0.1, 0.07, 0.05)})
		(child.get_node("Talk") as Interactable).interacted.connect(_talk_child)


func _talk_scribe() -> void:
	if Quests.is_done(&"leaves_of_old"):
		await say_lines([["Scribe", "Every leaf back in its bundle. The old tales are safe, Prince Rama."]])
	elif Quests.is_active(&"leaves_of_old"):
		await say_lines([["Scribe", "Still a few leaves out there, my prince. Look where the wind would carry them."]])
	else:
		Quests.start(&"leaves_of_old")
		await say_lines([
			["Scribe", "Prince Rama! A wind off the Sarayu tore my bundle open. The old tales are scattered over the courtyard."],
			["Rama", "Then we will gather them, every one."],
		])


func _talk_sumantra() -> void:
	if challenge_left >= 0.0:
		return
	if Quests.is_done(&"archers_challenge"):
		await say_lines([["Sumantra", "Six targets before the sand ran out. I will tell the king myself."]])
		return
	if not Quests.is_active(&"archers_challenge"):
		Quests.start(&"archers_challenge")
		await say_lines([
			["Sumantra", "A wager, young prince: six targets on the range, before this sand runs out."],
			["Lakshmana", "He accepts. I would bet on him against the whole army."],
		])
	else:
		await say_lines([["Sumantra", "Again? Good. The sand is turned."]])
	start_challenge()


func _talk_grandfather() -> void:
	if Quests.is_done(&"lost_child"):
		await say_lines([["Grandfather", "May you always find what others have lost, Prince Rama."]])
	elif Quests.is_active(&"lost_child"):
		await say_lines([["Grandfather", "Chandu loves to hide. He thinks he is a tiger."]])
	else:
		Quests.start(&"lost_child")
		await say_lines([
			["Grandfather", "Forgive me, my prince. My grandson Chandu ran off in the crowd, and my eyes are not what they were."],
			["Rama", "Rest here, grandfather. We will find him."],
		])


func _talk_child() -> void:
	if child_following or Quests.is_done(&"lost_child"):
		return
	if not Quests.is_active(&"lost_child"):
		Quests.start(&"lost_child")
	child_following = true
	(child.get_node("Talk") as Interactable).enabled = false
	await say_lines([
		["Chandu", "Shh! I am a tiger, hunting in the garden!"],
		["Rama", "A brave tiger. But your grandfather is looking for you. Will you walk with me?"],
	])


func _child_home() -> void:
	child_following = false
	Quests.complete(&"lost_child")
	hud.show_banner("Chandu is home.  +8 Dharma", Color(1.0, 0.85, 0.5), 2.5)
	await say_lines([["Grandfather", "Chandu! Thank you, Prince Rama. A kind heart is the first strength of a king."]])


func _talk_gardener() -> void:
	if Quests.is_done(&"lotus_for_guru"):
		await say_lines([["Gardener", "The guru smiled, they tell me. Thank you, my prince."]])
	elif Quests.is_active(&"lotus_for_guru"):
		await say_lines([["Gardener", "The lotuses float by the steps of the kalyani. Take them to Guru Vasishtha."]])
	else:
		Quests.start(&"lotus_for_guru")
		await say_lines([
			["Gardener", "The guru's worship needs lotuses, but my old knees cannot manage the kalyani steps any more."],
			["Lakshmana", "We will fetch them, grandfather."],
		])


func _talk_vasishtha() -> void:
	if Quests.is_active(&"lotus_for_guru") and Quests.goal_reached(&"lotus_for_guru"):
		Quests.complete(&"lotus_for_guru")
		hud.show_banner("Lotuses for the Guru.  +5 Dharma", Color(1.0, 0.85, 0.5), 2.5)
		await say_lines([["Vasishtha", "Lotuses from the gardener, carried by a prince. Service is the root of every strength, Rama."]])
	else:
		await say_lines([["Vasishtha", "A sage waits at the gate, Rama. Go when your heart is ready."]])


# --- Things to find -------------------------------------------------------------------

func _build_scrolls() -> void:
	for spec in SCROLLS:
		var id := StringName(spec[0])
		if id in GameState.lore:
			continue
		var it := Interactable.new()
		it.name = "Leaf_" + spec[0]
		it.prompt = "Pick up"
		it.glint = true
		it.radius = 2.2
		it.position = spec[1]
		var leaf := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.6, 0.03, 0.12)
		leaf.mesh = m
		leaf.material_override = load("res://assets/materials/env/straw.tres")
		leaf.position = Vector3.UP * 0.05
		leaf.rotation.y = randf() * TAU
		it.add_child(leaf)
		add_child(it)
		it.interacted.connect(_pick_leaf.bind(it, id))


func _pick_leaf(it: Interactable, id: StringName) -> void:
	if not Quests.is_active(&"leaves_of_old") and not Quests.is_done(&"leaves_of_old"):
		Quests.start(&"leaves_of_old")
	GameState.find_lore(id)
	it.queue_free()
	var lore := Quests.get_lore(id)
	hud.show_banner("Palm leaf: %s\n(read it in the Journal)" % (lore.title if lore else ""), Color(1.0, 0.9, 0.6), 2.5)
	if Quests.progress(&"leaves_of_old") >= 5:
		hud.show_banner("Leaves of the Old Tales complete.  +80 Punya", Color(1.0, 0.85, 0.5), 2.5)


func _build_lotuses() -> void:
	if Quests.is_done(&"lotus_for_guru"):
		return
	for i in LOTUSES.size():
		var it := Interactable.new()
		it.name = "Lotus%d" % i
		it.prompt = "Gather"
		it.radius = 3.2
		it.glint = true
		it.position = LOTUSES[i]
		var bloom := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.28
		m.height = 0.24
		bloom.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.62, 0.75)
		bloom.material_override = mat
		it.add_child(bloom)
		add_child(it)
		it.interacted.connect(_gather_lotus.bind(it))


func _gather_lotus(it: Interactable) -> void:
	if not Quests.is_active(&"lotus_for_guru"):
		hud.show_banner("A lotus for someone's worship, perhaps. Ask the gardener.", Color(0.9, 0.85, 0.75), 2.5)
		return
	it.queue_free()
	Quests.progress(&"lotus_for_guru", 1, false)
	refresh_tracker()


func _build_gate() -> void:
	_gate = Interactable.new()
	_gate.name = "Gate"
	_gate.prompt = "To the gate"
	_gate.radius = 4.0
	_gate.glint = true
	_gate.position = Vector3(0, 0, -41)
	add_child(_gate)
	_gate.interacted.connect(go_to_gate)


## On to the sage at the gate (mission 2's story).
func go_to_gate() -> void:
	GameState.current_mission = 2
	SaveSystem.save_game()
	hud.set_cinematic(true)
	rama.controls_locked = true
	await say_lines([["Lakshmana", "The sage is waiting, brother. Let us go."]])
	if is_inside_tree():
		get_tree().change_scene_to_file(GATE_SCENE)


# --- The Archer's Challenge ----------------------------------------------------------

func _build_range() -> void:
	for p: Vector3 in RANGE:
		var d := (load(DUMMY) as PackedScene).instantiate() as TargetDummy
		d.punya_reward = 0  # no farming in the palace
		d.position = p
		add_child(d)
		d.health.died.connect(_on_target_down)
		dummies.append(d)


func start_challenge() -> void:
	(GameState.quests[String(&"archers_challenge")] as Dictionary)["count"] = 0
	for d in dummies:
		d.health.revive()
	challenge_left = CHALLENGE_TIME
	hud.show_banner("Fell six targets!", Color(1.0, 0.8, 0.4), 1.5)


func _on_target_down() -> void:
	if challenge_left < 0.0:
		return
	for d in dummies:
		d.respawn_delay = 60.0  # stays down for the rest of the round
	if Quests.progress(&"archers_challenge", 1, false) >= 6:
		challenge_left = -1.0
		Quests.complete(&"archers_challenge")
		hud.show_banner("Six before the sand ran out!  +100 Punya", Color(1.0, 0.85, 0.5), 2.5)
		_reset_targets()
		say_lines([["Sumantra", "Six! The sand still running! I have lost my wager gladly."]])


func _challenge_failed() -> void:
	challenge_left = -1.0
	_reset_targets()
	refresh_tracker()
	hud.show_banner("The sand ran out. Talk to Sumantra to try again.", Color(0.95, 0.75, 0.55), 3.0)


func _reset_targets() -> void:
	for d in dummies:
		d.respawn_delay = 2.0
		d.health.revive()
