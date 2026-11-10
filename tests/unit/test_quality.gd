extends TestCase
## Thermal-friendly defaults and quality presets.

var _q := 1
var _path := ""


func before_each() -> void:
	_q = Settings.quality
	_path = Settings.config_path
	Settings.config_path = "user://test_quality.cfg"


func after_each() -> void:
	Settings.set_quality(_q)
	DirAccess.remove_absolute(Settings.config_path)
	Settings.config_path = _path
	Settings.set_fps_context("game")


func test_frames_are_capped() -> void:
	assert_eq(int(ProjectSettings.get_setting("application/run/max_fps")), 60, "never 90-120 fps on phones")
	Settings.set_quality(Settings.Quality.HIGH)
	Settings.set_fps_context("game")
	assert_eq(Engine.max_fps, 60)
	Settings.set_quality(Settings.Quality.BATTERY)
	assert_eq(Engine.max_fps, 30)
	Settings.set_quality(Settings.Quality.BALANCED)
	Settings.set_fps_context("menu")
	assert_eq(Engine.max_fps, 30, "menus don't need 60")
	Settings.set_fps_context("cinematic")
	assert_eq(Engine.max_fps, 30)


func test_render_scale_and_no_msaa() -> void:
	assert_eq(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")), 0)
	Settings.set_quality(Settings.Quality.BALANCED)
	var vp := get_tree().root
	assert_almost(vp.scaling_3d_scale, 0.75, 0.001)
	assert_eq(vp.msaa_3d, Viewport.MSAA_DISABLED)
	Settings.set_quality(Settings.Quality.BATTERY)
	assert_almost(vp.scaling_3d_scale, 0.6, 0.001)


func test_level_detail_follows_the_preset() -> void:
	var level: Node = load("res://kandas/01_bala/siddhashrama.tscn").instantiate()
	level.auto_start = false
	add_child(level)
	await get_tree().process_frame
	Settings.set_quality(Settings.Quality.BATTERY)
	var sun: DirectionalLight3D = level.get_node("Sun")
	Settings.apply_to_sun(sun)
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_ORTHOGONAL)
	assert_false((level.get_node("WorldEnvironment") as WorldEnvironment).environment.glow_enabled)
	var flies := level.find_child("Fireflies", true, false) as CPUParticles3D
	assert_eq(flies.amount, 30, "ambient particles halved")
	Settings.set_quality(Settings.Quality.BALANCED)
	Settings.apply_to_sun(sun)
	assert_eq(flies.amount, 60)
	assert_true((level.get_node("WorldEnvironment") as WorldEnvironment).environment.glow_enabled)
	level.queue_free()
	Music.stop()


func test_preset_is_saved() -> void:
	Settings.set_quality(Settings.Quality.HIGH)
	Settings.quality = Settings.Quality.BATTERY
	Settings.load_settings()
	assert_eq(Settings.quality, Settings.Quality.HIGH)
