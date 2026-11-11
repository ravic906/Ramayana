class_name SkyRakshasa
extends CharacterBody3D
## Maricha and Subahu, Tataka's sons, who fall on Vishvamitra's yagna from the
## night sky, riding clouds of maya.
##
## Both circle the altar, volley projectiles (shootable) and swoop low (dodge;
## while low and recovering they are exposed). Only one swoops at a time.
##   SUBAHU  "the cruel one": rains fire bolts on the altar and the huts. Below
##           15% health a smoke shield turns arrows aside; only the Agneyastra
##           can end him.
##   MARICHA rains blood shards. Below 25% he yields and cannot be killed; the
##           Manavastra carries him far over the sea (an act of mercy).

signal defeated(boss: SkyRakshasa)
signal banished(boss: SkyRakshasa)
signal shielded(boss: SkyRakshasa)
signal yielded(boss: SkyRakshasa)

enum Kind { SUBAHU, MARICHA }
enum S { DORMANT, DESCEND, CIRCLE, VOLLEY, SWOOP_WINDUP, SWOOP, RECOVER, LAST_STAND, YIELDING, DEAD, BANISHED }

const SFX_GROWL := preload("res://assets/audio/sfx/growl.wav")
const BOLT := preload("res://characters/bosses/tataka/boulder.tscn")
const SCALE := 1.7
const SUBAHU_SHIELD_AT := 0.15
const MARICHA_YIELD_AT := 0.25

static var _swooper: SkyRakshasa = null

@export var kind := Kind.SUBAHU
@export var max_health := 380.0
@export var orbit_radius := 11.0
@export var orbit_height := 2.8
@export var volley_damage := 14.0
@export var swoop_damage := 18.0

@onready var health: Health = $Health
@onready var model: RakshasaModel = $RakshasaModel

var state := S.DORMANT
var center := Vector3.ZERO
var sea_direction := Vector3(-1, 0.2, 1)
var _t := 0.0
var _angle := 0.0
var _orbit_dir := 1.0
var _attack_cd := 2.0
var _swoop_from := Vector3.ZERO
var _swoop_to := Vector3.ZERO
var _swoop_hit := false
var _descend_from := Vector3.ZERO
var _cloud: CPUParticles3D
var _shield: CPUParticles3D


