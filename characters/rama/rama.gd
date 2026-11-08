class_name Rama
extends CharacterBody3D
## Player controller for Shri Rama. Locomotion lives in StateMachine states.
##
## Archery: pressing Bow enters the Aim state and Rama draws the Kodanda.
##   - Release quickly: a snap shot with generous auto-aim.
##   - Hold: the camera moves over his shoulder, time slows as the string
##     tightens, the phone vibrates with rising tension. Drag to aim.
##   - Release in the golden moment just after full draw: a perfect shot
##     (double damage, hero arrow cam). Hold too long and his aim trembles.

signal arrow_fired(arrow: Arrow, target: Node3D)
signal draw_changed(amount: float, perfect_window: bool)
signal aim_started
signal aim_ended
signal released(arrow: Arrow, power: float, perfect: bool)
signal aim_target_changed(target: Node3D)
signal hurt(amount: float)
signal perfect_dodge
signal rama_died
signal respawned
## Emitted with the armed astra, or null when disarmed.
signal astra_armed_changed(astra: AstraResource)
signal astra_detonated(position: Vector3)

@export_group("Movement")
@export var move_speed := 6.0
@export var acceleration := 40.0
@export var turn_speed := 12.0

@export_group("Dodge")
@export var dodge_speed := 9.5
@export var dodge_duration := 0.55
@export var dodge_cooldown := 0.5

@export_group("Archery")
@export var arrow_scene: PackedScene
## Snap-shot damage and auto-aim (quick tap of the Bow button).
@export var arrow_damage := 18.0
@export var shoot_cooldown := 0.25
@export var aim_range := 25.0
@export var aim_cone_degrees := 140.0

@export_group("Draw")
## Real seconds to reach full draw.
@export var draw_time := 0.65
## Releases faster than this are snap shots.
@export var snap_shot_time := 0.18
## Seconds after reaching full draw in which a release is perfect.
@export var perfect_window := 0.45
## Holding full draw longer than this makes the aim tremble.
@export var fatigue_time := 2.2
@export var aim_move_factor := 0.35
@export var focus_time_scale := 0.55
@export var min_damage := 12.0
@export var max_damage := 34.0
@export var perfect_multiplier := 2.0
@export var min_arrow_speed := 32.0
@export var max_arrow_speed := 70.0
## Aim assist while drawing: cone around the reticle.
@export var assist_range := 45.0
@export var assist_cone_degrees := 16.0
@export var arrow_cam_time_scale := 0.2

@export_group("Astras")
## Astra slots (slot 0 = the Agni button / astra_1 action).
@export var astras: Array[AstraResource] = []
@export var respawn_delay := 3.0

## Node whose yaw defines "forward" for the joystick (usually the camera rig).
@export var camera_rig_path: NodePath

@onready var visual: Node3D = $Visual
@onready var bow_muzzle: Marker3D = $Visual/BowMuzzle
@onready var health: Health = $Health
@onready var state_machine: StateMachine = $StateMachine
## Visual + animation. Optional so gameplay works with any placeholder visual.
@onready var model: RamaModel = get_node_or_null("Visual/RamaModel") as RamaModel

const SFX_NOCK := preload("res://assets/audio/sfx/nock.wav")
const SFX_TWANG := preload("res://assets/audio/sfx/twang.wav")
const SFX_WHOOSH := preload("res://assets/audio/sfx/whoosh.wav")
const SFX_PERFECT := preload("res://assets/audio/sfx/perfect.wav")
const SFX_CREAK := preload("res://assets/audio/sfx/creak_loop.wav")
const SFX_HEARTBEAT := preload("res://assets/audio/sfx/heartbeat.wav")
const SFX_HURT := preload("res://assets/audio/sfx/rama_hurt.wav")
const SFX_IGNITE := preload("res://assets/audio/sfx/ignite.wav")

var camera_rig: Node3D
var cam: FollowCamera
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var is_drawing := false
var draw_amount := 0.0
## Real seconds since the draw started.
var hold_time := 0.0
## Real seconds spent at full draw (-1 until reached).
var full_draw_time := -1.0
var aim_target: Node3D
var aim_point := Vector3.ZERO
var armed_astra: AstraResource
## Astra id -> real seconds of cooldown left.
var astra_cooldowns := {}
var spawn_point := Vector3.ZERO

