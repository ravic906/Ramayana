extends Node
## Cinematic, adaptive music. Each scene ("track") has cues: separate pieces
## for exploring and for combat (or boss phases), crossfaded as the action
## changes. Cues are seamless loops built by tools/fetch_music.py.
##   play(track)          crossfade to a scene's music
##   set_intensity(0..1)  explore <-> combat (with hysteresis, so it doesn't flap)
##   set_layer(name, on)  boss phases, e.g. Tataka's "maya"
##   stinger(name)        a one-shot cinematic hit over the music
##   duck(on)             dip under cutscenes; voices dip it further (voice_duck)
## Sound effects are routed to the SFX bus automatically.

const DIR := "res://assets/audio/music/"
const TRACKS := {
	"menu": {"explore": "menu"},
	"ayodhya": {"explore": "ayodhya", "combat": "trials_combat"},
	"forest": {"explore": "forest", "combat": "forest_combat"},
	"tataka": {"explore": "tataka", "maya": "tataka_maya"},
	"bloom": {"explore": "bloom"},
}
const STINGERS := ["sting_reveal", "sting_blessing"]
const SILENT_DB := -60.0
const CROSSFADE := 2.0
const INTO_COMBAT := 0.6     # fights hit fast
const OUT_OF_COMBAT := 3.0   # and settle slowly
const DUCK_DB := -6.0
const VOICE_DUCK_DB := -7.0
const STINGER_DUCK_DB := -9.0
const COMBAT_ON := 0.5
const COMBAT_OFF := 0.2

var current := ""   # scene track
var cue := ""       # piece playing now
var intensity := 0.0
var ducked := false
var voice_ducked := false

var _combat := false
var _layers := {}
var _player: AudioStreamPlayer
var _tween: Tween
var _stinger_duck := false
var _stinger_gen := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps playing while paused
	Settings.ensure_audio_buses()
	get_tree().node_added.connect(_route_sfx)


## Crossfades to a scene's music (no-op if it is already playing).
func play(track: String) -> void:
	if track == current or not TRACKS.has(track):
		return
	current = track
	intensity = 0.0
	_combat = false
	_layers.clear()
	_switch(_wanted_cue(), CROSSFADE)


func stop() -> void:
	current = ""
	_stinger_duck = false
	_stinger_gen += 1
	for c in get_children():
		if String(c.name).begins_with("stinger_"):
			c.queue_free()
	_switch("", CROSSFADE)


## 0 = exploring, 1 = full combat.
func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	if intensity >= COMBAT_ON:
		_combat = true
	elif intensity <= COMBAT_OFF:
		_combat = false
	var wanted := _wanted_cue()
	if wanted != cue:
		_switch(wanted, INTO_COMBAT if _combat else OUT_OF_COMBAT)


func set_layer(layer: String, on: bool) -> void:
	_layers[layer] = on
	var wanted := _wanted_cue()
	if wanted != cue:
		_switch(wanted, 1.2)


## A one-shot cinematic hit; the music steps back while it rings.
func stinger(name: String) -> void:
	var stream := load(DIR + name + ".ogg") as AudioStream
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	var p := AudioStreamPlayer.new()
	p.name = "stinger_" + name
	p.stream = stream
	p.bus = &"Music"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	_stinger_duck = true
	_stinger_gen += 1
	var gen := _stinger_gen
	_apply_volume(0.3)
	get_tree().create_timer(minf(stream.get_length(), 6.0), true, false, true).timeout.connect(func() -> void:
		if gen == _stinger_gen and _stinger_duck:
			_stinger_duck = false
			_apply_volume(1.5))


func duck(on: bool) -> void:
	if ducked != on:
		ducked = on
		_apply_volume(0.6)


func voice_duck(on: bool) -> void:
	if voice_ducked != on:
		voice_ducked = on
		_apply_volume(0.25 if on else 0.8)


## The volume the playing cue should sit at.
func target_db() -> float:
	var db := 0.0
	if ducked:
		db += DUCK_DB
	if voice_ducked:
		db += VOICE_DUCK_DB
	if _stinger_duck:
		db += STINGER_DUCK_DB
	return db


func player() -> AudioStreamPlayer:
	return _player


func _wanted_cue() -> String:
	if not TRACKS.has(current):
		return ""
	var t: Dictionary = TRACKS[current]
	for layer: String in _layers:
		if _layers[layer] and t.has(layer):
			return t[layer]
	if _combat and t.has("combat"):
		return t["combat"]
	return t["explore"]


func _switch(new_cue: String, seconds: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if _player:
		var old := _player
		old.name = "fading_" + old.name
		var t := create_tween()
		t.tween_property(old, "volume_db", SILENT_DB, seconds)
		t.tween_callback(old.queue_free)
		_player = null
	cue = new_cue
	if new_cue == "":
		return
	var stream := load(DIR + new_cue + ".ogg") as AudioStream
	if stream == null:
		push_warning("Music cue missing: " + new_cue)
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_player = AudioStreamPlayer.new()
	_player.name = new_cue
	_player.stream = stream
	_player.bus = &"Music"
	_player.volume_db = SILENT_DB
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_player.play()
	_apply_volume(seconds)


func _apply_volume(seconds: float) -> void:
	if _player == null:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", target_db(), seconds)


## Every other player (bow, impacts...) goes to the SFX bus; voices set their own.
func _route_sfx(node: Node) -> void:
	if node.get_parent() == self:
		return
	if node is AudioStreamPlayer and (node as AudioStreamPlayer).bus == &"Master":
		(node as AudioStreamPlayer).bus = &"SFX"
	elif node is AudioStreamPlayer3D and (node as AudioStreamPlayer3D).bus == &"Master":
		(node as AudioStreamPlayer3D).bus = &"SFX"
	elif node is AudioStreamPlayer2D and (node as AudioStreamPlayer2D).bus == &"Master":
		(node as AudioStreamPlayer2D).bus = &"SFX"
