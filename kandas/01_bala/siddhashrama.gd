extends StoryLevel
## Bala Kanda, mission 5: Six Nights at Siddhashrama. Rama and Lakshmana guard
## Vishvamitra's yagna. Three waves of rakshasas come down the forest lanes
## (raiders run for the sacred fire); on the last night Maricha and Subahu
## attack from the sky. Subahu falls to the Agneyastra; Maricha is spared and
## carried over the sea by the Manavastra. At dawn the yagna is complete.

const D := "res://data/dialogue/part01/"
const MANAVASTRA_SLOT := 3
const DAWN_ENV := "res://assets/env/real/realistic_environment.tres"
const DAWN_SKY := "res://assets/materials/env/sky.tres"
const SAGE := "res://characters/npc/vasishtha.tscn"

## Tests turn this off to drive the mission by hand.
@export var auto_start := true

@onready var env: Node3D = $Environment
@onready var fire: SacredFire = $SacredFire
@onready var spawner: WaveSpawner = $Defence
@onready var lakshmana: Lakshmana = $Lakshmana
@onready var subahu: SkyRakshasa = $Subahu
@onready var maricha: SkyRakshasa = $Maricha
@onready var sun: DirectionalLight3D = $Sun
@onready var world_env: WorldEnvironment = $WorldEnvironment

var sages: Array[Node3D] = []
var sage_hits := 0
var fire_lowest := 1.0
var raiders_stopped := 0
var bosses_started := false
var subahu_down := false
var maricha_gone := false
var yagna_complete := false
var _retrying := false


func _ready() -> void:
	hud.get_node("Root/HintLabel").visible = false
	Settings.apply_to_sun(sun)
	shots = {
		&"altar": [Vector3(5.5, 2.6, 7.5), Vector3(0, 1.6, 0)],
		&"brothers": [Vector3(-2.5, 1.9, 19.0), Vector3(0, 1.4, 14.5)],
		&"rama": [Vector3(1.4, 1.7, 17.4), Vector3(0, 1.5, 14.0)],
		&"sky": [Vector3(0, 2.0, 18.0), Vector3(0, 11.0, -20.0)],
		&"dawn_wide": [Vector3(12.0, 9.0, 22.0), Vector3(0, 1.0, 0)],
	}
	for i in 8:
		var hut := env.get_node_or_null("Hut%d" % i) as Node3D
		if hut:
			hut.add_to_group(&"huts")
	_seat_sages()
	lakshmana.command = Lakshmana.Command.ATTACK
	lakshmana.guard_point = fire
	rama.spawn_point = rama.global_position
	rama.respawned.connect(_on_rama_respawned)
	fire.defiled.connect(_on_fire_defiled)
	fire.health.changed.connect(func(c: float, m: float) -> void: fire_lowest = minf(fire_lowest, c / m))
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	spawner.wave_started.connect(_on_wave_started)
	spawner.wave_cleared.connect(func(_i: int) -> void: Music.set_intensity(0.3))
	spawner.all_cleared.connect(_on_waves_cleared)
	for boss: SkyRakshasa in [subahu, maricha]:
		boss.sea_direction = (env.get_node("SeaDirection") as Node3D).global_position
	subahu.shielded.connect(_on_subahu_shielded)
	subahu.defeated.connect(_on_subahu_defeated)
	maricha.yielded.connect(_on_maricha_yielded)
	maricha.banished.connect(_on_maricha_banished)
	Music.play("ashram")
	if auto_start:
		_begin.call_deferred()


func _seat_sages() -> void:
	var palettes := [Color(0.95, 0.85, 0.65), Color(0.9, 0.62, 0.25), Color(0.85, 0.8, 0.7)]
	for i in 6:
		var m := env.get_node_or_null("Sage%d" % i) as Node3D
		if m == null:
			continue
		var sage := spawn_npc(SAGE, m.global_position, fire.global_position)
		sage.add_to_group(&"bystanders")
		if "garment" in sage:
			sage.set("garment", palettes[i % palettes.size()])
		if sage.has_signal("hurt"):
			sage.hurt.connect(func(_n: Node) -> void: sage_hits += 1)
		sages.append(sage)
	if story_enabled():
		_vishvamitra = spawn_npc("res://characters/npc/vishvamitra.tscn", Vector3(2.4, 0, 3.2), fire.global_position)


