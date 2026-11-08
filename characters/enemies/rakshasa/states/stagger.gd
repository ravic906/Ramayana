extends State
## Knocked off balance by a big hit: the attack is interrupted.

var _t := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_t = 0.0
	var r := actor as Rakshasa
	r.release_attack_token()
	r.model.set_glow(0.0)
	r.model.anim.speed_scale = 1.0
	r.model.play(&"hit", 0.05)


func physics_update(delta: float) -> void:
	var r := actor as Rakshasa
	_t += delta
	r.steer(Vector3.ZERO, 0.0, delta)
	if _t >= 0.6:
		machine.transition_to(&"Chase")
