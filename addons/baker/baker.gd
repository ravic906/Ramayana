@tool
extends EditorPlugin
## Bakes the LightmapGI of the scene named in BAKE_SCENE, then quits: Godot
## exposes no bake call to scripts, so this presses the editor's own
## "Bake Lightmaps" button (see tools/bake_lightmaps.sh). Does nothing in
## normal editor sessions.
##
## The game's default look is Realistic, so the bake sees the scene as the
## StyleSwitcher would set it: realistic environment and sun, PBR materials.
## Everything is put back before the scene is saved.


func _enter_tree() -> void:
	if OS.get_environment("BAKE_SCENE") == "":
		return
	_go.call_deferred()


func _go() -> void:
	await get_tree().create_timer(2.0).timeout
	var path := OS.get_environment("BAKE_SCENE")
	# The bake reimports its own images; wait until the editor's first scan is over.
	var fs := EditorInterface.get_resource_filesystem()
	while fs.is_scanning():
		await get_tree().create_timer(1.0).timeout
	await get_tree().create_timer(3.0).timeout
	EditorInterface.open_scene_from_path(path)
	await get_tree().create_timer(2.0).timeout
	var scene := EditorInterface.get_edited_scene_root()
	var lms := scene.find_children("*", "LightmapGI", true, false)
	if lms.is_empty():
		printerr("BAKER: no LightmapGI in ", path)
		get_tree().quit(1)
		return
	var lm := lms[0] as LightmapGI
	var restore := _realistic(scene) if OS.get_environment("BAKE_STYLE") != "stylised" else {}
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(lm)
	EditorInterface.edit_node(lm)
	await get_tree().create_timer(1.0).timeout
	var btn: Button = null
	for b in EditorInterface.get_base_control().find_children("*", "Button", true, false):
		if (b as Button).text == "Bake Lightmaps" and (b as Button).is_visible_in_tree():
			btn = b
	if btn == null:
		printerr("BAKER: no bake button")
		get_tree().quit(1)
		return
	# Everything not baked into the lightmap stays out of the bake (dynamic
	# geometry inside it darkens the probes it is later lit by).
	# Only the level's environment is baked: characters, props and spawned
	# things must never take a lightmap slot (a body swapped in later would
	# be painted with the old one's).
	var env := scene.get_node_or_null("Environment")
	var excluded := []
	var modes := {}
	for gi: GeometryInstance3D in scene.find_children("*", "GeometryInstance3D", true, false):
		var in_env := env != null and env.is_ancestor_of(gi)
		if gi.gi_mode == GeometryInstance3D.GI_MODE_DYNAMIC or not in_env:
			excluded.append(gi)
			modes[gi] = gi.gi_mode
			gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	printerr("BAKER: ", excluded.size(), " dynamic objects kept out of the bake")
	# Light probes for everything that moves (characters, foliage batches):
	# a grid over the level's static geometry at body heights. Godot's own
	# probe placement produced none here, so they are placed explicitly.
	var probes := _place_probes(scene, lm)
	printerr("BAKER: ", probes.size(), " light probes placed")
	var old := lm.light_data
	lm.light_data = null
	var t0 := Time.get_ticks_msec()
	btn.pressed.emit()
	# The first bake asks where to save the .lmbake: next to the scene.
	await get_tree().create_timer(1.5).timeout
	for d in EditorInterface.get_base_control().find_children("*", "EditorFileDialog", true, false):
		var dlg := d as EditorFileDialog
		if dlg.visible:
			dlg.hide()
			dlg.file_selected.emit(path.get_basename() + ".lmbake")
	var limit := int(OS.get_environment("BAKE_TIMEOUT_S")) if OS.get_environment("BAKE_TIMEOUT_S") != "" else 3600
	while lm.light_data == null and Time.get_ticks_msec() - t0 < limit * 1000:
		await get_tree().create_timer(2.0).timeout
	var ok := lm.light_data != null
	if not ok:
		lm.light_data = old
	printerr("BAKER: done=", ok, " in ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
	# The level loads the data itself (BakedLighting.baked_data), on the main
	# thread: referenced from the scene it can deadlock the threaded load.
	if ok and "baked_data" in lm:
		lm.set("baked_data", lm.light_data.resource_path)
		lm.light_data = null
	_restore(restore)
	for pr: Node in probes:
		pr.get_parent().remove_child(pr)
		pr.free()
	for gi: GeometryInstance3D in excluded:
		gi.gi_mode = modes[gi]
	EditorInterface.save_scene()
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(0 if ok else 1)


## Applies the Realistic look in the edited scene; returns what to put back.
func _realistic(scene: Node) -> Dictionary:
	var out := {"materials": []}
	var sw: Node = null
	for n in scene.find_children("*", "Node", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("style_switcher.gd"):
			sw = n
	if sw == null:
		return out
	var we := sw.get_node_or_null(sw.get("world_environment_path")) as WorldEnvironment
	var sun := sw.get_node_or_null(sw.get("sun_path")) as DirectionalLight3D
	if we:
		out["env"] = [we, we.environment]
		we.environment = load(sw.get("realistic_environment"))
	if sun:
		out["sun"] = [sun, sun.rotation, sun.light_energy, sun.light_color]
		sun.rotation = Vector3(deg_to_rad(sw.get("realistic_sun_pitch_deg")), sun.rotation.y, 0.0)
		sun.light_energy = sw.get("realistic_sun_energy")
		sun.light_color = sw.get("realistic_sun_color")
	var map: Dictionary = sw.get_script().get_script_constant_map()["MAP"]
	for gi: GeometryInstance3D in scene.find_children("*", "GeometryInstance3D", true, false):
		if gi.material_override and map.has(gi.material_override.resource_path):
			out["materials"].append([gi, gi.material_override])
			gi.material_override = load(map[gi.material_override.resource_path])
	printerr("BAKER: realistic look, ", out["materials"].size(), " materials swapped")
	return out


func _restore(r: Dictionary) -> void:
	if r.has("env"):
		(r["env"][0] as WorldEnvironment).environment = r["env"][1]
	if r.has("sun"):
		var sun: DirectionalLight3D = r["sun"][0]
		sun.rotation = r["sun"][1]
		sun.light_energy = r["sun"][2]
		sun.light_color = r["sun"][3]
	for pair: Array in r.get("materials", []):
		(pair[0] as GeometryInstance3D).material_override = pair[1]


func _place_probes(scene: Node, lm: LightmapGI) -> Array:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if mi.gi_mode != GeometryInstance3D.GI_MODE_STATIC or mi.mesh == null:
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var out := []
	if first:
		return out
	var spacing := 4.0
	var min_x := maxf(box.position.x, -70.0)
	var max_x := minf(box.end.x, 70.0)
	var min_z := maxf(box.position.z, -200.0)
	var max_z := minf(box.end.z, 200.0)
	var nx := int((max_x - min_x) / spacing) + 1
	var nz := int((max_z - min_z) / spacing) + 1
	if nx * nz > 1500:
		spacing *= sqrt(float(nx * nz) / 1500.0)
		nx = int((max_x - min_x) / spacing) + 1
		nz = int((max_z - min_z) / spacing) + 1
	var space := (scene as Node3D).get_world_3d().direct_space_state
	for ix in nx:
		for iz in nz:
			var x := min_x + ix * spacing
			var z := min_z + iz * spacing
			# stand on the ground where there is one
			var ground := 0.0
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -20, z)))
			if hit:
				ground = (hit["position"] as Vector3).y
			for h in [0.5, 1.6, 3.0]:
				var p := LightmapProbe.new()
				lm.get_parent().add_child(p)
				p.global_position = Vector3(x, ground + h, z)
				out.append(p)
	return out
