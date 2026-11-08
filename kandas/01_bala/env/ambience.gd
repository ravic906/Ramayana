class_name Ambience
extends Node3D
## Living touches for the training grounds: flocks of birds circling in the
## golden sky and dust motes drifting in the sunlight. Disabled on low quality.

@export var flocks := 3
@export var birds_per_flock := 7
@export var dust_amount := 140

var _birds: MultiMeshInstance3D
var _flock_params: Array = []


func _ready() -> void:
	if Settings.low_quality:
		return
	_build_birds()
	_build_dust()


func _process(_delta: float) -> void:
	if _birds == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var mm := _birds.multimesh
	var i := 0
	for f in _flock_params:
		var center: Vector3 = f["center"]
		for b in birds_per_flock:
			var a: float = f["phase"] + t * f["speed"] + b * 0.11
			var r: float = f["radius"] + sin(b * 2.3) * 3.0
			var pos := center + Vector3(cos(a) * r, sin(t * 0.7 + b) * 1.5 + b * 0.4, sin(a) * r)
			var tangent := Vector3(-sin(a), 0, cos(a)) * signf(f["speed"])
			var basis := Basis.looking_at(tangent, Vector3.UP)
			mm.set_instance_transform(i, Transform3D(basis, pos))
			i += 1


func _build_birds() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		st.add_vertex(Vector3(0, 0, -0.25))
		st.add_vertex(Vector3(0.9 * side, 0.05, 0.15))
		st.add_vertex(Vector3(0, 0, 0.3))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = st.commit()
	mm.instance_count = flocks * birds_per_flock
	_birds = MultiMeshInstance3D.new()
	_birds.name = "Birds"
	_birds.multimesh = mm
	_birds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/bird.gdshader")
	_birds.material_override = mat
	add_child(_birds)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for f in flocks:
		_flock_params.append({
			"center": Vector3(rng.randf_range(-40, 40), rng.randf_range(26, 42), rng.randf_range(-80, -10)),
			"radius": rng.randf_range(14, 26),
			"speed": rng.randf_range(0.12, 0.2) * (1.0 if f % 2 == 0 else -1.0),
			"phase": rng.randf() * TAU,
		})


func _build_dust() -> void:
	var p := CPUParticles3D.new()
	p.name = "Dust"
	p.amount = dust_amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(30, 4, 30)
	p.direction = Vector3(1, 0.2, 0.3)
	p.spread = 40.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	p.mesh = FX.glow_quad(Color(1.0, 0.85, 0.55, 0.6), 0.07)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.position = Vector3(0, 3.5, -18)
	add_child(p)
