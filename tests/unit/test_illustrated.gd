extends TestCase
## The illustrated-look trial: Mission 1's level restyles itself and forces the
## stylised bodies while it is open; the player's saved look is untouched.

var _style := 0


func before_each() -> void:
	_style = Settings.visual_style
	Settings.visual_style = Settings.VisualStyle.REALISTIC


func after_each() -> void:
	Settings.visual_style = _style
	Settings.style_override = -1
	TimeFX.clear_all()


func _open() -> Node3D:
	var level: Node3D = load("res://kandas/01_bala/training_grounds.tscn").instantiate()
	level.get_node("WaveSpawner").auto_start = false
	add_child(level)
	return level


func test_training_grounds_is_illustrated() -> void:
	var level := _open()
	assert_false(Settings.is_realistic(), "stylised bodies while the level is open")
	assert_eq(Settings.visual_style, Settings.VisualStyle.REALISTIC, "the saved choice is not changed")
	for i in 5:
		await get_tree().process_frame
	assert_true(level.get_node_or_null("IllustratedLook") != null, "look node added")
	var painted := 0
	for mi in level.get_node("Environment").find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count() if mi.mesh else 0:
			var m := mi.get_active_material(s) as ShaderMaterial
			if m and m.shader and m.shader.resource_path.ends_with("toon_painted.gdshader"):
				painted += 1
	assert_true(painted > 0, "architecture uses the painted toon shader")
	var we := level.get_node("WorldEnvironment") as WorldEnvironment
	var sky := we.environment.sky.sky_material as ShaderMaterial
	assert_true(sky.shader.resource_path.ends_with("sky_painted.gdshader"), "painted dusk sky")
	level.free()
	assert_true(Settings.is_realistic(), "override cleared when the level closes")


func test_other_levels_keep_the_players_look() -> void:
	var level: Node3D = load("res://kandas/01_bala/ayodhya_hub.tscn").instantiate()
	add_child(level)
	assert_true(Settings.is_realistic())
	assert_true(level.get_node_or_null("IllustratedLook") == null)
	level.free()
