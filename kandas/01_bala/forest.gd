extends StoryLevel
## Bala Kanda, missions 3-4: Tataka's forest. The silent path (two ambushes,
## the Dharma moment of sparing a fleeing rakshasa) leads to the ruined grove
## where Tataka waits. After her defeat the forest blooms and Vishvamitra
## grants the astras for real.

const D := "res://data/dialogue/part01/"
const ASTRAS: Array[StringName] = [&"agneyastra", &"varunastra", &"vayavyastra"]

@onready var env: Node3D = $Environment
@onready var encounter1: WaveSpawner = $Encounter1
@onready var encounter2: WaveSpawner = $Encounter2
@onready var tataka: Tataka = $Tataka
@onready var lakshmana: Lakshmana = $Lakshmana
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun

var boss_started := false
var boss_defeated := false
var _sage: Node3D
var _fleeing_one: Rakshasa


func _ready() -> void:
	hud.get_node("Root/HintLabel").visible = false
	Settings.apply_to_sun(sun)
	var grove := (env.get_node("GroveCenter") as Node3D).global_position
	shots = {
		&"sage": [Vector3(2.5, 1.9, -3.0), Vector3(0.5, 1.6, -7.0)],
		&"brothers": [Vector3(-2.0, 1.8, 2.5), Vector3(0.0, 1.4, -2.0)],
		&"grove_wide": [grove + Vector3(6.0, 7.0, 24.0), grove + Vector3(0, 3.0, -6.0)],
		&"tataka": [grove + Vector3(2.0, 3.5, 4.0), grove + Vector3(0, 4.5, -8.0)],
	}
	for t in [[$Trigger1, encounter1], [$Trigger2, encounter2]]:
		(t[0] as Area3D).body_entered.connect(_on_encounter_trigger.bind(t[1]))
	encounter1.all_cleared.connect(func() -> void: lakshmana.say("The forest grows quiet again. Too quiet."))
	encounter2.enemy_spawned.connect(_on_encounter2_spawned)
	for e: WaveSpawner in [encounter1, encounter2]:
		e.wave_started.connect(func(_i: int, _n: int) -> void: Music.set_intensity(1.0))
		e.all_cleared.connect(func() -> void: Music.set_intensity(0.0))
	if GameState.current_mission < 4:
		Music.play("forest")
	$BossTrigger.body_entered.connect(_on_boss_trigger)
	tataka.defeated.connect(_on_tataka_defeated)
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is Boulder:
			(n as Boulder).shot_down.connect(func(_b: Boulder) -> void:
				if stats:
					stats.facts["boulder_shot"] = true))
	tataka.phase_changed.connect(func(_p: int) -> void: Music.set_layer("maya", true))
	tataka.phase_changed.connect(func(_p: int) -> void:
		hud.show_banner("Tataka weaves her maya!\nWatch for the dust.", Color(0.85, 0.55, 0.95), 2.5))
	tataka.staggered.connect(func() -> void: lakshmana.say("She's down, brother! Now!", 2.0))
	if GameState.current_mission >= 4:
		_place_at_grove_entry()
	else:
		set_objective("Follow the path north into the silent forest", $Trigger1)
	encounter1.all_cleared.connect(func() -> void:
		set_objective("Press on toward the heart of the forest", $Trigger2))
	encounter2.all_cleared.connect(func() -> void:
		set_objective("Reach the ruined grove", $BossTrigger))
	encounter1.wave_started.connect(func(_i: int, _n: int) -> void: set_objective("Rakshasas! Defend yourselves"))
	encounter2.wave_started.connect(func(_i: int, _n: int) -> void: set_objective("Rakshasas! Spare any who flee"))
	tataka.phase_changed.connect(func(_p: int) -> void:
		set_objective("Tataka hides in her maya: watch the dust, strike when she appears", tataka, false))
	if story_enabled():
		_intro.call_deferred()


