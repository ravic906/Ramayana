extends State
## Rama standing still.


func physics_update(delta: float) -> void:
	var rama := actor as Rama
	rama.apply_gravity(delta)
	rama.apply_horizontal(Vector3.ZERO, delta)
	rama.move_and_slide()
	if rama.action_just_pressed(&"dodge") and rama.can_dodge():
		machine.transition_to(&"Dodge")
	elif rama.action_just_pressed(&"shoot") and rama.can_shoot():
		machine.transition_to(&"Aim")
	elif rama.get_move_input().length() > 0.05:
		machine.transition_to(&"Move")
