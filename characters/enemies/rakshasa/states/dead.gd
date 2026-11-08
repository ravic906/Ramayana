extends State
## Falls, lingers, sinks into the ground, then frees itself.

var _t := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_t = 0.0
	var r := actor as Rakshasa
	r.model.set_glow(0.0)
	r.model.anim.speed_scale = 1.0
	r.model.play(&"death", 0.1)


func physics_update(delta: float) -> void:
	var r := actor as Rakshasa
	_t += delta
	r.velocity = Vector3.ZERO
	if _t > 2.2:
		r.model.position.y -= delta * 0.8
	if _t > 3.6:
		r.queue_free()
