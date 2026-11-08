class_name FX
extends RefCounted
## Small one-shot visual effects built in code (mobile-friendly CPU particles).


static func sparks(parent: Node, at: Vector3, color: Color, amount: int = 24, speed: float = 6.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.45
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.mesh = glow_quad(color, 0.06)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	_spawn(parent, p, at)


## Additive, camera-facing, soft round quad for particles.
static func glow_quad(color: Color, size: float) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	mat.albedo_texture = _soft_dot()
	mesh.material = mat
	return mesh


static var _dot: Texture2D


static func _soft_dot() -> Texture2D:
	if _dot == null:
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		g.gradient = grad
		g.width = 32
		g.height = 32
		_dot = g
	return _dot


## One-shot burst of flame/smoke particles.
static func burst(parent: Node, at: Vector3, color: Color, amount: int, speed: float, size: float,
		lifetime: float, gravity: float = 0.0, smoke: bool = false) -> CPUParticles3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.2
	p.gravity = Vector3(0, gravity, 0)
	p.mesh = glow_quad(color, size)
	if smoke:
		(p.mesh.surface_get_material(0) as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	if smoke:
		p.color = color
	_spawn(parent, p, at)
	return p


## Positions a one-shot emitter *before* it enters the tree (CPUParticles3D
## starts emitting on entering, in world space) and frees it when done.
static func _spawn(parent: Node, p: CPUParticles3D, at: Vector3) -> void:
	p.emitting = false
	p.position = (parent as Node3D).to_local(at) if parent is Node3D else at
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