func _ready() -> void:
	model.scale = Vector3.ONE * SCALE
	health.max_health = max_health * (0.75 if Settings.story_mode else Settings.enemy_health_scale())
	health.revive()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_cloud = _particles(Color(0.12, 0.08, 0.14, 0.75), 1.6, 40, 1.4)
	_cloud.position = Vector3.UP * 0.2
	# A glowing aura so they read against the night forest on a small screen.
	var aura_color := Color(1.0, 0.4, 0.1, 0.55) if kind == Kind.SUBAHU else Color(0.65, 0.35, 1.0, 0.55)
	var aura := _particles(aura_color, 0.7, 36, 1.2)
	(aura.mesh.surface_get_material(0) as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	aura.direction = Vector3.UP
	aura.gravity = Vector3(0, 0.6, 0)
	aura.position = Vector3.UP * 2.0
	_shield = _particles(Color(0.25, 0.2, 0.2, 0.8), 1.4, 50, 1.0)
	_shield.position = Vector3.UP * 1.6
	_shield.emitting = false
	_orbit_dir = 1.0 if kind == Kind.SUBAHU else -1.0
	_angle = 0.0 if kind == Kind.SUBAHU else PI  # phase of the sweep: they keep to opposite ends
	visible = false
	collision_layer = 0


func display_name() -> String:
	return "Subahu" if kind == Kind.SUBAHU else "Maricha"


## They come down out of the sky toward their orbit round `around`.
func awaken(around: Vector3, from: Vector3) -> void:
	center = around
	_descend_from = from
	global_position = from
	visible = true
	collision_layer = 4
	add_to_group(&"enemies")
	_sound(SFX_GROWL, 2.0, 0.6 if kind == Kind.SUBAHU else 0.8)
	_enter(S.DESCEND)


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.2 * SCALE


func is_exposed() -> bool:
	return state in [S.RECOVER, S.SWOOP]


func _physics_process(delta: float) -> void:
	_t += delta
	match state:
		S.DORMANT, S.DEAD:
			return
		S.DESCEND:
			var k := clampf(_t / 2.5, 0.0, 1.0)
			var goal := _orbit_point()
			global_position = _descend_from.lerp(goal, 1.0 - pow(1.0 - k, 3.0))
			_face(center - global_position, delta)
			model.play(&"idle")
			if k >= 1.0:
				_enter(S.CIRCLE)
		S.CIRCLE:
			_angle += delta * 0.45
			_move_to(_orbit_point(), 6.0, delta)
			_face(_tangent(), delta)
			model.play(&"run", 0.2, 0.6)
			_attack_cd -= delta
			if _attack_cd <= 0.0:
				_choose_attack()
		S.VOLLEY:
			_face(_target_point() - global_position, delta)
			model.set_glow(clampf(_t / 0.8, 0.0, 1.0))
			if _t >= 0.8:
				_volley()
				_recover(1.0)
		S.SWOOP_WINDUP:
			_face(_swoop_to - global_position, delta)
			model.set_glow(clampf(_t / 0.9, 0.0, 1.0))
			global_position.y += delta * 1.5  # rears up before the dive
			if _t >= 0.9:
				_swoop_from = global_position
				model.set_glow(0.0)
				model.play(&"strike", 0.1, 0.8)
				_enter(S.SWOOP)
		S.SWOOP:
			var k := clampf(_t / 0.9, 0.0, 1.0)
			var p := _swoop_from.lerp(_swoop_to, k)
			p.y = lerpf(_swoop_from.y, _swoop_to.y, sin(k * PI * 0.5))
			global_position = p
			if not _swoop_hit:
				for group in [&"player", &"companions"]:
					for n in get_tree().get_nodes_in_group(group):
						var t := n as Node3D
						if t and t.global_position.distance_to(global_position - Vector3.UP * 1.0) < 2.2 and t.has_method("on_attacked"):
							_swoop_hit = true
							t.on_attacked(swoop_damage, self)
			if k >= 1.0:
				_release_swoop()
				_recover(1.8)  # low and exposed
		S.RECOVER:
			model.play(&"idle")
			if _t >= _recover_time():
				_enter(S.CIRCLE)
		S.LAST_STAND:
			# Subahu hovers in his smoke, still raining fire.
			_angle += delta * 0.25
			_move_to(_orbit_point() - Vector3.UP * 1.0, 4.0, delta)
			_face(center - global_position, delta)
			_attack_cd -= delta
			if _attack_cd <= 0.0:
				_attack_cd = 3.2
				_volley()
		S.YIELDING:
			# Maricha drops low near the altar's edge and will not fight.
			var goal := center + (global_position - center).normalized() * 9.0
			goal.y = center.y + 3.0
			_move_to(goal, 3.0, delta)
			_face(center - global_position, delta)
			model.play(&"hit", 0.3, 0.2)
		S.BANISHED:
			var k := clampf(_t / 3.0, 0.0, 1.0)
			global_position = _swoop_from.lerp(_swoop_from + sea_direction * 260.0, k * k) + Vector3.UP * 60.0 * sin(k * PI) * 0.6
			rotation.z += delta * 9.0
			model.scale = Vector3.ONE * SCALE * (1.0 - k * 0.9)
			if k >= 1.0:
				visible = false
				set_physics_process(false)


var _recover_seconds := 1.0


func _recover_time() -> float:
	return _recover_seconds


func _recover(seconds: float) -> void:
	_recover_seconds = seconds
	model.set_glow(0.0)
	_attack_cd = randf_range(2.2, 3.4)
	_enter(S.RECOVER)


func _enter(s: int) -> void:
	state = s
	_t = 0.0


## They keep to the far side of the altar from Rama, sweeping back and forth
## across that arc, so on a phone they stay in front of the camera.
func _orbit_point() -> Vector3:
	var a := _arc_angle()
	return center + Vector3(sin(a), 0, cos(a)) * orbit_radius + Vector3.UP * orbit_height


func _arc_angle() -> float:
	var r := _rama()
	var away := (center - r.global_position) if r else Vector3.FORWARD
	var base := atan2(away.x, away.z)
	return base + sin(_angle) * 1.25


func _tangent() -> Vector3:
	var a := _arc_angle()
	return Vector3(cos(a), 0, -sin(a)) * (_orbit_dir if cos(_angle) >= 0.0 else -_orbit_dir)


func _move_to(goal: Vector3, speed: float, delta: float) -> void:
	global_position = global_position.move_toward(goal, speed * delta)


func _face(dir: Vector3, delta: float) -> void:
	dir.y = 0.0
	if dir.length_squared() > 0.0001:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), clampf(5.0 * delta, 0.0, 1.0))


func _rama() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _target_point() -> Vector3:
	var r := _rama()
	return r.global_position if r else center


