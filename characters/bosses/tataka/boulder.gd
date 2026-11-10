class_name Boulder
extends Area3D
## A projectile hurled along a high arc: Tataka's boulders, Subahu's fire bolts
## (kind "fire": they leave burning ground) and Maricha's blood shards (kind
## "shard"). Rama can shoot them down (they are in the "enemies" group, so aim
## assist finds them); a red ring marks where they will land. Landing hurts
## Rama, his companions and the sacred fire.

signal shot_down(boulder: Boulder)

const SFX_HIT := preload("res://assets/audio/sfx/club_hit.wav")

var start := Vector3.ZERO
var end := Vector3.ZERO
var flight_time := 1.3
var arc_height := 7.0
var damage := 20.0
var radius := 2.4
var thrower: Node
## "rock", "fire" or "shard".
var kind := &"rock"
var _t := 0.0
var _marker: MeshInstance3D
var _rock: MeshInstance3D

@onready var health: Health = $Health


func _ready() -> void:
	add_to_group(&"enemies")
	health.died.connect(_on_shot)
	_rock = MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.75 if kind == &"rock" else 0.45
	m.height = 1.3 if kind == &"rock" else (0.9 if kind == &"fire" else 1.4)
	m.radial_segments = 10
	m.rings = 6
	_rock.mesh = m
	if kind == &"rock":
		_rock.material_override = load("res://assets/materials/env/dark_stone.tres")
	else:
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(1.0, 0.5, 0.1) if kind == &"fire" else Color(0.55, 0.05, 0.08)
		_rock.material_override = glow
		var trail := CPUParticles3D.new()
		trail.amount = 24
		trail.lifetime = 0.5
		trail.local_coords = false
		trail.gravity = Vector3.ZERO
		trail.mesh = FX.glow_quad(Color(1.0, 0.45, 0.1, 0.8) if kind == &"fire" else Color(0.5, 0.05, 0.1, 0.8), 0.35)
		add_child(trail)
	add_child(_rock)
	_marker = MeshInstance3D.new()
	_marker.mesh = MeshKit.torus(radius - 0.15, radius, 28)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 0.15, 0.1, 0.7)
	_marker.material_override = mat
	_marker.top_level = true
	add_child(_marker)
	_marker.global_position = end + Vector3.UP * 0.05
	_marker.scale = Vector3(1, 0.2, 1)
	global_position = start


func get_aim_point() -> Vector3:
	return global_position


func _physics_process(delta: float) -> void:
	_t += delta
	var s := clampf(_t / flight_time, 0.0, 1.0)
	global_position = start.lerp(end, s) + Vector3.UP * (4.0 * arc_height * s * (1.0 - s))
	_rock.rotation += Vector3(3.0, 2.0, 0.0) * delta
	(_marker.material_override as StandardMaterial3D).albedo_color.a = 0.35 + 0.5 * s
	if s >= 1.0:
		_land()


func _land() -> void:
	var parent := get_parent()
	FX.burst(parent, end + Vector3.UP * 0.4, Color(0.45, 0.38, 0.3, 0.7), 18, 5.0, 0.8, 0.9, -2.0, true)
	_play(parent, end)
	for group in [&"player", &"companions", &"objective", &"bystanders"]:
		for p in get_tree().get_nodes_in_group(group):
			var t := p as Node3D
			if t == null or not t.has_method("on_attacked"):
				continue
			var reach = t.get("reach_radius")
			var r := radius + (float(reach) if reach != null else 0.0)
			if t.global_position.distance_to(end) < r:
				t.on_attacked(damage, thrower)
	if kind == &"fire":
		var patch := FirePatch.new()
		patch.hostile = true
		patch.radius = 2.2
		patch.dps = 6.0
		patch.duration = 7.0
		patch.source = thrower
		parent.add_child(patch)
		patch.global_position = end
	var cam := get_viewport().get_camera_3d()
	var rig := cam.get_parent().get_parent() as FollowCamera if cam and cam.get_parent() else null
	if rig:
		rig.shake(0.35)
	queue_free()


func _on_shot() -> void:
	FX.sparks(get_parent(), global_position, Color(0.8, 0.7, 0.55), 30, 6.0)
	FX.burst(get_parent(), global_position, Color(0.4, 0.35, 0.3, 0.7), 12, 4.0, 0.6, 0.6, -6.0, true)
	shot_down.emit(self)
	queue_free()


func _play(parent: Node, at: Vector3) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = SFX_HIT
	p.pitch_scale = 0.6
	p.volume_db = 4.0
	p.unit_size = 15.0
	parent.add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)
