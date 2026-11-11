class_name RakshasaModel
extends Node3D
## Visual for a rakshasa: the shared rigged body with a rakshasa palette,
## glowing eyes, horns, tusks and a weapon. Animation is played directly on
## the body's AnimationPlayer with crossfades (cheaper than an AnimationTree).

enum Weapon { CLUB, BOW, NONE }

const MAT := "res://assets/materials/"

@export var weapon := Weapon.CLUB
@export var horns := true
@export var body_material := "res://assets/materials/rakshasa_body.tres"
@export var body_material_realistic := "res://assets/materials/env_real/rakshasa_body_pbr.tres"
@export var hair_material := "res://assets/materials/rakshasa_hair.tres"

@onready var body: Node3D = $Body
@onready var skeleton: Skeleton3D = $Body/Armature/Skeleton3D
@onready var anim: AnimationPlayer = $Body/AnimationPlayer

var _body_mat: ShaderMaterial
var _flash := 0.0
var _flash_color := Color.WHITE
var _glow := 0.0
var _current := &""


func _ready() -> void:
	_apply_style()
	Settings.style_changed.connect(func(_s: int) -> void: _apply_style())
	FaceController.set_eyes(skeleton, load(MAT + "rakshasa_eyes.tres"))
	var hair_mat: Material = load(hair_material)
	(skeleton.get_node("Eyebrows") as MeshInstance3D).material_override = hair_mat
	# Rakshasas keep the wild long hair.
	var gathered := skeleton.find_child("Hair", true, false) as MeshInstance3D
	var hair := skeleton.find_child("HairLong", true, false) as MeshInstance3D
	if hair and gathered:
		gathered.visible = false
		hair.visible = true
	elif gathered:
		hair = gathered
	if hair:
		hair.material_override = hair_mat
	_build_props()
	play(&"idle")


## Body material for the current visual style (duplicated: flashes are per rakshasa).
func _apply_style() -> void:
	var path := body_material_realistic if Settings.is_realistic() else body_material
	_body_mat = (load(path) as ShaderMaterial).duplicate()
	FaceController.set_skin(skeleton, _body_mat)


func _process(delta: float) -> void:
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	_body_mat.set_shader_parameter(&"flash", maxf(_flash, _glow))
	_body_mat.set_shader_parameter(&"flash_color", _flash_color if _flash > _glow else Color(1.0, 0.15, 0.05))


func play(clip: StringName, blend: float = 0.15, speed: float = 1.0) -> void:
	if _current == clip and anim.is_playing():
		anim.speed_scale = speed
		return
	_current = clip
	anim.play(clip, blend)
	anim.speed_scale = speed


func clip_length(clip: StringName) -> float:
	return anim.get_animation(clip).length if anim.has_animation(clip) else 1.0


## Brief white flash when hit.
func hit_flash(color: Color = Color.WHITE, strength: float = 1.5) -> void:
	_flash_color = color
	_flash = strength


## Sustained red glow during an attack wind-up (0 = off).
func set_glow(amount: float) -> void:
	_glow = amount


func _build_props() -> void:
	var batch := PropBatch.new(skeleton)
	var bone: Material = load(MAT + "bone.tres")
	# Horns sweep up and outward from the temples; tusks from the lower jaw.
	for side in [-1.0, 1.0]:
		if horns:
			batch.add("Head", MeshKit.cyl(0.0, 0.03, 0.2, 8), bone, Transform3D(
			MeshKit.basis_along(Vector3(0.55 * side, 1.0, -0.15)), Vector3(0.06 * side, 1.79, 0.0)))
		batch.add("Head", MeshKit.cyl(0.0, 0.009, 0.05, 6), bone, Transform3D(
			MeshKit.basis_along(Vector3(0.2 * side, 1.0, 0.25)), Vector3(0.025 * side, 1.635, 0.085)))
	# Bone necklace.
	batch.add("spine_03", MeshKit.torus(0.11, 0.125, 18), bone,
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(28)).scaled(Vector3(1, 1, 0.85)), Vector3(0, 1.47, -0.03)))
	# Short loincloth flaps (front and back) and belt.
	var cloth: Material = load(MAT + "loincloth.tres")
	for z in [0.115, -0.15]:
		batch.add("pelvis", MeshKit.box(Vector3(0.24, 0.42, 0.012)), cloth,
			Transform3D(Basis(Vector3.RIGHT, deg_to_rad(6.0 if z > 0 else -6.0)), Vector3(0, 0.8, z)), true)
	batch.add("pelvis", MeshKit.torus(0.15, 0.17, 20), cloth,
		Transform3D(Basis().scaled(Vector3(1.05, 1.6, 0.82)), Vector3(0, 0.99, -0.025)), true)
	if weapon == Weapon.CLUB:
		_build_club(batch, bone)
	elif weapon == Weapon.BOW:
		_build_bow(batch)
	batch.commit()


func _build_club(batch: PropBatch, spikes: Material) -> void:
	var wood: Material = load(MAT + "dark_wood.tres")
	# Rest pose: right arm along -X, so the club points forward (+Z) and a bit up.
	var grip := Transform3D(MeshKit.basis_along(Vector3(0.0, 0.5, 1.0)), Vector3(-0.77, 1.44, -0.05))
	batch.add("hand_r", MeshKit.cyl(0.07, 0.025, 0.8, 10), wood, grip * Transform3D(Basis(), Vector3(0, 0.35, 0)), true)
	for i in 6:
		var a := TAU * i / 6.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		batch.add("hand_r", MeshKit.cyl(0.0, 0.015, 0.07, 5), spikes,
			grip * Transform3D(MeshKit.basis_along(dir), Vector3(0, 0.6 + 0.08 * (i % 2), 0) + dir * 0.07))


func _build_bow(batch: PropBatch) -> void:
	var wood: Material = load(MAT + "dark_wood.tres")
	# Rest pose: left arm along +X; the bow stands vertical with its belly forward.
	var grip := Transform3D(Basis(), Vector3(0.77, 1.455, -0.06))
	var segs := 8
	for i in segs:
		var t0 := lerpf(-1.0, 1.0, float(i) / segs)
		var t1 := lerpf(-1.0, 1.0, float(i + 1) / segs)
		var p0 := Vector3(0.0, t0 * 0.6, 0.09 * (1.0 - t0 * t0))
		var p1 := Vector3(0.0, t1 * 0.6, 0.09 * (1.0 - t1 * t1))
		batch.add("hand_l", MeshKit.cyl(0.012, 0.012, p0.distance_to(p1), 6), wood,
			grip * Transform3D(MeshKit.basis_along(p1 - p0), (p0 + p1) * 0.5), true)
	batch.add("hand_l", MeshKit.cyl(0.002, 0.002, 1.2, 4), load(MAT + "string_mat.tres"), grip)
