class_name WaypointBeacon
extends Node3D
## A soft column of golden light over the current objective, so it can be
## found from afar. Fades when Rama is close (it must never clutter a fight).

const NEAR := 6.0
const FAR := 14.0

var target: Node3D
var _beam: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	top_level = true
	_beam = MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.18
	m.bottom_radius = 0.45
	m.height = 14.0
	m.radial_segments = 12
	m.rings = 1
	m.cap_top = false
	m.cap_bottom = false
	_beam.mesh = m
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_color = Color(1.0, 0.8, 0.35, 0.0)
	_mat.albedo_texture = _gradient()
	_beam.material_override = _mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position.y = 7.0
	add_child(_beam)


func _process(_delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		visible = false
		return
	visible = true
	global_position = target.global_position
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var d := player.global_position.distance_to(global_position) if player else FAR
	_mat.albedo_color.a = 0.32 * clampf((d - NEAR) / (FAR - NEAR), 0.0, 1.0)


## Vertical fade: bright at the base, gone at the top.
static func _gradient() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 1))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 64
	return t
