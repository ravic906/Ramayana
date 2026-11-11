extends StoryLevel
## Bala Kanda, mission 2 (second half): the road along the Sarayu.
##
## The brothers leave Ayodhya behind Vishvamitra and walk the river's bank; he
## talks as they go (his past as King Kaushika, the river's source). A herd
## stampedes, panicked by distant rakshasas: Lakshmana's Guard command and
## arrows landed close turn the charging bulls from the sage, and no animal is
## harmed. At a sandbank camp at dusk he teaches them Bala and Atibala; at dawn
## he wakes them ("Kausalya's son, Rama, the dawn has come") and they go on
## toward the Ganga and the Silent Forest (mission 3).
##
## Side content: the widow's lamps, the boatman's oar, three palm leaves.

const D := "res://data/dialogue/part01/"
const NPC := "res://characters/npc/npc_model.tscn"
const SAGE := "res://characters/npc/vishvamitra.tscn"
## Leaf id -> [marker, offset].
const LEAVES := {
	"kaushika": ["Shrine", Vector3(0.0, 0, -3.0)],
	"confluence": ["Oar", Vector3(-6.0, 0, 7.0)],
	"kama_ashrama": ["Talk6", Vector3(-8.0, 0, 3.0)],
}
## Lines the party speaks on the road, at talk points 1..6 (point 4 starts the stampede).
const WALK_LINES := {
	1: [["Vishvamitra", "Your father's grief will pass, Rama. A word kept outlives every sorrow."],
		["Rama", "I know, Guru-dev. I only hope he does not watch the road too long."]],
	2: [["Lakshmana", "Guru-dev, they say you were a king once."],
		["Vishvamitra", "Kaushika, of the line of Kusha. I had armies, and I lost a contest to a man who had only his tapas."],
		["Vishvamitra", "So I set down the crown and became what you see. It took me longer than you have been alive."]],
	3: [["Vishvamitra", "The Sarayu is born of a lake Brahma made with his mind, high on Kailasa. That is why its water runs clear, even here."],
		["Lakshmana", "Then it has walked further than we have."]],
	4: [["Rama", "Guru-dev, the birds have gone quiet."],
		["Vishvamitra", "Something stirs in the south. Stay close to me."]],
	5: [["Vishvamitra", "The rakshasas drive even the deer from their grazing. You will see why, soon enough."]],
	6: [["Lakshmana", "The sun is low, brother. Will we sleep under the sky tonight?"],
		["Rama", "Under the sky, beside a river, with a guru keeping watch. Kings sleep worse."]],
}
const LAMP_COUNT := 5
## Late afternoon at the city gate to sunset at the camp (sun pitch, degrees).
const SUN_PITCH_START := -24.0
const SUN_PITCH_CAMP := -7.0

@onready var env: Node3D = $Environment
@onready var sun: DirectionalLight3D = $Sun
@onready var lakshmana: Lakshmana = $Lakshmana
@onready var world_env: WorldEnvironment = $WorldEnvironment

var sage: NpcModel
var widow: NpcModel
var boatman: NpcModel
var herd: Array[Animal] = []
var bulls: Array[Animal] = []
var stampede_started := false
var stampede_done := false
var at_camp := false
var camp_seat: Interactable
var oar_carried := false
var _talk_done := {}
var _leg := 0
var _leg_busy := false
var _markers := {}
var _sun_energy := -1.0
var _sun_color := Color.WHITE
var _fire: Node3D
var _fireflies: CPUParticles3D
var _lamps_afloat: Array[Node3D] = []
var _light_override := false


func m(marker: String) -> Vector3:
	return (env.get_node(marker) as Node3D).global_position


