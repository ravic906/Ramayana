class_name Tataka
extends CharacterBody3D
## Tataka, the cursed yakshini of Malada and Karusha. Portrayed with gravity:
## a giant, sorrowful, dangerous figure, never a figure of fun.
##
## Phase 1: charge (telegraphed, crashing into trees stuns her), ground slam
## (shockwave ring: roll through it), boulder throw (shoot boulders down).
## Phase 2 (below half health): maya. She vanishes into the mist, a dust trail
## betrays her movement, and she reappears close for a short exposed window.
## A stagger meter fills as Rama lands hits; when full she kneels and takes
## bonus damage.

signal defeated
signal phase_changed(phase: int)
signal staggered

enum S { DORMANT, CHASE, CHARGE_WINDUP, CHARGE, SLAM_WINDUP, SLAM, THROW_WINDUP, RECOVER, VANISHED, REAPPEAR, STAGGER, DEAD }

const SCALE := 2.4
const STRIKE_HIT_TIME := 0.4
const STAGGER_FULL := 140.0
const SFX_GROWL := preload("res://assets/audio/sfx/growl.wav")
const SFX_SLAM := preload("res://assets/audio/sfx/fire_explosion.wav")
const BOULDER := preload("res://characters/bosses/tataka/boulder.tscn")

@export var max_health := 900.0
@export var move_speed := 3.0
@export var charge_speed := 17.0
@export var charge_damage := 28.0
@export var slam_damage := 24.0
@export var boulder_damage := 20.0
@export var slam_radius := 11.0

@onready var health: Health = $Health
@onready var model: RakshasaModel = $RakshasaModel

