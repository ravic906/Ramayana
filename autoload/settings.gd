extends Node
## Player-facing settings, saved to user://settings.cfg.
##   visual_style: Realistic (default: physically based materials + photographed
##                 sky) or Stylised (toon, the original Art Bible look).
##   story_mode:   gentler boss damage for younger players.
##   low_quality:  turns off ambient life and real-time shadows.
##   music_volume / sfx_volume / voice_volume: 0..1, applied to their buses.
## Command-line overrides (after "--"): --low-quality, --realistic, --stylised.

signal style_changed(style: int)

enum VisualStyle { STYLISED, REALISTIC }

const DEFAULT_PATH := "user://settings.cfg"

## Realistic is the default look (approved by the owner); Stylised stays available.
var visual_style := VisualStyle.REALISTIC
var low_quality := false
var story_mode := false
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
	if "--realistic" in args:
		visual_style = VisualStyle.REALISTIC
	elif "--stylised" in args:
		visual_style = VisualStyle.STYLISED


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
	cfg.set_value("gameplay", "story_mode", story_mode)
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
	story_mode = bool(cfg.get_value("gameplay", "story_mode", false))
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


func apply_to_sun(sun: DirectionalLight3D) -> void:
	if sun:
		sun.shadow_enabled = not low_quality