func _ready() -> void:
	Settings.apply_to_sun(sun)
	hud.get_node("Root/HintLabel").visible = false
	lakshmana.command = Lakshmana.Command.FOLLOW
	_begin_stats()
	stats.facts["sage_unharmed"] = true
	if GameState.current_part == 1 and GameState.current_mission <= 2:
		GameState.checkpoint = "sarayu"
		SaveSystem.save_game()
	var camp := m("CampCenter")
	shots = {
		&"city": [m("Start") + Vector3(3.0, 2.2, -10.0), m("Start") + Vector3(0, 7.0, 70.0)],
		&"camp_wide": [camp + Vector3(1.0, 2.6, 8.5), camp + Vector3(0, 0.6, 0)],
		&"water": [m("CampWater") + Vector3(-3.5, 1.6, 4.0), m("CampWater") + Vector3(0, 0.6, 0)],
		&"dawn_wide": [m("CampWater") + Vector3(-6.5, 2.0, 5.5), m("CampWater") + Vector3(1.5, 0.7, -1.0)],
	}
	_build_people()
	_build_lamps()
	_build_oar()
	_build_leaves()
	_build_herd()
	_build_camp()
	rama.global_position = m("Start")
	rama.visual.rotation.y = 0.0
	lakshmana.global_position = m("Start") + Vector3(-1.4, 0, 2.0)
	sage = spawn_npc(SAGE, m("Start") + Vector3(1.2, 0, -5.0), m("Talk1")) as NpcModel
	Music.play("sarayu")
	set_objective("Walk with Vishvamitra along the Sarayu", sage)
	Quests.changed.connect(_refresh_markers)
	_refresh_markers()
	if story_enabled():
		_intro.call_deferred()
	else:
		_next_leg.call_deferred()


func _intro() -> void:
	await cutscene(D + "road_departure.tres")
	if is_inside_tree():
		_next_leg()


# --- The walk ---------------------------------------------------------------------

## The sage walks to the next talk point, then waits for Rama to catch up.
func _next_leg() -> void:
	if _leg_busy or not is_instance_valid(sage):
		return
	_leg += 1
	if _leg > WALK_LINES.size():
		_walk_to_camp()
		return
	var target := m("Talk%d" % _leg) + Vector3(1.0, 0, 0)
	_leg_busy = true
	var t := sage.walk_to(target, maxf(sage.global_position.distance_to(target) / 1.4, 0.5))
	await t.finished
	_leg_busy = false
	if is_instance_valid(sage):
		sage.face(rama.global_position)


func _walk_to_camp() -> void:
	set_objective("Follow the sage to the sandbank at the river's bend", sage)
	var seat := m("SageSeat")
	_leg_busy = true
	var t := sage.walk_to(seat, sage.global_position.distance_to(seat) / 1.4)
	await t.finished
	_leg_busy = false
	if not is_instance_valid(sage):
		return
	at_camp = true
	sage.face(m("CampCenter"))
	sage.play(&"sit_talk")
	_fire.visible = true
	camp_seat.enabled = true
	set_objective("Rest by the fire at the camp", camp_seat)


func _process(delta: float) -> void:
	super._process(delta)
	_update_light()
	if not is_instance_valid(sage) or _leg_busy or _leg < 1 or _leg > WALK_LINES.size():
		return
	# Rama caught up with the waiting sage: talk, then walk on.
	if rama.global_position.distance_to(sage.global_position) < 9.0 and not _talk_done.has(_leg):
		_talk_done[_leg] = true
		_talk_at(_leg)


func _talk_at(i: int) -> void:
	await say_lines(WALK_LINES[i])
	if not is_inside_tree():
		return
	if i == 4 and not stampede_done:
		start_stampede()
		return
	_next_leg()


## Late afternoon drifts to sunset as Rama walks north.
func _update_light() -> void:
	if _light_override:
		return
	if _sun_energy < 0.0:
		_sun_energy = sun.light_energy
		_sun_color = sun.light_color
	var t := clampf(-rama.global_position.z / absf(m("CampCenter").z), 0.0, 1.0)
	sun.rotation.x = deg_to_rad(lerpf(SUN_PITCH_START, SUN_PITCH_CAMP, t))
	sun.light_energy = _sun_energy * lerpf(1.0, 0.7, t)
	sun.light_color = _sun_color.lerp(Color(1.0, 0.62, 0.38), t * 0.8)


# --- The stampede (Lakshmana's Guard tutorial) -----------------------------------------

