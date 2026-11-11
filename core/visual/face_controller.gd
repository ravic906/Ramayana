class_name FaceController
extends Node
## Brings a character's face to life on the rig built by tools/face_rig_builder.gd:
## blinks, eye saccades and gaze, emotion presets, lip sync to the Voice autoload,
## and gameplay expressions (effort at the bow, a wince when struck).
##
## Add it as a child of a character model and call setup(skeleton). It does no
## work when the face is far from the camera, so crowds cost nothing.

## Shapes on the Head mesh and the Eyebrows mesh (ARKit-style names; a
## commissioned head only needs these shapes to plug in).
const HEAD_SHAPES := ["jaw_open", "mouth_smile", "mouth_frown", "mouth_wide", "mouth_round", "lips_press", "cheek_raise"]
const BROW_SHAPES := ["brow_raise", "brow_furrow", "brow_sad"]
const LID_OPEN_DEG := -58.0
## Faces further than this from the camera are left alone.
const ACTIVE_DISTANCE := 14.0

## Each emotion: blend shape weights, plus "lid" (0 open .. 1 closed) for a
## heavier or narrower look. Kept restrained: dignity first.
const EMOTIONS := {
	&"neutral": {},
	&"calm": {"mouth_smile": 0.1, "lid": 0.08},
	&"resolve": {"brow_furrow": 0.28, "lips_press": 0.35, "lid": 0.14},
	&"concern": {"brow_sad": 0.5, "brow_furrow": 0.2, "mouth_frown": 0.2, "lid": 0.05},
	&"grief": {"brow_sad": 0.9, "mouth_frown": 0.55, "lid": 0.32},
	&"anger": {"brow_furrow": 0.85, "lips_press": 0.5, "mouth_frown": 0.25, "lid": 0.2},
	&"fury": {"brow_furrow": 1.0, "mouth_wide": 0.6, "jaw_open": 0.22, "mouth_frown": 0.45, "lid": 0.1},
	&"smile": {"mouth_smile": 0.6, "cheek_raise": 0.45, "lid": 0.16},
	&"joy": {"mouth_smile": 0.9, "cheek_raise": 0.7, "jaw_open": 0.12, "brow_raise": 0.25, "lid": 0.2},
	&"reverence": {"brow_raise": 0.2, "brow_sad": 0.15, "mouth_smile": 0.14, "lid": 0.38},
	&"wonder": {"brow_raise": 0.75, "jaw_open": 0.12, "mouth_round": 0.2},
	&"pain": {"brow_furrow": 0.7, "brow_sad": 0.45, "mouth_wide": 0.5, "jaw_open": 0.14, "lid": 0.42},
	&"effort": {"brow_furrow": 0.6, "lips_press": 0.75, "lid": 0.25},
}

## Name used by the Voice autoload for this character's lines ("Rama", ...).
@export var speaker := ""
## The resting expression this character returns to.
@export var default_emotion: StringName = &"calm"

var emotion: StringName = &"calm"
## 0..1 effort laid over the emotion (Rama at full draw).
var effort := 0.0
## Where to look (world space). Null: straight ahead.
var look_target: Variant = null

var _head: MeshInstance3D
var _brows: MeshInstance3D
var _balls: Array[Node3D] = []
var _lids: Array[Node3D] = []
var _head_idx := {}
var _brow_idx := {}
var _weights := {}
var _blink := 0.0
var _blink_t := 0.0
var _next_blink := 3.0
var _double_blink := false
var _saccade := Vector2.ZERO
var _next_saccade := 1.0
var _gaze := Vector2.ZERO
var _wince := 0.0
var _talk_phase := 0.0
var _ready_rig := false
var _voice: Node  # the Voice autoload, looked up at run time (this script also loads in tools)


## Finds the rig parts under `skeleton`. Returns false if this body has no face rig.
func setup(skeleton: Skeleton3D) -> bool:
	_head = skeleton.get_node_or_null("Head") as MeshInstance3D
	_brows = skeleton.get_node_or_null("Eyebrows") as MeshInstance3D
	if _head == null or _head.mesh == null:
		return false
	for n in HEAD_SHAPES:
		_head_idx[n] = _head.find_blend_shape_by_name(n)
	if _brows and _brows.mesh:
		for n in BROW_SHAPES:
			_brow_idx[n] = _brows.find_blend_shape_by_name(n)
	for side in ["EyeL", "EyeR"]:
		var pivot := skeleton.get_node_or_null("HeadAttachment/" + side) as Node3D
		if pivot:
			_balls.append(pivot.get_node("Ball"))
			_lids.append(pivot.get_node("UpperLid"))
	emotion = default_emotion
	_voice = skeleton.get_node_or_null("/root/Voice")
	_next_blink = randf_range(1.0, 4.0)
	_ready_rig = true
	return true


## Sets the expression the face eases toward.
func set_emotion(e: StringName) -> void:
	emotion = e if EMOTIONS.has(e) else default_emotion


## A quick involuntary wince (when struck).
func wince() -> void:
	_wince = 1.0
	_blink = 1.0
	_blink_t = 0.0


## Current weight of a shape (for tests and debugging).
func weight(shape: String) -> float:
	return _weights.get(shape, 0.0)


func is_talking() -> bool:
	return speaker != "" and _voice != null and _voice.speaking and _voice.current_speaker == speaker


func _process(delta: float) -> void:
	if not _ready_rig or not is_instance_valid(_head):
		return
	var cam := get_viewport().get_camera_3d()
	if cam and not is_talking():
		var to := _head.global_position + Vector3.UP * 1.6 - cam.global_position
		if to.length_squared() > ACTIVE_DISTANCE * ACTIVE_DISTANCE or to.dot(-cam.global_transform.basis.z) < 0.0:
			return  # too far to read, or behind the camera
	_wince = move_toward(_wince, 0.0, delta * 2.5)
	_update_blink(delta)
	_update_gaze(delta)
	_update_shapes(delta)