func _intro() -> void:
	if GameState.current_mission >= 4:
		_start_boss()
		return
	_sage = spawn_npc("res://characters/npc/vishvamitra.tscn", Vector3(0.5, 0, -7.0), Vector3(0, 0, 0))
	await cutscene(D + "forest_intro.tres")
	if is_instance_valid(_sage):
		_sage.queue_free()


func _place_at_grove_entry() -> void:
	var entry := (env.get_node("GroveEntry") as Node3D).global_position
	rama.global_position = entry + Vector3(0, 0, 6.0)
	rama.spawn_point = rama.global_position
	lakshmana.global_position = rama.global_position + Vector3(-1.5, 0, 2.0)


func _on_encounter_trigger(body: Node3D, spawner: WaveSpawner) -> void:
	if body is Rama and spawner.current_wave < 0:
		spawner.spawn_wave(0)
		rama.spawn_point = rama.global_position
		lakshmana.say("Rakshasas, brother! Real ones, this time.", 2.5)


## The first rakshasa of the second ambush will flee when badly hurt.
func _on_encounter2_spawned(r: Rakshasa) -> void:
	if _fleeing_one != null:
		return
	_fleeing_one = r
	r.flee_below = 0.35
	r.spared.connect(func(_r: Rakshasa) -> void:
		if stats:
			stats.facts["spared"] = true
		GameState.add_dharma(10)
		hud.show_subtitle("Rama", "Go. Do not return.", 2.5)
		get_tree().create_timer(2.8).timeout.connect(func() -> void:
			if is_instance_valid(lakshmana):
				lakshmana.say("Mercy is also dharma, brother.")))
	r.died.connect(func(dead: Rakshasa) -> void:
		if dead.is_fleeing():
			lakshmana.say("He had already turned to flee..."))


func _on_boss_trigger(body: Node3D) -> void:
	if body is Rama and not boss_started:
		_start_boss()


func _start_boss() -> void:
	if boss_started:
		return
	boss_started = true
	if GameState.current_mission == 3 and story_enabled():
		await complete_mission(3)
		if not is_inside_tree():
			return
	Music.play("tataka")
	Music.stinger("sting_reveal")
	PartFlow.advance_to(4)
	rama.spawn_point = rama.global_position
	var gate := env.get_node("GroveGate") as StaticBody3D
	gate.collision_layer = 1
	if story_enabled():
		_sage = spawn_npc("res://characters/npc/vishvamitra.tscn",
			(env.get_node("GroveEntry") as Node3D).global_position + Vector3(2.5, 0, 3.0), tataka.global_position)
		shots[&"rama"] = [rama.global_position + Vector3(1.2, 1.7, 2.2), rama.global_position + Vector3(0, 1.5, -1.0)]
		shots[&"sage"] = [_sage.global_position + Vector3(-1.5, 1.8, 2.0), _sage.global_position + Vector3(0, 1.6, 0)]
		await cutscene(D + "tataka_intro.tres")
		if not is_inside_tree():
			return
		# The sage steps back out of the grove to watch.
		if is_instance_valid(_sage):
			_sage.walk_to((env.get_node("GroveEntry") as Node3D).global_position + Vector3(4.0, 0, 9.0), 3.0)
	tataka.awaken()
	set_objective("Defeat Tataka: dodge her charge, roll through the shockwave, shoot down the boulders", tataka, false)
	hud.show_boss("Tataka", tataka.health)


func _on_tataka_defeated() -> void:
	set_objective("")
	boss_defeated = true
	Music.stop()  # a moment of silence before the forest blooms
	hud.show_boss("", null)
	await get_tree().create_timer(2.5).timeout
	if not is_inside_tree():
		return
	if story_enabled():
		var center := (env.get_node("GroveCenter") as Node3D).global_position
		shots[&"rama"] = [rama.global_position + Vector3(1.2, 1.7, 2.2), rama.global_position + Vector3(0, 1.5, -1.0)]
		shots[&"astras"] = [rama.global_position + Vector3(0, 2.4, 5.0), rama.global_position + Vector3(0, 1.8, 0)]
		shots[&"grove_wide"] = [center + Vector3(6.0, 7.0, 13.0), center + Vector3(0, 0, -3.0)]
		await cutscene(D + "tataka_bloom.tres")
		if is_inside_tree():
			await complete_mission(4)
		if is_inside_tree():
			go_to_mission(5)
	else:
		_on_story_action(&"bloom")
		_on_story_action(&"grant_astras")