func _build_herd() -> void:
	var c := m("HerdSpot")
	var kinds := ["deer", "deer", "deer", "deer", "stag", "deer", "stag", "deer"]
	for i in kinds.size():
		var a := Animal.spawn(self, kinds[i], c + Vector3(randf_range(-7, 7), 0, randf_range(-7, 7)))
		a.rotation.y = randf() * TAU
		herd.append(a)


func start_stampede() -> void:
	if stampede_started:
		return
	stampede_started = true
	Music.set_intensity(1.0)
	say_lines([["Lakshmana", "Horns, far to the south. The herd is panicking!"]])
	lakshmana.guard_point = sage
	lakshmana.command = Lakshmana.Command.ATTACK
	hud.highlight_command(8.0)
	hud.show_banner("Tap Lakshmana's button to set him to Guard: he will shield the sage.\nLand an arrow close to a charging bull to turn it. No animal is harmed.",
		Color(1.0, 0.9, 0.6), 6.0)
	set_objective("Protect the sage from the stampede", sage, false)
	var route := PackedVector3Array([m("StampedeCross"), m("StampedeTo")])
	for a in herd:
		a.stampede(PackedVector3Array([a.global_position.lerp(m("StampedeCross"), 0.5)]) + route)
	for i in 2:
		await get_tree().create_timer(2.5 if i == 0 else 5.0).timeout
		if not is_inside_tree():
			return
		var bull := Animal.spawn(self, "bull", m("StampedeFrom") + Vector3(0, 0, -6.0 * i))
		bulls.append(bull)
		bull.struck.connect(_on_sage_struck)
		bull.turned.connect(_on_bull_turned)
		bull.charge(sage)
	# Over when no bull is charging any more.
	while is_inside_tree() and bulls.any(func(b: Animal) -> bool: return is_instance_valid(b) and b.is_charging()):
		await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
	await get_tree().create_timer(2.0).timeout
	_end_stampede()


func _on_bull_turned(by: Node) -> void:
	if by == lakshmana:
		lakshmana.say("Not past me!", 1.5)
	else:
		hud.show_banner("The bull swerves away.", Color(0.9, 0.85, 0.7), 1.5)


func _on_sage_struck(_target: Node3D) -> void:
	stats.facts["sage_unharmed"] = false
	lakshmana.say("Guru-dev!", 1.5)


func _end_stampede() -> void:
	stampede_done = true
	Music.set_intensity(0.0)
	lakshmana.command = Lakshmana.Command.FOLLOW
	lakshmana.guard_point = null
	var unharmed: bool = stats.facts.get("sage_unharmed", true)
	if unharmed:
		GameState.add_dharma(5)
		hud.show_banner("The sage is unharmed, and no creature was hurt.  +5 Dharma", Color(1.0, 0.85, 0.5), 3.0)
	await say_lines([["Vishvamitra", "You turned them without spilling a drop of blood. That is the beginning of a protector."]
		if unharmed else ["Vishvamitra", "I am unhurt, princes. A bruise is a small teacher. Come."]])
	if is_inside_tree():
		set_objective("Walk with Vishvamitra along the Sarayu", sage)
		_next_leg()


# --- The camp: Bala and Atibala, then dawn ------------------------------------------------

