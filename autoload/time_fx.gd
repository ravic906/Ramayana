extends Node
## Central owner of Engine.time_scale. Systems request named slow-motion
## layers (draw focus, arrow cam, hit-stop); the slowest active layer wins
## and everything returns to normal speed when layers are cleared.

var _layers: Dictionary = {}


func set_layer(layer: StringName, scale: float) -> void:
	_layers[layer] = clampf(scale, 0.01, 1.0)
	_apply()


func clear_layer(layer: StringName) -> void:
	_layers.erase(layer)
	_apply()


func clear_all() -> void:
	_layers.clear()
	_apply()


func has_layer(layer: StringName) -> bool:
	return _layers.has(layer)


## Brief freeze on impact. Duration is in real (unscaled) seconds.
func hitstop(duration: float = 0.06, scale: float = 0.05) -> void:
	set_layer(&"hitstop", scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	clear_layer(&"hitstop")


func current_scale() -> float:
	return Engine.time_scale


## Converts a scaled delta back to real seconds.
func unscaled(delta: float) -> float:
	return delta / maxf(Engine.time_scale, 0.01)


func _apply() -> void:
	var s := 1.0
	for v: float in _layers.values():
		s = minf(s, v)
	Engine.time_scale = s


func _exit_tree() -> void:
	Engine.time_scale = 1.0
