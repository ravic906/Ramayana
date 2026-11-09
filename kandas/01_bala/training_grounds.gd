extends Node3D
## Bala Kanda prologue: the royal training grounds of Ayodhya at golden hour.
## The rakshasas here are Guru Vasishtha's maya (illusion) trials.

@onready var rama: Rama = $Rama
@onready var spawner: WaveSpawner = $WaveSpawner
@onready var sun: DirectionalLight3D = $Sun


func _ready() -> void:
	# Vishvamitra has taught Rama the Agneyastra (story beat comes later).
	GameState.unlock_astra(&"agneyastra")
	rama.respawned.connect(spawner.restart_wave)
	spawner.all_cleared.connect(_on_trials_complete)
	Settings.apply_to_sun(sun)


## Part 1's playable slice ends with Vasishtha's final trial.
func _on_trials_complete() -> void:
	GameState.complete_part(&"part_01")
	SaveSystem.save_game()
