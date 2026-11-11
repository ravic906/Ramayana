extends StoryLevel
## Bala Kanda, mission 6 (first half): Vishala at evening. King Sumati welcomes
## Vishvamitra and the princes (Valmiki, Bala Kanda 47); the city's lamps are
## lit and its people about; two small kindnesses to do; at night, in the guest
## house, the sage tells of the churning of the ocean and of Diti's penance on
## this ground; in the morning, the north gate and the road to Gautama's ashram.

const D := "res://data/dialogue/part01/"
const SAGE := "res://characters/npc/vishvamitra.tscn"
const MAN := "res://characters/npc/npc_model.tscn"
const WOMAN := "res://characters/npc/npc_woman.tscn"
const ASHRAM := "res://kandas/01_bala/gautama_ashram.tscn"
const LEAVES := {"churning_ocean": "Leaf1", "vishala_founding": "Leaf2", "king_sumati": "Leaf3", "gangas_descent": "Leaf4"}
const FLOWERS := 3

@onready var env: Node3D = $Environment
@onready var sun: DirectionalLight3D = $Sun
@onready var lakshmana: Lakshmana = $Lakshmana

var sage: NpcModel
var king: NpcModel
var weaver: NpcModel
var oil_seller: NpcModel
var priest: NpcModel
var folk: Array[NpcModel] = []
var guest_house: Interactable
var north_gate: Interactable
var night_done := false
var oil_carried := false
var _markers := {}
var _temple_light: OmniLight3D


func m(marker: String) -> Vector3:
	return (env.get_node(marker) as Node3D).global_position


func _ready() -> void:
	Settings.apply_to_sun(sun)
	hud.get_node("Root/HintLabel").visible = false
	lakshmana.command = Lakshmana.Command.FOLLOW
	_begin_stats()
	if GameState.current_part == 1 and GameState.current_mission <= 6:
		GameState.checkpoint = "vishala"
		SaveSystem.save_game()
	shots = {
		&"court": [m("Welcome") + Vector3(6.0, 3.5, 10.0), m("KingSpot") + Vector3(0, 2.0, 0)],
	}
	rama.global_position = m("Start")
	rama.visual.rotation.y = 0.0
	lakshmana.global_position = m("Start") + Vector3(-1.5, 0, 2.0)
	sage = spawn_npc(SAGE, m("Start") + Vector3(1.4, 0, -3.0), m("Welcome")) as NpcModel
	king = _person(MAN, m("KingSpot"), m("Welcome"), {"garment": Color(0.75, 0.2, 0.25), "trim": Color(0.9, 0.7, 0.25),
		"sash": Color(0.95, 0.85, 0.5), "crown": true, "beard": true, "long_hair": true, "hair_color": Color(0.35, 0.3, 0.28)}, "Sumati")
	weaver = _person(WOMAN, m("Weaver"), Vector3(0, 0, m("Weaver").z), {"garment": Color(0.2, 0.42, 0.55), "sash": Color(0.85, 0.6, 0.3)}, "Weaver")
	oil_seller = _person(MAN, m("OilSeller"), Vector3(0, 0, m("OilSeller").z), {"garment": Color(0.6, 0.5, 0.35), "beard": true}, "Oil-seller")
	priest = _person(MAN, m("Priest"), m("Priest") + Vector3(-3, 0, 0), {"garment": Color(0.95, 0.92, 0.85), "sash": Color(0.95, 0.6, 0.2),
		"topknot": true, "beard": true}, "Priest")
	(weaver.get_node("Talk") as Interactable).interacted.connect(_talk_weaver)
	(oil_seller.get_node("Talk") as Interactable).interacted.connect(_talk_oil_seller)
	(priest.get_node("Talk") as Interactable).interacted.connect(_talk_priest)
	(king.get_node("Talk") as Interactable).interacted.connect(func() -> void:
		say_lines([["Sumati", "The city is yours tonight, princes. Ask, and it is given."]]))
	_build_folk()
	_build_flowers()
	_build_leaves()
	_build_temple_lamp()
	guest_house = _interactable("GuestHouse", "Rest for the night", m("GuestHouse"))
	guest_house.enabled = false
	guest_house.interacted.connect(night_scene)
	north_gate = _interactable("NorthGate", "On to Gautama's ashram", m("NorthGate"))
	north_gate.enabled = false
	north_gate.interacted.connect(func() -> void:
		GameState.checkpoint = "ashram"
		SaveSystem.save_game()
		go_to_scene(ASHRAM))
	Music.play("vishala")
	set_objective("Walk up the street to King Sumati's palace", env.get_node("Welcome"))
	Quests.changed.connect(_refresh_markers)
	_refresh_markers()
	if story_enabled():
		_arrive.call_deferred()
	else:
		_after_welcome()


