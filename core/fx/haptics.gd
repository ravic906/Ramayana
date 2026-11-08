class_name Haptics
extends RefCounted
## Phone vibration helpers (no-ops on desktop). Android needs the VIBRATE
## permission, which is enabled in export_presets.cfg.

static var enabled := true


## strength 0..1 maps to vibration amplitude.
static func pulse(duration_ms: int, strength: float) -> void:
	if not enabled or not OS.has_feature("mobile"):
		return
	Input.vibrate_handheld(duration_ms, clampf(strength, 0.05, 1.0))
