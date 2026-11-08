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
	Settings.apply_to_sun(sun)
