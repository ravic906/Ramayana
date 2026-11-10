class_name FirePatch
extends Node3D
## Burning ground. Agneyastra's burns enemies; a `hostile` patch (Subahu's fire
## bolts) burns Rama, his companions and the sacred fire instead. Varunastra
## quenches either kind.

const TICK := 0.5

var radius := 2.5
var dps := 8.0
var duration := 3.0
var burn_dps := 5.0
var source: Node
var hostile := false
var _age := 0.0
var _tick := 0.0
var _disc: MeshInstance3D
var _flames: CPUParticles3D


func _ready() -> void:
	_disc = MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = 0.02
	m.radial_segments = 24
	_disc.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.35, 0.05, 0.45)
	mat.albedo_texture = FX._soft_dot()
	_disc.material_override = mat
	_disc.position.y = 0.03
	add_child(_disc)
	_flames = CPUParticles3D.new()
	_flames.amount = 60
	_flames.lifetime = 0.8
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_flames.emission_ring_axis = Vector3.UP
	_flames.emission_ring_radius = radius * 0.8
	_flames.emission_ring_inner_radius = 0.0
	_flames.emission_ring_height = 0.05
	_flames.direction = Vector3.UP
	_flames.spread = 10.0
	_flames.initial_velocity_min = 1.0
	_flames.initial_velocity_max = 2.6
	_flames.mesh = FX.glow_quad(Color(1.0, 0.5, 0.12), 0.45)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	_flames.scale_amount_curve = curve
	add_child(_flames)


func _physics_process(delta: float) -> void:
	_age += delta
	_tick -= delta
	if _tick <= 0.0:
		_tick += TICK
		if hostile:
			_burn_the_righteous()
		for enemy in ([] if hostile else get_tree().get_nodes_in_group(&"enemies")):
			var e := enemy as Node3D
			if e == null:
				continue
			var d := Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length()
			if d <= radius:
				var h := e.get_node_or_null("Health") as Health
				if h:
					h.take_damage(dps * TICK, source)
				Burn.apply(e, burn_dps, 1.5, source)
	var fade := clampf((duration - _age) / 0.6, 0.0, 1.0)
	(_disc.material_override as StandardMaterial3D).albedo_color.a = 0.45 * fade
	_flames.emitting = fade > 0.3
	if _age >= duration:
		queue_free()


func _burn_the_righteous() -> void:
	for group in [&"player", &"companions", &"objective", &"bystanders"]:
		for n in get_tree().get_nodes_in_group(group):
			var t := n as Node3D
			if t == null:
				continue
			var reach = t.get("reach_radius")
			var r := radius + (float(reach) if reach != null else 0.0)
			var d := Vector2(t.global_position.x - global_position.x, t.global_position.z - global_position.z).length()
			if d <= r and t.has_method("on_attacked"):
				t.on_attacked(dps * TICK, source)

