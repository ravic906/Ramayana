extends Node3D
## Bala Kanda training arena: Vishvamitra's test of Rama's archery.

@onready var rama: Rama = $Rama
@onready var spawner: WaveSpawner = $WaveSpawner


func _ready() -> void:
	# Vishvamitra has taught Rama the Agneyastra (story beat comes later).
	GameState.unlock_astra(&"agneyastra")
	rama.respawned.connect(spawner.restart_wave)
