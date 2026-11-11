extends Node
## Player-facing settings, saved to user://settings.cfg.
##   visual_style: Realistic (default: physically based materials + photographed
##                 sky) or Stylised (toon, the original Art Bible look).
##   difficulty:   Story (for the tale: Rama takes half damage, foes are weaker,
##                 aim assist is wider, the perfect window longer), Warrior (the
##                 full challenge) or Maharathi (hard: foes hit harder, last
##                 longer and strike sooner; unlocked once Tataka is defeated).
##                 `story_mode` reads/writes Story vs Warrior for older code.
##   difficulty_chosen: the player picked a mode (asked once, on first Play).
##   quality:      Battery saver / Balanced (default) / High: frame cap, 3D render
##                 scale (FSR upscaling, the UI stays sharp), shadows, glow and
##                 particle counts. Phones heat up fast at native resolution and
##                 an uncapped 90-120 Hz, so even High is capped at 60 fps.
##   low_quality:  legacy flag = the Battery saver preset.
##   music_volume / sfx_volume / voice_volume: 0..1, applied to their buses.
## Command-line overrides (after "--"): --low-quality, --realistic, --stylised.

signal style_changed(style: int)

enum VisualStyle { STYLISED, REALISTIC }

const DEFAULT_PATH := "user://settings.cfg"

## Realistic is the default look (approved by the owner); Stylised stays available.
var visual_style := VisualStyle.REALISTIC
var low_quality := false
enum Quality { BATTERY, BALANCED, HIGH }
var quality := Quality.BALANCED
## "menu" / "game" / "cinematic": menus and cutscenes need fewer frames.
var fps_context := "game"
enum Difficulty { STORY, WARRIOR, MAHARATHI }
var difficulty := Difficulty.WARRIOR
var story_mode: bool:
	get:
		return difficulty == Difficulty.STORY
	set(value):
		difficulty = Difficulty.STORY if value else (Difficulty.WARRIOR if difficulty == Difficulty.STORY else difficulty)
var difficulty_chosen := false
var music_volume := 0.8
var sfx_volume := 1.0
var voice_volume := 1.0
var config_path := DEFAULT_PATH


func _ready() -> void:
	ensure_audio_buses()
	load_settings()
	var args := OS.get_cmdline_user_args()
	if "--low-quality" in args:
		low_quality = true
		quality = Quality.BATTERY
	apply_quality()
	if "--realistic" in args:
		visual_style = VisualStyle.REALISTIC
	elif "--stylised" in args:
		visual_style = VisualStyle.STYLISED


func set_story_mode(on: bool) -> void:
	set_difficulty(Difficulty.STORY if on else Difficulty.WARRIOR)


func set_difficulty(d: Difficulty) -> void:
	if d == Difficulty.MAHARATHI and not maharathi_unlocked():
		d = Difficulty.WARRIOR
	difficulty = d
	difficulty_chosen = true
	save_settings()


## Maharathi opens once Tataka has been defeated in the story.
func maharathi_unlocked() -> bool:
	var gs := get_node_or_null("/root/GameState")
	return gs != null and bool(gs.get_flag("tataka_defeated", false))


## The next mode for a toggle button (skips Maharathi while it is locked).
func next_difficulty() -> Difficulty:
	var n := (difficulty + 1) % 3 as Difficulty
	if n == Difficulty.MAHARATHI and not maharathi_unlocked():
		n = Difficulty.STORY
	return n


func mode_name() -> String:
	return ["Story", "Warrior", "Maharathi"][difficulty]


## Scales damage Rama (and what he protects) receives.
func incoming_damage_scale() -> float:
	return [0.5, 1.0, 1.5][difficulty]


## Scales enemy (and boss) health.
func enemy_health_scale() -> float:
	return [0.8, 1.0, 1.3][difficulty]


## Scales how long foes wind up an attack (shorter = less time to react).
func telegraph_scale() -> float:
	return [1.15, 1.0, 0.85][difficulty]


## Added to the perfect-release window (seconds).
func perfect_window_bonus() -> float:
	return [0.2, 0.0, -0.05][difficulty]


## Scales the aim-assist cone.
func assist_scale() -> float:
	return [1.6, 1.0, 0.8][difficulty]


func is_realistic() -> bool:
	return visual_style == VisualStyle.REALISTIC


func set_visual_style(style: int) -> void:
	if style == visual_style:
		return
	visual_style = style
	save_settings()
	style_changed.emit(style)