func _update_blink(delta: float) -> void:
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink_t = 0.0
		_blink = 1.0
		if _double_blink:
			_double_blink = false
			_next_blink = randf_range(2.5, 6.0)
		else:
			_double_blink = randf() < 0.15
			_next_blink = 0.28 if _double_blink else randf_range(2.5, 6.0)
	# A blink: shut in ~70 ms, open in ~110 ms.
	_blink_t += delta
	var closed := 0.0
	if _blink > 0.0:
		closed = clampf(_blink_t / 0.07, 0.0, 1.0) if _blink_t < 0.07 else clampf(1.0 - (_blink_t - 0.07) / 0.11, 0.0, 1.0)
		if _blink_t > 0.18:
			_blink = 0.0
	var preset: Dictionary = EMOTIONS.get(emotion, {})
	var lid := maxf(closed, clampf(preset.get("lid", 0.0) + effort * 0.2 + _wince * 0.6, 0.0, 1.0))
	# Looking down, the lids follow the eyes a little.
	lid = clampf(lid + maxf(-_gaze.y, 0.0) * 0.6, 0.0, 1.0)
	for l in _lids:
		l.rotation.x = deg_to_rad(lerpf(LID_OPEN_DEG, 0.0, lid))


func _update_gaze(delta: float) -> void:
	_next_saccade -= delta
	if _next_saccade <= 0.0:
		_next_saccade = randf_range(0.4, 2.2)
		_saccade = Vector2(randf_range(-0.07, 0.07), randf_range(-0.04, 0.04))
	var want := _saccade
	if look_target is Vector3 and not _balls.is_empty():
		var pivot := _balls[0].get_parent() as Node3D
		var local := pivot.global_transform.affine_inverse() * (look_target as Vector3)
		var yaw := atan2(local.x, local.z)
		var pitch := atan2(local.y, Vector2(local.x, local.z).length())
		want += Vector2(clampf(yaw, -0.45, 0.45), clampf(pitch, -0.3, 0.3))
	# Saccades are fast; the eyes snap rather than drift.
	_gaze = _gaze.lerp(want, minf(delta * 22.0, 1.0))
	for b in _balls:
		b.rotation = Vector3(-_gaze.y, _gaze.x, 0.0)


func _update_shapes(delta: float) -> void:
	var target := {}
	var preset: Dictionary = EMOTIONS.get(emotion, {})
	for k in preset:
		if k != "lid":
			target[k] = preset[k]
	if effort > 0.0:
		for k in EMOTIONS[&"effort"]:
			if k != "lid":
				target[k] = maxf(target.get(k, 0.0), EMOTIONS[&"effort"][k] * effort)
	if _wince > 0.0:
		for k in EMOTIONS[&"pain"]:
			if k != "lid":
				target[k] = maxf(target.get(k, 0.0), EMOTIONS[&"pain"][k] * _wince)
	if is_talking():
		var level: float = _voice.mouth_level()
		_talk_phase += delta * 7.0
		# Speech overrides the mouth: open with the voice, shapes vary by syllable.
		target["lips_press"] = 0.0
		target["jaw_open"] = maxf(target.get("jaw_open", 0.0) * 0.5, level * 0.75)
		target["mouth_round"] = level * (0.25 + 0.25 * sin(_talk_phase * 1.3))
		target["mouth_wide"] = maxf(target.get("mouth_wide", 0.0), level * (0.2 + 0.2 * sin(_talk_phase * 0.7 + 1.0)))
	var rate := minf(delta * 9.0, 1.0)
	var fast := minf(delta * 22.0, 1.0)
	for k in HEAD_SHAPES + BROW_SHAPES:
		var cur: float = _weights.get(k, 0.0)
		var goal: float = target.get(k, 0.0)
		var nxt := lerpf(cur, goal, fast if k == "jaw_open" else rate)
		if absf(nxt - cur) < 0.0005 and absf(goal - nxt) < 0.0005:
			continue  # settled: no work for the renderer either
		cur = nxt
		_weights[k] = cur
		if _head_idx.get(k, -1) >= 0:
			_head.set_blend_shape_value(_head_idx[k], cur)
		elif _brow_idx.get(k, -1) >= 0:
			_brows.set_blend_shape_value(_brow_idx[k], cur)


## Puts `mat` on every skin surface of the rig (body, head, eyelids).
static func set_skin(skeleton: Skeleton3D, mat: Material) -> void:
	for n in ["Body", "Head", "Garment", "HeadAttachment/EyeL/UpperLid", "HeadAttachment/EyeR/UpperLid"]:
		var mi := skeleton.get_node_or_null(n) as MeshInstance3D
		if mi:
			mi.material_override = mat


## Puts `mat` on both eyeballs.
static func set_eyes(skeleton: Skeleton3D, mat: Material) -> void:
	for n in ["HeadAttachment/EyeL/Ball", "HeadAttachment/EyeR/Ball"]:
		var mi := skeleton.get_node_or_null(n) as MeshInstance3D
		if mi:
			mi.material_override = mat


## Adds a FaceController to `model` for the rig under `skeleton`.
static func attach(model: Node, skeleton: Skeleton3D, speaker_name: String, emotion_default: StringName = &"calm") -> FaceController:
	var f := FaceController.new()
	f.name = "Face"
	f.speaker = speaker_name
	f.default_emotion = emotion_default
	model.add_child(f)
	if not f.setup(skeleton):
		f.queue_free()
		return null
	return f
