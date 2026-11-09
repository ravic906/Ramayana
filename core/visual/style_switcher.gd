class_name StyleSwitcher
extends Node
## Switches a level between the Stylised (toon) and Realistic (PBR) looks:
## swaps materials by resource path across the scene (including nodes that
## spawn later), the WorldEnvironment, and the sun, and adds a reflection probe
## for the Realistic look. Driven by the Settings autoload.

const MAP := {
	"res://assets/materials/env/arch.tres": "res://assets/materials/env_real/arch_pbr.tres",
	"res://assets/materials/env/paving.tres": "res://assets/materials/env_real/paving_pbr.tres",
	"res://assets/materials/env/gold.tres": "res://assets/materials/env_real/gold_pbr.tres",
	"res://assets/materials/env/wood.tres": "res://assets/materials/env_real/wood_pbr.tres",
	"res://assets/materials/env/cloth_red.tres": "res://assets/materials/env_real/cloth_red_pbr.tres",
	"res://assets/materials/gold.tres": "res://assets/materials/env_real/gold_pbr.tres",
	"res://assets/materials/gold_plain.tres": "res://assets/materials/env_real/gold_pbr.tres",
	"res://assets/materials/ruby.tres": "res://assets/materials/env_real/ruby_pbr.tres",
	"res://assets/materials/pearl.tres": "res://assets/materials/env_real/pearl_pbr.tres",
	"res://assets/materials/wood.tres": "res://assets/materials/env_real/wood_pbr.tres",
	"res://assets/materials/rama_body.tres": "res://assets/materials/env_real/rama_body_pbr.tres",
	"res://assets/materials/env/bark.tres": "res://assets/materials/env_real/bark_pbr.tres",
	"res://assets/materials/env/leaves.tres": "res://assets/materials/env_real/leaves_pbr.tres",
	"res://assets/materials/env/leaves_b.tres": "res://assets/materials/env_real/leaves_b_pbr.tres",
	"res://assets/materials/env/plant.tres": "res://assets/materials/env_real/plant_pbr.tres",
	"res://assets/materials/env/flowers.tres": "res://assets/materials/env_real/flowers_pbr.tres",
	"res://assets/materials/env/grass.tres": "res://assets/materials/env_real/grass_pbr.tres",
	"res://assets/materials/env/rock.tres": "res://assets/materials/env_real/rock_pbr.tres",
}
const REALISTIC_ENV := "res://assets/env/real/realistic_environment.tres"

@export var world_environment_path: NodePath
@export var sun_path: NodePath
## Sun settings for the Realistic look (matches the photographed sky's sun).
@export var realistic_sun_pitch_deg := -7.0
@export var realistic_sun_energy := 3.2
@export var realistic_sun_color := Color(1.0, 0.76, 0.52)

var style := -1
var _world_env: WorldEnvironment
var _sun: DirectionalLight3D
var _stylised_env: Environment
var _stylised_sun := {}
var _probe: ReflectionProbe
var _forward := {}
var _reverse := {}


func _ready() -> void:
	_world_env = get_node_or_null(world_environment_path) as WorldEnvironment
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	if _world_env:
		_stylised_env = _world_env.environment
	if _sun:
		_stylised_sun = {"rotation": _sun.rotation, "energy": _sun.light_energy, "color": _sun.light_color}
	for k: String in MAP:
		_forward[k] = MAP[k]
		_reverse[MAP[k]] = k
	get_tree().node_added.connect(_on_node_added)
	Settings.style_changed.connect(apply)
	apply.call_deferred(Settings.visual_style)


func apply(new_style: int) -> void:
	style = new_style
	var realistic := style == Settings.VisualStyle.REALISTIC
	_apply_materials(get_tree().current_scene if get_tree().current_scene else get_parent(), realistic)
	if _world_env:
		_world_env.environment = load(REALISTIC_ENV) if realistic else _stylised_env
	if _sun:
		if realistic:
			_sun.rotation = Vector3(deg_to_rad(realistic_sun_pitch_deg), _stylised_sun["rotation"].y, 0.0)
			_sun.light_energy = realistic_sun_energy
			_sun.light_color = realistic_sun_color
		elif not _stylised_sun.is_empty():
			_sun.rotation = _stylised_sun["rotation"]
			_sun.light_energy = _stylised_sun["energy"]
			_sun.light_color = _stylised_sun["color"]
	_set_probe(realistic)


func _on_node_added(node: Node) -> void:
	if style == Settings.VisualStyle.REALISTIC and node is GeometryInstance3D:
		_apply_node.call_deferred(node, true)


func _apply_materials(root: Node, realistic: bool) -> void:
	if root == null:
		return
	if root is GeometryInstance3D:
		_apply_node(root, realistic)
	for child in root.get_children():
		_apply_materials(child, realistic)


func _apply_node(node: Node, realistic: bool) -> void:
	if not is_instance_valid(node):
		return
	var gi := node as GeometryInstance3D
	var table: Dictionary = _forward if realistic else _reverse
	if gi.material_override and table.has(gi.material_override.resource_path):
		gi.material_override = load(table[gi.material_override.resource_path])
	# MultiMeshes carry per-surface materials on their (scene-local) mesh.
	var mmi := node as MultiMeshInstance3D
	if mmi and mmi.multimesh and mmi.multimesh.mesh:
		var mesh := mmi.multimesh.mesh
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s)
			if m and table.has(m.resource_path):
				mesh.surface_set_material(s, load(table[m.resource_path]))
	var mi := node as MeshInstance3D
	if mi and mi.mesh:
		for s in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(s)
			if base == null:
				continue
			if realistic and _forward.has(base.resource_path):
				mi.set_surface_override_material(s, load(_forward[base.resource_path]))
			elif not realistic:
				var over := mi.get_surface_override_material(s)
				if over and _reverse.has(over.resource_path):
					mi.set_surface_override_material(s, null)


func _set_probe(on: bool) -> void:
	if on and _probe == null:
		_probe = ReflectionProbe.new()
		_probe.name = "CourtyardReflections"
		_probe.size = Vector3(60, 22, 64)
		_probe.position = Vector3(0, 6, -18)
		_probe.update_mode = ReflectionProbe.UPDATE_ONCE
		_probe.box_projection = true
		get_parent().add_child(_probe)
	elif not on and _probe != null:
		_probe.queue_free()
		_probe = null
