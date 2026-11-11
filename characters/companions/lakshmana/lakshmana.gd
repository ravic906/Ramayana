class_name Lakshmana
extends CharacterBody3D
## Lakshmana, Rama's companion. An archer like his brother:
##   FOLLOW  a step behind Rama's left shoulder (story scenes, exploring)
##   ATTACK  shoots the nearest rakshasa from range; shoves away any that close in
##   GUARD   holds a point (the sacred fire, else Rama) and shoots whatever nears it
##   DOWNED  knocked down: kneels, then recovers (he never dies)
## The player toggles ATTACK/GUARD with the Command button (action "companion").

signal command_changed(command: int)
signal downed
signal recovered

enum Command { FOLLOW, ATTACK, GUARD }

const SKIN := Color(0.86, 0.68, 0.52)
const GARMENT := Color(0.8, 0.28, 0.12)
const TRIM := Color(0.8, 0.6, 0.2)
const SASH := Color(0.95, 0.8, 0.35)
const ARROW := preload("res://characters/rama/arrow.tscn")
const SHOT_INTERVAL := 1.5
const ARROW_DAMAGE := 9.0
const RANGE := 22.0
const STANDOFF := 9.0
const SHOVE_RANGE := 2.0
const GUARD_RADIUS := 7.0
const DOWNED_TIME := 6.0

@export var follow := true
@export var follow_offset := Vector3(-1.4, 0.0, 2.4)
@export var move_speed := 6.5
@export var command := Command.ATTACK:
	set(value):
		command = value
		command_changed.emit(value)
## Where to stand in GUARD (if unset, he guards Rama).
@export var guard_point: Node3D

@onready var model: RamaModel = $Visual/RamaModel
@onready var visual: Node3D = $Visual

var target: Rama
var foe: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var health: Health
var is_downed := false
var _shot_left := 0.8
var _downed_left := 0.0
var _foe_check := 0.0


func _ready() -> void:
	add_to_group(&"companions")
	health = get_node_or_null("Health") as Health
	if health == null:
		health = Health.new()
		health.name = "Health"
		health.max_health = 120.0 * Skills.mult("lakshmana_health")
		add_child(health)
	health.died.connect(_on_downed)
	health.damaged.connect(func(_a: float, _s: Node) -> void: model.play_hit())
	if model.face_rig:
		model.face_rig.speaker = "Lakshmana"
	_apply_style()
	Settings.style_changed.connect(func(_s: int) -> void: _apply_style())


## Enemies may go for him (unless he is down).
func can_be_targeted() -> bool:
	return not is_downed


func on_attacked(damage: float, source: Node) -> bool:
	if is_downed:
		return false
	health.take_damage(damage * Settings.incoming_damage_scale(), source)
	return true


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.3


## ATTACK <-> GUARD (from FOLLOW, starts with ATTACK).
func toggle_command() -> void:
	command = Command.GUARD if command == Command.ATTACK else Command.ATTACK
	if command == Command.ATTACK:
		say("With you, brother!", 1.8)
	elif guard_point:
		say("I'll guard the fire.", 1.8)
	else:
		say("I'll stay close, brother.", 1.8)


func _physics_process(delta: float) -> void:
	velocity.y = velocity.y - gravity * delta if not is_on_floor() else 0.0
	if is_downed:
		_downed_left -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if _downed_left <= 0.0:
			_recover()
		return
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
	if command != Command.FOLLOW and Input.is_action_just_pressed(&"companion") and not target.controls_locked:
		toggle_command()
	_shot_left -= delta
	_foe_check -= delta
	if command != Command.FOLLOW and _foe_check <= 0.0:
		_foe_check = 0.4
		foe = _pick_foe()
	if command != Command.FOLLOW and foe != null and is_instance_valid(foe):
		_fight(delta)
	else:
		_follow(delta)


func _anchor() -> Vector3:
	if command == Command.GUARD and guard_point != null and is_instance_valid(guard_point):
		return guard_point.global_position
	return target.global_position


func _pick_foe() -> Node3D:
	var anchor := _anchor()
	var best: Node3D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node3D):
			continue
		var h := e.get_node_or_null("Health") as Health
		if h != null and h.is_dead():
			continue
		if e.has_method("is_fleeing") and e.is_fleeing():
			continue  # sparing the fleeing is Rama's choice to make
		var p := (e as Node3D).global_position
		if global_position.distance_to(p) > RANGE:
			continue
		if command == Command.GUARD and anchor.distance_to(p) > GUARD_RADIUS + 6.0:
			continue
		var d := anchor.distance_squared_to(p) if command == Command.GUARD else global_position.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = e
	return best


