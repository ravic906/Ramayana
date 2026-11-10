class_name SacredFire
extends Node3D
## The yagna's sacred fire on Vishvamitra's altar: what Rama defends at
## Siddhashrama. Raiders head for it ("objective" group) and Subahu's fire bolts
## rain on it. Its flames dim as it is defiled; at zero the yagna is broken.

signal defiled

## Rakshasas strike the fire from the altar's edge.
@export var reach_radius := 1.9

var health: Health
var _flames: CPUParticles3D
var _embers: CPUParticles3D
var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	add_to_group(&"objective")
	health = Health.new()
	health.name = "Health"
	health.max_health = 100.0
	add_child(health)
	health.died.connect(func() -> void: defiled.emit())
	health.damaged.connect(func(_a: float, _s: Node) -> void:
		FX.burst(get_parent(), global_position + Vector3.UP * 1.6, Color(0.25, 0.05, 0.05, 0.8), 14, 2.5, 0.7, 0.6, 0.3, true))
	_flames = CPUParticles3D.new()
	_flames.name = "Flames"
	_flames.amount = 36
	_flames.lifetime = 0.9
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flames.emission_box_extents = Vector3(0.5, 0.05, 0.5)  # fills the kund
	_flames.direction = Vector3.UP
	_flames.spread = 12.0
	_flames.gravity = Vector3(0, 2.2, 0)
	_flames.initial_velocity_min = 0.6
	_flames.initial_velocity_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	_flames.scale_amount_curve = curve
	# Low alpha + a colour ramp keep overlapping additive flames orange, not white.
	_flames.mesh = FX.glow_quad(Color(1.0, 0.55, 0.15, 0.32), 0.7)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.45, 1.0))
	ramp.add_point(0.35, Color(1.0, 0.45, 0.08, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.45, 0.06, 0.02, 0.0))
	_flames.color_ramp = ramp
	_flames.position = Vector3.UP * 0.1
	add_child(_flames)
	_embers = CPUParticles3D.new()
	_embers.name = "Embers"
	_embers.amount = 24
	_embers.lifetime = 2.5
	_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_embers.emission_sphere_radius = 0.5
	_embers.direction = Vector3.UP
	_embers.spread = 35.0
	_embers.gravity = Vector3(0, 0.8, 0)
	_embers.initial_velocity_min = 0.5
	_embers.initial_velocity_max = 1.5
	_embers.mesh = FX.glow_quad(Color(1.0, 0.75, 0.3, 0.9), 0.05)
	_embers.position = Vector3.UP * 0.5
	add_child(_embers)
	_light = OmniLight3D.new()
	_light.name = "FireLight"
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.omni_range = 16.0
	_light.omni_attenuation = 1.4
	_light.shadow_enabled = false
	_light.position = Vector3.UP * 1.2
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	var k := 0.25 + 0.75 * health.ratio()
	_light.light_energy = (2.6 + 0.35 * sin(_t * 11.0) + 0.2 * sin(_t * 17.3)) * k
	_flames.scale_amount_min = k
	_flames.scale_amount_max = k * 1.2


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.2


func can_be_targeted() -> bool:
	return not health.is_dead()


## Struck by a raider (melee) or a bolt.
func on_attacked(damage: float, source: Node) -> bool:
	health.take_damage(damage, source)
	return true


func rekindle() -> void:
	health.revive()