func _arrive() -> void:
	sage.walk_to(m("SageSpot"), 12.0)
	# The welcome plays when Rama reaches the forecourt.
	while is_inside_tree() and rama.global_position.distance_to(m("Welcome")) > 7.0:
		await get_tree().process_frame
	if not is_inside_tree():
		return
	sage.global_position = m("SageSpot")
	sage.face(m("KingSpot"))
	await cutscene(D + "vishala_welcome.tres")
	if is_inside_tree():
		_after_welcome()


func _after_welcome() -> void:
	sage.global_position = m("SageSpot")
	guest_house.enabled = true
	set_objective("Explore Vishala, then rest at the guest house", guest_house, false)


## The night: the sage's story, then morning and the road north.
func night_scene() -> void:
	if night_done or not guest_house.enabled:
		return
	guest_house.enabled = false
	night_done = true
	set_objective("")
	_tween_sun(-2.0, 0.15, Color(0.55, 0.6, 0.9))
	sage.global_position = m("GuestHouse") + Vector3(2.5, 0, 1.0)
	sage.face(m("GuestHouse"))
	sage.play(&"sit_talk")
	rama.global_position = m("GuestHouse") + Vector3(1.0, 0, -1.2)
	lakshmana.global_position = m("GuestHouse") + Vector3(0.8, 0, 1.8)
	if story_enabled():
		await cutscene(D + "churning.tres")
	if not is_inside_tree():
		return
	GameState.find_lore(&"churning_ocean")
	sage.play(&"idle")
	_tween_sun(-35.0, 1.0, Color(1.0, 0.92, 0.8))
	hud.show_banner("Morning in Vishala", Color(1.0, 0.9, 0.65), 2.5)
	north_gate.enabled = true
	set_objective("Leave by the north gate, on to Gautama's ashram", north_gate)


func _tween_sun(pitch_deg: float, energy_mult: float, color: Color) -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(sun, "rotation:x", deg_to_rad(pitch_deg), 1.5)
	t.tween_property(sun, "light_energy", sun.light_energy * energy_mult, 1.5)
	t.tween_property(sun, "light_color", color, 1.5)


# --- People -----------------------------------------------------------------------------

func _person(scene: String, pos: Vector3, look: Vector3, props: Dictionary, speaker: String) -> NpcModel:
	var n := (load(scene) as PackedScene).instantiate() as NpcModel
	for k in props:
		n.set(k, props[k])
	n.speaker = speaker
	n.position = pos
	add_child(n)
	n.face(look)
	actors[speaker] = n
	var it := Interactable.new()
	it.name = "Talk"
	it.prompt = "Talk"
	n.add_child(it)
	return n


