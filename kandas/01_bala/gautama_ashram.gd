extends StoryLevel
## Bala Kanda, mission 6 (second half): Gautama's ashram near Mithila, at dawn
## (Valmiki, Bala Kanda 48-49). No combat. The hermitage is overgrown and
## grey; as Rama pauses at its three places (the fire altar, the well, the
## tulasi), each wakes and light and colour come back. Then the light gathers
## at the heart, where Ahalya has kept her long, unseen penance: at Rama's
## coming she becomes visible, the brothers touch her feet, she receives them
## as guests, flowers fall, and Gautama returns.
##
## Reverence first (docs/STORY.md): nothing of her past is retold in the
## scene; the codex holds a short, neutral note.

const D := "res://data/dialogue/part01/"
const SAGE := "res://characters/npc/vishvamitra.tscn"
const MAN := "res://characters/npc/npc_model.tscn"
const WOMAN := "res://characters/npc/npc_woman.tscn"
const PLACES := {
	"altar": ["Altar", "The fire altar", ["Lakshmana", "The ash is old, brother, but the stones are warm."]],
	"well": ["Well", "The well", ["Vishvamitra", "Someone drew water here every morning for a very long time."]],
	"tulasi": ["Tulasi", "The tulasi", ["Rama", "The tulasi is alive. Someone has tended it, unseen."]],
}
const LEAVES := {"ahalya": "Leaf1", "gautama": "Leaf2", "mithila_road": "Leaf3"}

@onready var env: Node3D = $Environment
@onready var sun: DirectionalLight3D = $Sun
@onready var lakshmana: Lakshmana = $Lakshmana
@onready var world_env: WorldEnvironment = $WorldEnvironment

var sage: NpcModel
var ahalya: NpcModel
var gautama: NpcModel
var woken := {}
var _pausing := false
var _heart_open := false
var _scene_played := false
var _sun_energy := -1.0
var _places: Dictionary = {}
var _glow: OmniLight3D


func m(marker: String) -> Vector3:
	return (env.get_node(marker) as Node3D).global_position


func _ready() -> void:
	Settings.apply_to_sun(sun)
	hud.get_node("Root/HintLabel").visible = false
	lakshmana.command = Lakshmana.Command.FOLLOW
	_begin_stats()
	if GameState.current_part == 1 and GameState.current_mission <= 6:
		GameState.checkpoint = "ashram"
		SaveSystem.save_game()
	var heart := m("Heart")
	shots = {&"heart": [heart + Vector3(4.5, 2.6, 8.0), heart + Vector3(0, 1.1, -1.0)]}
	rama.global_position = m("Start")
	rama.visual.rotation.y = 0.0
	lakshmana.global_position = m("Start") + Vector3(-1.5, 0, 2.0)
	sage = spawn_npc(SAGE, m("Start") + Vector3(1.6, 0, -2.0), heart) as NpcModel
	# Grey before the dawn: low sun, cool light; it warms as the places wake.
	sun.rotation.x = deg_to_rad(-6.0)
	sun.light_color = Color(0.7, 0.72, 0.85)
	for key: String in PLACES:
		var spec: Array = PLACES[key]
		var it := Interactable.new()
		it.name = "Place_" + key
		it.prompt = "Pause here"
		it.radius = 3.0
		it.glint = true
		add_child(it)
		it.global_position = m(spec[0])
		it.interacted.connect(wake.bind(key))
		_places[key] = it
		var nm := NavMarker.new()
		nm.kind = NavMarker.Kind.MAIN
		nm.label = spec[1]
		it.add_child(nm)
	_build_leaves()
	Music.play("ashram_dawn")
	set_objective("Walk through the silent ashram: pause at its three places (0 / 3)")
	if story_enabled():
		_intro.call_deferred()


func _intro() -> void:
	await say_lines([
		["Vishvamitra", "This was the ashram of the sage Gautama. No one has kept it for many years."],
		["Rama", "And yet it does not feel empty, Guru-dev."],
		["Vishvamitra", "Walk through it, Rama. Gently."],
	])