func _build_camp() -> void:
	_fire = Node3D.new()
	_fire.name = "CampFire"
	add_child(_fire)
	_fire.global_position = m("CampCenter")
	var flames := CPUParticles3D.new()
	flames.amount = 22
	flames.lifetime = 0.8
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.2
	flames.direction = Vector3.UP
	flames.spread = 12.0
	flames.gravity = Vector3(0, 2.0, 0)
	flames.initial_velocity_min = 0.4
	flames.initial_velocity_max = 0.9
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	flames.scale_amount_curve = curve
	flames.mesh = FX.glow_quad(Color(1.0, 0.55, 0.15, 0.32), 0.45)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.45, 1.0))
	ramp.add_point(0.35, Color(1.0, 0.45, 0.08, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.45, 0.06, 0.02, 0.0))
	flames.color_ramp = ramp
	flames.position.y = 0.2
	_fire.add_child(flames)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.3)
	light.light_energy = 1.6
	light.omni_range = 9.0
	light.position.y = 0.9
	_fire.add_child(light)
	_fire.visible = false
	_fireflies = CPUParticles3D.new()
	_fireflies.name = "Fireflies"
	_fireflies.amount = 40
	_fireflies.lifetime = 6.0
	_fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fireflies.emission_box_extents = Vector3(10, 1.2, 10)
	_fireflies.gravity = Vector3.ZERO
	_fireflies.spread = 180.0
	_fireflies.initial_velocity_min = 0.1
	_fireflies.initial_velocity_max = 0.35
	_fireflies.mesh = FX.glow_quad(Color(0.95, 1.0, 0.55, 0.9), 0.06)
	add_child(_fireflies)
	_fireflies.global_position = m("CampCenter") + Vector3(-2, 1.0, 0)
	_fireflies.emitting = false
	camp_seat = Interactable.new()
	camp_seat.name = "CampSeat"
	camp_seat.prompt = "Sit by the fire"
	camp_seat.radius = 3.0
	camp_seat.glint = true
	camp_seat.enabled = false
	add_child(camp_seat)
	camp_seat.global_position = m("RamaSeat")
	camp_seat.interacted.connect(camp_scene)


## Seats Rama (and Lakshmana) by the fire: physics off so the seat stone
## doesn't push them, facing the fire, in a story pose.
func _seat(who: Node3D, seat: Vector3, pose: StringName) -> void:
	var model: RamaModel = who.get("model")
	who.set_physics_process(false)
	who.global_position = seat
	var d := m("CampCenter") - seat
	(who.get("visual") as Node3D).rotation.y = atan2(-d.x, -d.z)
	model.play_pose(pose)


func _unseat(who: Node3D) -> void:
	(who.get("model") as RamaModel).clear_pose()
	who.set_physics_process(true)


func camp_scene() -> void:
	if not at_camp or not camp_seat.enabled:
		return
	camp_seat.enabled = false
	set_objective("")
	_float_lamps()
	_seat(rama, m("RamaSeat"), &"sit")
	_seat(lakshmana, m("LakshmanaSeat"), &"sit")
	_light_override = true
	_tween_light(-4.0, 0.55, Color(1.0, 0.55, 0.32), 3.0)
	if Settings.quality != Settings.Quality.BATTERY:
		_fireflies.emitting = true
	Music.play("sarayu_dusk")
	await cutscene(D + "bala_atibala.tres")
	if not is_inside_tree():
		return
	await _fade(true)
	_on_story_action(&"dawn")
	await _fade(false)
	await cutscene(D + "sarayu_dawn.tres")
	if not is_inside_tree():
		return
	stats.facts["leaves_sarayu"] = LEAVES.keys().all(func(id: String) -> bool: return StringName(id) in GameState.lore)
	GameState.checkpoint = ""
	await complete_mission(2)
	if is_inside_tree():
		go_to_mission(3)


func _on_story_action(action_name: StringName) -> void:
	match action_name:
		&"rama_sip":
			_unseat(rama)
			rama.set_physics_process(false)
			rama.global_position = m("CampWater")
			var d := Vector3(1, 0, 0)
			rama.visual.rotation.y = atan2(-d.x, -d.z)
			rama.model.play_pose(&"kneel")
		&"grant_bala":
			grant_bala_atibala()
			_seat(rama, m("RamaSeat"), &"sit")
		&"nightfall":
			_tween_light(2.0, 0.08, Color(0.5, 0.55, 0.85), 3.0)
			_tween_sky(0.25, 3.0)
		&"dawn":
			_fire.visible = false
			_fireflies.emitting = false
			sun.rotation = Vector3(deg_to_rad(-6.0), deg_to_rad(-75.0), 0)  # the sun rises over the river, east
			sun.light_color = Color(1.0, 0.72, 0.62)
			sun.light_energy = _sun_energy * 0.6 if _sun_energy > 0.0 else 0.8
			_tween_sky(1.0, 0.1)
			sage.play(&"idle")
			_unseat(lakshmana)
			_unseat(rama)
			Music.play("bloom")
		&"rise":
			for who: Node3D in [rama, lakshmana]:
				_unseat(who)
				var d := sage.global_position - who.global_position
				(who.get("visual") as Node3D).rotation.y = atan2(-d.x, -d.z)
		&"morning_rites":
			for who: Node3D in [rama, lakshmana]:
				who.set_physics_process(false)
				var offset := Vector3(0, 0, 1.5) if who == lakshmana else Vector3.ZERO
				who.global_position = m("CampWater") + offset
				(who.get("visual") as Node3D).rotation.y = atan2(-1.0, 0.0)
				(who.get("model") as RamaModel).play_pose(&"kneel")


