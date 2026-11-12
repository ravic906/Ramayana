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
	# Batches (trees, plants, props) stay out of the bake (addons/baker
	# excludes dynamic objects while it runs); foliage takes its ambient from
	# the gi_fill shader global (see core/visual/baked_lighting.gd).
	for mmi: MultiMeshInstance3D in root.find_children("*", "MultiMeshInstance3D", true, false):
		mmi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	return n