func _on_story_action(action_name: StringName) -> void:
	match action_name:
		&"bloom":
			Music.play("bloom")
			bloom()
		&"astra_ceremony":
			Music.stinger("sting_blessing")
			_astra_ceremony()
		&"grant_astras":
			grant_astras()


## Vishvamitra's gift: the three astras become Rama's for good.
func grant_astras() -> void:
	for id in ASTRAS:
		GameState.unlock_astra(id)
	GameState.set_flag("tataka_defeated")
	GameState.complete_part(&"part_01")
	SaveSystem.save_game()


## The curse lifts: mist thins, light warms, flowers and grass return.
func bloom() -> void:
	var t := create_tween().set_parallel(true)
	var e := world_env.environment
	if e:
		t.tween_property(e, "fog_density", e.fog_density * 0.3, 4.0)
	t.tween_property(sun, "light_energy", sun.light_energy * 1.6, 4.0)
	t.tween_property(sun, "light_color", Color(1.0, 0.86, 0.62), 4.0)
	for node in get_tree().get_nodes_in_group(&"bloom"):
		var mmi := node as MultiMeshInstance3D
		if mmi == null or not mmi.has_meta(&"bloom_targets"):
			continue
		var targets: Array = mmi.get_meta(&"bloom_targets")
		mmi.visible = true
		t.tween_method(func(k: float) -> void:
			for i in targets.size():
				var target_xf: Transform3D = targets[i]
				var delay := float(i % 10) / 10.0 * 0.5
				var s := clampf((k - delay) / (1.0 - delay), 0.0, 1.0)
				mmi.multimesh.set_instance_transform(i, target_xf.scaled_local(Vector3.ONE * maxf(s, 0.001))), 0.0, 1.0, 3.5)
	_green_the_grove(t)
	for mist in env.get_children():
		if mist is CPUParticles3D and String(mist.name).begins_with("Mist"):
			(mist as CPUParticles3D).emitting = false


## The bare earth of the grove turns green (works for both looks).
func _green_the_grove(t: Tween) -> void:
	var earth := env.get_node_or_null("GroveEarth") as MeshInstance3D
	if earth == null or not (earth.material_override is ShaderMaterial):
		return
	var m := earth.material_override.duplicate() as ShaderMaterial
	earth.material_override = m
	var greens := {
		&"tint": Color(0.55, 0.8, 0.42),
		&"color_a": Color(0.28, 0.42, 0.18),
		&"color_b": Color(0.36, 0.5, 0.22),
	}
	for param: StringName in greens:
		var from = m.get_shader_parameter(param)
		if from is Color:
			t.tween_method(func(c: Color) -> void: m.set_shader_parameter(param, c),
				from, greens[param], 4.0)


## Three radiant lights (fire, water, wind) circle Rama and bow to him.
func _astra_ceremony() -> void:
	var colors := [Color(1.0, 0.45, 0.1), Color(0.3, 0.65, 1.0), Color(0.8, 0.98, 0.9)]
	for i in 3:
		var orb := OmniLight3D.new()
		orb.light_color = colors[i]
		orb.light_energy = 3.0
		orb.omni_range = 4.0
		add_child(orb)
		var a := TAU * i / 3.0
		orb.global_position = rama.global_position + Vector3(cos(a) * 2.2, 2.2, sin(a) * 2.2)
		var glow := FX.burst(self, orb.global_position, colors[i], 40, 1.5, 0.35, 1.2, 0.5)
		var t := create_tween()
		t.tween_property(orb, "global_position", rama.global_position + Vector3(0, 1.4, 0), 2.5).set_delay(1.5 + i * 0.4)
		t.tween_callback(func() -> void:
			FX.sparks(self, rama.global_position + Vector3.UP * 1.4, colors[i], 30, 3.0)
			orb.queue_free())
