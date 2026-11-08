class_name FollowCamera
extends Node3D
## Third-person camera rig: this node follows the target and yaws; the
## SpringArm3D child pitches and avoids clipping. Swipe (or drag) anywhere not
## claimed by the on-screen controls to rotate.
##
## Archery: set_aiming() blends to a tight over-the-shoulder view whose zoom
## follows the draw; follow_arrow() rides along with a hero shot; shake()
## adds trauma. Smoothing uses real time so slow motion never makes it lag.

signal arrow_cam_finished

@export var target_path: NodePath
@export var follow_speed := 10.0
@export var height_offset := 1.4
@export var swipe_sensitivity := 0.006
@export var min_pitch_deg := -55.0
@export var max_pitch_deg := -10.0
@export var initial_pitch_deg := -25.0

@export_group("Aim")
@export var aim_spring_length := 2.8
@export var aim_height := 1.72
@export var aim_shoulder_offset := 0.8
@export var aim_fov := 50.0
@export var full_draw_fov := 36.0
@export var aim_sensitivity_scale := 0.45
@export var aim_min_pitch_deg := -35.0
@export var aim_max_pitch_deg := 20.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var target: Node3D
var aim_weight := 0.0
var draw := 0.0
var arrow_cam_active := false

var _aiming := false
var _base_length := 7.0
var _base_fov := 60.0
var _trauma := 0.0
var _shake_time := 0.0
var _arrow: Node3D
var _arrow_hold := 0.0
var _dof: CameraAttributesPractical


func _ready() -> void:
	spring_arm.rotation.x = deg_to_rad(initial_pitch_deg)
	_base_length = spring_arm.spring_length
	_base_fov = camera.fov
	target = get_node_or_null(target_path) as Node3D
	if target != null:
		global_position = target.global_position + Vector3.UP * height_offset
	# Depth of field only on Vulkan renderers (Mobile/Forward+).
	if RenderingServer.get_rendering_device() != null:
		_dof = CameraAttributesPractical.new()
		_dof.dof_blur_far_distance = 22.0
		_dof.dof_blur_far_transition = 12.0
		_dof.dof_blur_amount = 0.0
		camera.attributes = _dof


func _physics_process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	if arrow_cam_active:
		_update_arrow_cam(real_delta)
	elif target != null:
		var height := lerpf(height_offset, aim_height, aim_weight)
		var goal := target.global_position + Vector3.UP * height
		global_position = global_position.lerp(goal, clampf(follow_speed * real_delta, 0.0, 1.0))

	aim_weight = move_toward(aim_weight, 1.0 if _aiming else 0.0, real_delta * 5.0)
	var w := smoothstep(0.0, 1.0, aim_weight)
	if not arrow_cam_active:
		spring_arm.spring_length = lerpf(_base_length, aim_spring_length * lerpf(1.0, 0.85, draw), w)
		camera.fov = lerpf(_base_fov, lerpf(aim_fov, full_draw_fov, draw * draw), w)
	if _dof:
		_dof.dof_blur_far_enabled = w > 0.01
		_dof.dof_blur_amount = 0.08 * w * draw

	_trauma = maxf(_trauma - real_delta * 1.8, 0.0)
	_shake_time += real_delta * 30.0
	var s := _trauma * _trauma
	camera.h_offset = aim_shoulder_offset * w + sin(_shake_time * 1.3) * 0.08 * s
	camera.v_offset = cos(_shake_time * 1.7) * 0.06 * s
	camera.rotation.z = sin(_shake_time * 0.9) * 0.02 * s


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and not arrow_cam_active:
		rotate_by((event as InputEventScreenDrag).relative)


func rotate_by(relative: Vector2) -> void:
	var sens := swipe_sensitivity * lerpf(1.0, aim_sensitivity_scale, aim_weight)
	rotation.y -= relative.x * sens
	var lo := lerpf(min_pitch_deg, aim_min_pitch_deg, aim_weight)
	var hi := lerpf(max_pitch_deg, aim_max_pitch_deg, aim_weight)
	var pitch := spring_arm.rotation.x - relative.y * sens
	spring_arm.rotation.x = clampf(pitch, deg_to_rad(lo), deg_to_rad(hi))


# --- Archery ----------------------------------------------------------------

func set_aiming(on: bool) -> void:
	_aiming = on
	if on:
		# Level the view a little so the horizon is in front of the arrow.
		var pitch := clampf(spring_arm.rotation.x, deg_to_rad(-14.0), deg_to_rad(4.0))
		create_tween().tween_property(spring_arm, "rotation:x", pitch, 0.2)


func is_aiming() -> bool:
	return _aiming


func set_draw(amount: float) -> void:
	draw = clampf(amount, 0.0, 1.0)


## World-space ray through the centre of the screen (the reticle).
func get_aim_ray() -> Array:
	var origin := camera.global_position
	var dir := -camera.global_basis.z
	return [origin, dir.normalized()]


## 0..1; decays over time.
func shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func kick(fov_punch: float = 4.0) -> void:
	camera.fov += fov_punch
	shake(0.35)


## Rides behind the arrow until it lands, then returns to the player.
func follow_arrow(arrow: Node3D) -> void:
	if arrow == null or not is_instance_valid(arrow):
		return
	_arrow = arrow
	_arrow_hold = 0.0
	arrow_cam_active = true
	spring_arm.spring_length = 2.6
	camera.fov = 50.0
	arrow.tree_exiting.connect(_on_arrow_gone, CONNECT_ONE_SHOT)


func _update_arrow_cam(real_delta: float) -> void:
	if _arrow != null and is_instance_valid(_arrow) and _arrow.is_inside_tree():
		var dir := -_arrow.global_basis.z
		var side := dir.cross(Vector3.UP).normalized()
		global_position = _arrow.global_position + Vector3.UP * 0.3 + side * 0.35
		var yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(real_delta * 12.0, 0.0, 1.0))
		spring_arm.rotation.x = lerpf(spring_arm.rotation.x, deg_to_rad(-8.0), clampf(real_delta * 8.0, 0.0, 1.0))
	else:
		# Linger on the impact for a heartbeat, then return to Rama.
		_arrow_hold += real_delta
		if _arrow_hold > 0.45:
			stop_arrow_cam()


func stop_arrow_cam() -> void:
	if not arrow_cam_active:
		return
	_arrow = null
	arrow_cam_active = false
	spring_arm.spring_length = aim_spring_length
	arrow_cam_finished.emit()


func _on_arrow_gone() -> void:
	_arrow = null