## Bala and Atibala: no weariness (see Rama.has_bala_atibala).
func grant_bala_atibala() -> void:
	GameState.set_flag("bala_atibala", true)
	GameState.find_lore(&"bala_atibala")
	Music.stinger("sting_blessing")
	FX.sparks(self, rama.global_position + Vector3.UP * 1.2, Color(1.0, 0.85, 0.4), 40, 2.5)
	hud.show_banner("Bala and Atibala\nNo weariness: your dodge recovers faster, your bow holds steady longer.",
		Color(1.0, 0.85, 0.45), 4.0)
	SaveSystem.save_game()


func _tween_light(pitch_deg: float, energy_mult: float, color: Color, seconds: float) -> void:
	if _sun_energy < 0.0:
		_sun_energy = sun.light_energy
	var t := create_tween().set_parallel(true)
	t.tween_property(sun, "rotation:x", deg_to_rad(pitch_deg), seconds)
	t.tween_property(sun, "light_energy", _sun_energy * energy_mult, seconds)
	t.tween_property(sun, "light_color", color, seconds)


## Dims the sky and ambient light with the night (1.0 = as authored).
var _sky_base := {}


func _tween_sky(mult: float, seconds: float) -> void:
	var e := world_env.environment
	if e == null:
		return
	if _sky_base.is_empty() or _sky_base.get("env") != e:
		_sky_base = {"env": e, "bg": e.background_energy_multiplier, "amb": e.ambient_light_energy}
	var t := create_tween().set_parallel(true)
	t.tween_property(e, "background_energy_multiplier", _sky_base["bg"] * mult, seconds)
	t.tween_property(e, "ambient_light_energy", _sky_base["amb"] * mult, seconds)


func _fade(out: bool) -> void:
	var layer := get_node_or_null("NightFade") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "NightFade"
		layer.layer = 35
		var r := ColorRect.new()
		r.name = "Rect"
		r.color = Color(0, 0, 0, 0)
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(r)
		add_child(layer)
	var rect := layer.get_node("Rect") as ColorRect
	var t := create_tween()
	t.tween_property(rect, "color:a", 1.0 if out else 0.0, 1.2)
	await t.finished


# --- People and their quests ---------------------------------------------------------------

func _person(pos: Vector3, face: Vector3, look: Dictionary, speaker: String) -> NpcModel:
	var n := (load(NPC) as PackedScene).instantiate() as NpcModel
	for k in look:
		n.set(k, look[k])
	n.speaker = speaker
	n.position = pos
	add_child(n)
	n.face(face)
	actors[speaker] = n
	var it := Interactable.new()
	it.name = "Talk"
	it.prompt = "Talk"
	n.add_child(it)
	return n


func _build_people() -> void:
	widow = _person(m("Widow"), m("GhatWater"), {"garment": Color(0.93, 0.92, 0.88), "trim": Color(0.85, 0.83, 0.78),
		"sash": Color(0.93, 0.92, 0.88), "hair_color": Color(0.55, 0.52, 0.5), "skin": Color(0.62, 0.45, 0.33)}, "Widow")
	(widow.get_node("Talk") as Interactable).interacted.connect(_talk_widow)
	boatman = _person(m("Boatman"), m("GhatWater"), {"garment": Color(0.55, 0.42, 0.28), "trim": Color(0.4, 0.3, 0.2),
		"sash": Color(0.75, 0.3, 0.2), "beard": true, "skin": Color(0.55, 0.38, 0.26)}, "Boatman")
	(boatman.get_node("Talk") as Interactable).interacted.connect(_talk_boatman)


