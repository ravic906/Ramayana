extends State
## Rama has fallen: no control until he rises again at the spawn point.

var _t := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_t = 0.0
	(actor as Rama).die()


func physics_update(delta: float) -> void:
	var rama := actor as Rama
	_t += TimeFX.unscaled(delta)
	rama.apply_gravity(delta)
	rama.apply_horizontal(Vector3.ZERO, delta)
	rama.move_and_slide()
	if _t >= rama.respawn_delay:
		rama.respawn()
		machine.transition_to(&"Idle")