func _process(delta: float) -> void:
	super._process(delta)
	if _sun_energy < 0.0:
		_sun_energy = sun.light_energy
	if _heart_open and not _scene_played and rama.global_position.distance_to(m("Heart")) < 4.0:
		_scene_played = true
		ahalya_scene()


## Rama pauses at a place of the ashram; it wakes, and light comes back.
func wake(key: String) -> void:
	if woken.has(key) or _pausing:
		return
	_pausing = true
	var it: Interactable = _places[key]
	it.enabled = false
	rama.controls_locked = true
	rama.model.play_pose(&"kneel")
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree():
		return
	rama.model.clear_pose()
	rama.controls_locked = false
	_pausing = false
	woken[key] = true
	it.queue_free()
	_bloom(key)
	FX.sparks(self, m(PLACES[key][0]) + Vector3.UP * 0.8, Color(1.0, 0.85, 0.5), 30, 1.5)
	var n := woken.size()
	_light_step(n)
	say_lines([PLACES[key][2]])
	if n < PLACES.size():
		set_objective("Walk through the silent ashram: pause at its three places (%d / 3)" % n)
	else:
		_open_heart()


## The overgrowth around a place draws back.
func _bloom(key: String) -> void:
	for node in get_tree().get_nodes_in_group(&"overgrowth"):
		if node.get_meta(&"place", "") == key:
			var t := create_tween()
			t.tween_property(node, "scale", Vector3(1, 0.02, 1), 2.5).set_trans(Tween.TRANS_SINE)
			t.tween_callback(func() -> void: (node as Node3D).visible = false)
	for node in get_tree().get_nodes_in_group(&"bloom"):
		if node.get_meta(&"place", "") == key:
			(node as Node3D).visible = true
			create_tween().tween_property(node, "scale", Vector3.ONE, 3.0).set_delay(1.2).set_trans(Tween.TRANS_SINE)


## Each place woken warms the dawn a little more.
func _light_step(n: int) -> void:
	var k := float(n) / PLACES.size()
	var t := create_tween().set_parallel(true)
	t.tween_property(sun, "rotation:x", deg_to_rad(lerpf(-6.0, -22.0, k)), 3.0)
	t.tween_property(sun, "light_color", Color(0.7, 0.72, 0.85).lerp(Color(1.0, 0.82, 0.62), k), 3.0)
	t.tween_property(sun, "light_energy", _sun_energy * lerpf(1.0, 1.4, k), 3.0)
	var e := world_env.environment
	if e and e.fog_enabled:
		t.tween_property(e, "fog_density", e.fog_density * 0.6, 3.0)


func _open_heart() -> void:
	_heart_open = true
	_bloom("heart")
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.85, 0.6)
	_glow.light_energy = 0.0
	_glow.omni_range = 9.0
	add_child(_glow)
	_glow.global_position = m("AhalyaSpot") + Vector3.UP * 1.4
	create_tween().tween_property(_glow, "light_energy", 1.6, 3.0)
	set_objective("The light gathers at the heart of the ashram", env.get_node("Heart"))


func ahalya_scene() -> void:
	set_objective("")
	stage_ahalya()
	if story_enabled():
		await cutscene(D + "ahalya.tres")
	else:
		for a in [&"reveal", &"pranam", &"flowers", &"gautama"]:
			_on_story_action(a)
	if not is_inside_tree():
		return
	stats.facts["leaves_m6"] = LEAVES.keys().all(func(id: String) -> bool: return StringName(id) in GameState.lore)
	stats.facts["vishala_kind"] = Quests.is_done(&"weavers_thread") and Quests.is_done(&"temple_lamp")
	GameState.checkpoint = ""
	await complete_mission(6)
	if is_inside_tree():
		go_to_mission(7)


