class_name Rama
extends CharacterBody3D
## Player controller for Shri Rama. Locomotion lives in StateMachine states;
## archery is an overlay action available while idle or moving.

signal arrow_fired(arrow: Arrow, target: Node3D)

@export_group("Movement")
@export var move_speed := 6.0
@export var acceleration := 40.0
@export var turn_speed := 12.0

@export_group("Dodge")
@export var dodge_speed := 14.0
@export var dodge_duration := 0.35
@export var dodge_cooldown := 0.5

@export_group("Archery")
@export var arrow_scene: PackedScene
@export var arrow_damage := 25.0
@export var shoot_cooldown := 0.3
@export var aim_range := 25.0
@export var aim_cone_degrees := 140.0

## Node whose yaw defines "forward" for the joystick (usually the camera rig).
@export var camera_rig_path: NodePath

@onready var visual: Node3D = $Visual
@onready var bow_muzzle: Marker3D = $Visual/BowMuzzle
@onready var health: Health = $Health
@onready var state_machine: StateMachine = $StateMachine

var camera_rig: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _shoot_timer := 0.0
var _dodge_timer := 0.0


func _ready() -> void:
	add_to_group(&"player")
	camera_rig = get_node_or_null(camera_rig_path) as Node3D


func _physics_process(delta: float) -> void:
	_shoot_timer = maxf(_shoot_timer - delta, 0.0)
	_dodge_timer = maxf(_dodge_timer - delta, 0.0)
	if Input.is_action_just_pressed(&"shoot") and can_shoot():
		shoot()


# --- Movement helpers used by states -------------------------------------

func get_move_input() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")


## Converts 2D stick input to a world-space direction relative to the camera yaw.
func input_to_world(input: Vector2) -> Vector3:
	var basis := camera_rig.global_transform.basis if camera_rig != null else Basis.IDENTITY
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	return right * input.x - forward * input.y


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)


func apply_horizontal(desired: Vector3, delta: float, accel: float = acceleration) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(desired, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))


func get_facing() -> Vector3:
	var f := -visual.global_transform.basis.z
	return Vector3(f.x, 0.0, f.z).normalized()


# --- Dodge ----------------------------------------------------------------

func can_dodge() -> bool:
	return _dodge_timer <= 0.0 and not state_machine.is_in(&"Dodge")


func start_dodge_cooldown() -> void:
	_dodge_timer = dodge_cooldown


# --- Archery --------------------------------------------------------------

func can_shoot() -> bool:
	return _shoot_timer <= 0.0 and arrow_scene != null and not state_machine.is_in(&"Dodge")


func shoot() -> Arrow:
	_shoot_timer = shoot_cooldown
	var origin := bow_muzzle.global_position
	var target := AutoAim.find_best_target(global_position, get_facing(),
		get_tree().get_nodes_in_group(&"enemies"), aim_range, aim_cone_degrees)
	var direction := get_facing()
	if target != null:
		direction = (AutoAim.aim_point_of(target) - origin).normalized()
		# Snap Rama's facing to the target for readable feedback.
		var flat := Vector3(direction.x, 0.0, direction.z)
		if flat.length_squared() > 0.0001:
			visual.rotation.y = atan2(-flat.x, -flat.z)
	var arrow := arrow_scene.instantiate() as Arrow
	# Spawn into the level (not as Rama's child) so arrows don't inherit his movement.
	get_parent().add_child(arrow)
	arrow.global_position = origin
	arrow.launch(direction, self, arrow_damage)
	arrow_fired.emit(arrow, target)
	return arrow