func _fight(delta: float) -> void:
	var to := foe.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var desired := Vector3.ZERO
	if command == Command.GUARD:
		var home := _anchor() + (global_position - _anchor()).normalized() * 2.5
		var back := home - global_position
		back.y = 0.0
		if back.length() > 1.5:
			desired = back.normalized()
	elif dist > STANDOFF + 3.0:
		desired = dir
	elif dist < STANDOFF - 3.0 and dist > SHOVE_RANGE:
		desired = -dir
	var speed := move_speed * 0.8 if desired != Vector3.ZERO else 0.0
	velocity.x = desired.x * speed
	velocity.z = desired.z * speed
	move_and_slide()
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), clampf(12.0 * delta, 0.0, 1.0))
	model.set_locomotion(speed / move_speed)
	if _shot_left > 0.0:
		return
	if dist <= SHOVE_RANGE:
		_shove(dir)
	elif dist <= RANGE:
		_shoot()


func _shoot() -> void:
	_shot_left = SHOT_INTERVAL * Skills.mult("lakshmana_shot_interval") * randf_range(0.85, 1.15)
	model.play_shoot()
	var origin := global_position + Vector3.UP * 1.45 + visual.global_basis * Vector3(0, 0, -0.6)
	var aim: Vector3 = foe.get_aim_point() if foe.has_method("get_aim_point") else foe.global_position + Vector3.UP
	var arrow := ARROW.instantiate() as Arrow
	arrow.stick = false
	get_parent().add_child(arrow)
	arrow.global_position = origin
	arrow.launch((aim - origin).normalized(), self, ARROW_DAMAGE, 38.0)
	arrow.set_trail_color(Color(1.0, 0.75, 0.3, 0.7))


func _shove(dir: Vector3) -> void:
	_shot_left = SHOT_INTERVAL
	model.play_shoot()
	var h := foe.get_node_or_null("Health") as Health
	if h:
		h.take_damage(6.0, self)
	if foe.has_method("apply_knockback"):
		foe.apply_knockback(dir * 9.0)
	if foe.has_method("break_shield"):
		foe.break_shield()  # a shoulder-charge knocks a shield-bearer's guard aside


func _follow(delta: float) -> void:
	var goal := target.global_position + target.visual.global_basis * follow_offset
	if command == Command.GUARD and guard_point != null and is_instance_valid(guard_point):
		goal = guard_point.global_position + (target.global_position - guard_point.global_position).normalized() * 2.5
		# Step between the guarded one and anything charging at them.
		for a in get_tree().get_nodes_in_group(&"charging_animals"):
			var to_a: Vector3 = (a as Node3D).global_position - guard_point.global_position
			to_a.y = 0.0
			if to_a.length() < 16.0:
				goal = guard_point.global_position + to_a.normalized() * 1.6
				break
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


func _on_downed() -> void:
	is_downed = true
	_downed_left = DOWNED_TIME * Skills.mult("lakshmana_downed")
	foe = null
	model.set_locomotion(0.0)
	model.play_hit()
	visual.position.y = -0.35  # down on one knee
	say("I'm hit... give me a moment, brother.", 2.5)
	downed.emit()


func _recover() -> void:
	is_downed = false
	visual.position.y = 0.0
	health.revive()
	say("I'm with you again!", 1.8)
	recovered.emit()


## Short in-game line (subtitle on the HUD, spoken when voiced).
func say(text: String, seconds := 3.5) -> void:
	get_tree().call_group(&"hud", &"show_subtitle", "Lakshmana", text, seconds)


func _apply_style() -> void:
	var path := "res://assets/materials/env_real/rama_body_pbr.tres" if Settings.is_realistic() else "res://assets/materials/rama_body.tres"
	var mat := (load(path) as ShaderMaterial).duplicate() as ShaderMaterial
	mat.set_shader_parameter(&"region_base", SKIN)
	mat.set_shader_parameter(&"region_r", GARMENT)
	mat.set_shader_parameter(&"region_g", TRIM)
	mat.set_shader_parameter(&"region_b", SASH)
	mat.set_shader_parameter(&"inner_glow", 0.0)  # only Rama is radiant
	FaceController.set_skin(model.skeleton, mat)
