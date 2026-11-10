class_name Explosion
extends RefCounted
## Astra detonation: area damage with falloff, burning, knockback, a burning
## ground patch, and the full spectacle (fireball, shockwave, light, sound,
## shake, hit-stop, haptics).

const SFX_EXPLOSION := preload("res://assets/audio/sfx/fire_explosion.wav")


## Returns the enemies that were hit.
static func detonate(parent: Node, at: Vector3, astra: AstraResource, source: Node) -> Array:
	var hit := []
	if parent == null or not parent.is_inside_tree():
		return hit
	if astra.effect == AstraResource.Effect.BANISH:
		# Manavastra: no wound, only a force that carries the foe far away.
		for enemy in parent.get_tree().get_nodes_in_group(&"enemies"):
			var e := enemy as Node3D
			if e and e.has_method("banish") and e.get_aim_point().distance_to(at) <= astra.radius:
				e.banish(source)
				hit.append(e)
		FX.burst(parent, at, astra.color, 60, 7.0, 1.2, 1.0, 0.0, false)
		FX.sparks(parent, at, astra.glow_color, 50, 9.0)
		_feedback(parent, 0.15, 200, 0.8)
		return hit
	# Skills: Deep Waters (Varuna reach), Agni's Wrath (burn), Gale (Vayu's force).
	var radius := astra.radius * (Skills.mult("water_radius") if astra.effect == AstraResource.Effect.WATER else 1.0)
	var burn_dps := astra.burn_dps * Skills.mult("burn")
	var knockback := astra.knockback * (Skills.mult("wind_knockback") if astra.effect == AstraResource.Effect.WIND else 1.0)
	for enemy in parent.get_tree().get_nodes_in_group(&"enemies"):
		var e := enemy as Node3D
		if e == null:
			continue
		var p: Vector3 = e.get_aim_point() if e.has_method("get_aim_point") else e.global_position
		var d := p.distance_to(at)
		if d > radius:
			continue
		var falloff := 1.0 - d / radius
		if e.has_method("on_astra"):
			e.on_astra(astra, source)  # e.g. Subahu, whom only the Agneyastra can end
		var h := e.get_node_or_null("Health") as Health
		if h:
			Health.from_astra = true
			h.take_damage(astra.impact_damage * lerpf(0.4, 1.0, falloff), source)
			Health.from_astra = false
		if astra.effect == AstraResource.Effect.FIRE:
			Burn.apply(e, burn_dps, astra.burn_duration, source)
		elif astra.effect == AstraResource.Effect.WATER and e.has_node("Burn"):
			e.get_node("Burn").queue_free()
		if e.has_method("apply_knockback"):
			var away := e.global_position - at
			away.y = 0.0
			e.apply_knockback(away.normalized() * knockback * (0.4 + 0.6 * falloff))
		hit.append(e)

	var ground := _ground_point(parent, at)
	_spectacle(parent, at, ground, astra)
	if astra.effect == AstraResource.Effect.WATER:
		# Varunastra quenches burning ground nearby.
		for node in parent.get_children():
			if node is FirePatch and (node as Node3D).global_position.distance_to(ground) < radius + (node as FirePatch).radius:
				node.queue_free()
	if astra.effect != AstraResource.Effect.FIRE:
		_feedback(parent, 0.08, 120, 0.7)
		return hit
	var patch := FirePatch.new()
	patch.radius = astra.radius * 0.6
	patch.dps = astra.patch_dps
	patch.duration = astra.patch_duration
	patch.burn_dps = burn_dps
	patch.source = source
	patch.position = (parent as Node3D).to_local(ground) if parent is Node3D else ground
	parent.add_child(patch)

	var tfx := parent.get_node_or_null("/root/TimeFX")
	if tfx:
		tfx.hitstop(0.12, 0.05)
	Haptics.pulse(160, 1.0)
	var cam := parent.get_viewport().get_camera_3d()
	var rig := cam.get_parent().get_parent() as FollowCamera if cam and cam.get_parent() else null
	if rig:
		rig.shake(0.9)
	return hit


static func _feedback(parent: Node, hitstop: float, haptic_ms: int, shake: float) -> void:
	var tfx := parent.get_node_or_null("/root/TimeFX")
	if tfx:
		tfx.hitstop(hitstop, 0.08)
	Haptics.pulse(haptic_ms, 0.9)
	var cam := parent.get_viewport().get_camera_3d()
	var rig := cam.get_parent().get_parent() as FollowCamera if cam and cam.get_parent() else null
	if rig:
		rig.shake(shake)