## Townsfolk at their evening errands: women and men in the city's colours.
func _build_folk() -> void:
	var looks := [
		[WOMAN, {"garment": Color(0.75, 0.2, 0.35), "sash": Color(0.95, 0.75, 0.3)}],
		[MAN, {"garment": Color(0.9, 0.85, 0.7), "sash": Color(0.7, 0.4, 0.2)}],
		[WOMAN, {"garment": Color(0.95, 0.65, 0.15), "sash": Color(0.6, 0.15, 0.2)}],
		[MAN, {"garment": Color(0.35, 0.45, 0.6), "beard": true}],
		[WOMAN, {"garment": Color(0.3, 0.55, 0.35), "sash": Color(0.9, 0.8, 0.5)}],
		[MAN, {"garment": Color(0.65, 0.3, 0.2), "hair_color": Color(0.8, 0.8, 0.78), "beard": true, "staff": true}],
	]
	for i in looks.size():
		var p := m("Folk%d" % (i + 1))
		var n := (load(looks[i][0]) as PackedScene).instantiate() as NpcModel
		for k in looks[i][1]:
			n.set(k, looks[i][1][k])
		n.position = p
		add_child(n)
		n.face(p + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
		folk.append(n)


func _talk_weaver() -> void:
	if Quests.is_done(&"weavers_thread"):
		await say_lines([["Weaver", "The bride will wear your kindness in every thread, my prince."]])
	elif Quests.is_active(&"weavers_thread") and Quests.goal_reached(&"weavers_thread"):
		Quests.complete(&"weavers_thread")
		hud.show_banner("The Weaver's Thread.  +40 Punya", Color(1.0, 0.85, 0.5), 2.5)
		await say_lines([["Weaver", "Kusumbha, and so fresh! The red will be deep as the evening. Bless you."]])
	elif Quests.is_active(&"weavers_thread"):
		await say_lines([["Weaver", "The kusumbha grows in the temple garden, to the east. Three handfuls is all I need."]])
	else:
		Quests.start(&"weavers_thread")
		await say_lines([
			["Weaver", "Forgive an old weaver, my prince. A bride's sari waits on my loom, and I have run short of red."],
			["Weaver", "The kusumbha flowers grow in the temple garden. My legs will not take me there before dark."],
			["Rama", "Then ours will, mother. Keep the loom warm."],
		])


func _talk_oil_seller() -> void:
	if oil_carried or Quests.is_done(&"temple_lamp"):
		await say_lines([["Oil-seller", "Good oil, pressed this morning. May it burn long."]])
	elif Quests.is_active(&"temple_lamp"):
		oil_carried = true
		Quests.progress(&"temple_lamp", 1, false)
		hud.show_banner("Lamp oil  (bring it to the priest)", Color(1.0, 0.9, 0.6), 2.0)
		await say_lines([["Oil-seller", "The temple's share? Here, my prince. I set it aside every day."]])
	else:
		await say_lines([["Oil-seller", "Sesame oil, ghee, lamp wicks! The best in Vishala."]])
	_refresh_markers()


func _talk_priest() -> void:
	if Quests.is_done(&"temple_lamp"):
		await say_lines([["Priest", "The lamp burns. The deity sees, and so do I. Go well, princes of Raghu."]])
	elif oil_carried:
		oil_carried = false
		Quests.complete(&"temple_lamp")
		_light_temple_lamp()
		hud.show_banner("The Temple Lamp.  +30 Punya  +4 Dharma", Color(1.0, 0.85, 0.5), 2.5)
		await say_lines([["Priest", "Light comes back to the shrine, carried by a prince. That is how it should be."]])
	elif Quests.is_active(&"temple_lamp"):
		await say_lines([["Priest", "The oil-seller in the market keeps the temple's share."]])
	else:
		Quests.start(&"temple_lamp")
		await say_lines([
			["Priest", "Welcome, young princes. Forgive the dark: the evening lamp has burned dry."],
			["Priest", "The oil-seller in the market keeps the temple's share, but I may not leave the shrine."],
			["Lakshmana", "We will bring it, sir."],
		])
	_refresh_markers()


# --- Things --------------------------------------------------------------------------------

func _interactable(n: String, prompt: String, at: Vector3) -> Interactable:
	var it := Interactable.new()
	it.name = n
	it.prompt = prompt
	it.radius = 3.0
	it.glint = true
	add_child(it)
	it.global_position = at
	return it


func _build_flowers() -> void:
	if Quests.is_done(&"weavers_thread"):
		return
	var c := m("Garden")
	for i in FLOWERS:
		var a := TAU * i / FLOWERS
		var it := _interactable("Flower%d" % i, "Gather", c + Vector3(cos(a) * 3.5, 0.4, sin(a) * 2.8))
		var bloom := MeshInstance3D.new()
		bloom.mesh = MeshKit.sphere(0.12, 8)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.35, 0.1)
		bloom.material_override = mat
		bloom.position.y = 0.3
		it.add_child(bloom)
		it.interacted.connect(func() -> void:
			if not Quests.is_active(&"weavers_thread"):
				hud.show_banner("Kusumbha: a flower that dyes cloth red.", Color(0.9, 0.85, 0.75), 2.0)
				return
			it.queue_free()
			var n := Quests.progress(&"weavers_thread", 1, false)
			hud.show_banner("Kusumbha  %d / %d" % [n, FLOWERS], Color(1.0, 0.9, 0.6), 1.5)
			_refresh_markers())
		_mark("flower%d" % i, it, &"weavers_thread", NavMarker.Kind.PICKUP, "Kusumbha")


