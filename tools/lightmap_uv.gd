class_name LightmapUV
extends RefCounted
## Build-time helper: gives the static meshes of an environment a second UV
## set (UV2) for baked lighting, and marks what takes part in the bake.
## Distant scenery and water stay out (they gain nothing and cost atlas space).

const SKIP := ["water", "sky", "hills", "skyline", "flame", "banner", "river"]


## texel: metres per lightmap texel (0.25 = four texels per metre).
static func unwrap_all(root: Node, texel := 0.25) -> int:
	var n := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var skip := false
		for word: String in SKIP:
			if word in String(mi.name).to_lower() or word in String(mi.get_parent().name).to_lower():
				skip = true
		var am := mi.mesh as ArrayMesh
		if skip or am == null or am.get_surface_count() == 0:
			mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC  # lit by the probes
			continue
		if am.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV2 == 0:
			var mat := mi.material_override
			if am.lightmap_unwrap(mi.global_transform if mi.is_inside_tree() else Transform3D(), texel) != OK:
				push_warning("Lightmap unwrap failed: %s" % mi.name)
				mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
				continue
			mi.material_override = mat
		mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		n += 1
	for mmi: MultiMeshInstance3D in root.find_children("*", "MultiMeshInstance3D", true, false):
		split_into_clusters(mmi)
	# Batches (trees, plants, props) are lit by the baked light probes. They
	# must stay out of the bake itself (addons/baker excludes them while it
	# runs), or the probes come out black around them.
	for mmi: MultiMeshInstance3D in root.find_children("*", "MultiMeshInstance3D", true, false):
		mmi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	return n


## A MultiMesh takes its light from the probes at one point, the centre of
## its bounds; for a batch scattered across a level that point can be inside
## a wall, which turns the whole batch black. Splits a batch into clusters of
## nearby instances (cells of `cell` metres), each sampling near its own trees.
static func split_into_clusters(mmi: MultiMeshInstance3D, cell := 10.0) -> void:
	var mm := mmi.multimesh
	if mm == null or mm.instance_count < 2:
		return
	var cells := {}
	for i in mm.instance_count:
		var xf := mm.get_instance_transform(i)
		var key := Vector2i(floori(xf.origin.x / cell), floori(xf.origin.z / cell))
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(xf)
	if cells.size() < 2:
		return
	var parent := mmi.get_parent()
	var k := 0
	for key: Vector2i in cells:
		var xfs: Array = cells[key]
		var part := MultiMeshInstance3D.new()
		var pm := MultiMesh.new()
		pm.transform_format = MultiMesh.TRANSFORM_3D
		pm.mesh = mm.mesh
		pm.instance_count = xfs.size()
		for i in xfs.size():
			pm.set_instance_transform(i, xfs[i])
		part.multimesh = pm
		part.name = "%s_c%d" % [mmi.name, k]
		part.transform = mmi.transform
		part.visible = mmi.visible
		part.material_override = mmi.material_override
		part.cast_shadow = mmi.cast_shadow
		part.visibility_range_end = mmi.visibility_range_end
		for g in mmi.get_groups():
			if not String(g).begins_with("_"):
				part.add_to_group(g, true)
		for meta in mmi.get_meta_list():
			part.set_meta(meta, mmi.get_meta(meta))
		parent.add_child(part)
		k += 1
	parent.remove_child(mmi)
	mmi.free()
