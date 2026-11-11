class_name ShrinePuzzle
extends Node3D
## The forest shrine of Karusha's people (the Silent Forest, chapter II).
## Three bells hang from a beam: earth (low bronze), moon (silver), sun (small
## gold). The carved stone says: "The moon sets, the earth turns, the sun
## rises." Ring them in that order with arrows (moon, earth, sun) and the shrine
## wakes, and the thorns that choke the path fall away. A wrong bell silences
## them all and the order starts again.

signal solved
signal rung(bell: int, correct: bool)

## Bell indices (0 earth, 1 moon, 2 sun) in the order the carving gives.
const ORDER := [1, 0, 2]
const CARVING := "The moon sets, the earth turns, the sun rises."
const BELL_LOOK := [
	[0.32, Color(0.55, 0.38, 0.2)],   # earth: large, bronze
	[0.25, Color(0.8, 0.82, 0.86)],   # moon: silver
	[0.19, Color(1.0, 0.78, 0.3)],    # sun: small, gold
]

var bells: Array[StaticBody3D] = []
var progress := 0
var is_solved := false
var _sounds: Array[AudioStream] = []
var _wrong: AudioStream
var _lights: Array[OmniLight3D] = []


## Hangs the bells at the given world points (index 0 earth, 1 moon, 2 sun).
func setup(points: Array[Vector3]) -> void:
	for i in 3:
		_sounds.append(load("res://assets/audio/sfx/bell_%d.wav" % (i + 1)))
	_wrong = load("res://assets/audio/sfx/bell_wrong.wav")
	for i in points.size():
		var b := StaticBody3D.new()
		b.name = "Bell%d" % (i + 1)
		b.collision_layer = 1
		b.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = BELL_LOOK[i][0] + 0.12  # a little generous: they are high up
		cs.shape = shape
		b.add_child(cs)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = BELL_LOOK[i][1]
		mat.metallic = 0.9
		mat.roughness = 0.3
		var r: float = BELL_LOOK[i][0]
		var body := MeshInstance3D.new()
		body.mesh = MeshKit.cyl(r * 0.45, r, r * 1.4, 16)
		body.material_override = mat
		b.add_child(body)
		var crown := MeshInstance3D.new()
		crown.mesh = MeshKit.sphere(r * 0.45, 10)
		crown.position.y = r * 0.7
		crown.material_override = mat
		b.add_child(crown)
		var rope := MeshInstance3D.new()
		rope.mesh = MeshKit.cyl(0.015, 0.015, 0.5, 5)
		rope.position.y = r * 0.7 + 0.25
		rope.material_override = load("res://assets/materials/env/straw.tres")
		b.add_child(rope)
		# A Health that never empties: arrows report their hits through it.
		var h := Health.new()
		h.name = "Health"
		h.max_health = 1.0e9
		b.add_child(h)
		h.damaged.connect(func(_amount: float, _src: Node) -> void: ring(i))
		add_child(b)
		b.global_position = points[i]
		bells.append(b)


## A bell is struck (by an arrow, or a test).
func ring(i: int) -> void:
	if is_solved or i < 0 or i >= bells.size():
		return
	var b := bells[i]
	var t := create_tween()
	t.tween_property(b, "rotation:z", 0.35, 0.08)
	t.tween_property(b, "rotation:z", -0.22, 0.3).set_trans(Tween.TRANS_SINE)
	t.tween_property(b, "rotation:z", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	var correct: bool = ORDER[progress] == i
	_play(_sounds[i] if correct or progress == 0 else _wrong, b.global_position)
	if correct:
		progress += 1
		rung.emit(i, true)
		if progress >= ORDER.size():
			_wake()
	else:
		if progress > 0:
			_play(_wrong, b.global_position)
		progress = 1 if ORDER[0] == i else 0  # a wrong bell may itself begin the order
		rung.emit(i, false)


func _wake() -> void:
	is_solved = true
	for i in 3:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.75, 0.4)
		l.light_energy = 0.0
		l.omni_range = 6.0
		add_child(l)
		l.global_position = bells[i].global_position + Vector3.DOWN * 1.6
		create_tween().tween_property(l, "light_energy", 1.4, 2.0)
		_lights.append(l)
	solved.emit()


func _play(stream: AudioStream, at: Vector3) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.unit_size = 12.0
	add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)
