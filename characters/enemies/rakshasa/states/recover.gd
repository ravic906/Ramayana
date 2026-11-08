extends State
## Follow-through after an attack, then back to the chase.

var _t := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_t = 0.0


func exit() -> void:
	var r := actor as Rakshasa
	r.release_attack_token()
	r.attack_cooldown_left = r.data.attack_cooldown * randf_range(0.8, 1.25)


func physics_update(delta: float) -> void:
	var r := actor as Rakshasa
	_t += delta
	r.steer(Vector3.ZERO, 0.0, delta)
	if _t >= r.data.recover_time:
		machine.transition_to(&"Chase")
