extends State
## Badly wounded, the rakshasa turns and runs. If Rama lets it go, it escapes
## into the forest and Rama's Dharma rises.

const ESCAPE_TIME := 4.0
const ESCAPE_DISTANCE := 26.0

var _t := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_t = 0.0
	var r := actor as Rakshasa
	r.release_attack_token()
	r.model.set_glow(0.0)
	r.model.anim.speed_scale = 1.0


func physics_update(delta: float) -> void:
	var r := actor as Rakshasa
	_t += delta
	var away := -r.flat_to_target() if r.target else Vector3.FORWARD
	r.steer(away, r.data.move_speed * 1.25, delta)
	r.model.play(&"run", 0.15, 1.2)
	if _t >= ESCAPE_TIME or (r.target and r.flat_to_target().length() > ESCAPE_DISTANCE):
		r.escape()
