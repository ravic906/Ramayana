extends TestCase
## Stylised <-> Realistic switching and settings persistence.

var level: Node3D
var _saved_style := 0


func before_each() -> void:
	_saved_style = Settings.visual_style
	Settings.config_path = "user://test_settings.cfg"
	Settings.visual_style = Settings.VisualStyle.STYLISED
	level = load("res://kandas/01_bala/training_grounds.tscn").instantiate()
	level.get_node("WaveSpawner").auto_start = false
	add_child(level)


func after_each() -> void:
	level.queue_free()
	Settings.visual_style = _saved_style
	DirAccess.remove_absolute(Settings.config_path)
	Settings.config_path = Settings.DEFAULT_PATH


func _paving() -> GeometryInstance3D:
	return level.get_node("Environment/Paving")


func _rama_body() -> MeshInstance3D:
	return level.get_node("Rama").model.skeleton.get_node("Body")


func test_switches_materials_environment_and_back() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_paving().material_override.resource_path, "res://assets/materials/env/paving.tres")
	var stylised_env: Environment = level.get_node("WorldEnvironment").environment
	Settings.set_visual_style(Settings.VisualStyle.REALISTIC)
	await get_tree().process_frame
	assert_eq(_paving().material_override.resource_path, "res://assets/materials/env_real/paving_pbr.tres")
	var body_mat := _rama_body().get_surface_override_material(0)
	assert_true(body_mat != null and body_mat.resource_path.ends_with("rama_body_pbr.tres"), "Rama body PBR")
	var env: Environment = level.get_node("WorldEnvironment").environment
	assert_true(env.sky.sky_material is PanoramaSkyMaterial, "photographed sky")
	assert_true(level.find_child("CourtyardReflections", true, false) != null, "reflection probe")
	# A rakshasa spawned now uses the realistic body too.
	var r: Rakshasa = level.get_node("WaveSpawner").spawn_enemy("grunt", Vector3(0, 0, -20))
	await get_tree().process_frame
	assert_eq(r.model._body_mat.shader.resource_path, "res://assets/shaders/character_pbr.gdshader")
	Settings.set_visual_style(Settings.VisualStyle.STYLISED)
	await get_tree().process_frame
	assert_eq(_paving().material_override.resource_path, "res://assets/materials/env/paving.tres")
	assert_null(_rama_body().get_surface_override_material(0))
	assert_eq(level.get_node("WorldEnvironment").environment, stylised_env)
	assert_eq(r.model._body_mat.shader.resource_path, "res://assets/shaders/toon.gdshader")


func test_style_persists() -> void:
	Settings.set_visual_style(Settings.VisualStyle.REALISTIC)
	Settings.visual_style = Settings.VisualStyle.STYLISED
	Settings.load_settings()
	assert_true(Settings.is_realistic(), "loaded from settings.cfg")
	Settings.set_visual_style(Settings.VisualStyle.STYLISED)
