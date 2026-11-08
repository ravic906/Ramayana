class_name Burn
extends Node3D
## Burning status: ticks damage on the parent's Health, with embers and a
## crackle. Re-applying refreshes the duration (never stacks).

const TICK := 0.5
const SFX_BURN := preload("res://assets/audio/sfx/burn_loop.wav")

var dps := 5.0
var time_left := 3.0
var source: Node
var _tick := TICK


static func apply(target: Node, damage_per_second: float, duration: float, from: Node = null) -> Burn:
	if target == null or not (target is Node3D) or target.get_node_or_null("Health") == null:
		return null
	var burn := target.get_node_or_null("Burn") as Burn
	if burn == null:
		burn = Burn.new()
		burn.name = "Burn"
		target.add_child(burn)
	burn.dps = maxf(burn.dps if burn.time_left > 0.0 else 0.0, damage_per_second)
	burn.time_left = maxf(burn.time_left, duration)
	burn.source = from
	return burn


func _ready() -> void:
	position = Vector3.UP * 1.0
	var embers := CPUParticles3D.new()
	embers.amount = 24
	embers.lifetime = 0.7
	embers.local_coords = false
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 0.35
	embers.direction = Vector3.UP
	embers.spread = 20.0
	embers.initial_velocity_min = 0.6
	embers.initial_velocity_max = 1.6
	embers.gravity = Vector3(0, 1.5, 0)
	embers.mesh = FX.glow_quad(Color(1.0, 0.45, 0.1), 0.12)
	add_child(embers)
	var crackle := AudioStreamPlayer3D.new()
	var looped := SFX_BURN.duplicate() as AudioStreamWAV
	looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
	looped.loop_end = int(looped.get_length() * looped.mix_rate)
	crackle.stream = looped
	crackle.volume_db = -8.0
	crackle.unit_size = 6.0
	add_child(crackle)
	crackle.play()


func _physics_process(delta: float) -> void:
	var health := get_parent().get_node_or_null("Health") as Health
	if health == null or health.is_dead():
		queue_free()
		return
	time_left -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick += TICK
		health.take_damage(dps * TICK, source)
	if time_left <= 0.0:
		queue_free()