## Places everyone for the scene at the heart; Ahalya is there, unseen.
func stage_ahalya() -> void:
	ahalya = (load(WOMAN) as PackedScene).instantiate() as NpcModel
	ahalya.garment = Color(0.96, 0.94, 0.88)
	# An ascetic's plain ivory, an ochre border; the pallu ivory too, so
	# nothing reads as bare skin in the close-ups.
	ahalya.trim = Color(0.78, 0.52, 0.2)
	ahalya.sash = Color(0.9, 0.87, 0.78)
	ahalya.speaker = "Ahalya"
	ahalya.ornaments = true  # simple gold at the ears; nothing more
	ahalya.position = m("AhalyaSpot")
	add_child(ahalya)
	ahalya.face(m("Heart") + Vector3(0, 0, 4))
	ahalya.visible = false  # unseen, until Rama comes
	actors["Ahalya"] = ahalya
	rama.global_position = m("RamaSpot")
	_face(rama, m("AhalyaSpot"))
	lakshmana.global_position = m("LakshmanaSpot")
	_face(lakshmana, m("AhalyaSpot"))
	sage.global_position = m("SageSpot")
	sage.face(m("AhalyaSpot"))


func _face(who: Node3D, point: Vector3) -> void:
	var d := point - who.global_position
	(who.get("visual") as Node3D).rotation.y = atan2(-d.x, -d.z)


func _on_story_action(action_name: StringName) -> void:
	match action_name:
		&"reveal":
			# Like a flame from behind smoke: she is there, radiant.
			ahalya.visible = true
			ahalya.scale = Vector3.ONE * 0.98
			FX.burst(self, m("AhalyaSpot") + Vector3.UP * 1.0, Color(1.0, 0.9, 0.7), 60, 1.2, 0.5, 1.6, 0.6)
			if _glow:
				create_tween().tween_property(_glow, "light_energy", 2.6, 1.5)
			Music.stinger("sting_blessing")
		&"pranam":
			for who in [rama, lakshmana]:
				who.set_physics_process(false)
				(who.get("model") as RamaModel).play_pose(&"kneel")
		&"flowers":
			for who in [rama, lakshmana]:
				(who.get("model") as RamaModel).clear_pose()
				who.set_physics_process(true)
			_flower_rain()
		&"gautama":
			gautama = (load(MAN) as PackedScene).instantiate() as NpcModel
			gautama.garment = Color(0.93, 0.85, 0.6)
			gautama.sash = Color(0.85, 0.5, 0.2)
			gautama.hair_color = Color(0.85, 0.85, 0.82)
			gautama.beard = true
			gautama.long_hair = true
			gautama.topknot = true
			gautama.staff = true
			gautama.speaker = "Gautama"
			gautama.position = m("GautamaSpot") + Vector3(5, 0, -6)
			add_child(gautama)
			actors["Gautama"] = gautama
			gautama.walk_to(m("GautamaSpot"), 2.5)
			get_tree().create_timer(2.6).timeout.connect(func() -> void:
				if is_instance_valid(gautama) and is_instance_valid(ahalya):
					gautama.face(ahalya.global_position))


func _flower_rain() -> void:
	var p := CPUParticles3D.new()
	p.name = "FlowerRain"
	p.amount = 90
	p.lifetime = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(6, 0.5, 6)
	p.gravity = Vector3(0, -0.6, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	var petal := QuadMesh.new()
	petal.size = Vector2(0.06, 0.04)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.75, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	petal.material = mat
	p.mesh = petal
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.3))
	ramp.set_color(1, Color(0.95, 0.4, 0.45))
	p.color_initial_ramp = ramp
	add_child(p)
	p.global_position = m("Heart") + Vector3(0, 6, 0)
	get_tree().create_timer(9.0).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false)


func _build_leaves() -> void:
	for id: String in LEAVES:
		if StringName(id) in GameState.lore:
			continue
		var it := Interactable.new()
		it.name = "Leaf_" + id
		it.prompt = "Pick up"
		it.glint = true
		it.radius = 2.2
		add_child(it)
		it.global_position = m(LEAVES[id])
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
		var nm := NavMarker.new()
		nm.kind = NavMarker.Kind.PICKUP
		nm.label = "A palm leaf"
		it.add_child(nm)
