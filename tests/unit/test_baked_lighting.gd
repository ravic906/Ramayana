extends TestCase
## Every level carries baked lighting whose data the level loads itself
## (never referenced from the scene file: that load can deadlock).

const LEVELS := ["training_grounds", "ayodhya_hub", "sarayu_road", "forest", "siddhashrama", "vishala", "gautama_ashram"]


func test_levels_have_baked_lighting_loaded_at_run_time() -> void:
	for lv: String in LEVELS:
		var path := "res://kandas/01_bala/%s.tscn" % lv
		var text := FileAccess.get_file_as_string(path)
		assert_true(not text.contains("LightmapGIData"), "%s does not reference its lightmap data directly" % lv)
		var n := (load(path) as PackedScene).instantiate()
		var lm := n.find_children("*", "LightmapGI", true, false)
		assert_true(lm.size() == 1 and lm[0] is BakedLighting, "%s has BakedLighting" % lv)
		if lm.size() == 1:
			var data: String = lm[0].baked_data
			assert_true(ResourceLoader.exists(data), "%s: baked data %s exists" % [lv, data])
		n.free()


func test_foliage_fill_is_set_and_cleared() -> void:
	var lm := BakedLighting.new()
	lm.environment_mode = LightmapGI.ENVIRONMENT_MODE_CUSTOM_COLOR
	lm.environment_custom_color = Color(0.5, 0.5, 0.5)
	lm.environment_custom_energy = 2.0
	add_child(lm)
	var fill: Color = RenderingServer.global_shader_parameter_get(&"gi_fill")
	assert_true(fill.r > 0.5, "fill set while the level runs")
	lm.free()
	fill = RenderingServer.global_shader_parameter_get(&"gi_fill")
	assert_true(fill.r == 0.0, "fill cleared when it leaves")
