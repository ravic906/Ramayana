class_name Arrow
extends Node3D
## Straight-flying projectile. Each physics frame it ray-sweeps the segment it
## travels, so fast arrows never tunnel through thin targets, and it damages
## the first collider that has a Health child.

@export var speed := 40.0
@export var damage := 10.0
@export var lifetime := 2.0
## Layers 1 (world) and 3 (enemies).
@export_flags_3d_physics var collision_mask := 5

var direction := Vector3.FORWARD
var shooter: Node = null
var _age := 0.0


func launch(dir: Vector3, from: Node, dmg: float = damage) -> void:
	direction = dir.normalized()
	shooter = from
	damage = dmg
	if direction.length_squared() > 0.0:
		look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.FORWARD)


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	query.collide_with_areas = true
	if shooter is CollisionObject3D:
		query.exclude = [(shooter as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"]
		_on_hit(hit["collider"])
		return
	global_position = to
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_hit(other: Object) -> void:
	if other is Node:
		var health := (other as Node).get_node_or_null("Health") as Health
		if health != null:
			health.take_damage(damage, shooter)
	queue_free()