var state := S.DORMANT
var phase := 1
var target: Node3D
var stagger_meter := 0.0
var attacks_done := 0
var knockback := Vector3.ZERO
var _t := 0.0
var _attack_cd := 1.5
var _charge_dir := Vector3.ZERO
var _hit_done := false
var _ring: MeshInstance3D
var _dust: CPUParticles3D
var _vanish_goal := Vector3.ZERO
var _recover_time := 1.0
var _bonus_guard := false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	model.scale = Vector3.ONE * SCALE
	health.max_health = max_health
	health.revive()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_dust = CPUParticles3D.new()
	_dust.amount = 30
	_dust.lifetime = 1.2
	_dust.local_coords = false
	_dust.emitting = false
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_dust.emission_sphere_radius = 1.2
	_dust.direction = Vector3.UP
	_dust.initial_velocity_min = 0.5
	_dust.initial_velocity_max = 1.5
	_dust.gravity = Vector3(0, 0.5, 0)
	_dust.mesh = FX.glow_quad(Color(0.55, 0.48, 0.4, 0.5), 0.9)
	(_dust.mesh.surface_get_material(0) as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	add_child(_dust)


## Begins the fight (after the intro cutscene).
func awaken() -> void:
	if state != S.DORMANT:
		return
	add_to_group(&"enemies")
	_enter(S.CHASE)


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.25 * SCALE


func apply_knockback(impulse: Vector3) -> void:
	impulse.y = 0.0
	knockback += impulse * 0.15


func damage_scale() -> float:
	return 0.5 if Settings.story_mode else 1.0


func _physics_process(delta: float) -> void:
	velocity.y = velocity.y - gravity * delta if not is_on_floor() else 0.0
	knockback = knockback.move_toward(Vector3.ZERO, 10.0 * delta)
	if state == S.DORMANT or state == S.DEAD:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if _find_target() == null:
		return
	_t += delta
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var move := Vector3.ZERO
	match state:
		S.CHASE:
			_attack_cd -= delta
			if dist > 4.0:
				move = dir * move_speed
				model.play(&"walk", 0.2, 0.7)
			else:
				model.play(&"idle")
			_face(dir, delta)
			if _attack_cd <= 0.0:
				_choose_attack(dist)
		S.CHARGE_WINDUP:
			_face(dir, delta * 2.0)
			model.set_glow(0.4 + _t * 1.4)
			if _t >= 1.0:
				_charge_dir = dir
				_hit_done = false
				_enter(S.CHARGE)
		S.CHARGE:
			move = _charge_dir * charge_speed
			model.play(&"run", 0.1, 1.4)
			if not _hit_done and dist < 2.8:
				_hit_done = true
				if target.has_method("on_attacked"):
					target.on_attacked(charge_damage * damage_scale(), self)
			if is_on_wall() and _t > 0.2:
				# Crashed into the trees: stunned.
				_shake(0.6)
				FX.burst(get_parent(), global_position + Vector3.UP * 2.0, Color(0.5, 0.42, 0.32, 0.7), 20, 5.0, 1.0, 0.8, -2.0, true)
				_enter(S.STAGGER)
			elif _t >= 1.2:
				_recover(0.9)
		S.SLAM_WINDUP:
			_face(dir, delta)
			model.set_glow(0.4 + _t * 1.6)
			if _t >= 0.9:
				_start_slam()
		S.SLAM:
			var r := slam_radius * clampf(_t / 0.75, 0.0, 1.0)
			if _ring:
				_ring.scale = Vector3(r, 1.0, r)
			if not _hit_done and absf(dist - r) < 1.1 and target.is_on_floor():
				_hit_done = true
				if target.has_method("on_attacked"):
					target.on_attacked(slam_damage * damage_scale(), self)
			if _t >= 0.75:
				if _ring:
					_ring.queue_free()
				_recover(1.0)
		S.THROW_WINDUP:
			_face(dir, delta * 2.0)
			model.set_glow(0.3 + _t)
			if _t >= 0.8:
				_throw()
				_recover(0.9)
		S.RECOVER:
			_face(dir, delta)
			if _t >= _recover_time:
				_enter(S.CHASE)
		S.VANISHED:
			var to_goal := _vanish_goal - global_position
			to_goal.y = 0.0
			move = to_goal.normalized() * 6.0 if to_goal.length() > 0.5 else Vector3.ZERO
			if _t >= 2.2:
				_reappear(dir)
		S.REAPPEAR:
			_face(dir, delta * 3.0)
			model.set_glow(1.2)
			if _t >= 1.0:  # exposed window, then a slam
				_enter(S.SLAM_WINDUP)
				_t = 0.4
		S.STAGGER:
			if _t >= 2.8:
				_recover(0.5)
	velocity.x = move.x + knockback.x
	velocity.z = move.z + knockback.z
	move_and_slide()


func _choose_attack(dist: float) -> void:
	attacks_done += 1
	if phase == 2 and attacks_done % 3 == 0:
		_vanish()
	elif dist < 6.5:
		_enter(S.SLAM_WINDUP)
		model.play(&"strike", 0.1, STRIKE_HIT_TIME / 0.9)
		_sound(SFX_GROWL, 0.0, 0.6)
	elif dist > 15.0 or attacks_done % 2 == 0:
		_enter(S.THROW_WINDUP)
		model.play(&"shoot", 0.15, 0.0)
	else:
		_enter(S.CHARGE_WINDUP)
		_sound(SFX_GROWL, 2.0, 0.5)


func _start_slam() -> void:
	model.anim.speed_scale = 1.0
	model.set_glow(0.0)
	_hit_done = false
	_ring = MeshInstance3D.new()
	_ring.mesh = MeshKit.torus(0.92, 1.0, 40)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.4, 0.95, 0.75)
	_ring.material_override = mat
	_ring.top_level = true
	add_child(_ring)
	_ring.global_position = global_position + Vector3.UP * 0.25
	FX.burst(get_parent(), global_position + Vector3.UP * 0.3, Color(0.55, 0.45, 0.35, 0.7), 30, 9.0, 1.0, 0.8, -3.0, true)
	_sound(SFX_SLAM, 2.0, 0.55)
	_shake(0.7)
	_enter(S.SLAM)