var _shoot_timer := 0.0
var _dodge_timer := 0.0
var _haptic_timer := 0.0
var _engaged := false
var _creak: AudioStreamPlayer
var _heartbeat: AudioStreamPlayer


func _ready() -> void:
	add_to_group(&"player")
	camera_rig = get_node_or_null(camera_rig_path) as Node3D
	cam = camera_rig as FollowCamera
	if cam:
		cam.arrow_cam_finished.connect(_on_arrow_cam_finished)
	_creak = _loop_player(SFX_CREAK)
	_heartbeat = _loop_player(SFX_HEARTBEAT)
	spawn_point = global_position
	health.damaged.connect(_on_hurt)
	health.died.connect(_on_died)


func _exit_tree() -> void:
	TimeFX.clear_all()


func _physics_process(delta: float) -> void:
	_shoot_timer = maxf(_shoot_timer - delta, 0.0)
	_dodge_timer = maxf(_dodge_timer - delta, 0.0)
	var real_delta := TimeFX.unscaled(delta)
	for id in astra_cooldowns.keys():
		astra_cooldowns[id] = maxf(astra_cooldowns[id] - real_delta, 0.0)
	if Input.is_action_just_pressed(&"astra_1") and not health.is_dead():
		toggle_astra(0)
	if model != null:
		model.set_locomotion(Vector2(velocity.x, velocity.z).length() / move_speed)


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


## Snap shot: fires immediately at the best target near Rama's facing.
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
	var arrow := _spawn_arrow(origin, direction, arrow_damage, 40.0, false)
	if model != null:
		model.play_shoot()
	_sfx(SFX_TWANG, -4.0, 1.1)
	Haptics.pulse(40, 0.6)
	arrow_fired.emit(arrow, target)
	return arrow


func begin_draw() -> void:
	is_drawing = true
	draw_amount = 0.0
	hold_time = 0.0
	full_draw_time = -1.0
	_haptic_timer = 0.0
	_engaged = false
	_sfx(SFX_NOCK, -6.0, randf_range(0.95, 1.05))
	_creak.volume_db = -40.0
	_creak.play()
	aim_started.emit()


## Called every physics frame by the Aim state with real (unscaled) seconds.
func update_draw(real_delta: float) -> void:
	if not is_drawing:
		return
	hold_time += real_delta
	# Engage the archery stance and camera only once it's clearly a hold, so
	# quick taps (snap shots) never twitch the view.
	if not _engaged and hold_time >= snap_shot_time:
		_engaged = true
		if model:
			model.begin_aim()
		if cam:
			cam.set_aiming(true)
	draw_amount = minf(draw_amount + real_delta / draw_time, 1.0)
	if draw_amount >= 1.0:
		if full_draw_time < 0.0:
			full_draw_time = 0.0
			Haptics.pulse(35, 0.9)
			_heartbeat.play()
		else:
			full_draw_time += real_delta
	var in_perfect := is_in_perfect_window()

	# Focus: time slows as the string tightens (not for snap shots).
	if hold_time > snap_shot_time:
		TimeFX.set_layer(&"focus", lerpf(1.0, focus_time_scale, draw_amount * draw_amount))
	# Creak rises with tension, then settles while holding.
	var holding := full_draw_time >= 0.0
	_creak.volume_db = lerpf(-30.0, -5.0, draw_amount) if not holding else -16.0
	_creak.pitch_scale = 0.8 + 0.45 * draw_amount
	# Haptic "tension" ticks get stronger as the draw deepens.
	_haptic_timer -= real_delta
	if _haptic_timer <= 0.0 and not holding and hold_time > snap_shot_time:
		Haptics.pulse(16, 0.15 + 0.55 * draw_amount)
		_haptic_timer = 0.09
	# Fatigue: holding too long makes the aim tremble.
	var fatigue := clampf((full_draw_time - fatigue_time) / 1.5, 0.0, 1.0) if holding else 0.0
	if fatigue > 0.0 and cam:
		var t := hold_time
		cam.rotate_by(Vector2(cos(t * 2.3) * 2.3, -sin(t * 1.9) * 1.9) * fatigue * real_delta * 60.0)
		_heartbeat.pitch_scale = 1.0 + fatigue * 0.5

	_update_aim()
	if model:
		model.set_draw(draw_amount)
	if cam:
		cam.set_draw(draw_amount)
	draw_changed.emit(draw_amount, in_perfect)