func _choose_attack() -> void:
	var r := _rama()
	if r == null:
		_attack_cd = 1.0
		return
	if (_swooper == null or not is_instance_valid(_swooper)) and randf() < 0.45:
		_swooper = self
		_swoop_to = r.global_position + Vector3.UP * 1.2
		_swoop_hit = false
		_enter(S.SWOOP_WINDUP)
	else:
		_enter(S.VOLLEY)


func _release_swoop() -> void:
	if _swooper == self:
		_swooper = null


func _volley() -> void:
	var targets: Array[Vector3] = []
	var r := _rama()
	if kind == Kind.SUBAHU:
		# Fire on the altar, on Rama, and on a hut.
		targets.append(center + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)))
		if r:
			targets.append(Vector3(r.global_position.x, center.y, r.global_position.z))
		var huts := get_tree().get_nodes_in_group(&"huts")
		if not huts.is_empty():
			targets.append((huts.pick_random() as Node3D).global_position)
	else:
		for n in get_tree().get_nodes_in_group(&"companions") + ([r] if r else []):
			var t := n as Node3D
			if t:
				targets.append(Vector3(t.global_position.x, center.y, t.global_position.z))
		if r:
			targets.append(Vector3(r.global_position.x, center.y, r.global_position.z) + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
	for i in targets.size():
		var b := BOLT.instantiate() as Boulder
		b.kind = &"fire" if kind == Kind.SUBAHU else &"shard"
		b.start = global_position + Vector3.UP * 1.0
		b.end = targets[i]
		b.arc_height = 3.0
		b.radius = 2.0
		b.damage = volley_damage
		b.thrower = self
		b.flight_time = 1.15 + i * 0.15
		get_parent().add_child(b)
	_sound(SFX_GROWL, -2.0, 0.9 if kind == Kind.SUBAHU else 1.1)


# --- Damage, endings -------------------------------------------------------------

func _on_damaged(_amount: float, _source: Node) -> void:
	model.hit_flash(Color(1.0, 0.95, 0.85), 1.3)
	if health.is_dead():
		return
	if kind == Kind.SUBAHU and state != S.LAST_STAND and health.ratio() < SUBAHU_SHIELD_AT:
		# Smoke shield: arrows can no longer harm him. Only Agni can.
		health.invulnerable = true
		_shield.emitting = true
		_release_swoop()
		_attack_cd = 1.5
		_enter(S.LAST_STAND)
		shielded.emit(self)
	elif kind == Kind.MARICHA and state != S.YIELDING and health.ratio() < MARICHA_YIELD_AT:
		health.invulnerable = true  # Rama does not take his life
		_release_swoop()
		model.set_glow(0.0)
		_enter(S.YIELDING)
		yielded.emit(self)


## Called by Explosion for any astra that catches him.
func on_astra(astra: AstraResource, source: Node) -> void:
	if kind == Kind.SUBAHU and state == S.LAST_STAND and astra.effect == AstraResource.Effect.FIRE:
		health.invulnerable = false
		_shield.emitting = false
		health.take_damage(health.current + 1.0, source)


## The Manavastra: carried far over the sea, alive.
func banish(_source: Node) -> void:
	if kind != Kind.MARICHA or state != S.YIELDING:
		return
	remove_from_group(&"enemies")
	collision_layer = 0
	_swoop_from = global_position
	var d := sea_direction - global_position
	d.y = 0.0
	sea_direction = d.normalized()
	_enter(S.BANISHED)
	_sound(SFX_GROWL, 4.0, 0.5)
	banished.emit(self)


func _on_died() -> void:
	_release_swoop()
	state = S.DEAD
	remove_from_group(&"enemies")
	collision_layer = 0
	_shield.emitting = false
	_cloud.emitting = false
	model.set_glow(0.0)
	model.play(&"death", 0.2, 0.7)
	# He falls out of the sky.
	var t := create_tween()
	t.tween_property(self, "global_position:y", center.y, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(func() -> void:
		FX.burst(get_parent(), global_position + Vector3.UP * 0.5, Color(0.3, 0.2, 0.15, 0.8), 30, 6.0, 1.0, 1.0, -2.0, true))
	defeated.emit(self)


func _exit_tree() -> void:
	_release_swoop()


func _particles(color: Color, size: float, amount: int, radius: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.4
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.DOWN
	p.spread = 70.0
	p.gravity = Vector3(0, -0.4, 0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	var m := FX.glow_quad(color, size)
	(m.surface_get_material(0) as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	p.mesh = m
	add_child(p)
	return p


func _sound(stream: AudioStream, volume_db: float, pitch: float) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 25.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