var _vishvamitra: Node3D


func _begin() -> void:
	if story_enabled() and GameState.current_mission <= 5:
		await cutscene(D + "ashram_arrival.tres")
		if not is_inside_tree():
			return
	start_defence()


## The waves begin; the sacred fire's bar appears.
func start_defence() -> void:
	hud.show_objective("Sacred Fire", fire.health)
	hud.show_banner("Guard the sacred fire!", Color(1, 0.75, 0.35), 2.5)
	spawner.start()


# --- The defence ------------------------------------------------------------------

func _on_enemy_spawned(r: Rakshasa) -> void:
	if r.carries_torch:
		r.died.connect(func(dead: Rakshasa) -> void:
			if dead.global_position.distance_to(fire.global_position) > 5.0:
				raiders_stopped += 1)
	elif not r.is_ranged():
		r.target_mode = Rakshasa.TargetMode.NEAREST  # they fight Lakshmana too


func _on_wave_started(index: int, _total: int) -> void:
	Music.set_intensity(1.0)
	if index == 0:
		_varuna_lesson()
	elif index == 1:
		await get_tree().create_timer(3.0).timeout
		if is_inside_tree():
			lakshmana.say("Too many! Let Vayu sweep them back!", 3.0)
			hud.show_banner("Vayavyastra: its wind hurls a crowd away.", Color(0.8, 1.0, 0.95), 3.0)


## The first raiders' torches set a hut alight: a lesson in Varunastra.
func _varuna_lesson() -> void:
	await get_tree().create_timer(5.0).timeout
	if not is_inside_tree():
		return
	var hut := env.get_node_or_null("Hut1") as Node3D
	if hut == null:
		return
	var patch := FirePatch.new()
	patch.hostile = true
	patch.radius = 3.0
	patch.dps = 2.0
	patch.duration = 30.0
	add_child(patch)
	patch.global_position = hut.global_position
	lakshmana.say("The huts are burning! Varuna's waters, brother!", 3.0)
	hud.show_banner("Varunastra: tap Varuna, then loose a drawn arrow at the flames.", Color(0.55, 0.8, 1.0), 3.5)


func _on_fire_defiled() -> void:
	if _retrying or yagna_complete:
		return
	_retrying = true
	hud.show_banner("The sacred fire is defiled...\nThe sages rekindle it. Try again.", Color(1.0, 0.45, 0.35), 3.0)
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree():
		return
	fire.rekindle()
	for node in get_children():
		if node is FirePatch:
			node.queue_free()
	if bosses_started:
		for boss: SkyRakshasa in [subahu, maricha]:
			if boss.state != SkyRakshasa.S.DEAD and boss.state != SkyRakshasa.S.BANISHED:
				boss.health.invulnerable = false
				boss.health.revive()
				boss._enter(SkyRakshasa.S.CIRCLE)
	else:
		spawner.restart_wave()
	_retrying = false


func _on_rama_respawned() -> void:
	if not bosses_started:
		spawner.restart_wave()


func _on_waves_cleared() -> void:
	Music.set_intensity(0.0)
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree():
		start_sky_battle()


# --- Maricha and Subahu --------------------------------------------------------------

func start_sky_battle() -> void:
	if bosses_started:
		return
	bosses_started = true
	Music.play("sky_bosses")
	Music.stinger("sting_reveal")
	var entry := (env.get_node("SkyEntry") as Node3D).global_position
	if story_enabled():
		await cutscene(D + "last_night.tres")
		if not is_inside_tree():
			return
	var cam := get_node_or_null("FollowCamera")
	if cam and cam.has_method("frame_sky"):
		cam.frame_sky(true)
	subahu.awaken(fire.global_position, entry + Vector3(-4, 0, 0))
	maricha.awaken(fire.global_position, entry + Vector3(4, 0, 0))
	hud.show_boss("Subahu", subahu.health)
	hud.add_boss_bar("Maricha", maricha.health)