func is_in_perfect_window() -> bool:
	return full_draw_time >= 0.0 and full_draw_time <= perfect_window


## Fires the drawn arrow (or a snap shot for a quick tap) and ends the draw.
func release_draw() -> Arrow:
	if not is_drawing:
		return null
	var arrow: Arrow = null
	if hold_time < snap_shot_time:
		_finish_draw()
		return shoot() if can_shoot() else null
	var power := clampf(draw_amount, 0.25, 1.0)
	var perfect := is_in_perfect_window()
	_update_aim()
	var origin := model.get_nock_position() if model else bow_muzzle.global_position
	var direction := (aim_point - origin).normalized()
	var damage := lerpf(min_damage, max_damage, power) * (perfect_multiplier if perfect else 1.0)
	arrow = _spawn_arrow(origin, direction, damage, lerpf(min_arrow_speed, max_arrow_speed, power), perfect)
	var target := aim_target
	_shoot_timer = shoot_cooldown
	if armed_astra != null and draw_amount >= armed_astra.min_draw:
		var astra := armed_astra
		arrow.set_astra(astra)
		astra_cooldowns[astra.id] = astra.cooldown
		_set_armed(null)
		_sfx(SFX_IGNITE, -2.0, 1.3)
		arrow.impacted.connect(func(at: Vector3, _c: Object, _k: bool) -> void: astra_detonated.emit(at))

	_sfx(SFX_TWANG, lerpf(-8.0, 0.0, power), 0.9 + 0.2 * power)
	_sfx(SFX_WHOOSH, lerpf(-14.0, -4.0, power), 1.0)
	Haptics.pulse(int(lerpf(40, 90, power)), power)
	if model:
		model.play_shoot()
	if cam:
		cam.kick(2.0 + 4.0 * power)
	if perfect:
		_sfx(SFX_PERFECT, -3.0, 1.0)
		if target != null and cam:
			TimeFX.set_layer(&"arrow_cam", arrow_cam_time_scale)
			cam.follow_arrow(arrow)
			# Safety net: never leave the game in slow motion.
			get_tree().create_timer(2.5, true, false, true).timeout.connect(_on_arrow_cam_finished)
	_finish_draw()
	released.emit(arrow, power, perfect)
	arrow_fired.emit(arrow, target)
	return arrow


## Abandons the draw without firing (e.g. dodging).
func cancel_draw() -> void:
	if is_drawing:
		_finish_draw()


func _finish_draw() -> void:
	is_drawing = false
	_engaged = false
	draw_amount = 0.0
	full_draw_time = -1.0
	TimeFX.clear_layer(&"focus")
	_creak.stop()
	_heartbeat.stop()
	_heartbeat.pitch_scale = 1.0
	if model:
		model.end_aim()
	if cam:
		cam.set_aiming(false)
		cam.set_draw(0.0)
	if aim_target != null:
		aim_target = null
		aim_target_changed.emit(null)
	draw_changed.emit(0.0, false)
	aim_ended.emit()


## Aim follows the reticle (camera centre) with a gentle magnet to enemies.
func _update_aim() -> void:
	var origin := global_position + Vector3.UP * 1.5
	var dir := get_facing()
	if cam:
		var ray := cam.get_aim_ray()
		origin = ray[0]
		dir = ray[1]
	var target := AutoAim.find_best_target(origin, dir, get_tree().get_nodes_in_group(&"enemies"),
		assist_range, assist_cone_degrees)
	if target != null:
		aim_point = AutoAim.aim_point_of(target)
	else:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 80.0, 5)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		aim_point = hit["position"] if not hit.is_empty() else origin + dir * 80.0
	if target != aim_target:
		aim_target = target
		aim_target_changed.emit(target)
	var chest := global_position + Vector3.UP * 1.45
	var to_aim := aim_point - chest
	var flat := Vector3(to_aim.x, 0.0, to_aim.z)
	if flat.length_squared() > 0.0001:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-flat.x, -flat.z), 0.35)
	if model:
		model.set_aim_direction(to_aim.normalized())


