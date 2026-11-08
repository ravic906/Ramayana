class_name FollowCamera
extends Node3D
## Third-person camera rig: this node follows the target and yaws; the
## SpringArm3D child pitches and avoids clipping. Swipe (or drag) anywhere not
## claimed by the on-screen controls to rotate.

@export var target_path: NodePath
@export var follow_speed := 10.0
@export var height_offset := 1.4
@export var swipe_sensitivity := 0.006
@export var min_pitch_deg := -55.0
@export var max_pitch_deg := -10.0
@export var initial_pitch_deg := -25.0

@onready var spring_arm: SpringArm3D = $SpringArm3D

var target: Node3D


func _ready() -> void:
	spring_arm.rotation.x = deg_to_rad(initial_pitch_deg)
	target = get_node_or_null(target_path) as Node3D
	if target != null:
		global_position = target.global_position + Vector3.UP * height_offset


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var goal := target.global_position + Vector3.UP * height_offset
	global_position = global_position.lerp(goal, clampf(follow_speed * delta, 0.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		rotate_by((event as InputEventScreenDrag).relative)


func rotate_by(relative: Vector2) -> void:
	rotation.y -= relative.x * swipe_sensitivity
	var pitch := spring_arm.rotation.x - relative.y * swipe_sensitivity
	spring_arm.rotation.x = clampf(pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
