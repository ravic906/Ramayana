extends State
## Drawing the Kodanda: slow strafe while the string tightens. Releasing the
## Bow button looses the arrow; dodging cancels the draw.


func enter(_msg: Dictionary = {}) -> void:
	(actor as Rama).begin_draw()


func exit() -> void:
	(actor as Rama).cancel_draw()


func physics_update(delta: float) -> void:
	var rama := actor as Rama
	var input := rama.get_move_input()
	var direction := rama.input_to_world(input)
	rama.apply_gravity(delta)
	rama.apply_horizontal(direction * rama.move_speed * rama.aim_move_factor * minf(input.length(), 1.0), delta)
	rama.move_and_slide()
	rama.update_draw(TimeFX.unscaled(delta))
	if Input.is_action_just_pressed(&"dodge") and rama.can_dodge():
		machine.transition_to(&"Dodge")
	elif not Input.is_action_pressed(&"shoot"):
		rama.release_draw()
		machine.transition_to(&"Move" if input.length() > 0.05 else &"Idle")