func _on_subahu_shielded(_b: SkyRakshasa) -> void:
	hud.show_banner("Subahu hides in smoke! Only the Agneyastra can end him.", Color(1.0, 0.55, 0.25), 3.5)
	hud.show_subtitle("Vishvamitra", "His maya shields him! Only Agni's fire can end Subahu!", 3.5)


func _on_subahu_defeated(_b: SkyRakshasa) -> void:
	subahu_down = true
	hud.show_banner("Subahu falls.", Color(1.0, 0.7, 0.4), 2.5)
	lakshmana.say("Subahu is down, brother!", 2.0)
	_check_victory()


func _on_maricha_yielded(_b: SkyRakshasa) -> void:
	rama.grant_temporary_astra(MANAVASTRA_SLOT)
	hud.show_banner("Manavastra: carry him away. Do not kill.", Color(0.6, 0.8, 1.0), 3.5)
	hud.show_subtitle("Vishvamitra", "Maricha falters. The Manavastra carries without killing, Rama.", 4.0)


func _on_maricha_banished(_b: SkyRakshasa) -> void:
	maricha_gone = true
	GameState.add_dharma(20)
	rama.revoke_temporary_astras()
	Music.stinger("sting_blessing")
	hud.show_banner("Maricha is cast far over the sea.  +20 Dharma", Color(0.6, 0.85, 1.0), 3.0)
	await say_lines([
		["Rama", "This one I will not kill. Let the sea teach him what mercy is."],
		["Lakshmana", "He will remember this, brother."],
		["Rama", "Then let him remember that he was spared."],
	])
	_check_victory()


func _check_victory() -> void:
	if subahu_down and maricha_gone and not yagna_complete:
		yagna_complete = true
		hud.clear_boss_bars()
		var cam := get_node_or_null("FollowCamera")
		if cam and cam.has_method("frame_sky"):
			cam.frame_sky(false)
		await get_tree().create_timer(2.5).timeout
		if is_inside_tree():
			finish_yagna()


# --- Dawn ------------------------------------------------------------------------

## The yagna completes: dawn, the Dharma bonus, then on toward Mithila.
func finish_yagna() -> void:
	yagna_complete = true
	Music.play("bloom")
	if fire_lowest >= 0.75 and sage_hits == 0:
		GameState.add_dharma(15)
		hud.show_banner("The yagna is unbroken.  +15 Dharma", Color(1.0, 0.85, 0.5), 3.0)
	if raiders_stopped > 0:
		GameState.add_dharma(mini(raiders_stopped, 6) * 5)
	GameState.set_flag("yagna_protected", true)
	SaveSystem.save_game()
	hud.show_objective("", null)
	if story_enabled():
		await cutscene(D + "dawn.tres")
		if is_inside_tree():
			go_to_mission(6)
	else:
		dawn()


func _on_story_action(action_name: StringName) -> void:
	if action_name == &"dawn":
		dawn()


## Night gives way to dawn (both looks).
func dawn() -> void:
	var switcher := get_node_or_null("StyleSwitcher")
	if switcher:
		switcher.set("realistic_environment", DAWN_ENV)
		switcher.set("realistic_sun_pitch_deg", -12.0)
		switcher.set("realistic_sun_energy", 2.4)
		switcher.set("realistic_sun_color", Color(1.0, 0.78, 0.55))
	if Settings.is_realistic() and switcher:
		switcher.apply(Settings.visual_style)
	else:
		var e := world_env.environment
		if e and e.sky:
			e.sky.sky_material = load(DAWN_SKY)
		var t := create_tween().set_parallel(true)
		t.tween_property(sun, "light_energy", 1.4, 3.0)
		t.tween_property(sun, "light_color", Color(1.0, 0.8, 0.55), 3.0)
		if e:
			t.tween_property(e, "ambient_light_color", Color(0.75, 0.62, 0.5), 3.0)
			t.tween_property(e, "fog_light_color", Color(0.75, 0.6, 0.48), 3.0)
