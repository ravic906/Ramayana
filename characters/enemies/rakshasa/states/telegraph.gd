extends State
## Readable wind-up: the rakshasa growls and glows red, then the blow lands.
## It tracks Rama for the first part, then commits (so a dodge is rewarded).

var _t := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_t = 0.0
	(actor as Rakshasa).begin_wind_up()


func exit() -> void:
	(actor as Rakshasa).model.set_glow(0.0)


func physics_update(delta: float) -> void:
	var r := actor as Rakshasa
	_t += delta
	var k := _t / r.telegraph_time()
	r.model.set_glow(0.4 + 1.2 * k + sin(_t * 30.0) * 0.25)
	var face := r.flat_to_target() if (k < 0.6 and r.target != null) else Vector3.ZERO
	r.steer(Vector3.ZERO, 0.0, delta, face)
	if _t >= r.telegraph_time():
		r.perform_attack()
		machine.transition_to(&"Recover")
