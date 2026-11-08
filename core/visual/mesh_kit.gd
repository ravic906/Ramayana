class_name MeshKit
extends RefCounted
## Small procedural mesh + bone-attachment helpers for prototype props.


static func cyl(top: float, bottom: float, height: float, segments: int = 10) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


static func sphere(r: float, segments: int = 12) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segments
	m.rings = maxi(segments / 2, 4)
	return m


static func torus(inner: float, outer: float, segments: int = 16) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = segments
	m.ring_segments = 8
	return m


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func instance(mesh: Mesh, material: Material, xf: Transform3D = Transform3D.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.transform = xf
	return mi


## Attaches `node` to `bone`, placing it with a transform authored in the
## skeleton's rest-pose space. Reuses one BoneAttachment3D per bone.
static func attach(skeleton: Skeleton3D, bone: String, node: Node3D, rest_xf: Transform3D) -> void:
	var att_name := "Att_" + bone
	var att := skeleton.get_node_or_null(att_name) as BoneAttachment3D
	if att == null:
		att = BoneAttachment3D.new()
		att.name = att_name
		att.bone_name = bone
		skeleton.add_child(att)
	node.transform = skeleton.get_bone_global_rest(skeleton.find_bone(bone)).affine_inverse() * rest_xf
	att.add_child(node)


## Basis whose Y axis points along `dir`.
static func basis_along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	return Basis(x, y, x.cross(y))
