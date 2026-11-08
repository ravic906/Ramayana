class_name Arrow
extends Node3D
## Straight-flying projectile. Each physics frame it ray-sweeps the segment it
## travels, so fast arrows never tunnel through thin targets, and it damages
## the first collider that has a Health child. On impact: sparks, sound,
## hit-stop and a stuck arrow left in the target.

signal impacted(position: Vector3, collider: Object, killed: bool)

@export var speed := 40.0
@export var damage := 10.0
@export var lifetime := 2.0
## Layers 1 (world) and 3 (enemies).
@export_flags_3d_physics var collision_mask := 5

const SFX_IMPACT := preload("res://assets/audio/sfx/impact.wav")

var direction := Vector3.FORWARD
var shooter: Node = null
## A perfect release: brighter trail, bigger impact.
var perfect := false
## Leave the arrow stuck in what it hits (off for arrows aimed at Rama).
var stick := true
## Divine payload released on impact (e.g. Agneyastra).
var astra: AstraResource
var _flames: CPUParticles3D
var _age := 0.0
var _trail: MeshInstance3D


func _ready() -> void:
	_trail = MeshInstance3D.new()
	var quad := BoxMesh.new()
	quad.size = Vector3(0.012, 0.012, 1.0)
	_trail.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.75, 0.3, 0.6)
	_trail.material_override = mat
	add_child(_trail)
	_update_trail(0.0)


func launch(dir: Vector3, from: Node, dmg: float = damage, arrow_speed: float = speed, is_perfect: bool = false) -> void:
	direction = dir.normalized()
	shooter = from
	damage = dmg
	speed = arrow_speed
	perfect = is_perfect
	if direction.length_squared() > 0.0:
		look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.FORWARD)
	if perfect and _trail:
		(_trail.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.85, 0.35, 1.0)
		_trail.scale = Vector3(1.6, 1.6, 1.0)


func set_trail_color(color: Color) -> void:
	if _trail:
		(_trail.material_override as StandardMaterial3D).albedo_color = color


## Turns this arrow into an astra: fiery trail and flames in flight.
func set_astra(a: AstraResource) -> void:
	astra = a
	if a == null:
		return
	set_trail_color(Color(a.color, 1.0))
	_trail.scale = Vector3(3.0, 3.0, 1.6)
	_flames = CPUParticles3D.new()
	_flames.amount = 40
	_flames.lifetime = 0.35
	_flames.local_coords = false
	_flames.direction = Vector3(0, 0, 1)
	_flames.spread = 25.0
	_flames.initial_velocity_min = 1.0
	_flames.initial_velocity_max = 3.0
	_flames.gravity = Vector3(0, 2.0, 0)
	_flames.mesh = FX.glow_quad(a.color, 0.16)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	_flames.scale_amount_curve = curve
	add_child(_flames)
	var light := OmniLight3D.new()
	light.light_color = a.color
	light.light_energy = 2.0
	light.omni_range = 4.0
	add_child(light)


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	query.collide_with_areas = true
	if shooter is CollisionObject3D:
		query.exclude = [(shooter as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"]
		_on_hit(hit["collider"], hit["position"])
		return
	global_position = to
	_age += delta
	_update_trail(minf(_age * 6.0, 1.0))
	if _age >= lifetime:
		if astra != null:
			Explosion.detonate(get_parent(), global_position, astra, shooter)
			impacted.emit(global_position, null, false)
		queue_free()


func _update_trail(grow: float) -> void:
	if _trail == null:
		return
	var length := (0.9 if perfect else 0.6) * grow
	_trail.scale.z = maxf(length, 0.001)
	_trail.position = Vector3(0, 0, 0.4 + length * 0.5)


func _on_hit(other: Object, at: Vector3) -> void:
	var killed := false
	var health: Health = null
	if other is Node:
		health = (other as Node).get_node_or_null("Health") as Health
	if health != null:
		var was_alive := not health.is_dead()
		health.take_damage(damage, shooter)
		killed = was_alive and health.is_dead()
		if stick:
			_leave_stuck_arrow(other as Node3D, at)
		var tfx := get_node_or_null("/root/TimeFX")
		if tfx:
			tfx.hitstop(0.09 if (perfect or killed) else 0.05)
		Haptics.pulse(45, 0.9 if killed else 0.6)
	var parent := get_parent()
	if astra != null:
		Explosion.detonate(parent, at - direction * 0.2, astra, shooter)
	FX.sparks(parent, at, Color(1.0, 0.8, 0.35) if health else Color(0.8, 0.7, 0.55), 40 if perfect else 22, 7.0 if perfect else 5.0)
	_play_at(parent, SFX_IMPACT, at, 0.0 if health else -6.0)
	impacted.emit(at, other, killed)
	queue_free()


func _leave_stuck_arrow(target: Node3D, at: Vector3) -> void:
	if target == null:
		return
	var stuck := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.008
	shaft.bottom_radius = 0.008
	shaft.height = 0.5
	stuck.mesh = shaft
	stuck.material_override = load("res://assets/materials/gold_plain.tres")
	target.add_child(stuck)
	stuck.global_transform = Transform3D(
		Basis.looking_at(direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.FORWARD) * Basis(Vector3.RIGHT, PI / 2),
		at - direction * 0.18)
	get_tree().create_timer(4.0).timeout.connect(stuck.queue_free)


static func _play_at(parent: Node, stream: AudioStream, at: Vector3, volume_db: float) -> void:
	if parent == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.unit_size = 8.0
	parent.add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)
