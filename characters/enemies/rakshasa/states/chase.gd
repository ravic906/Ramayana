extends State
## Melee: close in and strike. Ranged: hold a standoff distance and strafe,
## loosing arrows when there is a clear line of sight.

var _strafe_timer := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_strafe_timer = randf_range(1.5, 3.0)


func physics_update(delta: float) -> void:
	var r := actor as Rakshasa
	if not r.target_alive():
		machine.transition_to(&"Idle")
		return
	var to_t := r.flat_to_target()
	var dist := to_t.length()
	var dir := to_t / maxf(dist, 0.001)
	var desired := Vector3.ZERO
	var speed := r.data.move_speed
	if r.is_ranged():
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = randf_range(1.5, 3.0)
			r.strafe_sign = -r.strafe_sign
		var side := dir.cross(Vector3.UP) * r.strafe_sign
		if dist > r.data.keep_distance + 2.0:
			desired = dir
		elif dist < r.data.keep_distance - 2.0:
			desired = -dir
		else:
			desired = side
			speed *= 0.6
	elif dist > r.data.attack_range * 0.85:
		desired = dir
	r.steer(desired, speed, delta, dir)
	r.model.play(&"idle" if desired == Vector3.ZERO else (&"walk" if speed < 3.0 else &"run"))

	var in_range := dist <= (r.data.attack_range if not r.is_ranged() else r.data.attack_range)
	if in_range and r.attack_cooldown_left <= 0.0 and (not r.is_ranged() or _has_line_of_sight(r)):
		if r.try_take_attack_token():
			machine.transition_to(&"Telegraph")


func _has_line_of_sight(r: Rakshasa) -> bool:
	var from := r.global_position + Vector3.UP * 1.5
	var to: Vector3 = r.target.global_position + Vector3.UP * 1.2
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return r.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
