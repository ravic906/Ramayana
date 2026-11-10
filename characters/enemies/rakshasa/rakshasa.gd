class_name Rakshasa
extends CharacterBody3D
## A rakshasa warrior: chases Rama, telegraphs its attacks, staggers on big
## hits and dies with a reward. Tuning comes from `data` (EnemyResource).

signal died(rakshasa: Rakshasa)
## Fled and was let go (an act of restraint: raises Dharma).
signal spared(rakshasa: Rakshasa)

## At most this many rakshasas may wind up an attack at once (readability).
const MAX_ATTACKERS := 2
const SEPARATION_RADIUS := 1.6
const STRIKE_HIT_TIME := 0.4  # seconds into the "strike" clip where the club lands
const SFX_GROWL := preload("res://assets/audio/sfx/growl.wav")
const SFX_CLUB := preload("res://assets/audio/sfx/club_hit.wav")
const SFX_BOW := preload("res://assets/audio/sfx/enemy_bow.wav")

static var _attackers := 0

@export var data: EnemyResource
@export var arrow_scene: PackedScene
@export var aggro_range := 45.0
## When > 0, the rakshasa flees once its health falls below this fraction.
@export var flee_below := 0.0
## Who it goes after:
##   PLAYER    Rama (default)
##   NEAREST   Rama or a companion (Lakshmana), whoever is closer
##   OBJECTIVE the nearest node in the "objective" group (e.g. the sacred fire);
##             turns on whoever hits it
enum TargetMode { PLAYER, NEAREST, OBJECTIVE }
@export var target_mode := TargetMode.PLAYER
## Raiders carry a burning torch to defile the sacred fire.
@export var carries_torch := false
## OBJECTIVE mode heads for this group ("objective" = the sacred fire,
## "bystanders" = the sages).
@export var objective_group := &"objective"
## Shield-bearer: arrows from the front (within 60 degrees) are turned aside.
@export var shield := false
## Mayavi: blinks around the field and conjures decoys.
@export var blinks := false
## A conjured decoy: dies to one hit, does no harm, gives nothing.
@export var is_decoy := false

@onready var health: Health = $Health
@onready var state_machine: StateMachine = $StateMachine
@onready var model: RakshasaModel = $RakshasaModel

var target: Node3D
var attack_cooldown_left := 0.0
var has_attack_token := false
var knockback := Vector3.ZERO
var strafe_sign := 1.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _retarget_left := 0.0


func _ready() -> void:
	add_to_group(&"enemies")
	model.scale = Vector3.ONE * data.model_scale
	health.max_health = data.max_health * Settings.enemy_health_scale()
	health.revive()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	strafe_sign = 1.0 if randf() < 0.5 else -1.0
	if carries_torch:
		_add_torch()
	if shield:
		_add_shield()
		health.damage_filter = _shield_filter
	if blinks:
		_blink_left = randf_range(2.0, 3.5)
		_add_shimmer()
	if is_decoy:
		health.max_health = 1.0
		health.revive()
		# Illusions fade on their own.
		get_tree().create_timer(14.0, false).timeout.connect(func() -> void:
			if is_inside_tree() and not health.is_dead():
				health.take_damage(1.0, null))
	attack_cooldown_left = randf_range(0.3, 1.2)


func _physics_process(delta: float) -> void:
	attack_cooldown_left = maxf(attack_cooldown_left - delta, 0.0)
	shield_down_left = maxf(shield_down_left - delta, 0.0)
	if blinks and not health.is_dead() and not is_decoy:
		_blink_left -= delta
		if _blink_left <= 0.0 and not state_machine.is_in(&"Telegraph"):
			blink()
	_retarget_left -= delta
	knockback = knockback.move_toward(Vector3.ZERO, 18.0 * delta)


func _exit_tree() -> void:
	release_attack_token()


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.1 * data.model_scale


func is_ranged() -> bool:
	return data.attack_kind == EnemyResource.AttackKind.RANGED


# --- Target -----------------------------------------------------------------

