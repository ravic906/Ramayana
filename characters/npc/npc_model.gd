class_name NpcModel
extends Node3D
## A story character on the shared rig: palette (skin / lower garment / trim /
## sash), hair and beard colour, and simple props (crown, sage's topknot, staff).
## Follows the visual style setting like the rakshasas do.

@export var skin := Color(0.72, 0.52, 0.38)
@export var garment := Color(0.92, 0.55, 0.18)
@export var trim := Color(0.8, 0.6, 0.2)
@export var sash := Color(0.95, 0.85, 0.65)
@export var hair_color := Color(0.1, 0.07, 0.05)
@export var beard := false
@export var crown := false
@export var topknot := false
@export var staff := false
@export var model_scale := 1.0

@onready var body: Node3D = $Body
@onready var skeleton: Skeleton3D = $Body/Armature/Skeleton3D
@onready var anim: AnimationPlayer = $Body/AnimationPlayer

var _staff: Node3D


func _ready() -> void:
	body.scale = Vector3.ONE * model_scale
	_apply_style()
	Settings.style_changed.connect(func(_s: int) -> void: _apply_style())
	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = hair_color
	hair_mat.roughness = 0.8
	hair_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for n in ["Hair", "Beard"]:
		var mi := skeleton.find_child(n, true, false) as MeshInstance3D
		if mi:
			mi.material_override = hair_mat
	(skeleton.get_node("Eyebrows") as MeshInstance3D).material_override = hair_mat
	var beard_mi := skeleton.find_child("Beard", true, false) as MeshInstance3D
	if beard_mi:
		beard_mi.visible = beard
	_build_props()
	anim.play(&"idle")
	anim.seek(randf() * 2.0)


signal hurt(npc: NpcModel)


## Bystanders (the sages at the yagna) flinch when struck but are never killed.
func on_attacked(_damage: float, _source: Node) -> bool:
	hurt.emit(self)
	anim.play(&"hit", 0.1)
	anim.queue(&"idle")
	return true


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.3


func play(clip: StringName, blend := 0.2) -> void:
	anim.play(clip, blend)


## Walks to `target` (world) over `seconds`, then idles.
func walk_to(target: Vector3, seconds: float) -> Tween:
	var flat := target - global_position
	flat.y = 0.0
	if flat.length_squared() > 0.01:
		rotation.y = atan2(flat.x, flat.z)
	play(&"walk")
	var t := create_tween()
	t.tween_property(self, "global_position", target, seconds)
	t.tween_callback(play.bind(&"idle"))
	return t


func face(point: Vector3) -> void:
	var d := point - global_position
	rotation.y = atan2(d.x, d.z)


func _process(_delta: float) -> void:
	if _staff:
		var hand := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("hand_r")).origin
		_staff.global_transform = Transform3D(Basis(), hand + Vector3(0, -0.25, 0))


func _apply_style() -> void:
	var path := "res://assets/materials/env_real/rama_body_pbr.tres" if Settings.is_realistic() else "res://assets/materials/rama_body.tres"
	var mat := (load(path) as ShaderMaterial).duplicate() as ShaderMaterial
	mat.set_shader_parameter(&"region_base", skin)
	mat.set_shader_parameter(&"region_r", garment)
	mat.set_shader_parameter(&"region_g", trim)
	mat.set_shader_parameter(&"region_b", sash)
	(skeleton.get_node("Body") as MeshInstance3D).material_override = mat


func _build_props() -> void:
	var batch := PropBatch.new(skeleton)
	var gold: Material = load("res://assets/materials/gold.tres")
	if crown:
		batch.add("Head", MeshKit.cyl(0.105, 0.115, 0.09, 16), gold, Transform3D(Basis(), Vector3(0, 1.75, -0.01)))
		batch.add("Head", MeshKit.cyl(0.05, 0.1, 0.12, 12), gold, Transform3D(Basis(), Vector3(0, 1.85, -0.01)))
		batch.add("Head", MeshKit.sphere(0.035), gold, Transform3D(Basis(), Vector3(0, 1.93, -0.01)))
	if topknot:
		var hair := StandardMaterial3D.new()
		hair.albedo_color = hair_color
		batch.add("Head", MeshKit.sphere(0.085, 10), hair, Transform3D(Basis().scaled(Vector3(1, 1.2, 1)), Vector3(0, 1.84, -0.03)))
		batch.add("Head", MeshKit.torus(0.05, 0.075, 12), load("res://assets/materials/wood.tres"), Transform3D(Basis(), Vector3(0, 1.79, -0.03)))
	batch.commit()
	if staff:
		_staff = Node3D.new()
		_staff.top_level = true
		_staff.add_child(MeshKit.instance(MeshKit.cyl(0.025, 0.03, 1.9, 6), load("res://assets/materials/wood.tres"),
			Transform3D(Basis(), Vector3(0, 0.15, 0))))
		add_child(_staff)
