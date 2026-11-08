extends State
## Camera-relative running; analog stick strength scales speed.


func physics_update(delta: float) -> void:
	var rama := actor as Rama
	var input := rama.get_move_input()
	var direction := rama.input_to_world(input)
	rama.apply_gravity(delta)
	rama.apply_horizontal(direction * rama.move_speed * minf(input.length(), 1.0), delta)
	rama.face_direction(direction, delta)
	rama.move_and_slide()
	if Input.is_action_just_pressed(&"dodge") and rama.can_dodge():
		machine.transition_to(&"Dodge")
	elif input.length() <= 0.05:
		machine.transition_to(&"Idle")