func _talk_widow() -> void:
	if Quests.is_done(&"river_lamps"):
		await say_lines([["Widow", "May the river carry your kindness as far as it carries the lamps, my prince."]])
	elif Quests.is_active(&"river_lamps"):
		await say_lines([["Widow", "The lamps were left along the road by those who could not bear to light them. Take them to the water where you rest."]])
	else:
		Quests.start(&"river_lamps")
		await say_lines([
			["Widow", "My prince. My husband ferried this river for thirty years. The rakshasas overturned his boat at night."],
			["Widow", "There are lamps along the road, five of them. Set them on the water for him, and for all the river has taken."],
			["Rama", "We will set them afloat tonight, mother. He will not be forgotten."],
		])


func _talk_boatman() -> void:
	if Quests.is_done(&"boatmans_oar"):
		await say_lines([["Boatman", "My oar is home and my boat is whole. Call on me, my prince, whenever a river stands in your way."]])
	elif oar_carried:
		oar_carried = false
		Quests.progress(&"boatmans_oar", 1, false)
		Quests.complete(&"boatmans_oar")
		hud.show_banner("The Boatman's Oar.  +40 Punya", Color(1.0, 0.85, 0.5), 2.5)
		await say_lines([["Boatman", "My oar! The current took it as if it wanted it. Thank you, Prince Rama."]])
	elif Quests.is_active(&"boatmans_oar"):
		await say_lines([["Boatman", "On the sandbank upstream, past the reeds. Mind the soft sand."]])
	else:
		Quests.start(&"boatmans_oar")
		await say_lines([
			["Boatman", "Forgive me, my princes, no crossing today. The current stole my oar in the night."],
			["Boatman", "I saw it come to rest on a sandbank upstream, past the reeds. My knees will not carry me there."],
			["Lakshmana", "Ours will. Wait here, boatman."],
		])


func _build_lamps() -> void:
	if Quests.is_done(&"river_lamps"):
		return
	for i in LAMP_COUNT:
		var it := Interactable.new()
		it.name = "Lamp%d" % (i + 1)
		it.prompt = "Take the lamp"
		it.radius = 2.4
		it.glint = true
		add_child(it)
		it.global_position = m("Lamp%d" % (i + 1))
		it.add_child(_diya(false))
		it.interacted.connect(_take_lamp.bind(it))
		_mark("lamp%d" % i, it, &"river_lamps", NavMarker.Kind.PICKUP, "A clay lamp")


func _diya(lit: bool) -> Node3D:
	var root := Node3D.new()
	var bowl := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.08
	s.is_hemisphere = true
	bowl.mesh = s
	bowl.rotation.x = PI
	bowl.position.y = 0.05
	bowl.material_override = load("res://assets/materials/env/red_sandstone.tres")
	root.add_child(bowl)
	if lit:
		var flame := MeshInstance3D.new()
		flame.mesh = FX.glow_quad(Color(1.0, 0.7, 0.3, 0.9), 0.12)
		flame.position.y = 0.12
		root.add_child(flame)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.65, 0.3)
		l.light_energy = 0.6
		l.omni_range = 2.5
		l.position.y = 0.2
		root.add_child(l)
	return root


func _take_lamp(it: Interactable) -> void:
	if not Quests.is_active(&"river_lamps"):
		hud.show_banner("A clay lamp, left by someone in mourning. Perhaps someone at the ghat knows.", Color(0.9, 0.85, 0.75), 2.5)
		return
	it.queue_free()
	var n := Quests.progress(&"river_lamps", 1, false)
	hud.show_banner("Clay lamp  %d / %d" % [n, LAMP_COUNT], Color(1.0, 0.9, 0.6), 1.5)
	_refresh_markers()


