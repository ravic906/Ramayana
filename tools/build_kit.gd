extends SceneTree
## Shared helpers for the environment builders (newer builders extend this):
## merged meshes per material, region-masked architecture, colliders,
## multimeshes, nature meshes with LODs, lamps. Subclasses fill `env_root` in
## build() and set OUT_SCENE via out_scene().

const M := "res://assets/materials/env/"
const NATURE := "res://assets/env/nature/"
const ARCH_MASKS := {"sandstone": Color(0, 0, 0), "red_sandstone": Color(1, 0, 0), "marble": Color(0, 1, 0), "dark_stone": Color(0, 0, 1)}
const NATURE_MATS := {
	"Bark_NormalTree": "bark", "Leaves_NormalTree": "leaves_jungle", "Leaves_TwistedTree": "leaves_dark",
	"Bark_TwistedTree": "bark_twisted", "Bark_DeadTree": "bark_dead", "Leaves": "plant", "Flowers": "flowers",
	"Grass": "grass", "Rocks": "rock", "Mushrooms": "mushrooms", "PathRocks": "pathrocks",
}

var rng := RandomNumberGenerator.new()
var env_root: Node3D
var body: StaticBody3D
var mats := {}
var _groups := {}


func out_scene() -> String:
	return ""


func build() -> void:
	pass


func _initialize() -> void:
	env_root = Node3D.new()
	env_root.name = out_scene().get_file().get_basename().to_pascal_case()
	body = StaticBody3D.new()
	body.name = "Collision"
	env_root.add_child(body)
	build()
	flush()
	print("Lightmap UVs: %d meshes" % LightmapUV.unwrap_all(env_root, 0.3))
	_own(env_root, env_root)
	var packed := PackedScene.new()
	var err := packed.pack(env_root)
	if err == OK:
		err = ResourceSaver.save(packed, out_scene(), ResourceSaver.FLAG_COMPRESS)
	print("Saved %s: %s" % [out_scene(), error_string(err)])
	quit(0 if err == OK else 1)


func mat(name: String) -> Material:
	if not mats.has(name):
		mats[name] = load(M + name + ".tres")
	return mats[name]


func at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


## Queues geometry into one merged mesh per material (architecture materials
## become region masks on the shared "arch" material).
func put(mesh: Mesh, xf: Transform3D, material: String) -> void:
	if ARCH_MASKS.has(material):
		mesh = _masked(mesh, ARCH_MASKS[material])
		material = "arch"
	if not _groups.has(material):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_groups[material] = st
	for s in mesh.get_surface_count():
		(_groups[material] as SurfaceTool).append_from(mesh, s, xf)


func box(size: Vector3, center: Vector3, material: String, basis := Basis(), collide := false) -> void:
	put(MeshKit.box(size), Transform3D(basis, center), material)
	if collide:
		collider_box(size, Transform3D(basis, center))


func _masked(mesh: Mesh, mask: Color) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var colors := PackedColorArray()
		colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		colors.fill(mask)
		arrays[Mesh.ARRAY_COLOR] = colors
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


func flush() -> void:
	for material: String in _groups:
		var mi := MeshInstance3D.new()
		mi.name = "Static_" + material
		mi.mesh = (_groups[material] as SurfaceTool).commit()
		mi.material_override = mat(material)
		env_root.add_child(mi)
	_groups.clear()


func collider_box(size: Vector3, xf: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)


func collider_cyl(pos: Vector3, radius: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	cs.position = pos + Vector3.UP * height * 0.5
	body.add_child(cs)


func multimesh(name: String, mesh: Mesh, xforms: Array, shadows := true, range_end := 0.0) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if range_end > 0.0:
		mmi.visibility_range_end = range_end
	env_root.add_child(mmi)
	return mmi


func nature_mesh(file: String) -> Mesh:
	var inst := (load(NATURE + file + ".gltf") as PackedScene).instantiate()
	var mi := inst.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var src_mesh := mi.mesh as ArrayMesh
	var im := ImporterMesh.new()
	for s in src_mesh.get_surface_count():
		var src := src_mesh.surface_get_material(s)
		var key: String = NATURE_MATS.get(src.resource_name if src else "", "plant")
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, src_mesh.surface_get_arrays(s), [], {}, mat(key))
	im.generate_lods(25.0, 60.0, [])
	inst.free()
	return im.get_mesh()


func rand_xf(pos: Vector3, scale_range: Vector2, tilt := 0.0) -> Transform3D:
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	if tilt > 0.0:
		b = Basis(Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5).normalized(), rng.randf() * tilt) * b
	return Transform3D(b.scaled(Vector3.ONE * rng.randf_range(scale_range.x, scale_range.y)), pos)


## Lamp posts (gold stands, flame cards) with a few real lights.
func lamps(points: Array, lit_every := 2) -> void:
	var xf := []
	var flames := []
	for p: Vector3 in points:
		put(MeshKit.cyl(0.22, 0.28, 0.12, 10), Transform3D(Basis(), p + Vector3.UP * 0.06), "gold")
		put(MeshKit.cyl(0.04, 0.06, 1.4, 6), Transform3D(Basis(), p + Vector3.UP * 0.8), "gold")
		put(MeshKit.cyl(0.2, 0.06, 0.12, 10), Transform3D(Basis(), p + Vector3.UP * 1.52), "gold")
		flames.append(Transform3D(Basis(), p + Vector3(0, 1.62, 0)))
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.42)
	var mmi := multimesh("LampFlames", quad, flames, false)
	mmi.material_override = mat("flame")
	for i in points.size():
		if i % lit_every != 0:
			continue
		var light := OmniLight3D.new()
		light.name = "LampLight%d" % i
		light.light_color = Color(1.0, 0.65, 0.3)
		light.light_energy = 1.3
		light.omni_range = 6.0
		light.position = (points[i] as Vector3) + Vector3(0, 1.7, 0)
		env_root.add_child(light)


func marker(name: String, p: Vector3) -> void:
	var m := Marker3D.new()
	m.name = name
	m.position = p
	env_root.add_child(m)


func _own(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_own(c, owner_node)
