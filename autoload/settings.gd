extends Node
## Player-facing settings, saved to user://settings.cfg.
##   visual_style: Realistic (default: physically based materials + photographed
##                 sky) or Stylised (toon, the original Art Bible look).
##   story_mode:   gentler boss damage for younger players.
##   low_quality:  turns off ambient life and real-time shadows.
## Command-line overrides (after "--"): --low-quality, --realistic, --stylised.

signal style_changed(style: int)

enum VisualStyle { STYLISED, REALISTIC }

const DEFAULT_PATH := "user://settings.cfg"

## Realistic is the default look (approved by the owner); Stylised stays available.
var visual_style := VisualStyle.REALISTIC
var low_quality := false
var story_mode := false
var config_path := DEFAULT_PATH


func _ready() -> void:
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
	return cfg.save(config_path)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(config_path) != OK:
		return
	visual_style = int(cfg.get_value("graphics", "visual_style", VisualStyle.REALISTIC))
	low_quality = bool(cfg.get_value("graphics", "low_quality", false))
	story_mode = bool(cfg.get_value("gameplay", "story_mode", false))


func apply_to_sun(sun: DirectionalLight3D) -> void:
	if sun:
		sun.shadow_enabled = not low_quality