# --- Astras -----------------------------------------------------------------

## Arms (or disarms) the astra in `slot`; the next drawn shot carries it.
func toggle_astra(slot: int) -> bool:
	if slot < 0 or slot >= astras.size():
		return false
	var astra := astras[slot]
	if armed_astra == astra:
		_set_armed(null)
		return true
	if not is_astra_ready(astra):
		return false
	_set_armed(astra)
	_sfx(SFX_IGNITE, -4.0, 1.0)
	Haptics.pulse(60, 0.7)
	return true


func is_astra_unlocked(astra: AstraResource) -> bool:
	return astra.id in GameState.unlocked_astras


func is_astra_ready(astra: AstraResource) -> bool:
	return is_astra_unlocked(astra) and astra_cooldown_left(astra) <= 0.0 and not health.is_dead()


func astra_cooldown_left(astra: AstraResource) -> float:
	return astra_cooldowns.get(astra.id, 0.0)


func _set_armed(astra: AstraResource) -> void:
	armed_astra = astra
	if model:
		model.set_astra_glow(astra)
	astra_armed_changed.emit(astra)


# --- Taking damage ------------------------------------------------------------

## Called by enemy melee attacks. Returns whether the blow connected.
func on_attacked(damage: float, source: Node) -> bool:
	if health.is_dead():
		return false
	if health.invulnerable:
		# The blow whiffed through a dodge roll: reward the timing.
		FX.sparks(get_parent(), global_position + Vector3.UP * 1.0, Color(1.0, 0.85, 0.4), 30, 4.0)
		_sfx(SFX_PERFECT, -6.0, 1.5)
		TimeFX.hitstop(0.12, 0.3)
		perfect_dodge.emit()
		return false
	health.take_damage(damage, source)
	return true


func _on_hurt(amount: float, _source: Node) -> void:
	if model:
		model.play_hit()
	if cam:
		cam.shake(0.45)
	Haptics.pulse(120, 1.0)
	_sfx(SFX_HURT, -2.0, randf_range(0.9, 1.1))
	hurt.emit(amount)
	if is_drawing and amount >= 20.0 and not health.is_dead():
		state_machine.transition_to(&"Idle")


func _on_died() -> void:
	state_machine.transition_to(&"Dead")


## Called by the Dead state on entry.
func die() -> void:
	cancel_draw()
	_set_armed(null)
	velocity = Vector3.ZERO
	if model:
		model.play_death()
	rama_died.emit()


## Called by the Dead state after the respawn delay.
func respawn() -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO
	health.revive()
	if model:
		model.revive()
	respawned.emit()


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.2


func _spawn_arrow(origin: Vector3, direction: Vector3, damage: float, arrow_speed: float, perfect: bool) -> Arrow:
	var arrow := arrow_scene.instantiate() as Arrow
	# Spawn into the level (not as Rama's child) so arrows don't inherit his movement.
	get_parent().add_child(arrow)
	arrow.global_position = origin
	arrow.launch(direction, self, damage, arrow_speed, perfect)
	return arrow


func _on_arrow_cam_finished() -> void:
	TimeFX.clear_layer(&"arrow_cam")
	if cam and cam.arrow_cam_active:
		cam.stop_arrow_cam()


func _loop_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var looped := stream.duplicate() as AudioStreamWAV
	looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
	looped.loop_begin = 0
	looped.loop_end = int(looped.get_length() * looped.mix_rate)
	var p := AudioStreamPlayer.new()
	p.stream = looped
	add_child(p)
	return p


func _sfx(stream: AudioStream, volume_db: float, pitch: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
