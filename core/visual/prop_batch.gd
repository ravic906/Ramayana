class_name PropBatch
extends RefCounted
## Collects many small bone-attached prop meshes and merges them into one
## mesh per (bone, material, shadow) group, cutting draw calls (each separate
## MeshInstance costs an opaque, outline and shadow pass on phones).

var skeleton: Skeleton3D
var _groups := {}


func _init(sk: Skeleton3D) -> void:
	skeleton = sk


## `rest_xf` is authored in the skeleton's rest-pose space.
func add(bone: String, mesh: Mesh, material: Material, rest_xf: Transform3D, casts_shadow: bool = false) -> void:
	var key := "%s#%d#%s" % [bone, material.get_instance_id(), casts_shadow]
	if not _groups.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_groups[key] = {"bone": bone, "material": material, "st": st, "shadow": casts_shadow}
	var local := skeleton.get_bone_global_rest(skeleton.find_bone(bone)).affine_inverse() * rest_xf
	for s in mesh.get_surface_count():
		(_groups[key]["st"] as SurfaceTool).append_from(mesh, s, local)


## Builds the merged meshes and attaches them; returns the created instances.
func commit() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for g in _groups.values():
		var mi := MeshInstance3D.new()
		mi.mesh = (g["st"] as SurfaceTool).commit()
		mi.material_override = g["material"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if g["shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var att_name: String = "Att_" + g["bone"]
		var att := skeleton.get_node_or_null(att_name) as BoneAttachment3D
		if att == null:
			att = BoneAttachment3D.new()
			att.name = att_name
			att.bone_name = g["bone"]
			skeleton.add_child(att)
		att.add_child(mi)
		out.append(mi)
	_groups.clear()
	return out
