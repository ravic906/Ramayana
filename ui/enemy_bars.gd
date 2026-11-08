class_name EnemyBars
extends Control
## Small health bars above wounded rakshasas (orange while burning).


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for node in get_tree().get_nodes_in_group(&"enemies"):
		var r := node as Rakshasa
		if r == null or r.health.current >= r.health.max_health:
			continue
		var head := r.global_position + Vector3.UP * 2.35 * r.data.model_scale
		if cam.is_position_behind(head) or cam.global_position.distance_to(head) > 40.0:
			continue
		var p := cam.unproject_position(head) - global_position
		var w := 76.0
		var rect := Rect2(p - Vector2(w * 0.5, 0), Vector2(w, 9))
		draw_rect(rect.grow(2.0), Color(0, 0, 0, 0.6))
		var fill := Color(1.0, 0.55, 0.1) if r.has_node("Burn") else Color(0.85, 0.12, 0.1)
		draw_rect(Rect2(rect.position, Vector2(w * r.health.ratio(), rect.size.y)), fill)
