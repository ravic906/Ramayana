extends Node3D
## Bala Kanda prologue: the royal training grounds of Ayodhya at golden hour.
## The rakshasas here are Guru Vasishtha's maya (illusion) trials.

@onready var rama: Rama = $Rama
@onready var spawner: WaveSpawner = $WaveSpawner
@onready var sun: DirectionalLight3D = $Sun
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	# Rama has not yet received any astra: Vishvamitra teaches them after
	# Tataka. Remove the permanent unlock that earlier prototype builds saved.
	if not GameState.get_flag("tataka_defeated"):
		GameState.unlocked_astras.erase(&"agneyastra")
	spawner.wave_started.connect(_on_wave_started)
	rama.respawned.connect(spawner.restart_wave)
	spawner.all_cleared.connect(_on_trials_complete)
	Settings.apply_to_sun(sun)


## Part 1's playable slice ends with Vasishtha's final trial.
func _on_trials_complete() -> void:
	rama.revoke_temporary_astras()
	GameState.complete_part(&"part_01")
	SaveSystem.save_game()
	await get_tree().create_timer(4.5).timeout
	if is_inside_tree():
		hud.show_banner("The vision fades. \"This is not yet yours.\"", Color(1, 0.75, 0.45), 3.5)


## In the final trial Vasishtha grants a glimpse of the Agneyastra.
func _on_wave_started(index: int, total: int) -> void:
	if index == total - 1:
		rama.grant_temporary_astra(0)
		await get_tree().create_timer(2.3).timeout
		if is_inside_tree():
			hud.show_banner("A vision of the Agneyastra...\nTap Agni, then loose a drawn arrow.", Color(1, 0.6, 0.25), 3.0)
