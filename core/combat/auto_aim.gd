class_name AutoAim
extends RefCounted
## Mobile-friendly target selection: picks the enemy that best balances
## proximity and alignment with the player's facing direction.

const DISTANCE_WEIGHT := 0.6
const ALIGNMENT_WEIGHT := 0.4


## Returns a score in (0, 1], or -1.0 if the target is out of range or outside the cone.
static func score(origin: Vector3, facing: Vector3, target_pos: Vector3, max_range: float, cone_degrees: float) -> float:
	var to_target := target_pos - origin
	to_target.y = 0.0
	var dist := to_target.length()
	if dist > max_range:
		return -1.0
	var flat_facing := Vector3(facing.x, 0.0, facing.z)
	if flat_facing.length_squared() < 0.0001 or dist < 0.0001:
		return 1.0
	var alignment := flat_facing.normalized().dot(to_target / dist)
	var half_cone := deg_to_rad(cone_degrees * 0.5)
	if alignment < cos(half_cone):
		return -1.0
	var distance_score := 1.0 - dist / max_range
	var alignment_score := (alignment + 1.0) * 0.5
	return maxf(DISTANCE_WEIGHT * distance_score + ALIGNMENT_WEIGHT * alignment_score, 0.0001)


## Picks the best Node3D from candidates. Candidates may implement
## get_aim_point() -> Vector3; otherwise their global_position is used.
## Candidates with a dead Health child are skipped.
static func find_best_target(origin: Vector3, facing: Vector3, candidates: Array, max_range: float, cone_degrees: float) -> Node3D:
	var best: Node3D = null
	var best_score := -1.0
	for candidate in candidates:
		if not (candidate is Node3D) or not is_instance_valid(candidate):
			continue
		var health := (candidate as Node).get_node_or_null("Health") as Health
		if health != null and health.is_dead():
			continue
		var s := score(origin, facing, aim_point_of(candidate), max_range, cone_degrees)
		if s > best_score:
			best_score = s
			best = candidate
	return best


static func aim_point_of(target: Node3D) -> Vector3:
	if target.has_method("get_aim_point"):
		return target.get_aim_point()
	return target.global_position
