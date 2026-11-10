extends StoryLevel
## Bala Kanda, missions 1-2: the royal training grounds of Ayodhya at golden
## hour. Mission 1: Guru Vasishtha's maya (illusion) trials. Mission 2: the sage
## Vishvamitra arrives at the gate and asks for Rama.

const D := "res://data/dialogue/part01/"

@onready var spawner: WaveSpawner = $WaveSpawner
@onready var sun: DirectionalLight3D = $Sun

var _vasishtha: Node3D


func _ready() -> void:
	# Rama has not yet received any astra: Vishvamitra teaches them after
	# Tataka. Remove the permanent unlock that earlier prototype builds saved.
	if not GameState.get_flag("tataka_defeated"):
		GameState.unlocked_astras.erase(&"agneyastra")
	spawner.wave_started.connect(_on_wave_started)
	rama.respawned.connect(spawner.restart_wave)
	spawner.all_cleared.connect(_on_trials_complete)
	Music.play("ayodhya")
	spawner.wave_started.connect(func(_i: int, _n: int) -> void: Music.set_intensity(1.0))
	spawner.wave_cleared.connect(func(_i: int) -> void: Music.set_intensity(0.35))
	spawner.all_cleared.connect(func() -> void: Music.set_intensity(0.0))
	Settings.apply_to_sun(sun)
	shots = {
		&"vasishtha": [Vector3(-4.0, 1.9, -3.0), Vector3(-7.5, 1.6, -9.0)],
		&"brothers": [Vector3(3.5, 1.8, 3.5), Vector3(0.0, 1.3, -1.0)],
		&"rama": [Vector3(1.6, 1.7, -3.2), Vector3(0.0, 1.5, 0.0)],
		&"gate": [Vector3(0.0, 4.0, -20.0), Vector3(0.0, 4.0, -48.0)],
		&"king": [Vector3(-2.5, 1.8, -33.0), Vector3(-5.0, 1.7, -37.0)],
		&"sage": [Vector3(1.5, 1.8, -34.0), Vector3(0.0, 1.7, -39.0)],
	}
	if story_enabled():
		_start_story.call_deferred()


func _start_story() -> void:
	_vasishtha = spawn_npc("res://characters/npc/vasishtha.tscn", Vector3(-7.5, 0, -9.0), Vector3.ZERO)
	var lakshmana := LAKSHMANA.instantiate() as Lakshmana
	lakshmana.position = Vector3(-1.6, 0, 1.8)
	lakshmana.command = Lakshmana.Command.FOLLOW  # Vasishtha's trials are Rama's alone
	add_child(lakshmana)
	if GameState.current_mission >= 2:
		# Resuming at "The Sage at the Gate".
		spawner.hold()
		_play_sage_at_gate()
		return
	spawner.hold()  # the first wave waits for the intro
	await cutscene(D + "m1_intro.tres")
	if is_inside_tree():
		spawner.start()


## Vasishtha's final trial ends mission 1.
func _on_trials_complete() -> void:
	rama.revoke_temporary_astras()
	PartFlow.advance_to(2)
	await get_tree().create_timer(4.5).timeout
	if not is_inside_tree():
		return
	hud.show_banner("The vision fades. \"This is not yet yours.\"", Color(1, 0.75, 0.45), 3.5)
	if story_enabled():
		await get_tree().create_timer(4.0).timeout
		if is_inside_tree():
			await cutscene(D + "trials_complete.tres")
			_play_sage_at_gate()


func _play_sage_at_gate() -> void:
	if not is_inside_tree():
		return
	rama.global_position = Vector3(0, 0, -30)
	rama.visual.rotation.y = 0.0
	var king := spawn_npc("res://characters/npc/dasharatha.tscn", Vector3(-5.0, 0, -37.0), Vector3(0, 0, -34))
	if _vasishtha:
		_vasishtha.global_position = Vector3(-7.0, 0, -35.0)
		_vasishtha.face(Vector3(0, 0, -36))
	var sage := spawn_npc("res://characters/npc/vishvamitra.tscn", Vector3(0, 0, -47.0), Vector3(0, 0, -30))
	sage.walk_to(Vector3(0, 0, -39.0), 3.5)
	king.face(Vector3(0, 0, -39.0))
	await cutscene(D + "sage_at_gate.tres")
	if is_inside_tree():
		go_to_mission(3)


## In the final trial Vasishtha grants a glimpse of the Agneyastra.
func _on_wave_started(index: int, total: int) -> void:
	if index == total - 1:
		rama.grant_temporary_astra(0)
		await get_tree().create_timer(2.3).timeout
		if is_inside_tree():
			hud.show_banner("A vision of the Agneyastra...\nTap Agni, then loose a drawn arrow.", Color(1, 0.6, 0.25), 3.0)
