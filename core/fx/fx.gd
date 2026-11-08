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
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = color
	mesh.material = mat
	p.mesh = mesh
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
