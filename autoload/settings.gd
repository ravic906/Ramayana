extends Node
## Player-facing quality settings (UI comes later). Low quality turns off
## ambient life (birds, dust) and real-time shadows for older phones.

var low_quality := false


func _ready() -> void:
	# Allow forcing from the command line: --low-quality (after "--").
	low_quality = "--low-quality" in OS.get_cmdline_user_args()


func apply_to_sun(sun: DirectionalLight3D) -> void:
	if sun:
		sun.shadow_enabled = not low_quality
