class_name TargetDummy
extends StaticBody3D
## Straw archery butt: flashes when hit, topples on "death"
## and respawns after a short delay.

@export var respawn_delay := 2.0
@export var hit_color := Color(1.0, 0.85, 0.3)

@onready var health: Health = $Health
@onready var mesh: MeshInstance3D = $Mesh

var _material: StandardMaterial3D
var _base_color: Color


func _ready() -> void:
	add_to_group(&"enemies")
	_material = (mesh.get_active_material(0) as StandardMaterial3D).duplicate()
	mesh.set_surface_override_material(0, _material)
	_base_color = _material.albedo_color
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.15


func _on_damaged(_amount: float, _source: Node) -> void:
	_material.albedo_color = hit_color
	var tween := create_tween()
	tween.tween_property(_material, "albedo_color", _base_color, 0.25)


func _on_died() -> void:
	GameState.add_punya(10)
	var tween := create_tween()
	tween.tween_property(mesh, "rotation_degrees:x", -85.0, 0.35)
	tween.tween_interval(respawn_delay)
	tween.tween_property(mesh, "rotation_degrees:x", 0.0, 0.35)
	tween.tween_callback(health.revive)