## At the camp the gathered lamps go onto the water and drift downstream.
func _float_lamps() -> void:
	if not Quests.is_active(&"river_lamps") or not Quests.goal_reached(&"river_lamps"):
		return
	Quests.complete(&"river_lamps")
	hud.show_banner("Lamps for the River.  +60 Punya  +8 Dharma", Color(1.0, 0.85, 0.5), 3.0)
	var start := m("CampWater")
	for i in LAMP_COUNT:
		var lamp := _diya(true)
		add_child(lamp)
		lamp.global_position = start + Vector3(1.5 + i * 0.9, -0.33, randf_range(-1.5, 1.5))
		_lamps_afloat.append(lamp)
		var t := create_tween()
		t.tween_property(lamp, "global_position", lamp.global_position + Vector3(randf_range(1, 5), 0, 90.0), 160.0)


func _build_oar() -> void:
	if Quests.is_done(&"boatmans_oar"):
		return
	var it := Interactable.new()
	it.name = "Oar"
	it.prompt = "Take the oar"
	it.radius = 2.6
	it.glint = true
	add_child(it)
	it.global_position = m("Oar")
	var oar := MeshInstance3D.new()
	oar.mesh = MeshKit.box(Vector3(0.08, 0.04, 2.2))
	oar.rotation.y = 0.6
	oar.position.y = 0.04
	oar.material_override = load("res://assets/materials/env/wood.tres")
	it.add_child(oar)
	var blade := MeshInstance3D.new()
	blade.mesh = MeshKit.box(Vector3(0.28, 0.03, 0.5))
	blade.position = Vector3(0.65, 0.04, 0.95)
	blade.rotation.y = 0.6
	blade.material_override = oar.material_override
	it.add_child(blade)
	it.interacted.connect(func() -> void:
		if not Quests.is_active(&"boatmans_oar"):
			hud.show_banner("A boatman's oar, washed up on the sand.", Color(0.9, 0.85, 0.75), 2.0)
		oar_carried = true
		if not Quests.is_active(&"boatmans_oar"):
			Quests.start(&"boatmans_oar")
		it.queue_free()
		hud.show_banner("You carry the oar. The boatman waits at the ghat.", Color(1.0, 0.9, 0.6), 2.0)
		_refresh_markers())
	_mark("oar", it, &"boatmans_oar", NavMarker.Kind.PICKUP, "The oar")


func _build_leaves() -> void:
	for id: String in LEAVES:
		if StringName(id) in GameState.lore:
			continue
		var spec: Array = LEAVES[id]
		var it := Interactable.new()
		it.name = "Leaf_" + id
		it.prompt = "Pick up"
		it.glint = true
		it.radius = 2.2
		add_child(it)
		it.global_position = m(spec[0]) + spec[1]
		var leaf := MeshInstance3D.new()
		leaf.mesh = MeshKit.box(Vector3(0.6, 0.03, 0.12))
		leaf.material_override = load("res://assets/materials/env/straw.tres")
		leaf.position.y = 0.05
		leaf.rotation.y = randf() * TAU
		it.add_child(leaf)
		it.interacted.connect(func() -> void:
			GameState.find_lore(StringName(id))
			it.queue_free()
			var lore := Quests.get_lore(StringName(id))
			hud.show_banner("Palm leaf: %s\n(read it in the Journal)" % (lore.title if lore else ""), Color(1.0, 0.9, 0.6), 2.5))
		_mark("leaf_" + id, it, &"", NavMarker.Kind.PICKUP, "A palm leaf")


func _mark(key: String, at: Node3D, quest: StringName, kind := NavMarker.Kind.SIDE, text := "") -> NavMarker:
	var nm := NavMarker.new()
	nm.name = "Marker_" + key
	nm.kind = kind
	nm.quest_id = quest
	nm.label = text
	at.add_child(nm)
	_markers[key] = nm
	return nm


## The ghat's people are marked while they have something to say.
func _refresh_markers() -> void:
	if not _markers.has("widow"):
		_mark("widow", widow, &"river_lamps", NavMarker.Kind.SIDE, "A widow at the ghat")
		_mark("boatman", boatman, &"boatmans_oar", NavMarker.Kind.SIDE, "The boatman")
	(_markers["widow"] as NavMarker).active = not Quests.is_active(&"river_lamps") and not Quests.is_done(&"river_lamps")
	(_markers["boatman"] as NavMarker).active = (not Quests.is_active(&"boatmans_oar") and not Quests.is_done(&"boatmans_oar")) or oar_carried