func find_target() -> Node3D:
	var valid := target != null and is_instance_valid(target) and _is_alive(target)
	if valid and (target_mode == TargetMode.PLAYER or _retarget_left > 0.0):
		return target
	_retarget_left = 1.0
	match target_mode:
		TargetMode.OBJECTIVE:
			target = _nearest_in([objective_group])
			if target == null:
				target = _nearest_in([&"player"])
		TargetMode.NEAREST:
			target = _nearest_in([&"player", &"companions"])
		_:
			var players := get_tree().get_nodes_in_group(&"player")
			target = players[0] as Node3D if not players.is_empty() else null
	return target


func target_alive() -> bool:
	var t := find_target()
	return t != null and _is_alive(t)


func _is_alive(t: Node) -> bool:
	if t.has_method("can_be_targeted") and not t.can_be_targeted():
		return false
	var h := t.get_node_or_null("Health") as Health
	return h == null or not h.is_dead()


func _nearest_in(groups: Array) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for g: StringName in groups:
		for n in get_tree().get_nodes_in_group(g):
			if not (n is Node3D) or not _is_alive(n):
				continue
			var d := global_position.distance_squared_to((n as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = n
	return best


func flat_to_target() -> Vector3:
	var d := target.global_position - global_position
	d.y = 0.0
	# Wide targets (the altar) are reached at their edge, not their centre.
	var reach = target.get("reach_radius")
	if reach != null and float(reach) > 0.0:
		d = d.normalized() * maxf(d.length() - float(reach), 0.05)
	return d


# --- Movement ---------------------------------------------------------------

## Moves along `desired` (flat, unnormalised ok) at `speed`, steering away from
## nearby rakshasas, then applies gravity and knockback.
func steer(desired: Vector3, speed: float, delta: float, face: Vector3 = Vector3.ZERO) -> void:
	var dir := desired.normalized() if desired.length_squared() > 0.0001 else Vector3.ZERO
	var push := Vector3.ZERO
	for other in _crowd():
		if other == self or not is_instance_valid(other):
			continue
		var away: Vector3 = global_position - (other as Node3D).global_position
		away.y = 0.0
		var d := away.length()
		if d > 0.01 and d < SEPARATION_RADIUS:
			push += away / d * (1.0 - d / SEPARATION_RADIUS)
	var move := (dir + push * 1.2)
	if move.length() > 1.0:
		move = move.normalized()
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(move * speed, 20.0 * delta)
	velocity.x = horizontal.x + knockback.x
	velocity.z = horizontal.z + knockback.z
	velocity.y = velocity.y - gravity * delta if not is_on_floor() else minf(velocity.y, 0.0)
	move_and_slide()
	var look := face if face.length_squared() > 0.0001 else horizontal
	face_toward(look, delta)


static var _crowd_frame := -1
static var _crowd_list: Array[Rakshasa] = []


## Every rakshasa on the field, gathered once per physics tick and shared.
func _crowd() -> Array[Rakshasa]:
	var f := Engine.get_physics_frames()
	if f != _crowd_frame:
		_crowd_frame = f
		_crowd_list.clear()
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if e is Rakshasa:
				_crowd_list.append(e)
	return _crowd_list


func face_toward(dir: Vector3, delta: float) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var yaw := atan2(-dir.x, -dir.z)
	model.rotation.y = lerp_angle(model.rotation.y, yaw, clampf(data.turn_speed * delta, 0.0, 1.0))


func apply_knockback(impulse: Vector3) -> void:
	impulse.y = 0.0
	knockback += impulse


# --- Attacks ----------------------------------------------------------------

func try_take_attack_token() -> bool:
	if has_attack_token:
		return true
	if _attackers >= MAX_ATTACKERS:
		return false
	_attackers += 1
	has_attack_token = true
	return true


func release_attack_token() -> void:
	if has_attack_token:
		has_attack_token = false
		_attackers = maxi(_attackers - 1, 0)


func begin_wind_up() -> void:
	_sfx(SFX_GROWL, -6.0, randf_range(0.85, 1.15))
	if is_ranged():
		model.play(&"shoot", 0.15, 0.0)
	else:
		model.play(&"strike", 0.12, STRIKE_HIT_TIME / maxf(data.telegraph_time, 0.05))


## The telegraphed blow lands (melee arc) or the arrow flies (ranged).
func perform_attack() -> void:
	model.anim.speed_scale = 1.0
	if target == null or not target_alive():
		return
	if is_decoy:
		return  # an illusion: its blows and arrows are nothing
	if is_ranged():
		_fire_arrow()
		return
	var to_t := flat_to_target()
	var facing := -model.global_basis.z
	facing.y = 0.0
	var in_reach := to_t.length() <= data.attack_range + 0.5
	var in_arc := facing.normalized().dot(to_t.normalized()) > cos(deg_to_rad(70.0))
	if in_reach and in_arc:
		var hit := true
		if target.has_method("on_attacked"):
			hit = target.on_attacked(data.damage, self)
		if hit:
			_sfx(SFX_CLUB, 0.0, randf_range(0.9, 1.1))


func _fire_arrow() -> void:
	if arrow_scene == null:
		return
	var origin := global_position + Vector3.UP * 1.45 * data.model_scale + (-model.global_basis.z) * 0.6
	var aim: Vector3 = target.get_aim_point() if target.has_method("get_aim_point") else target.global_position + Vector3.UP
	var arrow := arrow_scene.instantiate() as Arrow
	arrow.collision_mask = 3  # world + player
	arrow.stick = false
	get_parent().add_child(arrow)
	arrow.global_position = origin
	arrow.launch((aim - origin).normalized(), self, data.damage, 26.0)
	arrow.set_trail_color(Color(1.0, 0.2, 0.15, 0.8))
	_sfx(SFX_BOW, -3.0, randf_range(0.9, 1.1))


# --- Damage -------------------------------------------------------------------

func is_fleeing() -> bool:
	return state_machine.is_in(&"Flee")


func _on_damaged(amount: float, source: Node) -> void:
	model.hit_flash(Color(1.0, 0.95, 0.8), 1.6)
	# Raiders bound for the fire turn on whoever strikes them.
	if target_mode == TargetMode.OBJECTIVE and source is Node3D and source != target \
			and ((source as Node).is_in_group(&"player") or (source as Node).is_in_group(&"companions")):
		target_mode = TargetMode.NEAREST
		target = source
		_retarget_left = 3.0
	if flee_below > 0.0 and not health.is_dead() and health.ratio() < flee_below and not is_fleeing():
		state_machine.transition_to(&"Flee")
		return
	if not health.is_dead() and amount >= data.stagger_threshold:
		state_machine.transition_to(&"Stagger")


## Called by the Flee state when it gets away.
func escape() -> void:
	release_attack_token()
	remove_from_group(&"enemies")
	FX.burst(get_parent(), global_position + Vector3.UP, Color(0.2, 0.15, 0.12, 0.7), 16, 3.0, 1.0, 0.8, 0.5, true)
	spared.emit(self)
	queue_free()


func _on_died() -> void:
	release_attack_token()
	remove_from_group(&"enemies")
	collision_layer = 0
	if is_decoy:
		FX.burst(get_parent(), global_position + Vector3.UP, Color(0.45, 0.25, 0.7, 0.8), 20, 3.0, 0.8, 0.7, 0.5, true)
		died.emit(self)
		queue_free()
		return
	state_machine.transition_to(&"Dead")
	GameState.add_punya(data.punya_reward)
	died.emit(self)


func _sfx(stream: AudioStream, volume_db: float, pitch: float) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 10.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _add_torch() -> void:
	var flame := CPUParticles3D.new()
	flame.name = "Torch"
	flame.amount = 16
	flame.lifetime = 0.5
	flame.local_coords = false
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.06
	flame.direction = Vector3.UP
	flame.spread = 15.0
	flame.gravity = Vector3(0, 2.0, 0)
	flame.initial_velocity_min = 0.3
	flame.initial_velocity_max = 0.8
	flame.mesh = FX.glow_quad(Color(1.0, 0.55, 0.15, 0.9), 0.18)
	flame.position = Vector3(0.38, 1.75, -0.25) * data.model_scale
	model.add_child(flame)


# --- Shield-bearer -------------------------------------------------------------

var shield_down_left := 0.0
var _shield_mesh: MeshInstance3D


func _shield_filter(amount: float, source: Node) -> float:
	if Health.from_astra or shield_down_left > 0.0 or not (source is Node3D):
		return amount
	var to_src := (source as Node3D).global_position - global_position
	to_src.y = 0.0
	var facing := -model.global_basis.z
	facing.y = 0.0
	if to_src.length() > 0.01 and facing.normalized().dot(to_src.normalized()) > cos(deg_to_rad(60.0)):
		FX.sparks(get_parent(), global_position + Vector3.UP * 1.3 + facing.normalized() * 0.6, Color(0.9, 0.85, 0.7), 16, 4.0)
		return amount * 0.1
	return amount


## Lakshmana's shove (or a stagger) knocks the shield aside for a while.
func break_shield(seconds := 4.0) -> void:
	if shield:
		shield_down_left = seconds
		if _shield_mesh:
			var t := create_tween()
			t.tween_property(_shield_mesh, "rotation:z", 1.2, 0.2)
			t.tween_interval(seconds - 0.4)
			t.tween_property(_shield_mesh, "rotation:z", 0.0, 0.2)


func _add_shield() -> void:
	_shield_mesh = MeshInstance3D.new()
	_shield_mesh.name = "Shield"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.55
	disc.bottom_radius = 0.55
	disc.height = 0.08
	disc.radial_segments = 16
	_shield_mesh.mesh = disc
	_shield_mesh.material_override = load("res://assets/materials/env/dark_stone.tres")
	_shield_mesh.rotation = Vector3(PI / 2, 0, 0)
	_shield_mesh.position = Vector3(-0.15, 1.25, -0.5) * data.model_scale
	model.add_child(_shield_mesh)
	var boss := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.12
	s.height = 0.12
	boss.mesh = s
	boss.material_override = load("res://assets/materials/env/gold.tres")
	boss.position = Vector3(0, 0.06, 0)
	_shield_mesh.add_child(boss)


# --- Mayavi ----------------------------------------------------------------------

const DECOY_SCENE := "res://characters/enemies/rakshasa/rakshasa_mayavi.tscn"
var _blink_left := 4.0
var _decoys_made := false


## Vanishes in violet smoke and reappears elsewhere round its target; the first
## time, two decoys appear with it.
func blink() -> void:
	_blink_left = randf_range(3.5, 5.0)
	var t := find_target()
	if t == null:
		return
	FX.burst(get_parent(), global_position + Vector3.UP, Color(0.45, 0.25, 0.7, 0.8), 24, 3.5, 0.9, 0.8, 0.5, true)
	var a := randf() * TAU
	var p := t.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(7.0, 10.0)
	p.y = global_position.y
	global_position = p
	FX.burst(get_parent(), global_position + Vector3.UP, Color(0.45, 0.25, 0.7, 0.8), 24, 3.5, 0.9, 0.8, 0.5, true)
	if not _decoys_made:
		_decoys_made = true
		for i in 2:
			var d := (load(DECOY_SCENE) as PackedScene).instantiate() as Rakshasa
			d.is_decoy = true
			d.blinks = false
			var b := a + (i * 2 - 1) * 0.9
			d.position = t.global_position + Vector3(cos(b), 0, sin(b)) * 8.0
			get_parent().add_child(d)


func _add_shimmer() -> void:
	var p := CPUParticles3D.new()
	p.name = "Shimmer"
	p.amount = 14
	p.lifetime = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.gravity = Vector3(0, 0.8, 0)
	p.mesh = FX.glow_quad(Color(0.7, 0.45, 1.0, 0.6), 0.12)
	p.position = Vector3.UP * 1.2
	add_child(p)


## Astras always shake a rakshasa (brutes too, whom arrows barely stagger).
func on_astra(_astra: AstraResource, _source: Node) -> void:
	if not health.is_dead() and not is_fleeing():
		state_machine.transition_to.call_deferred(&"Stagger")

