class_name Lakshmana
extends CharacterBody3D
## Lakshmana as a (for now non-combat) companion: follows a step behind Rama's
## left shoulder, keeps pace, and speaks short lines through the HUD.
## Combat AI and Guard/Attack commands come in the next milestone.

const SKIN := Color(0.86, 0.68, 0.52)
const GARMENT := Color(0.8, 0.28, 0.12)
const TRIM := Color(0.8, 0.6, 0.2)
const SASH := Color(0.95, 0.8, 0.35)

@export var follow := true
@export var follow_offset := Vector3(-1.4, 0.0, 2.4)
@export var move_speed := 6.5

@onready var model: RamaModel = $Visual/RamaModel
@onready var visual: Node3D = $Visual

var target: Rama
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	add_to_group(&"companions")
	_apply_style()
	Settings.style_changed.connect(func(_s: int) -> void: _apply_style())


func _physics_process(delta: float) -> void:
	velocity.y = velocity.y - gravity * delta if not is_on_floor() else 0.0
	if not follow:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		model.set_locomotion(0.0)
		return
	if target == null or not is_instance_valid(target):
		var players := get_tree().get_nodes_in_group(&"player")
		target = players[0] as Rama if not players.is_empty() else null
		if target == null:
			return
	var goal := target.global_position + target.visual.global_basis * follow_offset
	var to := goal - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 25.0:
		global_position = goal  # caught behind: catch up off-screen
		return
	var speed := clampf(dist * 2.5, 0.0, move_speed) if dist > 0.5 else 0.0
	var dir := to / maxf(dist, 0.001)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()
	var face := dir if speed > 0.5 else target.get_facing()
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-face.x, -face.z), clampf(10.0 * delta, 0.0, 1.0))
	model.set_locomotion(speed / move_speed)


## Short in-game line (subtitle on the HUD).
func say(text: String, seconds := 3.5) -> void:
	get_tree().call_group(&"hud", &"show_subtitle", "Lakshmana", text, seconds)


func _apply_style() -> void:
	var path := "res://assets/materials/env_real/rama_body_pbr.tres" if Settings.is_realistic() else "res://assets/materials/rama_body.tres"
	var mat := (load(path) as ShaderMaterial).duplicate() as ShaderMaterial
	mat.set_shader_parameter(&"region_base", SKIN)
	mat.set_shader_parameter(&"region_r", GARMENT)
	mat.set_shader_parameter(&"region_g", TRIM)
	mat.set_shader_parameter(&"region_b", SASH)
	(model.skeleton.get_node("Body") as MeshInstance3D).material_override = mat
