class_name WaveSpawner
extends Node3D
## Spawns waves of rakshasas at its Marker3D children. Advances when a wave is
## cleared; restart_wave() resets the current wave (e.g. after Rama falls).

signal wave_started(index: int, total: int)
signal wave_cleared(index: int)
signal all_cleared
signal enemy_spawned(rakshasa: Rakshasa)

## Loaded on demand (not preloaded) so enemy data resources always resolve
## their script class first.
const SCENES := {
	"grunt": "res://characters/enemies/rakshasa/rakshasa_grunt.tscn",
	"archer": "res://characters/enemies/rakshasa/rakshasa_archer.tscn",
}

@export var auto_start := true
@export var start_delay := 3.0
@export var break_time := 4.0
@export var waves: Array[PackedStringArray] = [
	PackedStringArray(["grunt", "grunt", "grunt"]),
	PackedStringArray(["grunt", "grunt", "archer"]),
	PackedStringArray(["grunt", "grunt", "grunt", "grunt", "archer", "archer"]),
]

var current_wave := -1
var alive: Array[Rakshasa] = []
var finished := false
var _generation := 0


func _ready() -> void:
	if auto_start:
		start()


func start() -> void:
	current_wave = -1
	finished = false
	_queue_wave(0, start_delay)


## Cancels any wave queued to start (e.g. while an intro cutscene plays).
func hold() -> void:
	_generation += 1


func restart_wave() -> void:
	_clear_alive()
	_queue_wave(maxi(current_wave, 0), 2.0)


func spawn_points() -> Array[Marker3D]:
	var points: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D:
			points.append(child)
	return points


func spawn_wave(index: int) -> void:
	_generation += 1
	current_wave = index
	var points := spawn_points()
	var types := waves[index]
	for i in types.size():
		var point: Marker3D = points[i % points.size()]
		var offset := Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
		spawn_enemy(types[i], point.global_position + offset)
	wave_started.emit(index, waves.size())


func spawn_enemy(kind: String, at: Vector3) -> Rakshasa:
	var r := (load(SCENES[kind]) as PackedScene).instantiate() as Rakshasa
	# Place before entering the tree so it never overlaps anyone at the origin.
	var parent := get_parent() as Node3D
	r.position = parent.to_local(at) if parent else at
	get_parent().add_child(r)
	r.died.connect(_on_enemy_died)
	r.spared.connect(_on_enemy_died)
	alive.append(r)
	# Summoned in a burst of dark smoke.
	FX.burst(get_parent(), at + Vector3.UP * 0.8, Color(0.15, 0.05, 0.1, 0.8), 24, 3.0, 1.2, 1.0, 0.5, true)
	enemy_spawned.emit(r)
	return r


func _on_enemy_died(r: Rakshasa) -> void:
	alive.erase(r)
	if alive.is_empty() and current_wave >= 0 and not finished:
		wave_cleared.emit(current_wave)
		if current_wave + 1 < waves.size():
			_queue_wave(current_wave + 1, break_time)
		else:
			finished = true
			all_cleared.emit()


func _queue_wave(index: int, delay: float) -> void:
	_generation += 1
	var gen := _generation
	await get_tree().create_timer(delay, false).timeout
	if gen == _generation and is_inside_tree():
		spawn_wave(index)


func _clear_alive() -> void:
	for r in alive:
		if is_instance_valid(r):
			r.queue_free()
	alive.clear()