func toggle_visual_style() -> void:
	set_visual_style(VisualStyle.STYLISED if is_realistic() else VisualStyle.REALISTIC)


func style_name() -> String:
	return "Realistic" if is_realistic() else "Stylised"


func save_settings() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "visual_style", visual_style)
	cfg.set_value("graphics", "low_quality", low_quality)
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("gameplay", "difficulty", difficulty)
	cfg.set_value("gameplay", "difficulty_chosen", difficulty_chosen)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "voice_volume", voice_volume)
	return cfg.save(config_path)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(config_path) != OK:
		return
	visual_style = int(cfg.get_value("graphics", "visual_style", VisualStyle.REALISTIC))
	low_quality = bool(cfg.get_value("graphics", "low_quality", false))
	quality = int(cfg.get_value("graphics", "quality", Quality.BATTERY if low_quality else Quality.BALANCED))
	low_quality = quality == Quality.BATTERY
	# Older configs saved only story_mode.
	var legacy := Difficulty.STORY if bool(cfg.get_value("gameplay", "story_mode", false)) else Difficulty.WARRIOR
	difficulty = clampi(int(cfg.get_value("gameplay", "difficulty", legacy)), 0, 2) as Difficulty
	difficulty_chosen = bool(cfg.get_value("gameplay", "difficulty_chosen", false))
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", 1.0)), 0.0, 1.0)
	voice_volume = clampf(float(cfg.get_value("audio", "voice_volume", 1.0)), 0.0, 1.0)
	apply_audio()


## Creates the Music, SFX and Voice buses (all feed Master) if they don't exist.
func ensure_audio_buses() -> void:
	for bus_name in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, &"Master")
	apply_audio()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	apply_audio()
	save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	apply_audio()
	save_settings()


func set_voice_volume(v: float) -> void:
	voice_volume = clampf(v, 0.0, 1.0)
	apply_audio()
	save_settings()


func apply_audio() -> void:
	for pair in [["Music", music_volume], ["SFX", sfx_volume], ["Voice", voice_volume]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i != -1:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(pair[1], 0.0001)))
			AudioServer.set_bus_mute(i, pair[1] <= 0.001)


func set_quality(q: int) -> void:
	quality = clampi(q, Quality.BATTERY, Quality.HIGH)
	low_quality = quality == Quality.BATTERY
	save_settings()
	apply_quality()
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene:
		apply_to_sun(scene.get_node_or_null("Sun") as DirectionalLight3D)


func quality_name() -> String:
	return ["Battery saver", "Balanced", "High"][quality]


func cycle_quality() -> void:
	set_quality((quality + 1) % 3)


## Frames per second for the current context and preset.
func target_fps() -> int:
	if fps_context != "game":
		return 30
	return 30 if quality == Quality.BATTERY else 60


func set_fps_context(context: String) -> void:
	fps_context = context
	Engine.max_fps = target_fps()


## Frame cap, 3D render scale and anti-aliasing for the whole game.
func apply_quality() -> void:
	Engine.max_fps = target_fps()
	if not is_inside_tree():
		return
	var vp := get_tree().root
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if RenderingServer.get_rendering_device() != null \
		else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = [0.6, 0.75, 0.85][quality]
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality == Quality.HIGH else Viewport.SCREEN_SPACE_AA_DISABLED


## Per-level: the sun's shadows, the environment's glow, and ambient particles.
func apply_to_sun(sun: DirectionalLight3D) -> void:
	if sun == null:
		return
	sun.shadow_enabled = true
	match quality:
		Quality.BATTERY:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.directional_shadow_max_distance = 20.0
		Quality.BALANCED:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 26.0
		_:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 32.0
	var level := sun.get_parent()
	var we := level.get_node_or_null("WorldEnvironment") as WorldEnvironment if level else null
	if we and we.environment:
		we.environment.glow_enabled = quality != Quality.BATTERY
	if level:
		_scale_particles(level, 0.5 if quality == Quality.BATTERY else 1.0)


## Ambient particles (mist, fireflies, spores...) are thinned on Battery saver.
func _scale_particles(root: Node, k: float) -> void:
	for p in root.find_children("*", "CPUParticles3D", true, false):
		var cp := p as CPUParticles3D
		if not cp.has_meta(&"base_amount"):
			cp.set_meta(&"base_amount", cp.amount)
		cp.amount = maxi(int(int(cp.get_meta(&"base_amount")) * k), 1)
