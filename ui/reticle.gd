class_name Reticle
extends Control
## Archery reticle at the screen centre: the ring tightens as the string is
## drawn and turns gold during the perfect-release window. Also marks the
## aim-assist target.

var draw_amount := 0.0
var perfect := false
var weight := 0.0
var lock_position := Vector2.ZERO
var has_lock := false
var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_pulse += delta / maxf(Engine.time_scale, 0.01)
	queue_redraw()


func _draw() -> void:
	if weight <= 0.01:
		return
	var c := size * 0.5
	var a := weight
	var gold := Color(1.0, 0.82, 0.3, a)
	var white := Color(1.0, 1.0, 1.0, 0.85 * a)
	var col := gold if perfect else white
	var radius := lerpf(70.0, 16.0, draw_amount)
	if perfect:
		radius += sin(_pulse * 18.0) * 2.5
	draw_arc(c, radius, 0.0, TAU, 48, Color(0, 0, 0, 0.35 * a), 6.0, true)
	draw_arc(c, radius, 0.0, TAU, 48, col, 2.5, true)
	for i in 4:
		var dir := Vector2.from_angle(i * PI / 2.0 + PI / 4.0)
		draw_line(c + dir * (radius + 6.0), c + dir * (radius + 18.0), col, 2.5, true)
	draw_circle(c, 2.5, col)
	if draw_amount > 0.0:
		draw_arc(c, 90.0, -PI / 2.0, -PI / 2.0 + TAU * draw_amount, 64, Color(gold, 0.55 * a), 4.0, true)
	if has_lock:
		var s := 14.0 + sin(_pulse * 8.0) * 2.0
		var lc := Color(1.0, 0.35, 0.25, a)
		var pts := PackedVector2Array([lock_position + Vector2(0, -s), lock_position + Vector2(s, 0),
			lock_position + Vector2(0, s), lock_position + Vector2(-s, 0), lock_position + Vector2(0, -s)])
		draw_polyline(pts, lc, 2.5, true)
