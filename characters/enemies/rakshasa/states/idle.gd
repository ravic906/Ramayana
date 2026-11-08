extends State
## Waits until Rama is alive and within aggro range.


func enter(_msg: Dictionary = {}) -> void:
	(actor as Rakshasa).model.play(&"idle")


func physics_update(delta: float) -> void:
	var r := actor as Rakshasa
	r.steer(Vector3.ZERO, 0.0, delta)
	if r.target_alive() and r.flat_to_target().length() < r.aggro_range:
		machine.transition_to(&"Chase")