func _build_leaves() -> void:
	for id: String in LEAVES:
		if StringName(id) in GameState.lore:
			continue
		var it := _interactable("Leaf_" + id, "Pick up", m(LEAVES[id]))
		it.radius = 2.2
		var leaf := MeshInstance3D.new()
		leaf.mesh = MeshKit.box(Vector3(0.6, 0.03, 0.12))
		leaf.material_override = load("res://assets/materials/env/straw.tres")
		leaf.position.y = 0.05
		it.add_child(leaf)
		it.interacted.connect(func() -> void:
			GameState.find_lore(StringName(id))
			it.queue_free()
			var lore := Quests.get_lore(StringName(id))
			hud.show_banner("Palm leaf: %s\n(read it in the Journal)" % (lore.title if lore else ""), Color(1.0, 0.9, 0.6), 2.5))
		_mark("leaf_" + id, it, &"", NavMarker.Kind.PICKUP, "A palm leaf")


func _build_temple_lamp() -> void:
	_temple_light = OmniLight3D.new()
	_temple_light.light_color = Color(1.0, 0.7, 0.35)
	_temple_light.light_energy = 0.0
	_temple_light.omni_range = 7.0
	add_child(_temple_light)
	_temple_light.global_position = m("TempleLamp") + Vector3.UP * 1.0
	if Quests.is_done(&"temple_lamp"):
		_temple_light.light_energy = 1.8


func _light_temple_lamp() -> void:
	create_tween().tween_property(_temple_light, "light_energy", 1.8, 2.0)
	FX.sparks(self, m("TempleLamp") + Vector3.UP, Color(1.0, 0.8, 0.4), 24, 1.5)


func _mark(key: String, at: Node3D, quest: StringName, kind := NavMarker.Kind.SIDE, text := "") -> NavMarker:
	var nm := NavMarker.new()
	nm.name = "Marker_" + key
	nm.kind = kind
	nm.quest_id = quest
	nm.label = text
	at.add_child(nm)
	_markers[key] = nm
	return nm


func _refresh_markers() -> void:
	if not _markers.has("weaver"):
		_mark("weaver", weaver, &"weavers_thread", NavMarker.Kind.SIDE, "A weaver")
		_mark("priest", priest, &"temple_lamp", NavMarker.Kind.SIDE, "The temple priest")
		_mark("oil", oil_seller, &"temple_lamp", NavMarker.Kind.SIDE, "The oil-seller")
	(_markers["weaver"] as NavMarker).active = not Quests.is_done(&"weavers_thread") and \
		(not Quests.is_active(&"weavers_thread") or Quests.goal_reached(&"weavers_thread"))
	(_markers["priest"] as NavMarker).active = not Quests.is_done(&"temple_lamp") and (not Quests.is_active(&"temple_lamp") or oil_carried)
	(_markers["oil"] as NavMarker).active = Quests.is_active(&"temple_lamp") and not oil_carried
