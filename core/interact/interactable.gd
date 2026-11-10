class_name Interactable
extends Node3D
## Something Rama can talk to or pick up: the HUD shows its prompt on the
## Interact button when he is near (action "interact").

signal interacted

@export var prompt := "Talk"
@export var radius := 2.6
@export var enabled := true
## A soft golden glint so pickups can be found.
@export var glint := false


func _ready() -> void:
	add_to_group(&"interactables")
	if glint:
		var p := CPUParticles3D.new()
		p.name = "Glint"
		p.amount = 10
		p.lifetime = 1.4
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.35
		p.direction = Vector3.UP
		p.gravity = Vector3(0, 0.4, 0)
		p.initial_velocity_min = 0.1
		p.initial_velocity_max = 0.3
		p.mesh = FX.glow_quad(Color(1.0, 0.85, 0.4, 0.8), 0.12)
		p.position = Vector3.UP * 0.5
		add_child(p)


func interact() -> void:
	if enabled:
		interacted.emit()