static func _ground_point(parent: Node, at: Vector3) -> Vector3:
	var space := (parent as Node3D).get_world_3d().direct_space_state if parent is Node3D else null
	if space:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 6.0, 1))
		if not hit.is_empty():
			return hit["position"]
	return Vector3(at.x, 0.0, at.z)


static func _spectacle(parent: Node, at: Vector3, ground: Vector3, astra: AstraResource) -> void:
	# Fireball.
	var ball := MeshInstance3D.new()
	ball.mesh = MeshKit.sphere(1.0, 16)
	var ball_mat := StandardMaterial3D.new()
	ball_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ball_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ball_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball_mat.albedo_color = Color(astra.color.lerp(astra.glow_color, 0.4), 0.55)
	ball.material_override = ball_mat
	parent.add_child(ball)
	ball.global_position = at
	ball.scale = Vector3.ONE * 0.3
	var t := ball.create_tween().set_parallel(true)
	t.tween_property(ball, "scale", Vector3.ONE * astra.radius * 0.5, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(ball_mat, "albedo_color", Color(astra.color, 0.0), 0.4)
	t.chain().tween_callback(ball.queue_free)

	# Shockwave ring along the ground.
	var ring := MeshInstance3D.new()
	ring.mesh = MeshKit.torus(0.92, 1.0, 32)
	var ring_mat := ball_mat.duplicate() as StandardMaterial3D
	ring_mat.albedo_color = Color(astra.glow_color, 0.7)
	ring.material_override = ring_mat
	parent.add_child(ring)
	ring.global_position = ground + Vector3.UP * 0.15
	ring.scale = Vector3(0.5, 0.3, 0.5)
	var rt := ring.create_tween().set_parallel(true)
	rt.tween_property(ring, "scale", Vector3(astra.radius * 1.4, 0.3, astra.radius * 1.4), 0.5).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring_mat, "albedo_color", Color(astra.color, 0.0), 0.5)
	rt.chain().tween_callback(ring.queue_free)

	# Flash of light.
	var light := OmniLight3D.new()
	light.light_color = astra.glow_color
	light.light_energy = 4.0
	light.omni_range = astra.radius * 3.0
	parent.add_child(light)
	light.global_position = at + Vector3.UP * 0.5
	var lt := light.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.7)
	lt.tween_callback(light.queue_free)

	if astra.effect == AstraResource.Effect.WATER:
		FX.burst(parent, at, astra.color, 80, 10.0, 0.35, 0.9, -9.0)
		FX.burst(parent, ground + Vector3.UP * 0.3, astra.glow_color, 40, 6.0, 0.6, 0.6, -4.0)
		_sound(parent, at, preload("res://assets/audio/sfx/impact.wav"), 0.6)
		_sound(parent, at, preload("res://assets/audio/sfx/whoosh.wav"), 0.5)
		return
	if astra.effect == AstraResource.Effect.WIND:
		FX.burst(parent, ground + Vector3.UP * 0.6, astra.color, 70, 14.0, 0.5, 0.8, 1.5)
		FX.burst(parent, ground + Vector3.UP * 0.3, Color(0.75, 0.65, 0.5, 0.6), 24, 8.0, 1.0, 1.0, 0.5, true)
		_sound(parent, at, preload("res://assets/audio/sfx/whoosh.wav"), 0.4)
		_sound(parent, at, preload("res://assets/audio/sfx/whoosh.wav"), 0.7)
		return
	# Flames, embers and smoke.
	FX.burst(parent, at, astra.color, 70, 9.0, 0.6, 0.7, 2.5)
	FX.burst(parent, at, astra.glow_color, 30, 5.0, 0.5, 0.5, 1.0)
	FX.sparks(parent, at, Color(1.0, 0.7, 0.25), 50, 11.0)
	FX.burst(parent, at + Vector3.UP * 0.8, Color(0.28, 0.22, 0.2, 0.4), 12, 2.0, 0.9, 1.4, 2.0, true)

	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = SFX_EXPLOSION
	sfx.volume_db = 4.0
	sfx.unit_size = 20.0
	parent.add_child(sfx)
	sfx.global_position = at
	sfx.play()
	sfx.finished.connect(sfx.queue_free)


static func _sound(parent: Node, at: Vector3, stream: AudioStream, pitch: float) -> void:
	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = stream
	sfx.pitch_scale = pitch
	sfx.volume_db = 4.0
	sfx.unit_size = 20.0
	parent.add_child(sfx)
	sfx.global_position = at
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