func _throw() -> void:
	if _find_target() == null:
		return
	model.anim.speed_scale = 1.0
	model.set_glow(0.0)
	var count := 1 if phase == 1 else 3
	for i in count:
		var b := BOULDER.instantiate() as Boulder
		var lead := Vector3.ZERO
		if target is CharacterBody3D:
			lead = (target as CharacterBody3D).velocity * 0.6
			lead.y = 0.0
		var spread := Vector3((i - (count - 1) * 0.5) * 3.5, 0.0, 0.0).rotated(Vector3.UP, model.rotation.y)
		b.start = global_position + Vector3.UP * 4.6
		b.end = Vector3(target.global_position.x, global_position.y, target.global_position.z) + lead + spread
		b.damage = boulder_damage * damage_scale()
		b.thrower = self
		b.flight_time = 1.3 + i * 0.12
		b.shot_down.connect(func(_b: Boulder) -> void: _add_stagger(30.0))
		get_parent().add_child(b)
	_sound(SFX_GROWL, 0.0, 0.7)


func _find_target() -> Node3D:
	if target == null or not is_instance_valid(target):
		var players := get_tree().get_nodes_in_group(&"player")
		target = players[0] if not players.is_empty() else null
	return target


func _vanish() -> void:
	if _find_target() == null:
		return
	FX.burst(get_parent(), global_position + Vector3.UP * 2.5, Color(0.2, 0.15, 0.3, 0.8), 40, 4.0, 2.0, 1.4, 0.8, true)
	model.visible = false
	remove_from_group(&"enemies")
	collision_layer = 0
	_dust.emitting = true
	var side := 1.0 if randf() < 0.5 else -1.0
	var around := (target.global_position - global_position).normalized().cross(Vector3.UP) * side
	_vanish_goal = target.global_position + around * 7.0
	_enter(S.VANISHED)


func _reappear(dir: Vector3) -> void:
	model.visible = true
	add_to_group(&"enemies")
	collision_layer = 4
	_dust.emitting = false
	model.rotation.y = atan2(-dir.x, -dir.z)
	FX.burst(get_parent(), global_position + Vector3.UP * 2.5, Color(0.2, 0.15, 0.3, 0.8), 40, 4.0, 2.0, 1.2, 0.8, true)
	_sound(SFX_GROWL, 3.0, 0.55)
	_enter(S.REAPPEAR)


func _recover(seconds: float) -> void:
	model.set_glow(0.0)
	model.anim.speed_scale = 1.0
	_recover_time = seconds
	_attack_cd = randf_range(1.0, 1.8) if phase == 1 else randf_range(0.6, 1.2)
	_enter(S.RECOVER)


func _enter(s: int) -> void:
	state = s
	_t = 0.0
	if s == S.STAGGER:
		model.set_glow(0.0)
		model.anim.speed_scale = 1.0
		model.play(&"hit", 0.1, 0.35)
		stagger_meter = 0.0
		staggered.emit()
		if _ring:
			_ring.queue_free()


func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() > 0.0001:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), clampf(4.0 * delta, 0.0, 1.0))


func _add_stagger(amount: float) -> void:
	if state in [S.STAGGER, S.VANISHED, S.DEAD, S.DORMANT]:
		return
	stagger_meter += amount
	if stagger_meter >= STAGGER_FULL:
		_enter(S.STAGGER)


func _on_damaged(amount: float, source: Node) -> void:
	model.hit_flash(Color(1.0, 0.95, 0.85), 1.2)
	# Kneeling: Rama's arrows strike true (bonus damage).
	if state == S.STAGGER and not _bonus_guard and not health.is_dead():
		_bonus_guard = true
		health.take_damage(amount * 0.5, source)
		_bonus_guard = false
	# Crossing half health starts the maya phase; it takes priority over a stagger.
	if phase == 1 and health.ratio() < 0.5 and not health.is_dead():
		phase = 2
		phase_changed.emit(2)
		stagger_meter = 0.0
		if state != S.STAGGER and state != S.VANISHED:
			_vanish()
		return
	_add_stagger(amount)


func _on_died() -> void:
	state = S.DEAD
	remove_from_group(&"enemies")
	collision_layer = 0
	model.visible = true
	_dust.emitting = false
	model.set_glow(0.0)
	model.anim.speed_scale = 0.6
	model.play(&"death", 0.2, 0.6)
	if _ring:
		_ring.queue_free()
	defeated.emit()


func _shake(amount: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var rig := cam.get_parent().get_parent() as FollowCamera if cam and cam.get_parent() else null
	if rig:
		rig.shake(amount)


func _sound(stream: AudioStream, volume_db: float, pitch: float) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 20.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
