extends State
## Quick dodge roll with invulnerability frames.

var _direction := Vector3.ZERO
var _time_left := 0.0


func enter(_msg: Dictionary = {}) -> void:
	var rama := actor as Rama
	var input := rama.get_move_input()
	_direction = rama.input_to_world(input) if input.length() > 0.05 else rama.get_facing()
	_time_left = rama.dodge_duration
	rama.health.invulnerable = true
	rama.face_direction(_direction, 1.0)
	if rama.model != null:
		rama.model.play_roll(rama.dodge_duration)


func exit() -> void:
	var rama := actor as Rama
	rama.health.invulnerable = false
	rama.start_dodge_cooldown()


func physics_update(delta: float) -> void:
	var rama := actor as Rama
	_time_left -= delta
	rama.apply_gravity(delta)
	var h := _direction * rama.dodge_speed
	rama.velocity.x = h.x
	rama.velocity.z = h.z
	rama.move_and_slide()
	if _time_left <= 0.0:
		machine.transition_to(&"Move" if rama.get_move_input().length() > 0.05 else &"Idle")
